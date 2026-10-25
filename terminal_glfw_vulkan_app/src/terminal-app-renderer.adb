with Ada.Unchecked_Deallocation;
with Ada.Real_Time;
with Interfaces;
with System;

with Terminal.Common;
with Terminal.Common.Bytes;
with Terminal.Common.Status;
with Terminal.App.Fonts;
with Terminal.App.Graphics;
with Terminal.App.Graphics_Transport;
with Terminal.App.Frame_Image_Storage;
with Terminal.App.Image_Animation;
with Terminal.App.Image_Colors;
with Terminal.App.Image_Ingestion;
with Terminal.App.Image_Media;
with Terminal.App.Image_Store;
with Terminal.App.Image_Placements;
with Terminal.App.Image_Rendering;
with Terminal.App.ITerm2_Files;
with Terminal.App.Hyperlinks;
with Terminal.App.Render_Model;
with Terminal.App.Text_Shaper;
with Terminal.App.Theme;
with Terminal.App.Vulkan_Submit;

package body Terminal.App.Renderer is
   package RM renames Terminal.App.Render_Model;
   package VS renames Terminal.App.Vulkan_Submit;
   package FIS renames Terminal.App.Frame_Image_Storage;

   use type Terminal.Core.Cell_Kind;
   use type Terminal.App.ITerm2_Files.Save_Status;
   use type Terminal.App.Image_Media.Decode_Status;
   use type Terminal.App.Image_Store.Animation_Playback_State;
   use type Terminal.App.Image_Store.Image_Frame_Access;
   use type Terminal.App.Image_Store.Image_Object_Access;
   use type Terminal.App.Image_Store.Theme_Operation_Access;
   use type Terminal.App.Image_Placements.Virtual_Placement_Access;
   use type Terminal.App.Image_Placements.Conventional_Placement_Access;
   use type Terminal.Core.Cell_Width;
   use type Terminal.Core.Color_Kind;
   use type Terminal.Core.Cursor_Shape;
   use type Terminal.Core.Dirty_Row_Array_Access;
   use type Terminal.Core.Ignored_Graphics_Protocol;
   use type Terminal.Core.Graphics_ID;
   use type Terminal.Core.Graphics_Stream_ID;
   use type Terminal.Core.Graphics_Screen_Generation;
   use type Terminal.Core.Graphics_Event_Sequence;
   use type Terminal.Core.Graphics_Transaction_Generation;
   use type Terminal.Core.Graphics_Scroll_Sequence;
   use type Terminal.Core.Graphics_Scroll_Direction;
   use type Terminal.Core.Graphics_Scroll_Event_Array_Access;
   use type Terminal.Core.Kitty_Graphics_Result_Code;
   use type Terminal.Core.Style;
   use type Terminal.Common.Code_Point;
   use type Terminal.App.Splits.Split_Orientation;
   use type Terminal.App.Graphics.Data_Decode_Status;
   use type Terminal.App.Graphics.ITerm2_Size_Unit;
   use type Terminal.App.Graphics_Transport.Load_Status;
   use type Terminal.App.Graphics_Transport.Byte_Array_Access;
   use type Interfaces.Unsigned_64;
   use type Interfaces.Unsigned_32;
   use type Ada.Real_Time.Time;
   use type RM.Colour_Glyph_Array_Access;
   use type RM.Glyph_Array_Access;
   use type RM.Image_Array_Access;
   use type RM.Image_Array_View;
   use type RM.Image_Data_Access;
   use type RM.Image_Data_View;
   use type RM.Image_Protocol;
   use type RM.Rectangle_Array_Access;
   use type RM.Text_Run_Array_Access;
   use type RM.Text_Run_Direction;
   use type RM.Text_Run_Script;
   use type RM.Text_Run_Shape_Status;
   use type Textrender.Status_Code;
   use type VS.Build_Status;

   Pixel_Size   : constant Positive := 16;
   Atlas_Width  : constant Positive := 1024;
   Atlas_Height : constant Positive := 1024;
   Max_Link_Overlay_Chars : constant Natural := 96;
   Tab_Bar_Rows : constant Natural := 1;
   Pane_Border_Pixels : constant Natural := 2;

   function Origin_X (R : Renderer) return Natural is
     (R.Draw_Offset_X + Content_Margin);

   function Origin_Y (R : Renderer) return Natural is
     (R.Draw_Offset_Y + Content_Margin);

   function Trimmed_Natural (Value : Natural) return String is
      Text : constant String := Natural'Image (Value);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Trimmed_Natural;

   function Bounded_Status_Label (Text : String) return String is
     (if Text'Length <= Max_Status_Label_Length
      then Text
      else Text (Text'First .. Text'First + Max_Status_Label_Length - 1));

   procedure Clear_Last_Media_Diagnostics (R : in out Renderer) is
   begin
      Terminal.App.Image_Rendering.Clear (R.Last_Media);
   end Clear_Last_Media_Diagnostics;

   function Stored_Image_Count (R : Renderer) return Natural is
     (Terminal.App.Image_Store.Object_Count (R.Image_Objects));

   function Stored_Image_Bytes (R : Renderer) return Natural is
     (Terminal.App.Image_Store.Byte_Count (R.Image_Objects));

   function Allocation_Length (Data : RM.Image_Data_Access) return Natural is
     (if Data = null then 0 else Data'Length);

   function Allocation_Length (Data : RM.Image_Data_View) return Natural is
     (if Data = null then 0 else Data'Length);

   function Stored_Animation_Frame_Count (R : Renderer) return Natural is
     (Terminal.App.Image_Store.Animation_Frame_Count (R.Image_Objects));

   procedure Free_Rectangles is new Ada.Unchecked_Deallocation
     (RM.Rectangle_Array, RM.Rectangle_Array_Access);
   procedure Free_Glyphs is new Ada.Unchecked_Deallocation
     (RM.Glyph_Array, RM.Glyph_Array_Access);
   procedure Free_Text_Runs is new Ada.Unchecked_Deallocation
     (RM.Text_Run_Array, RM.Text_Run_Array_Access);
   procedure Free_Colour_Glyphs is new Ada.Unchecked_Deallocation
     (RM.Colour_Glyph_Array, RM.Colour_Glyph_Array_Access);
   procedure Free_Shaped_Run_Map is new Ada.Unchecked_Deallocation
     (Shaped_Run_Map_Array, Shaped_Run_Map_Array_Access);
   procedure Free_Image_Data is new Ada.Unchecked_Deallocation
     (Terminal.Common.Bytes.Byte_Array, RM.Image_Data_Access);
   procedure Free_String is new Ada.Unchecked_Deallocation
     (String, String_Access);
   procedure Free_Virtual_Placement is new Ada.Unchecked_Deallocation
     (Virtual_Placement, Virtual_Placement_Access);
   procedure Free_Conventional_Placement is new Ada.Unchecked_Deallocation
     (Conventional_Placement, Conventional_Placement_Access);
   procedure Free_Staged_Graphics_Event is new Ada.Unchecked_Deallocation
     (Staged_Graphics_Event, Staged_Graphics_Event_Access);
   procedure Free_Sixel_Palette_Entry is new Ada.Unchecked_Deallocation
     (Sixel_Palette_Entry, Sixel_Palette_Entry_Access);

   function Frame_Image_Count (R : Renderer) return Natural is
     (FIS.Count (R.Frame_Images));

   function Frame_Image_Commands
     (R : Renderer) return RM.Image_Array_View is
     (FIS.Commands (R.Frame_Images));

   function Frame_Image_Capacity (R : Renderer) return Natural is
     (FIS.Capacity (R.Frame_Images));

   procedure Append_Image_Command
     (R       : in out Renderer;
      Command : RM.Image_Command) is
   begin
      FIS.Append (R.Frame_Images, Command);
   end Append_Image_Command;

   procedure Append_Image_Command
     (R       : in out Renderer;
      Command : RM.Image_Command;
      Decoded : in out RM.Image_Data_Access;
      Encoded : in out RM.Image_Data_Access;
      Preview : in out RM.Image_Data_Access) is
   begin
      FIS.Append (R.Frame_Images, Command, Decoded, Encoded, Preview);
   end Append_Image_Command;

   procedure Truncate_Image_Commands
     (R         : in out Renderer;
      New_Count : Natural) is
   begin
      FIS.Truncate (R.Frame_Images, New_Count);
   end Truncate_Image_Commands;

   function Sixel_Palette_For
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID)
      return Sixel_Palette_Entry_Access
   is
      Current : Sixel_Palette_Entry_Access := R.Sixel_Palettes;
   begin
      while Current /= null loop
         if Current.Stream_ID = Stream_ID then
            return Current;
         end if;
         Current := Current.Next;
      end loop;
      Current := new Sixel_Palette_Entry'
        (Stream_ID => Stream_ID,
         Palette   => Terminal.App.Graphics.Default_Sixel_Palette,
         Next      => R.Sixel_Palettes);
      R.Sixel_Palettes := Current;
      return Current;
   exception
      when Storage_Error =>
         return null;
   end Sixel_Palette_For;

   function Find_Staged_Graphics_Event
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event)
      return Staged_Graphics_Event_Access
   is
      Current : Staged_Graphics_Event_Access := R.Staged_Graphics_Events;
   begin
      while Current /= null loop
         if Current.Stream_ID = Event.Stream_ID
           and then Current.Sequence = Event.Sequence
         then
            return Current;
         end if;
         Current := Current.Next;
      end loop;
      return null;
   end Find_Staged_Graphics_Event;

   procedure Stage_Graphics_Event
     (R       : in out Renderer;
      Event   : Terminal.Core.Graphics_Event;
      Payload : String)
   is
      Existing : constant Staged_Graphics_Event_Access :=
        Find_Staged_Graphics_Event (R, Event);
      Item : Staged_Graphics_Event_Access := null;
   begin
      if R.Closed
        or else not Event.Pending
        or else Payload'Length /= Event.Payload_Length
        or else Existing /= null
      then
         return;
      end if;
      Item := new Staged_Graphics_Event'
        (Stream_ID => Event.Stream_ID,
         Sequence  => Event.Sequence,
         Payload   => new String'(Payload),
         Next      => R.Staged_Graphics_Events);
      R.Staged_Graphics_Events := Item;
   exception
      when Storage_Error =>
         if Item /= null then
            if Item.Payload /= null then
               Free_String (Item.Payload);
            end if;
            Free_Staged_Graphics_Event (Item);
         end if;
   end Stage_Graphics_Event;

   function Complete_Event_Text
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event) return String
   is
      Staged : constant Staged_Graphics_Event_Access :=
        Find_Staged_Graphics_Event (R, Event);
   begin
      if Staged /= null and then Staged.Payload /= null then
         return Staged.Payload.all;
      elsif Event.Preview_Length = 0 then
         return "";
      else
         return Event.Preview (1 .. Event.Preview_Length);
      end if;
   end Complete_Event_Text;

   function Ceiling_Positive (Value : Float) return Positive is
      Result : Positive := 1;
   begin
      while Float (Result) < Value loop
         Result := Result + 1;
      end loop;
      return Result;
   end Ceiling_Positive;

   function Measured_Cell_Width
     (Text     : in out Textrender.Renderer;
      Fallback : Positive)
      return Positive
   is
      Max_Width : Float := Float (Fallback);
   begin
      for C in Character'Pos (' ') .. Character'Pos ('~') loop
         declare
            Metric : Textrender.Glyph_Metric;
            Status : constant Textrender.Status_Code :=
              Textrender.Get_Glyph
                (R => Text,
                 C => Textrender.Codepoint (C),
                 M => Metric);
         begin
            if Status = Textrender.Success or else Status = Textrender.Glyph_Missing then
               declare
                  Right_Edge : constant Float :=
                    Metric.Bearing_X + Float (Metric.W);
               begin
                  Max_Width := Float'Max (Max_Width, Right_Edge);
               end;
               Max_Width := Float'Max (Max_Width, Metric.Advance_X);
            end if;
         end;
      end loop;

      return Ceiling_Positive (Max_Width) + 1;
   end Measured_Cell_Width;

   function Is_Emoji_Scalar (Codepoint : Terminal.Common.Code_Point) return Boolean is
      C : constant Natural := Natural (Codepoint);
   begin
      return (C in 16#1F000# .. 16#1FAFF#)
        or else (C in 16#2600# .. 16#27BF#);
   end Is_Emoji_Scalar;

   function Colour_PNG_Extent
     (Data   : Textrender.Encoded_Image;
      Width  : out Natural;
      Height : out Natural)
      return Boolean
   is
      Result : Terminal.App.Graphics.Graphics_Data_Preview;
   begin
      Width := 0;
      Height := 0;

      if Data'Length = 0 then
         return False;
      end if;

      declare
         Source : Terminal.Common.Bytes.Byte_Array (1 .. Data'Length);
      begin
         for I in Data'Range loop
            Source (I - Data'First + 1) :=
              Terminal.Common.Bytes.Byte (Data (I));
         end loop;

         Terminal.App.Graphics.Decode_PNG_RGBA_Data
           (PNG    => Source,
            Length => Source'Length,
            Result => Result);
      end;

      Width := Result.Pixel_Width;
      Height := Result.Pixel_Height;
      Terminal.App.Graphics.Release (Result);

      return Width > 0 and then Height > 0;
   exception
      when Storage_Error | Constraint_Error =>
         Width := 0;
         Height := 0;
         Terminal.App.Graphics.Release (Result);
         return False;
      when others =>
         Terminal.App.Graphics.Release (Result);
         raise;
   end Colour_PNG_Extent;

   function Decode_Colour_PNG
     (Data   : Textrender.Encoded_Image;
      Width  : Natural;
      Height : Natural;
      Pixels : out Textrender.Rgba_Buffer)
      return Boolean
   is
      Result : Terminal.App.Graphics.Graphics_Data_Preview;
   begin
      if Data'Length = 0
        or else Width = 0
        or else Height = 0
        or else Pixels'Length /= Width * Height * 4
      then
         return False;
      end if;

      declare
         Source : Terminal.Common.Bytes.Byte_Array (1 .. Data'Length);
      begin
         for I in Data'Range loop
            Source (I - Data'First + 1) :=
              Terminal.Common.Bytes.Byte (Data (I));
         end loop;

         Terminal.App.Graphics.Decode_PNG_RGBA_Data
           (PNG    => Source,
            Length => Source'Length,
            Result => Result);
      end;

      if Result.Decode_Status /= Terminal.App.Graphics.Decode_Ok
        or else not Result.Decode_Complete
        or else Result.Pixel_Width /= Width
        or else Result.Pixel_Height /= Height
        or else Result.Decoded_Length /= Pixels'Length
        or else Result.Bytes = null
      then
         Terminal.App.Graphics.Release (Result);
         return False;
      end if;

      for I in Pixels'Range loop
         Pixels (I) :=
           Textrender.Alpha
             (Result.Bytes (Result.Bytes'First + I - Pixels'First));
      end loop;

      Terminal.App.Graphics.Release (Result);
      return True;
   exception
      when Storage_Error | Constraint_Error =>
         Terminal.App.Graphics.Release (Result);
         return False;
      when others =>
         Terminal.App.Graphics.Release (Result);
         raise;
   end Decode_Colour_PNG;

   function XTerm_Indexed_Color
     (R     : Renderer;
      Index : Natural) return RM.Pixel_Color is
     (Terminal.App.Image_Colors.XTerm_Indexed (R.Color_Theme, Index));

   function Kitty_Indexed_Color
     (R     : Renderer;
      Index : Natural) return RM.Pixel_Color is
     (Terminal.App.Image_Colors.Kitty_Indexed (R.Color_Theme, Index));

   function Color_Byte (Value : Float) return Terminal.Common.Bytes.Byte
      renames Terminal.App.Image_Colors.Color_Byte;

   function Expand_Kitty_Indexed
     (R            : Renderer;
      Indexed_Format : Natural;
      Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Source       : RM.Image_Data_View;
      Target       : RM.Image_Data_Access) return Boolean
   is (Terminal.App.Image_Colors.Expand_Kitty_Indexed
         (R.Color_Theme,
          Indexed_Format,
          Pixel_Width,
          Pixel_Height,
          Source,
          Target));

   function Resolve_Color
     (R          : Renderer;
      Color      : Terminal.Core.Color;
      Default    : RM.Pixel_Color)
      return RM.Pixel_Color
   is
   begin
      case Color.Kind is
         when Terminal.Core.Default =>
            return Default;
         when Terminal.Core.Indexed =>
            return XTerm_Indexed_Color (R, Color.Index);
         when Terminal.Core.RGB =>
            return
              (R => Float (Color.R) / 255.0,
               G => Float (Color.G) / 255.0,
               B => Float (Color.B) / 255.0,
               A => 1.0);
      end case;
   end Resolve_Color;

   function Dim_Color (Color : RM.Pixel_Color) return RM.Pixel_Color is
      Scale : constant Float := 0.55;
   begin
      return
        (R => Color.R * Scale,
         G => Color.G * Scale,
         B => Color.B * Scale,
         A => Color.A);
   end Dim_Color;

   function Foreground
     (R    : Renderer;
      Cell : Terminal.Core.Cell) return RM.Pixel_Color
   is
      Color : RM.Pixel_Color;
   begin
      if (not Cell.Style.Inverse)
        and then Cell.Style.Bold
        and then Cell.Style.Foreground.Kind = Terminal.Core.Indexed
        and then Cell.Style.Foreground.Index <= 7
      then
         Color := XTerm_Indexed_Color (R, Cell.Style.Foreground.Index + 8);
      elsif Cell.Style.Inverse then
         Color := Resolve_Color (R, Cell.Style.Background, R.Color_Theme.Default_BG);
      else
         Color := Resolve_Color (R, Cell.Style.Foreground, R.Color_Theme.Default_FG);
      end if;

      if Cell.Style.Faint then
         return Dim_Color (Color);
      else
         return Color;
      end if;
   end Foreground;

   function Background
     (R    : Renderer;
      Cell : Terminal.Core.Cell) return RM.Pixel_Color
   is
   begin
      if Cell.Style.Inverse then
         return Resolve_Color (R, Cell.Style.Foreground, R.Color_Theme.Default_FG);
      else
         return Resolve_Color (R, Cell.Style.Background, R.Color_Theme.Default_BG);
      end if;
   end Background;

   function Has_Non_Default_Background
     (Cell : Terminal.Core.Cell) return Boolean is
     (Cell.Style.Inverse
      or else Cell.Style.Background.Kind /= Terminal.Core.Default);

   function Underline_Color
     (R          : Renderer;
      Cell       : Terminal.Core.Cell;
      Foreground : RM.Pixel_Color)
      return RM.Pixel_Color
   is
   begin
      return Resolve_Color (R, Cell.Style.Underline_Color, Foreground);
   end Underline_Color;

   function Is_Cursor_Cell
     (Snapshot : Terminal.Core.Render_Snapshot;
      Row      : Positive;
      Col      : Positive)
      return Boolean
   is
   begin
      return Snapshot.Cursor.Visible
        and then Snapshot.Cursor.Row = Row
        and then Snapshot.Cursor.Col = Col;
   end Is_Cursor_Cell;

   function Cursor_Block_Height (R : Renderer) return Positive is
   begin
      return Positive'Min (R.CH, Pixel_Size);
   end Cursor_Block_Height;

   function Cursor_Block_Y (R : Renderer; Cell_Y : Float) return Float is
   begin
      return Cell_Y + Float (R.CH - Cursor_Block_Height (R)) / 2.0;
   end Cursor_Block_Y;

   function Cursor_Bar_Width (R : Renderer) return Positive is
   begin
      return Positive'Max (1, Positive'Min (3, R.CW));
   end Cursor_Bar_Width;

   function Cursor_Underline_Height (R : Renderer) return Positive is
   begin
      return Positive'Max (1, Positive'Min (3, R.CH));
   end Cursor_Underline_Height;

   function Is_Block_Cursor
     (Snapshot : Terminal.Core.Render_Snapshot;
      Row      : Positive;
      Col      : Positive)
      return Boolean
   is
   begin
      return Is_Cursor_Cell (Snapshot, Row, Col)
        and then Snapshot.Cursor.Shape = Terminal.Core.Cursor_Block;
   end Is_Block_Cursor;

   function Cell_Column_Span (Cell : Terminal.Core.Cell) return Positive is
     (if Cell.Text.Width = Terminal.Core.Width_Two then 2 else 1);

   function Is_Hovered_Link_Cell
     (R    : Renderer;
      Cell : Terminal.Core.Cell) return Boolean is
     (Cell.Link.Active
      and then Terminal.App.Hyperlinks.Same_Link (Cell.Link, R.Hovered_Link));

   procedure Set_Render_Status
     (R      : in out Renderer;
      Status : out Render_Status;
      Value  : Render_Status) is
   begin
      R.Last_Render_Status := Value;
      Status := Value;
   end Set_Render_Status;

   procedure Reset_Frame (R : in out Renderer) is separate;

   procedure Release_Frame (R : in out Renderer) is separate;

   function Grown_Capacity
     (Current  : Natural;
      Required : Positive) return Positive
   is
   begin
      if Current >= Required then
         return Positive (Current);
      elsif Current = 0 then
         return Required;
      elsif Current <= Natural'Last / 2 then
         return Positive'Max (Required, Positive (Current * 2));
      else
         return Required;
      end if;
   end Grown_Capacity;

   procedure Ensure_Frame_Capacity
     (R               : in out Renderer;
      Rectangle_Count : Positive;
      Glyph_Count     : Positive;
      Colour_Count    : Positive;
      Image_Count     : Positive;
      Text_Run_Count  : Positive;
      Success         : out Boolean) is separate;

   function Find_Virtual_Placement
     (R            : Renderer;
      Stream_ID    : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
      Image_ID     : Terminal.Core.Graphics_ID;
      Placement_ID : Terminal.Core.Graphics_ID)
      return Virtual_Placement_Access
   is
      Current : Virtual_Placement_Access := R.Virtual_Placements;
   begin
      --  As for conventional placements, p=0 is implicit rather than an
      --  addressable placement identity.  Repeated puts with p omitted or
      --  zero must therefore create independent virtual prototypes.
      if Placement_ID = 0 then
         return null;
      end if;

      while Current /= null loop
         if Current.Stream_ID = Stream_ID
           and then Current.Alternate_Screen = Alternate_Screen
           and then Current.Screen_Generation = Screen_Generation
           and then Current.Image_ID = Image_ID
           and then Current.Placement_ID = Placement_ID
         then
            return Current;
         end if;
         Current := Current.Next;
      end loop;
      return null;
   end Find_Virtual_Placement;

   function Find_Addressed_Virtual_Placement
     (R            : Renderer;
      Stream_ID    : Terminal.Core.Graphics_Stream_ID;
      Image_ID     : Terminal.Core.Graphics_ID;
      Placement_ID : Terminal.Core.Graphics_ID)
      return Virtual_Placement_Access
   is
      Current : Virtual_Placement_Access := R.Virtual_Placements;
   begin
      --  A nonzero placement ID identifies the (image, placement) pair for
      --  the whole graphics stream.  Screen ownership controls visibility
      --  and lifetime, but is not part of the protocol identity.
      if Placement_ID = 0 then
         return null;
      end if;

      while Current /= null loop
         if Current.Stream_ID = Stream_ID
           and then Current.Image_ID = Image_ID
           and then Current.Placement_ID = Placement_ID
         then
            return Current;
         end if;
         Current := Current.Next;
      end loop;
      return null;
   end Find_Addressed_Virtual_Placement;

   function Find_Virtual_Placement_For_Cell
     (R            : Renderer;
      Stream_ID    : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
      Image_ID     : Terminal.Core.Graphics_ID;
      Placement_ID : Terminal.Core.Graphics_ID)
      return Virtual_Placement_Access
   is
      Current : Virtual_Placement_Access;
   begin
      if Placement_ID /= 0 then
         return Find_Virtual_Placement
           (R,
            Stream_ID,
            Alternate_Screen,
            Screen_Generation,
            Image_ID,
            Placement_ID);
      end if;

      --  Kitty permits an omitted/zero underline color on a Unicode image
      --  placeholder. In that case any virtual placement belonging to the
      --  selected image is suitable. New placements are linked at the head,
      --  which also makes the choice deterministic.
      Current := R.Virtual_Placements;
      while Current /= null loop
         if Current.Stream_ID = Stream_ID
           and then Current.Alternate_Screen = Alternate_Screen
           and then Current.Screen_Generation = Screen_Generation
           and then Current.Image_ID = Image_ID
         then
            return Current;
         end if;
         Current := Current.Next;
      end loop;
      return null;
   end Find_Virtual_Placement_For_Cell;

   function Has_Virtual_Placement
     (R        : Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Image_ID : Terminal.Core.Graphics_ID) return Boolean
   is
      Current : Virtual_Placement_Access := R.Virtual_Placements;
   begin
      while Current /= null loop
         if Current.Stream_ID = Stream_ID
           and then Current.Image_ID = Image_ID
         then
            return True;
         end if;
         Current := Current.Next;
      end loop;
      return False;
   end Has_Virtual_Placement;

   function Find_Image_Object
     (R         : Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      ID        : Terminal.Core.Graphics_ID) return Image_Object_Access;

   function Find_Image_Object_By_Storage_Order
     (R             : Renderer;
      Stream_ID     : Terminal.Core.Graphics_Stream_ID;
      Storage_Order : Interfaces.Unsigned_64) return Image_Object_Access;

   procedure Move_Relative_Descendants
     (R                 : in out Renderer;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Parent_Image_ID   : Terminal.Core.Graphics_ID;
      Parent_Placement_ID : Terminal.Core.Graphics_ID;
      Alternate_Screen  : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation);

   subtype Placement_Geometry is Terminal.App.Image_Placements.Geometry;

   function Resolve_Placement_Geometry
     (R      : Renderer;
      Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Header : Terminal.App.Graphics.Graphics_Header)
      return Placement_Geometry
      is (Terminal.App.Image_Placements.Resolve
            (R.CW, R.CH, Pixel_Width, Pixel_Height, Header));

   function Resolve_Placement_Geometry
     (R      : Renderer;
      Object : Image_Object_Access;
      Header : Terminal.App.Graphics.Graphics_Header)
      return Placement_Geometry is
     (if Object = null
      then (others => <>)
      else Resolve_Placement_Geometry
        (R, Object.Pixel_Width, Object.Pixel_Height, Header));

   type Placement_Store_Status is
     (Placement_Not_Requested,
      Placement_Stored,
      Placement_Rejected,
      Placement_Parent_Missing,
      Placement_Cycle,
      Placement_Too_Deep,
      Placement_No_Space);

   function Store_Virtual_Placement
     (R         : in out Renderer;
      Event     : Terminal.Core.Graphics_Event;
      Header    : Terminal.App.Graphics.Graphics_Header;
      Prepared  : in out Virtual_Placement_Access)
      return Placement_Store_Status
   is
      Placement : Virtual_Placement_Access :=
        Find_Addressed_Virtual_Placement
          (R,
           Event.Stream_ID,
           Header.Kitty_ID,
           Header.Kitty_Placement_ID);
      Object : constant Image_Object_Access :=
        Find_Image_Object (R, Event.Stream_ID, Header.Kitty_ID);
      Geometry : constant Placement_Geometry :=
        Resolve_Placement_Geometry (R, Object, Header);
   begin
      if Header.Kitty_ID = 0
        or else not Header.Kitty_Virtual_Placement
        or else Header.Kitty_Parent_ID /= 0
        or else not Geometry.Valid
      then
         --  Kitty virtual placements are prototypes, not positioned objects,
         --  and therefore cannot themselves be relative placements.
         return Placement_Rejected;
      end if;

      if Placement = null then
         if R.Kitty_Placement_Count >= R.Graphics_Limits.Placements then
            R.Image_Store_Allocation_Failed := True;
            return Placement_No_Space;
         end if;
         if Prepared /= null then
            Placement := Prepared;
            Prepared := null;
         else
            if not Terminal.App.Image_Store.Allocation_Allowed
              (R.Image_Allocation_Control)
            then
               R.Image_Store_Allocation_Failed := True;
               return Placement_No_Space;
            end if;
            Placement := new Virtual_Placement;
         end if;
         Placement.Next := R.Virtual_Placements;
         R.Virtual_Placements := Placement;
         R.Kitty_Placement_Count := R.Kitty_Placement_Count + 1;
      elsif Prepared /= null then
         Free_Virtual_Placement (Prepared);
      end if;

      declare
         Next : constant Virtual_Placement_Access := Placement.Next;
      begin
         Placement.all :=
           (Stream_ID      => Event.Stream_ID,
            Alternate_Screen => Event.Alternate_Screen,
            Screen_Generation => Event.Screen_Generation,
            Image_ID       => Header.Kitty_ID,
            Image_Storage_Order => Object.Storage_Order,
            Placement_ID   => Header.Kitty_Placement_ID,
            Columns        => Geometry.Columns,
            Rows           => Geometry.Rows,
            Source_X       => Header.Kitty_Source_X,
            Source_Y       => Header.Kitty_Source_Y,
            Source_Width   => Header.Kitty_Source_Width,
            Source_Height  => Header.Kitty_Source_Height,
            Cell_X         => Header.Kitty_Cell_X,
            Cell_Y         => Header.Kitty_Cell_Y,
            Draw_Offset_X  => Geometry.Draw_Offset_X,
            Draw_Offset_Y  => Geometry.Draw_Offset_Y,
            Draw_Width     => Geometry.Draw_Width,
            Draw_Height    => Geometry.Draw_Height,
            Z_Index        => Header.Kitty_Z_Index,
            Parent_Offset_X => 0,
            Parent_Offset_Y => 0,
            Next           => Next);
      end;
      Move_Relative_Descendants
        (R,
         Event.Stream_ID,
         Header.Kitty_ID,
         Header.Kitty_Placement_ID,
         Event.Alternate_Screen,
         Event.Screen_Generation);
      return Placement_Stored;
   exception
      when Storage_Error =>
         R.Image_Store_Allocation_Failed := True;
         return Placement_No_Space;
   end Store_Virtual_Placement;

   procedure Delete_Virtual_Placements
     (R            : in out Renderer;
      Stream_ID    : Terminal.Core.Graphics_Stream_ID;
      Image_ID     : Terminal.Core.Graphics_ID;
      Placement_ID : Terminal.Core.Graphics_ID := 0;
      Match_Placement : Boolean := False)
   is
      Previous : Virtual_Placement_Access := null;
      Current  : Virtual_Placement_Access := R.Virtual_Placements;
   begin
      while Current /= null loop
         declare
            Next : constant Virtual_Placement_Access := Current.Next;
            Match : constant Boolean :=
              Current.Stream_ID = Stream_ID
              and then (Image_ID = 0 or else Current.Image_ID = Image_ID)
              and then
                (not Match_Placement
                 or else Current.Placement_ID = Placement_ID);
         begin
            if Match then
               if Previous = null then
                  R.Virtual_Placements := Next;
               else
                  Previous.Next := Next;
               end if;
               Free_Virtual_Placement (Current);
               R.Kitty_Placement_Count := R.Kitty_Placement_Count - 1;
            else
               Previous := Current;
            end if;
            Current := Next;
         end;
      end loop;
   end Delete_Virtual_Placements;

   procedure Release_Virtual_Placements (R : in out Renderer) is
      Current : Virtual_Placement_Access := R.Virtual_Placements;
      Next    : Virtual_Placement_Access;
   begin
      while Current /= null loop
         Next := Current.Next;
         Free_Virtual_Placement (Current);
         R.Kitty_Placement_Count := R.Kitty_Placement_Count - 1;
         Current := Next;
      end loop;
      R.Virtual_Placements := null;
   end Release_Virtual_Placements;

   function Find_Conventional_Placement
     (R            : Renderer;
      Stream_ID    : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
      Image_ID     : Terminal.Core.Graphics_ID;
      Placement_ID : Terminal.Core.Graphics_ID)
      return Conventional_Placement_Access
   is
      Current : Conventional_Placement_Access := R.Conventional_Placements;
   begin
      --  A zero placement ID is implicit and does not identify a prior
      --  placement. Each such command therefore creates a new placement.
      if Placement_ID = 0 then
         return null;
      end if;

      while Current /= null loop
         if Current.Stream_ID = Stream_ID
           and then Current.Alternate_Screen = Alternate_Screen
           and then Current.Screen_Generation = Screen_Generation
           and then Current.Image_ID = Image_ID
           and then Current.Placement_ID = Placement_ID
         then
            return Current;
         end if;
         Current := Current.Next;
      end loop;
      return null;
   end Find_Conventional_Placement;

   function Find_Addressed_Conventional_Placement
     (R            : Renderer;
      Stream_ID    : Terminal.Core.Graphics_Stream_ID;
      Image_ID     : Terminal.Core.Graphics_ID;
      Placement_ID : Terminal.Core.Graphics_ID)
      return Conventional_Placement_Access
   is
      Current : Conventional_Placement_Access := R.Conventional_Placements;
   begin
      --  Kitty defines a placement by the pair (image ID, placement ID).
      --  Keep that identity unique even if the replacement is issued while
      --  a different terminal screen is active.
      if Placement_ID = 0 then
         return null;
      end if;

      while Current /= null loop
         if Current.Stream_ID = Stream_ID
           and then Current.Protocol = RM.Image_Kitty
           and then Current.Image_ID = Image_ID
           and then Current.Placement_ID = Placement_ID
         then
            return Current;
         end if;
         Current := Current.Next;
      end loop;
      return null;
   end Find_Addressed_Conventional_Placement;

   procedure Move_Relative_Descendants
     (R                 : in out Renderer;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Parent_Image_ID   : Terminal.Core.Graphics_ID;
      Parent_Placement_ID : Terminal.Core.Graphics_ID;
      Alternate_Screen  : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation)
   is
      procedure Move
        (Image_ID     : Terminal.Core.Graphics_ID;
         Placement_ID : Terminal.Core.Graphics_ID;
         Depth         : Natural)
      is
         Current : Conventional_Placement_Access :=
           R.Conventional_Placements;
      begin
         if Depth >= Max_Relative_Placement_Depth then
            return;
         end if;
         while Current /= null loop
            if Current.Stream_ID = Stream_ID
              and then Current.Protocol = RM.Image_Kitty
              and then Current.Parent_Image_ID = Image_ID
              and then Current.Parent_Placement_ID = Placement_ID
            then
               Current.Alternate_Screen := Alternate_Screen;
               Current.Screen_Generation := Screen_Generation;
               if Current.Placement_ID /= 0 then
                  Move
                    (Current.Image_ID,
                     Current.Placement_ID,
                     Depth + 1);
               end if;
            end if;
            Current := Current.Next;
         end loop;
      end Move;
   begin
      if Parent_Image_ID /= 0 and then Parent_Placement_ID /= 0 then
         Move (Parent_Image_ID, Parent_Placement_ID, 0);
      end if;
   end Move_Relative_Descendants;

   function Has_Conventional_Placement
     (R        : Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Image_ID : Terminal.Core.Graphics_ID) return Boolean
   is
      Current : Conventional_Placement_Access := R.Conventional_Placements;
   begin
      while Current /= null loop
         if Current.Stream_ID = Stream_ID
           and then Current.Image_ID = Image_ID
         then
            return True;
         end if;
         Current := Current.Next;
      end loop;
      return False;
   end Has_Conventional_Placement;

   function Has_Image_Placement
     (R        : Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Image_ID : Terminal.Core.Graphics_ID) return Boolean is
     (Has_Virtual_Placement (R, Stream_ID, Image_ID)
      or else Has_Conventional_Placement (R, Stream_ID, Image_ID));

   function Has_Image_Placement
     (R      : Renderer;
      Object : Image_Object_Access) return Boolean
   is
      Virtual_Current : Virtual_Placement_Access := R.Virtual_Placements;
      Conventional_Current : Conventional_Placement_Access :=
        R.Conventional_Placements;
   begin
      if Object = null then
         return False;
      end if;
      while Virtual_Current /= null loop
         if Virtual_Current.Stream_ID = Object.Stream_ID
           and then Virtual_Current.Image_Storage_Order = Object.Storage_Order
         then
            return True;
         end if;
         Virtual_Current := Virtual_Current.Next;
      end loop;
      while Conventional_Current /= null loop
         if Conventional_Current.Stream_ID = Object.Stream_ID
           and then Conventional_Current.Image_Storage_Order =
             Object.Storage_Order
         then
            return True;
         end if;
         Conventional_Current := Conventional_Current.Next;
      end loop;
      return False;
   end Has_Image_Placement;

   type Relative_Placement_Status is
     (Relative_Valid,
      Relative_Parent_Missing,
      Relative_Cycle,
      Relative_Too_Deep);

   function To_Placement_Status
     (Status : Relative_Placement_Status) return Placement_Store_Status is
     (case Status is
         when Relative_Valid          => Placement_Stored,
         when Relative_Parent_Missing => Placement_Parent_Missing,
         when Relative_Cycle          => Placement_Cycle,
         when Relative_Too_Deep       => Placement_Too_Deep);

   function Validate_Relative_Placement
     (R                   : Renderer;
      Stream_ID           : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen    : Boolean;
      Screen_Generation   : Terminal.Core.Graphics_Screen_Generation;
      Child_Image_ID      : Terminal.Core.Graphics_ID;
      Child_Placement_ID  : Terminal.Core.Graphics_ID;
      Parent_Image_ID     : Terminal.Core.Graphics_ID;
      Parent_Placement_ID : Terminal.Core.Graphics_ID)
      return Relative_Placement_Status
   is
      Current_Image_ID : Terminal.Core.Graphics_ID := Parent_Image_ID;
      Current_Placement_ID : Terminal.Core.Graphics_ID :=
        Parent_Placement_ID;
   begin
      if Parent_Image_ID = 0 then
         return Relative_Valid;
      end if;

      for Depth in 1 .. Max_Relative_Placement_Depth loop
         if Current_Image_ID = Child_Image_ID
           and then Current_Placement_ID = Child_Placement_ID
         then
            return Relative_Cycle;
         end if;

         declare
            Parent : constant Conventional_Placement_Access :=
              Find_Conventional_Placement
                (R,
                 Stream_ID,
                 Alternate_Screen,
                 Screen_Generation,
                 Current_Image_ID,
                 Current_Placement_ID);
         begin
            if Parent /= null then
               if Parent.Parent_Image_ID = 0 then
                  return Relative_Valid;
               end if;
               Current_Image_ID := Parent.Parent_Image_ID;
               Current_Placement_ID := Parent.Parent_Placement_ID;
            else
               return
                 (if Find_Virtual_Placement
                    (R,
                     Stream_ID,
                     Alternate_Screen,
                     Screen_Generation,
                     Current_Image_ID,
                     Current_Placement_ID) = null
                  then Relative_Parent_Missing
                  else Relative_Valid);
            end if;
         end;
      end loop;

      --  A conforming implementation must permit at least eight ancestors.
      --  This implementation deliberately accepts up to thirty-two.
      return Relative_Too_Deep;
   end Validate_Relative_Placement;

   function Resolve_Virtual_Placement_Origin
     (R            : Renderer;
      Snapshot     : Terminal.Core.Render_Snapshot;
      Image_ID     : Terminal.Core.Graphics_ID;
      Placement_ID : Terminal.Core.Graphics_ID;
      Row           : out Integer;
      Col           : out Integer) return Boolean
   is
      Placement : constant Virtual_Placement_Access :=
        Find_Virtual_Placement
          (R,
           Snapshot.Graphics_Stream,
           Snapshot.Alternate_Screen,
           Snapshot.Screen_Generation,
           Image_ID,
           Placement_ID);
      Found : Boolean := False;
   begin
      Row := 0;
      Col := 0;
      if Placement = null then
         return False;
      end if;

      for Cell_Row in 1 .. Snapshot.Rows loop
         for Cell_Col in 1 .. Snapshot.Cols loop
            declare
               Cell : constant Terminal.Core.Cell :=
                 Terminal.Core.Cell_At (Snapshot, Cell_Row, Cell_Col);
            begin
               if Cell.Image.Is_Placeholder
                 and then Cell.Image.Image_ID_Valid
                 and then Cell.Image.Image_ID = Image_ID
                 and then Cell.Image.Placement_ID = Placement_ID
               then
                  if not Found then
                     Row := Cell_Row;
                     Col := Cell_Col;
                     Found := True;
                  else
                     Row := Integer'Min (Row, Cell_Row);
                     Col := Integer'Min (Col, Cell_Col);
                  end if;
               end if;
            end;
         end loop;
      end loop;
      return Found;
   end Resolve_Virtual_Placement_Origin;

   function Resolve_Conventional_Placement_Origin
     (R         : Renderer;
      Snapshot  : Terminal.Core.Render_Snapshot;
      Placement : Conventional_Placement_Access;
      Row       : out Integer;
      Col       : out Integer) return Boolean
   is
      Current : Conventional_Placement_Access := Placement;
      Row_Offset : Long_Long_Integer := 0;
      Col_Offset : Long_Long_Integer := 0;
      Base_Row : Integer := 0;
      Base_Col : Integer := 0;
      Base_Found : Boolean := False;
      Resolved_Row : Long_Long_Integer;
      Resolved_Col : Long_Long_Integer;
   begin
      Row := 0;
      Col := 0;
      if Current = null then
         return False;
      end if;

      for Depth in 0 .. Max_Relative_Placement_Depth loop
         if Current.Parent_Image_ID = 0 then
            if Snapshot.Scrollback_Offset > Integer'Last
              or else Current.Row >
                Integer'Last - Integer (Snapshot.Scrollback_Offset)
            then
               return False;
            end if;
            Base_Row := Current.Row + Integer (Snapshot.Scrollback_Offset);
            Base_Col := Current.Col;
            Base_Found := True;
            exit;
         end if;

         Row_Offset :=
           Row_Offset + Long_Long_Integer (Current.Parent_Offset_Y);
         Col_Offset :=
           Col_Offset + Long_Long_Integer (Current.Parent_Offset_X);

         declare
            Parent : constant Conventional_Placement_Access :=
              Find_Conventional_Placement
                (R,
                 Current.Stream_ID,
                 Current.Alternate_Screen,
                 Current.Screen_Generation,
                 Current.Parent_Image_ID,
                 Current.Parent_Placement_ID);
         begin
            if Parent /= null then
               Current := Parent;
            elsif Resolve_Virtual_Placement_Origin
                (R,
                 Snapshot,
                 Current.Parent_Image_ID,
                 Current.Parent_Placement_ID,
                 Base_Row,
                 Base_Col)
            then
               Base_Found := True;
               exit;
            else
               return False;
            end if;
         end;
      end loop;

      if not Base_Found or else Base_Col = 0 then
         return False;
      end if;

      Resolved_Row := Long_Long_Integer (Base_Row) + Row_Offset;
      Resolved_Col := Long_Long_Integer (Base_Col) + Col_Offset;
      if Resolved_Row < Long_Long_Integer (Integer'First)
        or else Resolved_Row > Long_Long_Integer (Integer'Last)
        or else Resolved_Col < Long_Long_Integer (Integer'First)
        or else Resolved_Col > Long_Long_Integer (Integer'Last)
      then
         return False;
      end if;

      Row := Integer (Resolved_Row);
      Col := Integer (Resolved_Col);
      return True;
   end Resolve_Conventional_Placement_Origin;

   function Store_Conventional_Placement
     (R      : in out Renderer;
      Event  : Terminal.Core.Graphics_Event;
      Header : Terminal.App.Graphics.Graphics_Header;
      Prepared : in out Conventional_Placement_Access)
      return Placement_Store_Status
   is
      Placement : Conventional_Placement_Access :=
        Find_Addressed_Conventional_Placement
          (R,
           Event.Stream_ID,
           Header.Kitty_ID,
           Header.Kitty_Placement_ID);
      Object : constant Image_Object_Access :=
        (if Header.Kitty_ID = 0
         then Find_Image_Object_By_Storage_Order
           (R, Event.Stream_ID, R.Last_Stored_Image_Order)
         else Find_Image_Object (R, Event.Stream_ID, Header.Kitty_ID));
      Geometry : constant Placement_Geometry :=
        Resolve_Placement_Geometry (R, Object, Header);
   begin
      if Header.Kitty_Virtual_Placement
        or else not Geometry.Valid
        or else Object = null
      then
         return Placement_Rejected;
      end if;

      --  Anonymous transmissions cannot subsequently be addressed, so a
      --  supplied placement identifier has no protocol meaning.
      if Header.Kitty_ID = 0 and then Header.Kitty_Parent_ID /= 0 then
         return Placement_Rejected;
      end if;

      declare
         Relative_Status : constant Relative_Placement_Status :=
           Validate_Relative_Placement
             (R,
              Event.Stream_ID,
              Event.Alternate_Screen,
              Event.Screen_Generation,
              Header.Kitty_ID,
              Header.Kitty_Placement_ID,
              Header.Kitty_Parent_ID,
              Header.Kitty_Parent_Placement_ID);
      begin
         if Relative_Status /= Relative_Valid then
            return To_Placement_Status (Relative_Status);
         end if;
      end;

      if Placement = null then
         if R.Kitty_Placement_Count >= R.Graphics_Limits.Placements then
            R.Image_Store_Allocation_Failed := True;
            return Placement_No_Space;
         end if;
         if Prepared /= null then
            Placement := Prepared;
            Prepared := null;
         else
            if not Terminal.App.Image_Store.Allocation_Allowed
              (R.Image_Allocation_Control)
            then
               R.Image_Store_Allocation_Failed := True;
               return Placement_No_Space;
            end if;
            Placement := new Conventional_Placement;
         end if;
         Placement.Next := R.Conventional_Placements;
         R.Conventional_Placements := Placement;
         R.Kitty_Placement_Count := R.Kitty_Placement_Count + 1;
      elsif Prepared /= null then
         Free_Conventional_Placement (Prepared);
      end if;

      declare
         Next : constant Conventional_Placement_Access := Placement.Next;
      begin
         Placement.all :=
           (Stream_ID      => Event.Stream_ID,
            Alternate_Screen => Event.Alternate_Screen,
            Screen_Generation => Event.Screen_Generation,
            Image_ID       => Header.Kitty_ID,
            Image_Storage_Order => Object.Storage_Order,
            Protocol       => RM.Image_Kitty,
            Placement_ID   =>
              (if Header.Kitty_ID = 0
               then 0
               else Header.Kitty_Placement_ID),
            Row            => Event.Row,
            Col            => Event.Col,
            Columns        => Geometry.Columns,
            Rows           => Geometry.Rows,
            Source_X       => Header.Kitty_Source_X,
            Source_Y       => Header.Kitty_Source_Y,
            Source_Width   => Header.Kitty_Source_Width,
            Source_Height  => Header.Kitty_Source_Height,
            Cell_X         => Header.Kitty_Cell_X,
            Cell_Y         => Header.Kitty_Cell_Y,
            Draw_Offset_X  => Geometry.Draw_Offset_X,
            Draw_Offset_Y  => Geometry.Draw_Offset_Y,
            Draw_Width     => Geometry.Draw_Width,
            Draw_Height    => Geometry.Draw_Height,
            Z_Index        => Header.Kitty_Z_Index,
            Parent_Image_ID => Header.Kitty_Parent_ID,
            Parent_Placement_ID => Header.Kitty_Parent_Placement_ID,
            Parent_Offset_X => Header.Kitty_Parent_Offset_X,
            Parent_Offset_Y => Header.Kitty_Parent_Offset_Y,
            Scroll_Sequence => Event.Scroll_Sequence,
            Clip_Top        => 0,
            Clip_Bottom     => 0,
            History_Attached => False,
            Next           => Next);
      end;
      Move_Relative_Descendants
        (R,
         Event.Stream_ID,
         Header.Kitty_ID,
         Header.Kitty_Placement_ID,
         Event.Alternate_Screen,
         Event.Screen_Generation);
      return Placement_Stored;
   exception
      when Storage_Error =>
         R.Image_Store_Allocation_Failed := True;
         return Placement_No_Space;
   end Store_Conventional_Placement;

   function Store_Auxiliary_Placement
     (R           : in out Renderer;
      Event       : Terminal.Core.Graphics_Event;
      Protocol    : RM.Image_Protocol;
      Draw_Width  : Positive;
      Draw_Height : Positive) return Boolean
   is
      Object : constant Image_Object_Access :=
        Find_Image_Object_By_Storage_Order
          (R, Event.Stream_ID, R.Last_Stored_Image_Order);
      Placement : Conventional_Placement_Access;
      Columns : Positive;
      Rows : Positive;
   begin
      if Object = null
        or else R.Kitty_Placement_Count >= R.Graphics_Limits.Placements
      then
         return False;
      end if;
      Columns := Positive'Max (1, 1 + (Draw_Width - 1) / R.CW);
      Rows := Positive'Max (1, 1 + (Draw_Height - 1) / R.CH);
      if not Terminal.App.Image_Store.Allocation_Allowed
        (R.Image_Allocation_Control)
      then
         return False;
      end if;
      Placement := new Conventional_Placement'
        (Stream_ID      => Event.Stream_ID,
         Alternate_Screen => Event.Alternate_Screen,
         Screen_Generation => Event.Screen_Generation,
         Image_ID       => 0,
         Image_Storage_Order => Object.Storage_Order,
         Protocol       => Protocol,
         Placement_ID   => 0,
         Row            => Event.Row,
         Col            => Event.Col,
         Columns        => Columns,
         Rows           => Rows,
         Source_X       => 0,
         Source_Y       => 0,
         Source_Width   => 0,
         Source_Height  => 0,
         Cell_X         => 0,
         Cell_Y         => 0,
         Draw_Offset_X  => 0,
         Draw_Offset_Y  => 0,
         Draw_Width     => Draw_Width,
         Draw_Height    => Draw_Height,
         Z_Index        => 0,
         Parent_Image_ID => 0,
         Parent_Placement_ID => 0,
         Parent_Offset_X => 0,
         Parent_Offset_Y => 0,
         Scroll_Sequence => Event.Scroll_Sequence,
         Clip_Top        => 0,
         Clip_Bottom     => 0,
         History_Attached => False,
         Next           => R.Conventional_Placements);
      R.Conventional_Placements := Placement;
      R.Kitty_Placement_Count := R.Kitty_Placement_Count + 1;
      return True;
   exception
      when Storage_Error | Constraint_Error =>
         return False;
   end Store_Auxiliary_Placement;

   procedure Delete_Conventional_Placements
     (R               : in out Renderer;
      Stream_ID       : Terminal.Core.Graphics_Stream_ID;
      Image_ID        : Terminal.Core.Graphics_ID;
      Placement_ID    : Terminal.Core.Graphics_ID := 0;
      Match_Placement : Boolean := False;
      Match_Protocol  : Boolean := True;
      Protocol        : RM.Image_Protocol := RM.Image_Kitty;
      Match_Screen    : Boolean := False;
      Alternate_Screen : Boolean := False;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation := 0)
   is
      Previous : Conventional_Placement_Access := null;
      Current  : Conventional_Placement_Access := R.Conventional_Placements;
   begin
      while Current /= null loop
         declare
            Next : constant Conventional_Placement_Access := Current.Next;
            Match : constant Boolean :=
              Current.Stream_ID = Stream_ID
              and then (Image_ID = 0 or else Current.Image_ID = Image_ID)
              and then
                (not Match_Protocol or else Current.Protocol = Protocol)
              and then
                (not Match_Screen
                 or else
                   (Current.Alternate_Screen = Alternate_Screen
                    and then Current.Screen_Generation = Screen_Generation))
              and then
                (not Match_Placement
                 or else Current.Placement_ID = Placement_ID);
         begin
            if Match then
               if Previous = null then
                  R.Conventional_Placements := Next;
               else
                  Previous.Next := Next;
               end if;
               Free_Conventional_Placement (Current);
               R.Kitty_Placement_Count := R.Kitty_Placement_Count - 1;
            else
               Previous := Current;
            end if;
            Current := Next;
         end;
      end loop;
   end Delete_Conventional_Placements;

   procedure Delete_Visible_Conventional_Placements
     (R           : in out Renderer;
      Snapshot    : Terminal.Core.Render_Snapshot;
      Delete_Data : Boolean);

   procedure Release_Conventional_Placements (R : in out Renderer) is
      Current : Conventional_Placement_Access := R.Conventional_Placements;
      Next    : Conventional_Placement_Access;
   begin
      while Current /= null loop
         Next := Current.Next;
         Free_Conventional_Placement (Current);
         R.Kitty_Placement_Count := R.Kitty_Placement_Count - 1;
         Current := Next;
      end loop;
      R.Conventional_Placements := null;
   end Release_Conventional_Placements;

   procedure Delete_Orphaned_Relative_Placements
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Preserve_Image_ID : Terminal.Core.Graphics_ID := 0;
      Delete_Data : Boolean := False);

   procedure Synchronize_Graphics_Screen
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot)
   is
      Virtual_Previous : Virtual_Placement_Access := null;
      Virtual_Current  : Virtual_Placement_Access := R.Virtual_Placements;
      Conventional_Previous : Conventional_Placement_Access := null;
      Conventional_Current  : Conventional_Placement_Access :=
        R.Conventional_Placements;
   begin
      --  The core advances this generation whenever a full-screen clear or
      --  entry into the alternate buffer clears that buffer. Retire only the
      --  placements belonging to that logical screen; image data remains
      --  available for later placement commands.
      while Virtual_Current /= null loop
         declare
            Next : constant Virtual_Placement_Access := Virtual_Current.Next;
            Stale : constant Boolean :=
              Virtual_Current.Stream_ID = Snapshot.Graphics_Stream
              and then Virtual_Current.Alternate_Screen =
                Snapshot.Alternate_Screen
              and then Virtual_Current.Screen_Generation /=
                Snapshot.Screen_Generation;
         begin
            if Stale then
               --  Virtual placements are invisible prototypes.  Clearing the
               --  viewport removes their placeholder cells, but prototypes
               --  must remain available to placeholder cells retained in
               --  scrollback.
               Virtual_Current.Screen_Generation := Snapshot.Screen_Generation;
            end if;
            Virtual_Previous := Virtual_Current;
            Virtual_Current := Next;
         end;
      end loop;

      while Conventional_Current /= null loop
         declare
            Next : constant Conventional_Placement_Access :=
              Conventional_Current.Next;
            Stale : constant Boolean :=
              Conventional_Current.Stream_ID = Snapshot.Graphics_Stream
              and then Conventional_Current.Alternate_Screen =
                Snapshot.Alternate_Screen
              and then Conventional_Current.Screen_Generation /=
                Snapshot.Screen_Generation;
         begin
            if Stale then
               declare
                  Origin_Row : Integer := 0;
                  Origin_Col : Integer := 0;
                  Resolved : constant Boolean :=
                    Resolve_Conventional_Placement_Origin
                      (R,
                       Snapshot,
                       Conventional_Current,
                       Origin_Row,
                       Origin_Col);
                  Row_Last : constant Long_Long_Integer :=
                    Long_Long_Integer (Origin_Row)
                    + Long_Long_Integer (Conventional_Current.Rows) - 1;
                  Col_Last : constant Long_Long_Integer :=
                    Long_Long_Integer (Origin_Col)
                    + Long_Long_Integer (Conventional_Current.Columns) - 1;
                  Visible : constant Boolean :=
                    Resolved
                    and then Origin_Row <= Snapshot.Rows
                    and then Origin_Col <= Snapshot.Cols
                    and then Row_Last >= 1
                    and then Col_Last >= 1;
               begin
                  if Visible then
                     if Conventional_Previous = null then
                        R.Conventional_Placements := Next;
                     else
                        Conventional_Previous.Next := Next;
                     end if;
                     Free_Conventional_Placement (Conventional_Current);
                     R.Kitty_Placement_Count := R.Kitty_Placement_Count - 1;
                  else
                     --  A screen clear has no effect on history that is no
                     --  longer visible.  Carry that placement into the new
                     --  generation so scrollback snapshots can still resolve
                     --  it.
                     Conventional_Current.Screen_Generation :=
                       Snapshot.Screen_Generation;
                     Conventional_Previous := Conventional_Current;
                  end if;
               end;
            else
               Conventional_Previous := Conventional_Current;
            end if;
            Conventional_Current := Next;
         end;
      end loop;
   end Synchronize_Graphics_Screen;

   procedure Synchronize_Graphics_Scroll
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot;
      Through  : Terminal.Core.Graphics_Scroll_Sequence)
   is
      Previous : Conventional_Placement_Access := null;
      Current  : Conventional_Placement_Access := R.Conventional_Placements;
   begin
      while Current /= null loop
         declare
            Next : constant Conventional_Placement_Access := Current.Next;
            Applies : constant Boolean :=
              Current.Stream_ID = Snapshot.Graphics_Stream
              and then Current.Alternate_Screen = Snapshot.Alternate_Screen
              and then Current.Screen_Generation = Snapshot.Screen_Generation;
            Delete_Current : Boolean := False;
         begin
            if Applies then
               if Current.Scroll_Sequence < Through
                 and then Snapshot.Graphics_Scroll_Count =
                    Terminal.Core.Max_Graphics_Scroll_Events
                 and then Current.Scroll_Sequence + 1 <
                   Snapshot.Graphics_Scroll_Oldest
               then
                  --  The renderer missed more mutations than the bounded core
                  --  journal retains. Dropping the placement is deterministic
                  --  and avoids drawing it at a silently incorrect location.
                  Delete_Current := True;
               elsif Snapshot.Graphics_Scroll_Events /= null then
                  for I in 1 .. Snapshot.Graphics_Scroll_Count loop
                     declare
                        Mutation : constant Terminal.Core.Graphics_Scroll_Event :=
                          Snapshot.Graphics_Scroll_Events (I);
                        Row_Last : constant Long_Long_Integer :=
                          Long_Long_Integer (Current.Row)
                          + Long_Long_Integer (Current.Rows) - 1;
                        Full_Primary : constant Boolean :=
                          not Snapshot.Alternate_Screen
                          and then Mutation.Top = 1
                          and then Mutation.Bottom = Snapshot.Rows;
                        Same_Clip : constant Boolean :=
                          Current.Clip_Top = Mutation.Top
                          and then Current.Clip_Bottom = Mutation.Bottom;
                        Entirely_Inside : constant Boolean :=
                          Current.Row >= Mutation.Top
                          and then Row_Last <=
                            Long_Long_Integer (Mutation.Bottom);
                        Move : constant Boolean :=
                          Current.Parent_Image_ID = 0
                          and then
                            (Entirely_Inside
                             or else Same_Clip
                             or else
                               (Full_Primary
                                and then Current.History_Attached
                                and then Mutation.Direction =
                                  Terminal.Core.Graphics_Scroll_Up));
                     begin
                        if Mutation.Sequence > Current.Scroll_Sequence
                          and then Mutation.Sequence <= Through
                          and then Move
                        then
                           if Mutation.Direction =
                             Terminal.Core.Graphics_Scroll_Up
                           then
                              Current.Row := Current.Row - Mutation.Count;
                              if Full_Primary then
                                 Current.History_Attached := True;
                              end if;
                           else
                              Current.Row := Current.Row + Mutation.Count;
                           end if;
                           if Mutation.Top /= 1
                             or else Mutation.Bottom /= Snapshot.Rows
                           then
                              Current.Clip_Top := Mutation.Top;
                              Current.Clip_Bottom := Mutation.Bottom;
                           end if;
                        end if;
                        if Mutation.Sequence > Current.Scroll_Sequence
                          and then Mutation.Sequence <= Through
                        then
                           Current.Scroll_Sequence := Mutation.Sequence;
                        end if;
                     end;
                  end loop;
               end if;

               if not Delete_Current then
                  declare
                     Row_Last : constant Long_Long_Integer :=
                       Long_Long_Integer (Current.Row)
                       + Long_Long_Integer (Current.Rows) - 1;
                  begin
                     if Current.Clip_Top > 0
                       and then
                         (Row_Last < Long_Long_Integer (Current.Clip_Top)
                          or else Current.Row > Current.Clip_Bottom)
                     then
                        Delete_Current := True;
                     elsif Current.History_Attached
                       and then Row_Last <
                         1 - Long_Long_Integer (Snapshot.Scrollback_Rows)
                     then
                        Delete_Current := True;
                     elsif Snapshot.Alternate_Screen
                       and then
                         (Row_Last < 1 or else Current.Row > Snapshot.Rows)
                     then
                        Delete_Current := True;
                     end if;
                  end;
               end if;
            end if;

            if Delete_Current then
               if Previous = null then
                  R.Conventional_Placements := Next;
               else
                  Previous.Next := Next;
               end if;
               Free_Conventional_Placement (Current);
               R.Kitty_Placement_Count := R.Kitty_Placement_Count - 1;
            else
               Previous := Current;
            end if;
            Current := Next;
         end;
      end loop;
      Delete_Orphaned_Relative_Placements (R, Snapshot.Graphics_Stream);
   end Synchronize_Graphics_Scroll;

   type Image_Storage_Order_List is
     array (Positive range 1 .. Max_Kitty_Image_Objects) of
       Interfaces.Unsigned_64;

   procedure Remember_Deleted_Image
     (Orders : in out Image_Storage_Order_List;
      Count  : in out Natural;
      Order  : Interfaces.Unsigned_64)
   is
   begin
      for I in 1 .. Count loop
         if Orders (I) = Order then
            return;
         end if;
      end loop;
      if Order /= 0 and then Count < Orders'Length then
         Count := Count + 1;
         Orders (Count) := Order;
      end if;
   end Remember_Deleted_Image;

   procedure Delete_Selected_Unplaced_Image_Objects
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Orders    : Image_Storage_Order_List;
      Count     : Natural);

   procedure Delete_Conventional_Placements_By_Z
     (R       : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Z_Index : Integer;
      Alternate_Screen : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
      Delete_Data : Boolean)
   is
      Previous : Conventional_Placement_Access := null;
      Current  : Conventional_Placement_Access := R.Conventional_Placements;
      Deleted_Orders : Image_Storage_Order_List := (others => 0);
      Deleted_Count : Natural := 0;
   begin
      while Current /= null loop
         declare
            Next : constant Conventional_Placement_Access := Current.Next;
         begin
            if Current.Stream_ID = Stream_ID
              and then Current.Protocol = RM.Image_Kitty
              and then Current.Alternate_Screen = Alternate_Screen
              and then Current.Screen_Generation = Screen_Generation
              and then Current.Z_Index = Z_Index
            then
               if Delete_Data then
                  Remember_Deleted_Image
                    (Deleted_Orders,
                     Deleted_Count,
                     Current.Image_Storage_Order);
               end if;
               if Previous = null then
                  R.Conventional_Placements := Next;
               else
                  Previous.Next := Next;
               end if;
               Free_Conventional_Placement (Current);
               R.Kitty_Placement_Count := R.Kitty_Placement_Count - 1;
            else
               Previous := Current;
            end if;
            Current := Next;
         end;
      end loop;
      if Delete_Data then
         Delete_Selected_Unplaced_Image_Objects
           (R, Stream_ID, Deleted_Orders, Deleted_Count);
      end if;
   end Delete_Conventional_Placements_By_Z;

   procedure Delete_Conventional_Placements_Intersecting
     (R          : in out Renderer;
      Stream_ID  : Terminal.Core.Graphics_Stream_ID;
      Row        : Positive;
      Col        : Positive;
      Match_Row  : Boolean := True;
      Match_Col  : Boolean := True;
      Match_Z    : Boolean := False;
      Z_Index    : Integer := 0;
      Match_Screen : Boolean := False;
      Alternate_Screen : Boolean := False;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation := 0;
      Snapshot     : Terminal.Core.Render_Snapshot;
      Delete_Data  : Boolean)
   is
      Previous : Conventional_Placement_Access := null;
      Current  : Conventional_Placement_Access := R.Conventional_Placements;
      Deleted_Orders : Image_Storage_Order_List := (others => 0);
      Deleted_Count : Natural := 0;
   begin
      while Current /= null loop
         declare
            Next : constant Conventional_Placement_Access := Current.Next;
            Origin_Row : Integer := 0;
            Origin_Col : Integer := 0;
            Resolved : constant Boolean :=
              Resolve_Conventional_Placement_Origin
                (R, Snapshot, Current, Origin_Row, Origin_Col);
            Row_Intersects : constant Boolean :=
              Resolved
              and then Long_Long_Integer (Row) >= Long_Long_Integer (Origin_Row)
              and then Long_Long_Integer (Row) <
                Long_Long_Integer (Origin_Row)
                  + Long_Long_Integer (Current.Rows);
            Col_Intersects : constant Boolean :=
              Resolved
              and then Long_Long_Integer (Col) >= Long_Long_Integer (Origin_Col)
              and then Long_Long_Integer (Col) <
                Long_Long_Integer (Origin_Col)
                  + Long_Long_Integer (Current.Columns);
            Match : constant Boolean :=
              Current.Stream_ID = Stream_ID
              and then Current.Protocol = RM.Image_Kitty
              and then
                (not Match_Screen
                 or else
                   (Current.Alternate_Screen = Alternate_Screen
                    and then Current.Screen_Generation = Screen_Generation))
              and then (not Match_Row or else Row_Intersects)
              and then (not Match_Col or else Col_Intersects)
              and then (not Match_Z or else Current.Z_Index = Z_Index);
         begin
            if Match then
               if Delete_Data then
                  Remember_Deleted_Image
                    (Deleted_Orders,
                     Deleted_Count,
                     Current.Image_Storage_Order);
               end if;
               if Previous = null then
                  R.Conventional_Placements := Next;
               else
                  Previous.Next := Next;
               end if;
               Free_Conventional_Placement (Current);
               R.Kitty_Placement_Count := R.Kitty_Placement_Count - 1;
            else
               Previous := Current;
            end if;
            Current := Next;
         end;
      end loop;
      if Delete_Data then
         Delete_Selected_Unplaced_Image_Objects
           (R, Stream_ID, Deleted_Orders, Deleted_Count);
      end if;
   end Delete_Conventional_Placements_Intersecting;

   function Find_Image_Object
     (R         : Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      ID        : Terminal.Core.Graphics_ID) return Image_Object_Access
   is (Terminal.App.Image_Store.Find_By_ID
         (R.Image_Objects, Stream_ID, ID));

   function Find_Image_Object_By_Storage_Order
     (R             : Renderer;
      Stream_ID     : Terminal.Core.Graphics_Stream_ID;
      Storage_Order : Interfaces.Unsigned_64) return Image_Object_Access
   is (Terminal.App.Image_Store.Find_By_Storage_Order
         (R.Image_Objects, Stream_ID, Storage_Order));

   function Find_Image_Object_By_Number
     (R      : Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Number : Terminal.Core.Graphics_ID) return Image_Object_Access
   is (Terminal.App.Image_Store.Find_By_Number
         (R.Image_Objects, Stream_ID, Number));

   function Allocate_Image_ID
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID)
      return Terminal.Core.Graphics_ID
   is
      Candidate : Terminal.Core.Graphics_ID := R.Next_Automatic_Image_ID;
   begin
      if Candidate = 0 then
         Candidate := 1;
      end if;

      --  At most 256 objects can exist, so a full 32-bit scan is never needed
      --  before a free non-zero identifier is found.
      for Attempt in 0 .. Max_Kitty_Image_Objects loop
         if Find_Image_Object (R, Stream_ID, Candidate) = null then
            R.Next_Automatic_Image_ID := Candidate + 1;
            if R.Next_Automatic_Image_ID = 0 then
               R.Next_Automatic_Image_ID := 1;
            end if;
            return Candidate;
         end if;
         Candidate := Candidate + 1;
         if Candidate = 0 then
            Candidate := 1;
         end if;
      end loop;
      return 0;
   end Allocate_Image_ID;

   procedure Release_Image_Objects (R : in out Renderer) is
   begin
      Terminal.App.Image_Store.Release_All (R.Image_Objects);
      Release_Virtual_Placements (R);
      Release_Conventional_Placements (R);
   end Release_Image_Objects;

   procedure Delete_Image_Object_By_Storage_Order
     (R             : in out Renderer;
      Stream_ID     : Terminal.Core.Graphics_Stream_ID;
      Storage_Order : Interfaces.Unsigned_64;
      Counted       : Boolean := True)
   is
      Current  : Image_Object_Access :=
        Terminal.App.Image_Store.First (R.Image_Objects);
      Virtual_Previous : Virtual_Placement_Access := null;
      Virtual_Current : Virtual_Placement_Access := R.Virtual_Placements;
      Conventional_Previous : Conventional_Placement_Access := null;
      Conventional_Current : Conventional_Placement_Access :=
        R.Conventional_Placements;
   begin
      if Storage_Order = 0 then
         return;
      end if;

      while Current /= null loop
         exit when Current.Stream_ID = Stream_ID
           and then Current.Storage_Order = Storage_Order;
         Current :=
           Terminal.App.Image_Store.Next_Object (Current);
      end loop;
      if Current = null then
         return;
      end if;

      while Virtual_Current /= null loop
         declare
            Next : constant Virtual_Placement_Access := Virtual_Current.Next;
         begin
            if Virtual_Current.Stream_ID = Stream_ID
              and then Virtual_Current.Image_Storage_Order = Storage_Order
            then
               if Virtual_Previous = null then
                  R.Virtual_Placements := Next;
               else
                  Virtual_Previous.Next := Next;
               end if;
               Free_Virtual_Placement (Virtual_Current);
               R.Kitty_Placement_Count := R.Kitty_Placement_Count - 1;
            else
               Virtual_Previous := Virtual_Current;
            end if;
            Virtual_Current := Next;
         end;
      end loop;

      while Conventional_Current /= null loop
         declare
            Next : constant Conventional_Placement_Access :=
              Conventional_Current.Next;
         begin
            if Conventional_Current.Stream_ID = Stream_ID
              and then Conventional_Current.Image_Storage_Order = Storage_Order
            then
               if Conventional_Previous = null then
                  R.Conventional_Placements := Next;
               else
                  Conventional_Previous.Next := Next;
               end if;
               Free_Conventional_Placement (Conventional_Current);
               R.Kitty_Placement_Count := R.Kitty_Placement_Count - 1;
            else
               Conventional_Previous := Conventional_Current;
            end if;
            Conventional_Current := Next;
         end;
      end loop;
      if Counted then
         Terminal.App.Image_Store.Delete_Object (R.Image_Objects, Current);
      else
         Terminal.App.Image_Store.Delete_Replacement
           (R.Image_Objects, Current);
      end if;
   end Delete_Image_Object_By_Storage_Order;

   procedure Delete_Image_Object
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      ID        : Terminal.Core.Graphics_ID)
   is
      Current  : Image_Object_Access :=
        Terminal.App.Image_Store.First (R.Image_Objects);
   begin
      if ID = 0 then
         return;
      end if;

      while Current /= null loop
         if Current.Stream_ID = Stream_ID and then Current.ID = ID then
            Delete_Image_Object_By_Storage_Order
              (R, Stream_ID, Current.Storage_Order);
            return;
         end if;
         Current :=
           Terminal.App.Image_Store.Next_Object (Current);
      end loop;
   end Delete_Image_Object;

   function Parent_Placement_Exists
     (R            : Renderer;
      Stream_ID    : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
      Image_ID     : Terminal.Core.Graphics_ID;
      Placement_ID : Terminal.Core.Graphics_ID) return Boolean is
     (Find_Conventional_Placement
        (R,
         Stream_ID,
         Alternate_Screen,
         Screen_Generation,
         Image_ID,
         Placement_ID) /= null
      or else Find_Virtual_Placement
        (R,
         Stream_ID,
         Alternate_Screen,
         Screen_Generation,
         Image_ID,
         Placement_ID) /= null);

   procedure Delete_Orphaned_Relative_Placements
     (R                 : in out Renderer;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Preserve_Image_ID : Terminal.Core.Graphics_ID := 0;
      Delete_Data       : Boolean := False)
   is
      Removed : Boolean;
   begin
      --  Removing a parent recursively removes its relative descendants.
      --  Process one orphan at a time because deleting its now-unreferenced
      --  image object can also unlink placements elsewhere in the list.
      loop
         Removed := False;
         declare
            Previous : Conventional_Placement_Access := null;
            Current  : Conventional_Placement_Access :=
              R.Conventional_Placements;
         begin
            while Current /= null loop
               if Current.Stream_ID = Stream_ID
                 and then Current.Parent_Image_ID /= 0
                 and then not Parent_Placement_Exists
                   (R,
                    Stream_ID,
                    Current.Alternate_Screen,
                    Current.Screen_Generation,
                    Current.Parent_Image_ID,
                    Current.Parent_Placement_ID)
               then
                  declare
                     Next : constant Conventional_Placement_Access :=
                       Current.Next;
                     Child_Image_ID : constant Terminal.Core.Graphics_ID :=
                       Current.Image_ID;
                  begin
                     if Previous = null then
                        R.Conventional_Placements := Next;
                     else
                        Previous.Next := Next;
                     end if;
                     Free_Conventional_Placement (Current);
                     R.Kitty_Placement_Count := R.Kitty_Placement_Count - 1;
                     if Delete_Data
                       and then Child_Image_ID /= Preserve_Image_ID
                       and then not Has_Image_Placement
                         (R, Stream_ID, Child_Image_ID)
                     then
                        Delete_Image_Object (R, Stream_ID, Child_Image_ID);
                     end if;
                     Removed := True;
                     exit;
                  end;
               end if;
               Previous := Current;
               Current := Current.Next;
            end loop;
         end;
         exit when not Removed;
      end loop;
   end Delete_Orphaned_Relative_Placements;

   procedure Delete_Selected_Unplaced_Image_Objects
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Orders    : Image_Storage_Order_List;
      Count     : Natural)
   is
   begin
      for I in 1 .. Count loop
         declare
            Object : constant Image_Object_Access :=
              Find_Image_Object_By_Storage_Order
                (R, Stream_ID, Orders (I));
         begin
            if Object /= null and then not Has_Image_Placement (R, Object) then
               Delete_Image_Object_By_Storage_Order
                 (R, Stream_ID, Orders (I));
            end if;
         end;
      end loop;
   end Delete_Selected_Unplaced_Image_Objects;

   procedure Delete_Visible_Conventional_Placements
     (R           : in out Renderer;
      Snapshot    : Terminal.Core.Render_Snapshot;
      Delete_Data : Boolean)
   is
      Previous : Conventional_Placement_Access := null;
      Current  : Conventional_Placement_Access := R.Conventional_Placements;
      Deleted_Orders : Image_Storage_Order_List := (others => 0);
      Deleted_Count : Natural := 0;
   begin
      while Current /= null loop
         declare
            Next : constant Conventional_Placement_Access := Current.Next;
            Origin_Row : Integer := 0;
            Origin_Col : Integer := 0;
            Resolved : constant Boolean :=
              Resolve_Conventional_Placement_Origin
                (R, Snapshot, Current, Origin_Row, Origin_Col);
            Visible : constant Boolean :=
              Resolved
              and then Current.Stream_ID = Snapshot.Graphics_Stream
              and then Current.Protocol = RM.Image_Kitty
              and then Current.Alternate_Screen = Snapshot.Alternate_Screen
              and then Current.Screen_Generation = Snapshot.Screen_Generation
              and then Origin_Row <= Snapshot.Rows
              and then Origin_Col <= Snapshot.Cols
              and then Long_Long_Integer (Origin_Row)
                + Long_Long_Integer (Current.Rows) - 1 >= 1
              and then Long_Long_Integer (Origin_Col)
                + Long_Long_Integer (Current.Columns) - 1 >= 1;
         begin
            if Visible then
               if Delete_Data then
                  Remember_Deleted_Image
                    (Deleted_Orders,
                     Deleted_Count,
                     Current.Image_Storage_Order);
               end if;
               if Previous = null then
                  R.Conventional_Placements := Next;
               else
                  Previous.Next := Next;
               end if;
               Free_Conventional_Placement (Current);
               R.Kitty_Placement_Count := R.Kitty_Placement_Count - 1;
            else
               Previous := Current;
            end if;
            Current := Next;
         end;
      end loop;
      if Delete_Data then
         Delete_Selected_Unplaced_Image_Objects
           (R, Snapshot.Graphics_Stream, Deleted_Orders, Deleted_Count);
      end if;
   end Delete_Visible_Conventional_Placements;

   procedure Delete_Image_ID_Range
     (R           : in out Renderer;
      Stream_ID   : Terminal.Core.Graphics_Stream_ID;
      First_ID    : Terminal.Core.Graphics_ID;
      Last_ID     : Terminal.Core.Graphics_ID;
      Delete_Data : Boolean)
   is
      Virtual_Previous : Virtual_Placement_Access := null;
      Virtual_Current  : Virtual_Placement_Access := R.Virtual_Placements;
      Conventional_Previous : Conventional_Placement_Access := null;
      Conventional_Current  : Conventional_Placement_Access :=
        R.Conventional_Placements;
      Object_Current : Image_Object_Access :=
        Terminal.App.Image_Store.First (R.Image_Objects);
   begin
      if Last_ID < First_ID then
         return;
      end if;

      while Virtual_Current /= null loop
         declare
            Next : constant Virtual_Placement_Access := Virtual_Current.Next;
            ID : constant Terminal.Core.Graphics_ID :=
              Virtual_Current.Image_ID;
         begin
            if Virtual_Current.Stream_ID = Stream_ID
              and then ID >= First_ID and then ID <= Last_ID
            then
               if Virtual_Previous = null then
                  R.Virtual_Placements := Next;
               else
                  Virtual_Previous.Next := Next;
               end if;
               Free_Virtual_Placement (Virtual_Current);
               R.Kitty_Placement_Count := R.Kitty_Placement_Count - 1;
            else
               Virtual_Previous := Virtual_Current;
            end if;
            Virtual_Current := Next;
         end;
      end loop;

      while Conventional_Current /= null loop
         declare
            Next : constant Conventional_Placement_Access :=
              Conventional_Current.Next;
            ID : constant Terminal.Core.Graphics_ID :=
              Conventional_Current.Image_ID;
         begin
            if Conventional_Current.Stream_ID = Stream_ID
              and then Conventional_Current.Protocol = RM.Image_Kitty
              and then ID >= First_ID and then ID <= Last_ID
            then
               if Conventional_Previous = null then
                  R.Conventional_Placements := Next;
               else
                  Conventional_Previous.Next := Next;
               end if;
               Free_Conventional_Placement (Conventional_Current);
               R.Kitty_Placement_Count := R.Kitty_Placement_Count - 1;
            else
               Conventional_Previous := Conventional_Current;
            end if;
            Conventional_Current := Next;
         end;
      end loop;

      if Delete_Data then
         while Object_Current /= null loop
            declare
               Next : constant Image_Object_Access :=
                 Terminal.App.Image_Store.Next_Object
                   (Object_Current);
               ID : constant Terminal.Core.Graphics_ID := Object_Current.ID;
            begin
               if Object_Current.Stream_ID = Stream_ID
                 and then Object_Current.Protocol = RM.Image_Kitty
                 and then ID >= First_ID and then ID <= Last_ID
               then
                  Delete_Image_Object_By_Storage_Order
                    (R, Stream_ID, Object_Current.Storage_Order);
               end if;
               Object_Current := Next;
            end;
         end loop;
      end if;
   end Delete_Image_ID_Range;

   function Evict_One_Unplaced_Image
     (R                 : in out Renderer;
      Preserve_Stream   : Terminal.Core.Graphics_Stream_ID;
      Preserve_Image_ID : Terminal.Core.Graphics_ID) return Boolean
   is
      Current   : Image_Object_Access :=
        Terminal.App.Image_Store.First (R.Image_Objects);
      Candidate : Image_Object_Access := null;
   begin
      while Current /= null loop
         if not
           (Preserve_Image_ID /= 0
            and then Current.Stream_ID = Preserve_Stream
            and then Current.ID = Preserve_Image_ID)
           and then not Has_Image_Placement (R, Current)
           and then
             (Candidate = null
              or else
                (Current.Usage_Hint = 1
                 and then Candidate.Usage_Hint /= 1)
              or else
                (Current.Usage_Hint = Candidate.Usage_Hint
                 and then Current.Storage_Order < Candidate.Storage_Order))
         then
            Candidate := Current;
         end if;
         Current :=
           Terminal.App.Image_Store.Next_Object (Current);
      end loop;

      if Candidate = null then
         return False;
      end if;
      Delete_Image_Object_By_Storage_Order
        (R, Candidate.Stream_ID, Candidate.Storage_Order);
      R.Image_Eviction_Count := R.Image_Eviction_Count + 1;
      return True;
   end Evict_One_Unplaced_Image;

   procedure Touch_Image_Object
     (R      : in out Renderer;
      Object : Image_Object_Access)
   is
   begin
      Terminal.App.Image_Store.Touch (R.Image_Objects, Object);
   end Touch_Image_Object;

   procedure Take_Image_Object
     (R              : in out Renderer;
      Stream_ID      : Terminal.Core.Graphics_Stream_ID;
      ID             : Terminal.Core.Graphics_ID;
      Image_Number   : Terminal.Core.Graphics_ID;
      Usage_Hint     : Natural;
      Protocol       : RM.Image_Protocol;
      Raw_Format     : Natural;
      Pixel_Width    : Natural;
      Pixel_Height   : Natural;
      Decoded_Length : Natural;
      Decoded_Row_Stride_Bytes : Natural;
      Bytes          : in out RM.Image_Data_Access;
      Stored_Bytes   : out RM.Image_Data_View;
      Additional_Bytes : Natural := 0)
   is
      Object : Image_Object_Access := Find_Image_Object (R, Stream_ID, ID);
      Previous_Length : constant Natural :=
        (if Object = null
         then 0
         else Terminal.App.Image_Store.Owned_Bytes (Object.all));
      Stored_Length : Natural := 0;
      Created_Object : Boolean := False;
      Created_Replacement : Boolean := False;

      procedure Roll_Back_New_Object is
      begin
         if Created_Replacement then
            Terminal.App.Image_Store.Delete_Replacement
              (R.Image_Objects, Object);
            R.Replaced_Image_Order := 0;
            Created_Replacement := False;
         elsif Created_Object then
            Terminal.App.Image_Store.Delete_Object
              (R.Image_Objects, Object);
            Created_Object := False;
         end if;
      end Roll_Back_New_Object;
   begin
      Stored_Bytes := null;
      R.Last_Stored_Image_Order := 0;
      R.Last_Stored_Image_Content_Serial := 0;
      if Bytes = null
        or else Decoded_Length = 0
        or else Raw_Format = 0
        or else Pixel_Width = 0
        or else Pixel_Height = 0
      then
         return;
      end if;

      if Additional_Bytes > Natural'Last - Bytes'Length then
         R.Image_Store_Allocation_Failed := True;
         return;
      end if;
      Stored_Length := Bytes'Length + Additional_Bytes;

      if Stored_Length > R.Graphics_Limits.Image_Bytes then
         R.Image_Store_Allocation_Failed := True;
         return;
      end if;
      if Stored_Length > R.Graphics_Limits.Per_Image_Bytes
        or else Pixel_Width > R.Graphics_Limits.Pixel_Dimension
        or else Pixel_Height > R.Graphics_Limits.Pixel_Dimension
      then
         R.Image_Store_Allocation_Failed := True;
         return;
      end if;

      while Terminal.App.Image_Store.Byte_Count (R.Image_Objects)
          - Previous_Length >
          R.Graphics_Limits.Image_Bytes - Stored_Length
        or else
          (Object = null
           and then Terminal.App.Image_Store.Object_Count (R.Image_Objects) >=
             R.Graphics_Limits.Image_Objects)
      loop
         if not Evict_One_Unplaced_Image (R, Stream_ID, ID) then
            R.Image_Store_Allocation_Failed := True;
            return;
         end if;
         Object := Find_Image_Object (R, Stream_ID, ID);
      end loop;

      if Object = null then
         declare
            Candidate : Image_Object_Access;
         begin
            Terminal.App.Image_Store.Create_Object (Candidate);
            begin
               Terminal.App.Image_Store.Link_New
                 (R.Image_Objects, Candidate);
            exception
               when others =>
                  Terminal.App.Image_Store.Release_Unowned_Object (Candidate);
                  raise;
            end;
            Object := Candidate;
            Created_Object := True;
         end;
      elsif R.Transactional_Image_Install then
         --  Keep the previous object and its placements intact until the
         --  combined transmit-and-display operation has installed its new
         --  placement.  Apply_Image_Event commits or rolls this object back.
         declare
            Previous_Order : constant Interfaces.Unsigned_64 :=
              Object.Storage_Order;
            Replaced : constant Image_Object_Access := Object;
            Replacement : Image_Object_Access;
         begin
            Terminal.App.Image_Store.Create_Object (Replacement);
            begin
               Terminal.App.Image_Store.Link_Replacement
                 (R.Image_Objects, Replacement, Replaced);
            exception
               when others =>
                  Terminal.App.Image_Store.Release_Unowned_Object
                    (Replacement);
                  raise;
            end;
            Object := Replacement;
            R.Replaced_Image_Order := Previous_Order;
            Created_Replacement := True;
         end;
      else
         --  Retransmitting an explicit ID replaces both its data and every
         --  placement made from the previous object.
         Delete_Virtual_Placements (R, Stream_ID, ID);
         Delete_Conventional_Placements (R, Stream_ID, ID);
      end if;

      declare
      begin
         Terminal.App.Image_Store.Install_Root
           (Container      => R.Image_Objects,
            Object         => Object,
            Stream_ID      => Stream_ID,
            ID             => ID,
            Number         => Image_Number,
            Protocol       => Protocol,
            Raw_Format     => Raw_Format,
            Pixel_Width    => Pixel_Width,
            Pixel_Height   => Pixel_Height,
            Decoded_Length => Decoded_Length,
            Row_Stride     => Decoded_Row_Stride_Bytes,
            Usage_Hint     => Usage_Hint,
            Data           => Bytes);
         R.Image_Install_Count := R.Image_Install_Count + 1;
         R.Image_Installed_Bytes :=
           R.Image_Installed_Bytes + Interfaces.Unsigned_64 (Stored_Length);
         R.Last_Stored_Image_Order := Object.Storage_Order;
         R.Last_Stored_Image_Content_Serial := Object.Content_Serial;
         Stored_Bytes := Terminal.App.Image_Store.Root_Data (Object);
      end;
      Delete_Orphaned_Relative_Placements
        (R, Stream_ID, Preserve_Image_ID => ID);
   exception
      when Storage_Error =>
         Roll_Back_New_Object;
         R.Image_Store_Allocation_Failed := True;
         Stored_Bytes := null;
      when others =>
         Roll_Back_New_Object;
         raise;
   end Take_Image_Object;

   function Find_Image_Frame
     (Object : Image_Object_Access;
      Number : Positive) return Image_Frame_Access
      renames Terminal.App.Image_Store.Find_Frame;

   function Animation_Frame_Exists
     (Object : Image_Object_Access;
      Number : Natural) return Boolean
      renames Terminal.App.Image_Store.Frame_Exists;

   function Animation_Frame_Bytes
     (Object : Image_Object_Access;
      Number : Positive) return RM.Image_Data_View
      renames Terminal.App.Image_Store.Frame_Bytes;

   function Animation_Frame_Gap
     (Object : Image_Object_Access;
      Number : Positive) return Integer
      renames Terminal.App.Image_Store.Frame_Gap;

   function Set_Animation_Frame_Gap
     (Object : Image_Object_Access;
      Number : Positive;
      Gap    : Integer) return Boolean
      renames Terminal.App.Image_Store.Set_Frame_Gap;

   procedure Copy_Frame_To_RGBA
     (Object : Image_Object_Access;
      Number : Positive;
      Target : in out Terminal.Common.Bytes.Byte_Array;
      Valid  : out Boolean)
      renames Terminal.App.Image_Store.Copy_Frame_To_RGBA;

   Max_Theme_Operations : constant Natural :=
     Max_Kitty_Animation_Frames * 4;

   procedure Release_Theme_Operation_List
     (Head : in out Theme_Operation_Access)
   is
   begin
      Terminal.App.Image_Store.Release_Unowned_Theme_Operations (Head);
   end Release_Theme_Operation_List;

   procedure Clear_Theme_Operations
     (R      : in out Renderer;
      Object : Image_Object_Access) is
   begin
      if Object = null then
         return;
      end if;
      Terminal.App.Image_Store.Clear_Theme_Operations
        (R.Image_Objects, Object);
   end Clear_Theme_Operations;

   procedure Archive_Root_Theme_Operations
     (R      : in out Renderer;
      Object : Image_Object_Access)
   is
   begin
      if Object = null
        or else Terminal.App.Image_Store.First_Theme_Operation (Object) = null
      then
         return;
      end if;
      Terminal.App.Image_Store.Archive_Root_Theme_Operations
        (R.Image_Objects, Object, Max_Theme_Operations);
   end Archive_Root_Theme_Operations;

   procedure Append_Theme_Operation
     (R         : in out Renderer;
      Object    : Image_Object_Access;
      Operation : in out Theme_Operation_Access)
   is
   begin
      if Object /= null and then Operation /= null then
         Terminal.App.Image_Store.Append_Theme_Operation
           (R.Image_Objects, Object, Operation);
      end if;
   end Append_Theme_Operation;

   function Reserve_Theme_Operation_Bytes
     (R          : in out Renderer;
      Object     : Image_Object_Access;
      Byte_Count : Natural;
      Op_Count   : Natural) return Boolean
   is
      Existing : Natural;
   begin
      if Object = null
        or else Op_Count > Max_Theme_Operations -
          Natural'Min
            (Terminal.App.Image_Store.Theme_Operation_Count_Of (Object),
             Max_Theme_Operations)
      then
         return False;
      end if;
      Existing := Terminal.App.Image_Store.Owned_Bytes (Object.all);
      if Byte_Count > R.Graphics_Limits.Per_Image_Bytes
        or else Existing > R.Graphics_Limits.Per_Image_Bytes - Byte_Count
        or else Byte_Count > R.Graphics_Limits.Image_Bytes
      then
         return False;
      end if;
      while Stored_Image_Bytes (R) >
        R.Graphics_Limits.Image_Bytes - Byte_Count
      loop
         if not Evict_One_Unplaced_Image
           (R, Object.Stream_ID, Object.ID)
         then
            return False;
         end if;
      end loop;
      return True;
   end Reserve_Theme_Operation_Bytes;

   function Ensure_Theme_Baseline
     (R      : in out Renderer;
      Object : Image_Object_Access) return Boolean
   is separate;

   function Prepare_Theme_Frame_Operation
     (R             : in out Renderer;
      Object        : Image_Object_Access;
      Header        : Terminal.App.Graphics.Graphics_Header;
      Data          : Terminal.App.Graphics.Graphics_Data_Preview;
      Target_Number : Positive;
      New_Frame     : Boolean;
      Operation     : out Theme_Operation_Access) return Boolean
   is separate;

   function Prepare_Theme_Composition_Operation
     (R           : in out Renderer;
      Object      : Image_Object_Access;
      Header      : Terminal.App.Graphics.Graphics_Header;
      Source      : Positive;
      Target      : Positive;
      Width       : Natural;
      Height      : Natural;
      Operation   : out Theme_Operation_Access) return Boolean
   is separate;

   function Replay_Theme_Operations
     (R      : in out Renderer;
      Object : Image_Object_Access) return Boolean
   is separate;

   procedure Apply_Animation_Frame
     (R      : in out Renderer;
      Event  : Terminal.Core.Graphics_Event;
      Header : Terminal.App.Graphics.Graphics_Header;
      Text   : String;
      Allow_Unknown_Compressed_PNG_Size : Boolean := False)
   is separate;

   procedure Delete_Animation_Frames
     (R      : in out Renderer;
      Object : Image_Object_Access)
   is
   begin
      if Object = null then
         return;
      end if;
      --  Keep only palette-sensitive history that contributed to the
      --  surviving root.  Archived non-root references replay through
      --  temporary canvases, so later frames may safely reuse their numbers.
      Archive_Root_Theme_Operations (R, Object);
      --  Archiving may allocate.  Do it before the irreversible frame removal
      --  so Storage_Error leaves the complete animation untouched.
      Terminal.App.Image_Store.Clear_Frames (R.Image_Objects, Object);
      Terminal.App.Image_Store.Set_Root_Gap (Object, 0);
      Terminal.App.Image_Store.Set_Current_Frame (Object, 1);
      Terminal.App.Image_Store.Set_Playback (Object, Animation_Stopped);
      Terminal.App.Image_Store.Set_Loop_Count (Object, 1);
      Terminal.App.Image_Store.Set_Loops_Completed (Object, 0);
      Terminal.App.Image_Store.Set_Deadline (Object, False);
      Touch_Image_Object (R, Object);
   end Delete_Animation_Frames;

   procedure Apply_Animation_Control
     (R      : in out Renderer;
      Event  : Terminal.Core.Graphics_Event;
      Header : Terminal.App.Graphics.Graphics_Header)
   is
      Object : constant Image_Object_Access :=
        Find_Image_Object (R, Event.Stream_ID, Header.Kitty_ID);
   begin
      R.Last_Animation_Result :=
        Terminal.App.Image_Animation.Apply_Control (Object, Header);
      if R.Last_Animation_Result = Terminal.Core.Kitty_OK then
         Touch_Image_Object (R, Object);
      end if;
   end Apply_Animation_Control;

   procedure Apply_Animation_Composition
     (R      : in out Renderer;
      Event  : Terminal.Core.Graphics_Event;
      Header : Terminal.App.Graphics.Graphics_Header)
   is separate;

   function Display_Frame_Bytes
     (Object : Image_Object_Access) return RM.Image_Data_View is
     (if Object = null then null
      else Animation_Frame_Bytes (Object, Object.Current_Frame));

   function Display_Frame_Format (Object : Image_Object_Access) return Natural is
     (if Object = null then 0
      elsif Object.Current_Frame = 1 then Object.Raw_Format
      else 32);

   function Display_Frame_Length (Object : Image_Object_Access) return Natural is
     (if Object = null then 0
      elsif Object.Current_Frame = 1 then Object.Decoded_Length
      else Object.Pixel_Width * Object.Pixel_Height * 4);

   function Display_Frame_Stride (Object : Image_Object_Access) return Natural is
     (if Object = null then 0
      elsif Object.Current_Frame = 1 then Object.Decoded_Row_Stride_Bytes
      else Object.Pixel_Width * 4);

   procedure Advance_Animations (R : in out Renderer) is
      Now : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Object : Image_Object_Access :=
        Terminal.App.Image_Store.First (R.Image_Objects);
   begin
      while Object /= null loop
         declare
            Advances : constant Natural :=
              Terminal.App.Image_Animation.Advance (Object, Now);
         begin
            if Advances > 0 then
               Terminal.App.Image_Store.Mark_Content_Changed
                 (R.Image_Objects, Object);
               R.Animation_Advance_Count :=
                 R.Animation_Advance_Count
                 + Interfaces.Unsigned_64 (Advances);
            end if;
         end;
         Object :=
           Terminal.App.Image_Store.Next_Object (Object);
      end loop;
   end Advance_Animations;


   function Image_Buffer_Extent
     (Raw_Format     : Natural;
      Pixel_Width    : Natural;
      Pixel_Height   : Natural;
      Row_Stride     : Natural) return Natural
   is
      Bytes_Per_Pixel : constant Natural :=
        (if Raw_Format = 8 then 1
         elsif Raw_Format = 16 then 2
         elsif Raw_Format = 24 then 3
         elsif Raw_Format = 32 then 4
         else 0);
      Row_Bytes : Natural := 0;
      Extent : Natural := 0;
   begin
      if Bytes_Per_Pixel = 0
        or else Pixel_Width = 0
        or else Pixel_Height = 0
        or else Pixel_Width > Natural'Last / Bytes_Per_Pixel
      then
         return 0;
      end if;

      Row_Bytes := Pixel_Width * Bytes_Per_Pixel;
      if Row_Stride < Row_Bytes
        or else Row_Stride = 0
        or else
          (Pixel_Height > 1
           and then Row_Stride >
             (Natural'Last - Row_Bytes) / (Pixel_Height - 1))
      then
         return 0;
      end if;

      Extent :=
        (if Pixel_Height = 1
         then Row_Bytes
         else (Pixel_Height - 1) * Row_Stride + Row_Bytes);
      if Extent > RM.Max_Image_Decoded_Data_Length then
         return 0;
      end if;

      return Extent;
   end Image_Buffer_Extent;

   function Image_Buffer_Ready
     (Data        : Terminal.App.Graphics.Graphics_Data_Preview;
      Image_Bytes : RM.Image_Data_Access) return Boolean
   is
      Required : constant Natural :=
        Image_Buffer_Extent
          (Data.Raw_Format,
           Data.Pixel_Width,
           Data.Pixel_Height,
           Data.Decoded_Row_Stride_Bytes);
   begin
      return Data.Decode_Complete
        and then Image_Bytes /= null
        and then Data.Raw_Format /= 0
        and then Data.Pixel_Width > 0
        and then Data.Pixel_Height > 0
        and then Data.Decoded_Row_Stride_Bytes > 0
        and then Required > 0
        and then Image_Bytes'Length >= Required
        and then Data.Decoded_Length = Required;
   end Image_Buffer_Ready;

   procedure Copy_Image_Preview
     (Source         : RM.Image_Data_View;
      Decoded_Length : Natural;
      Preview_Length : out Natural;
      Preview_Bytes  : out Terminal.Common.Bytes.Byte_Array)
   is
   begin
      Preview_Length :=
        Natural'Min (Decoded_Length, RM.Max_Image_Decoded_Preview_Length);
      Preview_Bytes := (others => 0);
      if Source = null then
         return;
      end if;

      for I in 1 .. Preview_Length loop
         exit when I > Source'Last;
         Preview_Bytes (I) := Source (I);
      end loop;
   end Copy_Image_Preview;

   procedure Copy_Image_Preview
     (Source         : RM.Image_Data_Access;
      Decoded_Length : Natural;
      Preview_Length : out Natural;
      Preview_Bytes  : out Terminal.Common.Bytes.Byte_Array) is
   begin
      Copy_Image_Preview
        (RM.Read_Only (Source), Decoded_Length, Preview_Length, Preview_Bytes);
   end Copy_Image_Preview;

   procedure Prepare_Image_Preview_Source
     (Decoded        : RM.Image_Data_View;
      Preview_Length : Natural;
      Preview_Bytes  : Terminal.Common.Bytes.Byte_Array;
      Result         : out RM.Image_Data_View;
      Owner          : out RM.Image_Data_Access)
   is
   begin
      Owner := null;
      if Decoded /= null then
         Result := Decoded;
      elsif Preview_Length = 0 then
         Result := null;
      else
         Owner := new Terminal.Common.Bytes.Byte_Array (1 .. Preview_Length);
         Owner.all := Preview_Bytes
           (Preview_Bytes'First .. Preview_Bytes'First + Preview_Length - 1);
         Result := RM.Read_Only (Owner);
      end if;
   end Prepare_Image_Preview_Source;

   procedure Capture_Image_Preview_Row
     (Preview_Length : in out Natural;
      Preview_Bytes  : in out Terminal.Common.Bytes.Byte_Array;
      Row_Y          : Natural;
      Row            : Terminal.Common.Bytes.Byte_Array;
      Continue       : in out Boolean)
   is
      pragma Unreferenced (Row_Y);
   begin
      for I in Row'Range loop
         exit when Preview_Length >= Preview_Bytes'Length;
         Preview_Length := Preview_Length + 1;
         Preview_Bytes (Preview_Length) := Row (I);
      end loop;
      Continue := True;
   end Capture_Image_Preview_Row;

   procedure Capture_Image_Row
     (Data              : Terminal.App.Graphics.Graphics_Data_Preview;
      Image_Bytes       : in out RM.Image_Data_Access;
      Image_Bytes_Owned : in out Boolean;
      Row_Y             : Natural;
      Row               : Terminal.Common.Bytes.Byte_Array;
      Max_Bytes         : Positive;
      Max_Dimension     : Positive;
      Continue          : in out Boolean)
   is
      Required : constant Natural :=
        Image_Buffer_Extent
          (Data.Raw_Format,
           Data.Pixel_Width,
           Data.Pixel_Height,
           Data.Decoded_Row_Stride_Bytes);
      Offset : Natural := 0;
   begin
      if Required = 0
        or else Required > Max_Bytes
        or else Data.Pixel_Width > Max_Dimension
        or else Data.Pixel_Height > Max_Dimension
        or else Row'Length /= Data.Decoded_Row_Stride_Bytes
        or else Row_Y >= Data.Pixel_Height
        or else Row_Y >
          (Natural'Last - 1) / Data.Decoded_Row_Stride_Bytes
      then
         Continue := False;
         return;
      end if;

      Offset := Row_Y * Data.Decoded_Row_Stride_Bytes + 1;
      if Offset > Required
        or else Row'Length > Required - Offset + 1
      then
         Continue := False;
         return;
      end if;

      if Image_Bytes = null then
         Image_Bytes := new Terminal.Common.Bytes.Byte_Array (1 .. Required);
         Image_Bytes.all := (others => 0);
         Image_Bytes_Owned := True;
      elsif Image_Bytes'Length < Required then
         Continue := False;
         return;
      end if;

      for I in Row'Range loop
         Image_Bytes (Offset + I - Row'First) := Row (I);
      end loop;
   exception
      when Storage_Error =>
         Continue := False;
   end Capture_Image_Row;

   procedure Add_Rectangle
     (R      : in out Renderer;
      X      : Float;
      Y      : Float;
      Width  : Float;
      Height : Float;
      Color  : RM.Pixel_Color;
      Layer  : RM.Rectangle_Layer := RM.Rectangle_Foreground)
   is
   begin
      if R.Rectangles = null or else R.Rectangle_Count >= R.Rectangles'Length then
         return;
      end if;

      R.Rectangle_Count := R.Rectangle_Count + 1;
      R.Rectangles (R.Rectangle_Count) :=
        (X => X,
         Y => Y,
         Width => Width,
         Height => Height,
         Color => Color,
         Layer => Layer);
   end Add_Rectangle;

   function Graphics_Protocol
     (Protocol : Terminal.Core.Ignored_Graphics_Protocol)
      return RM.Image_Protocol
   is
   begin
      case Protocol is
         when Terminal.Core.Sixel_Graphics =>
            return RM.Image_Sixel;
         when Terminal.Core.Kitty_Graphics =>
            return RM.Image_Kitty;
         when Terminal.Core.ITerm2_Graphics =>
            return RM.Image_ITerm2;
         when Terminal.Core.No_Graphics =>
            return RM.Image_Sixel;
      end case;
   end Graphics_Protocol;

   function Graphics_Tint
     (Protocol : Terminal.Core.Ignored_Graphics_Protocol) return RM.Pixel_Color
   is
   begin
      case Protocol is
         when Terminal.Core.Sixel_Graphics =>
            return (R => 0.10, G => 0.55, B => 0.90, A => 1.0);
         when Terminal.Core.Kitty_Graphics =>
            return (R => 0.30, G => 0.75, B => 0.30, A => 1.0);
         when Terminal.Core.ITerm2_Graphics =>
            return (R => 0.85, G => 0.35, B => 0.70, A => 1.0);
         when Terminal.Core.No_Graphics =>
            return (R => 0.50, G => 0.50, B => 0.50, A => 1.0);
      end case;
   end Graphics_Tint;

   procedure Add_Image_Event
     (R                     : in out Renderer;
      Event                 : Terminal.Core.Graphics_Event;
      Resolved_Image_ID     : Terminal.Core.Graphics_ID := 0;
      Resolved_Image_Number : Terminal.Core.Graphics_ID := 0) is separate;

   procedure Apply_Image_Event
     (R      : in out Renderer;
      Event  : Terminal.Core.Graphics_Event;
      Snapshot : Terminal.Core.Render_Snapshot;
      Placement_Status : out Placement_Store_Status) is separate;

   function Graphics_Event_Already_Processed
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event) return Boolean
   is
   begin
      for I in 1 .. R.Processed_Graphics_Event_Count loop
         if R.Processed_Graphics_Events (I).Stream_ID = Event.Stream_ID
           and then R.Processed_Graphics_Events (I).Sequence = Event.Sequence
         then
            return True;
         end if;
      end loop;
      return False;
   end Graphics_Event_Already_Processed;

   function Can_Remember_Graphics_Event
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event) return Boolean is
     (Graphics_Event_Already_Processed (R, Event)
      or else R.Processed_Graphics_Event_Count <
        Max_Processed_Graphics_Events);

   procedure Remember_Processed_Graphics_Event
     (R     : in out Renderer;
      Event : Terminal.Core.Graphics_Event;
      Result : Terminal.Core.Kitty_Graphics_Result)
   is
   begin
      for I in 1 .. R.Processed_Graphics_Event_Count loop
         if R.Processed_Graphics_Events (I).Stream_ID = Event.Stream_ID
           and then R.Processed_Graphics_Events (I).Sequence = Event.Sequence
         then
            R.Processed_Graphics_Events (I).Result := Result;
            return;
         end if;
      end loop;

      if R.Processed_Graphics_Event_Count = Max_Processed_Graphics_Events then
         R.Graphics_Event_Tracking_Failed := True;
         return;
      end if;
      R.Processed_Graphics_Event_Count :=
        R.Processed_Graphics_Event_Count + 1;
      R.Processed_Graphics_Events (R.Processed_Graphics_Event_Count) :=
        (Stream_ID => Event.Stream_ID,
         Sequence  => Event.Sequence,
         Result    => Result);
      if Event.Protocol = Terminal.Core.Kitty_Graphics then
         if Result.Code = Terminal.Core.Kitty_OK then
            R.Kitty_Success_Count := R.Kitty_Success_Count + 1;
         elsif Result.Code /= Terminal.Core.Kitty_No_Response then
            R.Kitty_Error_Count := R.Kitty_Error_Count + 1;
         end if;
      end if;
   end Remember_Processed_Graphics_Event;

   function Graphics_Result
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event)
      return Terminal.Core.Kitty_Graphics_Result
   is
   begin
      for I in 1 .. R.Processed_Graphics_Event_Count loop
         if R.Processed_Graphics_Events (I).Stream_ID = Event.Stream_ID
           and then R.Processed_Graphics_Events (I).Sequence = Event.Sequence
         then
            return R.Processed_Graphics_Events (I).Result;
         end if;
      end loop;
      return (others => <>);
   end Graphics_Result;

   function Graphics_Event_Processed
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event) return Boolean is
     (Graphics_Event_Already_Processed (R, Event));

   procedure Add_Image
     (R      : in out Renderer;
      Event  : Terminal.Core.Graphics_Event;
      Snapshot : Terminal.Core.Render_Snapshot)
   is
      Event_Header : constant Terminal.App.Graphics.Graphics_Header :=
        Terminal.App.Graphics.Header (Event);
      Header : Terminal.App.Graphics.Graphics_Header := Event_Header;
      Result : Terminal.Core.Kitty_Graphics_Result := (others => <>);
      Number_Object_Before : Image_Object_Access := null;
      Resolved_ID : Terminal.Core.Graphics_ID := 0;
      Placement_Image_ID : Terminal.Core.Graphics_ID := 0;
      Resolved_Geometry : Placement_Geometry := (others => <>);
      Geometry_Checked : Boolean := False;
      Placement_Status : Placement_Store_Status := Placement_Not_Requested;
      Image_Count_Before : constant Natural := Frame_Image_Count (R);
      Placement_Count_Before : constant Natural := R.Kitty_Placement_Count;
      Validation_Error : constant Boolean :=
        Event.Cancelled and then Event.Payload_Length > 0;
      Invalid_Chunk_Transition : constant Boolean :=
        Event.Protocol = Terminal.Core.Kitty_Graphics
        and then Event_Header.Recognized
        and then
          (not Event_Header.Kitty_More_Valid
           or else Event_Header.Kitty_More
           or else
             (Event_Header.Kitty_Transmission in 'f' | 't' | 's'
              and then Event_Header.Kitty_More_Specified));
      Retry_Sensitive : constant Boolean :=
        Event.Pending
        and then Event.Protocol = Terminal.Core.Kitty_Graphics
        and then Event.Sequence /= 0
        and then
          (Event_Header.Recognized
           and then
             (Event_Header.Kitty_More
              or else Event_Header.Kitty_More_Specified
              or else Event_Header.Kitty_ID /= 0
              or else Event_Header.Kitty_Image_Number /= 0
              or else Event_Header.Kitty_Action = 'd'));
      Replay_Guarded : constant Boolean :=
        Retry_Sensitive
        or else
          (Event.Pending
           and then Event.Sequence /= 0
           and then Event.Protocol in
             Terminal.Core.Sixel_Graphics | Terminal.Core.ITerm2_Graphics);
      Track_Result : constant Boolean :=
        Retry_Sensitive
        or else
          (Event.Pending
           and then Event.Protocol = Terminal.Core.Kitty_Graphics
           and then Event.Sequence /= 0
           and then Event_Header.Recognized
           and then not Event_Header.Kitty_More
           and then Event_Header.Kitty_Action in 'T' | 'p' | 'q');


      function Placement_Exists
        (Image_ID : Terminal.Core.Graphics_ID) return Boolean
      is
         Placement : Conventional_Placement_Access;
         Virtual   : Virtual_Placement_Access;
      begin
         if Image_ID = 0 then
            if R.Last_Stored_Image_Order /= 0 then
               Placement := R.Conventional_Placements;
               while Placement /= null loop
                  if Placement.Stream_ID = Event.Stream_ID
                    and then Placement.Image_Storage_Order =
                      R.Last_Stored_Image_Order
                  then
                     return True;
                  end if;
                  Placement := Placement.Next;
               end loop;
            end if;
            return Frame_Image_Count (R) > Image_Count_Before;
         elsif Header.Kitty_Virtual_Placement then
            if Header.Kitty_Placement_ID = 0 then
               --  Implicit placements are deliberately not addressable.
               --  A plain placement command must increase the count.  A
               --  transmit-and-display replacement may first remove the old
               --  image's placement, so identify its newly stored object by
               --  storage order in that case.
               if R.Kitty_Placement_Count > Placement_Count_Before then
                  return True;
               elsif Header.Kitty_Action /= 'T' then
                  return False;
               end if;
               Virtual := R.Virtual_Placements;
               while Virtual /= null loop
                  if Virtual.Stream_ID = Event.Stream_ID
                    and then Virtual.Alternate_Screen = Event.Alternate_Screen
                    and then Virtual.Screen_Generation = Event.Screen_Generation
                    and then Virtual.Image_ID = Image_ID
                    and then Virtual.Placement_ID = 0
                    and then Virtual.Image_Storage_Order =
                      R.Last_Stored_Image_Order
                  then
                     return True;
                  end if;
                  Virtual := Virtual.Next;
               end loop;
               return False;
            end if;
            return Find_Virtual_Placement
              (R,
               Event.Stream_ID,
               Event.Alternate_Screen,
               Event.Screen_Generation,
               Image_ID,
               Header.Kitty_Placement_ID) /= null;
         elsif Header.Kitty_Placement_ID /= 0 then
            return Find_Conventional_Placement
              (R,
               Event.Stream_ID,
               Event.Alternate_Screen,
               Event.Screen_Generation,
               Image_ID,
               Header.Kitty_Placement_ID) /= null;
         end if;

         --  As with virtual prototypes, a conventional p=0 placement is a
         --  new, non-addressable object for each command.  A replacement can
         --  leave the total count unchanged after removing the old image;
         --  its storage order distinguishes the replacement from stale data.
         if R.Kitty_Placement_Count > Placement_Count_Before then
            return True;
         elsif Header.Kitty_Action /= 'T' then
            return False;
         end if;
         Placement := R.Conventional_Placements;
         while Placement /= null loop
            if Placement.Stream_ID = Event.Stream_ID
              and then Placement.Alternate_Screen = Event.Alternate_Screen
              and then Placement.Screen_Generation = Event.Screen_Generation
              and then Placement.Image_ID = Image_ID
              and then Placement.Placement_ID = 0
              and then Placement.Image_Storage_Order = R.Last_Stored_Image_Order
            then
               return True;
            end if;
            Placement := Placement.Next;
         end loop;
         return False;
      end Placement_Exists;
   begin
      if Event.Cancelled and then not Validation_Error then
         if Event.Protocol = Terminal.Core.ITerm2_Graphics then
            Clear_Last_Media_Diagnostics (R);
         end if;
         R.Graphics_Event_Count := R.Graphics_Event_Count + 1;
         R.Kitty_Command_Count := R.Kitty_Command_Count + 1;
         R.Chunk_Cancel_Count := R.Chunk_Cancel_Count + 1;
         return;
      end if;

      if Replay_Guarded
        and then Graphics_Event_Already_Processed (R, Event)
      then
         return;
      end if;

      --  The result cache is fixed-capacity and covers every pane in an app
      --  frame. Refuse unsupported oversized snapshot batches before applying
      --  any persistent graphics side effect.
      if (Replay_Guarded or else Track_Result)
        and then not Can_Remember_Graphics_Event (R, Event)
      then
         R.Graphics_Event_Tracking_Failed := True;
         return;
      end if;

      if Event.Protocol = Terminal.Core.ITerm2_Graphics then
         --  Diagnostics describe the current event, including malformed and
         --  non-inline commands that never enter a decoder. Do this only after
         --  replay detection so a presentation retry retains its result.
         Clear_Last_Media_Diagnostics (R);
      end if;

      R.Graphics_Event_Count := R.Graphics_Event_Count + 1;
      if Event.Protocol = Terminal.Core.Kitty_Graphics then
         R.Kitty_Command_Count := R.Kitty_Command_Count + 1;
      end if;

      if Track_Result and then Header.Recognized then
         Result.Quiet := Natural'Min (Header.Kitty_Quiet, 2);
         Result.Respond :=
           not
             (Header.Kitty_Action = 'T'
              and then Header.Kitty_ID = 0
              and then Header.Kitty_Image_Number = 0);
         Result.Image_ID := Header.Kitty_ID;
         Result.Image_Number := Header.Kitty_Image_Number;
         Result.Has_Image_Number := Header.Kitty_Image_Number /= 0;
         Result.Placement_ID := Header.Kitty_Placement_ID;
         Result.Has_Placement_ID := Header.Kitty_Placement_ID /= 0;

         if Header.Kitty_Image_Number /= 0 then
            Number_Object_Before :=
              Find_Image_Object_By_Number
                (R, Event.Stream_ID, Header.Kitty_Image_Number);
         end if;
         if Header.Kitty_ID /= 0 then
            Resolved_ID := Header.Kitty_ID;
         elsif Header.Kitty_Image_Number /= 0
           and then Header.Kitty_Action not in 't' | 'T'
           and then Number_Object_Before /= null
         then
            Resolved_ID := Number_Object_Before.ID;
         end if;
      end if;

      if Event.Protocol = Terminal.Core.Kitty_Graphics
        and then Validation_Error
      then
         R.Chunk_Cancel_Count := R.Chunk_Cancel_Count + 1;
         Truncate_Image_Commands (R, Image_Count_Before);
         if Track_Result and then Header.Recognized then
            Result.Code := Terminal.Core.Kitty_EINVAL;
            Remember_Processed_Graphics_Event (R, Event, Result);
         end if;
         return;
      end if;

      if Invalid_Chunk_Transition then
         R.Chunk_Cancel_Count := R.Chunk_Cancel_Count + 1;
         Truncate_Image_Commands (R, Image_Count_Before);
         if Track_Result then
            Result.Code := Terminal.Core.Kitty_EINVAL;
            Remember_Processed_Graphics_Event (R, Event, Result);
         end if;
         return;
      end if;

      if Track_Result
        and then Header.Recognized
        and then Header.Kitty_Action = 'q'
      then
         Result.Image_ID := Header.Kitty_ID;
         if Header.Kitty_ID = 0
           or else Header.Kitty_Image_Number /= 0
           or else not Header.Kitty_More_Valid
         then
            Result.Code := Terminal.Core.Kitty_EINVAL;
         elsif not Header.Kitty_Transmission_Valid
           or else not Header.Kitty_Compression_Valid
           or else Header.Kitty_Format not in 8 | 16 | 24 | 32 | 100
             | Terminal.App.Graphics.Kitty_JPEG_Format | Terminal.App.Graphics.Kitty_GIF_Format
         then
            Result.Code := Terminal.Core.Kitty_ENOTSUP;
         elsif not Header.Kitty_Control_Data_Valid
           or else not Header.Kitty_Action_Controls_Valid
         then
            Result.Code := Terminal.Core.Kitty_EINVAL;
         else
            declare
               Query_Header : Terminal.App.Graphics.Graphics_Header := Header;
            begin
               if Query_Header.Kitty_Format = 0 then
                  Query_Header.Kitty_Format := 32;
                  Query_Header.Raw_Format := 32;
               end if;
               Result.Code :=
                 Terminal.App.Image_Ingestion.Validate_Kitty_Query
                   (Query_Header,
                    Complete_Event_Text (R, Event),
                    R.Graphics_Access,
                    R.Graphics_Limits.Per_Image_Bytes);
            end;
         end if;
         Remember_Processed_Graphics_Event (R, Event, Result);
         return;
      end if;

      if Event.Protocol = Terminal.Core.Kitty_Graphics
        and then Header.Recognized
        and then
          (Header.Kitty_Action not in 't' | 'T' | 'p' | 'd' | 'f' | 'a' | 'c'
           or else not Header.Kitty_Transmission_Valid
           or else not Header.Kitty_Compression_Valid
           or else not Header.Kitty_Control_Data_Valid
           or else not Header.Kitty_Action_Controls_Valid)
      then
         if Track_Result then
            Result.Code :=
              (if Header.Kitty_Action not in
                    't' | 'T' | 'p' | 'd' | 'f' | 'a' | 'c'
                 or else not Header.Kitty_Transmission_Valid
                 or else not Header.Kitty_Compression_Valid
               then Terminal.Core.Kitty_ENOTSUP
               else Terminal.Core.Kitty_EINVAL);
            Remember_Processed_Graphics_Event (R, Event, Result);
         end if;
         return;
      end if;

      if Event.Protocol = Terminal.Core.ITerm2_Graphics
        and then Header.Recognized
        and then Header.ITerm2_Control_Data_Valid
        and then not Header.ITerm2_Inline
      then
         declare
            Save_Status : Terminal.App.ITerm2_Files.Save_Status;
            Saved_Name : String
              (1 .. Terminal.App.ITerm2_Files.Max_File_Name_Length);
            Saved_Length : Natural;
         begin
            Terminal.App.ITerm2_Files.Save
              (Complete_Event_Text (R, Event),
               R.ITerm2_Downloads,
               R.Graphics_Limits.Per_Image_Bytes,
               Save_Status,
               Saved_Name,
               Saved_Length);
            pragma Unreferenced (Saved_Name, Saved_Length);
            Result.Code :=
              (case Save_Status is
                 when Terminal.App.ITerm2_Files.Save_Ok =>
                   Terminal.Core.Kitty_OK,
                 when Terminal.App.ITerm2_Files.Save_Too_Large =>
                   Terminal.Core.Kitty_ENOSPC,
                 when Terminal.App.ITerm2_Files.Save_Allocation_Failed =>
                   Terminal.Core.Kitty_ENOMEM,
                 when Terminal.App.ITerm2_Files.Save_Disabled =>
                   Terminal.Core.Kitty_ENOTSUP,
                 when Terminal.App.ITerm2_Files.Save_Invalid_Command
                    | Terminal.App.ITerm2_Files.Save_Invalid_Name
                    | Terminal.App.ITerm2_Files.Save_Invalid_Data =>
                   Terminal.Core.Kitty_EINVAL,
                 when others => Terminal.Core.Kitty_EBADF);
            if Save_Status =
              Terminal.App.ITerm2_Files.Save_Allocation_Failed
            then
               R.Allocation_Failure_Count := R.Allocation_Failure_Count + 1;
            elsif Save_Status /= Terminal.App.ITerm2_Files.Save_Ok then
               R.Transport_Failure_Count := R.Transport_Failure_Count + 1;
            end if;
            Remember_Processed_Graphics_Event (R, Event, Result);
            return;
         end;
      end if;

      R.Image_Store_Allocation_Failed := False;
      R.Image_Transport_Failed := False;
      R.Last_Animation_Result := Terminal.Core.Kitty_No_Response;
      Apply_Image_Event (R, Event, Snapshot, Placement_Status);
      if R.Kitty_Placement_Count > Placement_Count_Before then
         R.Placement_Create_Count :=
           R.Placement_Create_Count
           + Interfaces.Unsigned_64
               (R.Kitty_Placement_Count - Placement_Count_Before);
      elsif R.Kitty_Placement_Count < Placement_Count_Before then
         R.Placement_Delete_Count :=
           R.Placement_Delete_Count
           + Interfaces.Unsigned_64
               (Placement_Count_Before - R.Kitty_Placement_Count);
      end if;
      if R.Image_Transport_Failed then
         R.Transport_Failure_Count := R.Transport_Failure_Count + 1;
      end if;
      if R.Image_Store_Allocation_Failed then
         R.Allocation_Failure_Count := R.Allocation_Failure_Count + 1;
      end if;
      if Event.Protocol = Terminal.Core.ITerm2_Graphics
        and then Header.Recognized
        and then Header.ITerm2_Control_Data_Valid
        and then Header.ITerm2_Inline
      then
         declare
            Placement : Conventional_Placement_Access :=
              R.Conventional_Placements;
         begin
            while Placement /= null loop
               exit when Placement.Stream_ID = Event.Stream_ID
                 and then Placement.Protocol = RM.Image_ITerm2
                 and then Placement.Image_Storage_Order =
                   R.Last_Stored_Image_Order;
               Placement := Placement.Next;
            end loop;
            if Placement /= null and then R.Last_Stored_Image_Order /= 0 then
               --  iTerm2 emits no protocol reply, but an internal success
               --  result commits its default cursor movement atomically with
               --  the decoded image. Complete_Graphics_Event serializes
               --  replies only for Kitty events.
               Result.Code := Terminal.Core.Kitty_OK;
               if not Header.ITerm2_Do_Not_Move_Cursor then
                  Result.Move_Cursor := True;
                  Result.Cursor_To_Line_Start := True;
                  Result.Placement_Columns := 1;
                  Result.Placement_Rows := Placement.Rows;
               end if;
            end if;
         end;
      end if;
      if Header.Recognized and then Header.Kitty_Action in 'T' | 'p' then
         Placement_Image_ID := Header.Kitty_ID;
         if Placement_Image_ID = 0
           and then Header.Kitty_Image_Number /= 0
         then
            declare
               Stored : constant Image_Object_Access :=
                 Find_Image_Object_By_Number
                   (R, Event.Stream_ID, Header.Kitty_Image_Number);
            begin
               if Stored /= null then
                  Placement_Image_ID := Stored.ID;
               end if;
            end;
         end if;
         if Placement_Image_ID /= 0 then
            declare
               Object : constant Image_Object_Access :=
                 Find_Image_Object
                   (R, Event.Stream_ID, Placement_Image_ID);
            begin
               if Object /= null then
                  Resolved_Geometry :=
                    Resolve_Placement_Geometry (R, Object, Header);
                  Geometry_Checked := True;
               end if;
            end;
         elsif Header.Kitty_Action = 'T'
           and then R.Last_Stored_Image_Order /= 0
         then
            declare
               Object : constant Image_Object_Access :=
                 Find_Image_Object_By_Storage_Order
                   (R, Event.Stream_ID, R.Last_Stored_Image_Order);
            begin
               if Object /= null then
                  Resolved_Geometry :=
                    Resolve_Placement_Geometry (R, Object, Header);
                  Geometry_Checked := True;
               end if;
            end;
         elsif Header.Kitty_Action = 'T'
           and then Frame_Image_Commands (R) /= null
           and then Frame_Image_Count (R) > Image_Count_Before
         then
            Resolved_Geometry :=
              Resolve_Placement_Geometry
                (R,
                 FIS.Element (R.Frame_Images, Frame_Image_Count (R)).Pixel_Width,
                 FIS.Element (R.Frame_Images, Frame_Image_Count (R)).Pixel_Height,
                 Header);
            Geometry_Checked := True;
         end if;
      end if;
      if Track_Result then
         if Header.Recognized and then not Event_Header.Kitty_More then
            if Header.Kitty_ID /= 0
              and then Header.Kitty_Image_Number /= 0
            then
               Result.Code := Terminal.Core.Kitty_EINVAL;
            elsif not Header.Kitty_Transmission_Valid
              or else not Header.Kitty_Compression_Valid
            then
               Result.Code := Terminal.Core.Kitty_ENOTSUP;
            elsif Header.Kitty_Transmission in 'f' | 't' | 's'
              and then
                (not Header.Kitty_Data_Size_Valid
                 or else not Header.Kitty_Data_Offset_Valid
                 or else Header.Kitty_More_Specified)
            then
               Result.Code := Terminal.Core.Kitty_EINVAL;
            elsif Header.Kitty_Action not in
              't' | 'T' | 'p' | 'd' | 'f' | 'a' | 'c'
            then
               Result.Code := Terminal.Core.Kitty_ENOTSUP;
            elsif Header.Kitty_Action in 'f' | 'a' | 'c' then
               Result.Image_ID := Resolved_ID;
               Result.Code :=
                 (if R.Image_Transport_Failed
                  then Terminal.Core.Kitty_EBADF
                  elsif R.Image_Store_Allocation_Failed
                  then Terminal.Core.Kitty_ENOMEM
                  elsif R.Last_Animation_Result = Terminal.Core.Kitty_No_Response
                  then Terminal.Core.Kitty_EINVAL
                  else R.Last_Animation_Result);
            elsif Header.Kitty_Action = 'p' then
               Result.Image_ID := Resolved_ID;
               if Placement_Status = Placement_Parent_Missing then
                  Result.Code := Terminal.Core.Kitty_ENOPARENT;
               elsif Placement_Status = Placement_Cycle then
                  Result.Code := Terminal.Core.Kitty_ECYCLE;
               elsif Placement_Status = Placement_Too_Deep then
                  Result.Code := Terminal.Core.Kitty_ETOODEEP;
               elsif Placement_Status = Placement_No_Space then
                  Result.Code := Terminal.Core.Kitty_ENOMEM;
               elsif Resolved_ID = 0
                 or else Find_Image_Object
                   (R, Event.Stream_ID, Resolved_ID) = null
               then
                  Result.Code := Terminal.Core.Kitty_ENOENT;
               elsif Header.Kitty_Virtual_Placement
                 and then Header.Kitty_Parent_ID /= 0
               then
                  Result.Code := Terminal.Core.Kitty_EINVAL;
               elsif Header.Kitty_Parent_ID /= 0 then
                  declare
                     Relative_Status : constant Relative_Placement_Status :=
                       Validate_Relative_Placement
                         (R,
                          Event.Stream_ID,
                          Event.Alternate_Screen,
                          Event.Screen_Generation,
                          Resolved_ID,
                          Header.Kitty_Placement_ID,
                          Header.Kitty_Parent_ID,
                          Header.Kitty_Parent_Placement_ID);
                  begin
                     Result.Code :=
                       (case Relative_Status is
                           when Relative_Valid => Terminal.Core.Kitty_OK,
                           when Relative_Parent_Missing =>
                             Terminal.Core.Kitty_ENOPARENT,
                           when Relative_Cycle => Terminal.Core.Kitty_ECYCLE,
                           when Relative_Too_Deep =>
                             Terminal.Core.Kitty_ETOODEEP);
                  end;
               elsif Placement_Status = Placement_Rejected then
                  Result.Code := Terminal.Core.Kitty_EINVAL;
               else
                  Result.Code := Terminal.Core.Kitty_OK;
               end if;
            elsif Header.Kitty_Action in 't' | 'T' then
               if Placement_Status = Placement_Parent_Missing then
                  Result.Code := Terminal.Core.Kitty_ENOPARENT;
               elsif Placement_Status = Placement_Cycle then
                  Result.Code := Terminal.Core.Kitty_ECYCLE;
               elsif Placement_Status = Placement_Too_Deep then
                  Result.Code := Terminal.Core.Kitty_ETOODEEP;
               elsif Placement_Status = Placement_No_Space then
                  Result.Code := Terminal.Core.Kitty_ENOMEM;
               elsif Placement_Status = Placement_Rejected then
                  Result.Code := Terminal.Core.Kitty_EINVAL;
               elsif Header.Kitty_Image_Number /= 0 then
                  declare
                     Stored : constant Image_Object_Access :=
                       Find_Image_Object_By_Number
                         (R, Event.Stream_ID, Header.Kitty_Image_Number);
                  begin
                     if Stored = null
                       or else Stored = Number_Object_Before
                     then
                        Result.Code :=
                          (if R.Image_Store_Allocation_Failed
                           then Terminal.Core.Kitty_ENOMEM
                           elsif R.Image_Transport_Failed
                           then Terminal.Core.Kitty_EBADF
                           else Terminal.Core.Kitty_EINVAL);
                     else
                        Result.Image_ID := Stored.ID;
                        Result.Code := Terminal.Core.Kitty_OK;
                     end if;
                  end;
               elsif Header.Kitty_ID /= 0 then
                  Result.Code :=
                    (if R.Image_Store_Allocation_Failed
                     then Terminal.Core.Kitty_ENOMEM
                     elsif R.Image_Transport_Failed
                     then Terminal.Core.Kitty_EBADF
                     elsif R.Last_Stored_Image_Order = 0
                       or else Find_Image_Object
                         (R, Event.Stream_ID, Header.Kitty_ID) = null
                     then Terminal.Core.Kitty_EINVAL
                     else Terminal.Core.Kitty_OK);
               elsif Header.Kitty_Action = 'T' then
                  Result.Code :=
                    (if (R.Last_Stored_Image_Order /= 0
                         and then Placement_Exists (0))
                       or else Frame_Image_Count (R) > Image_Count_Before
                     then Terminal.Core.Kitty_OK
                     elsif R.Image_Store_Allocation_Failed
                     then Terminal.Core.Kitty_ENOMEM
                     elsif R.Image_Transport_Failed
                     then Terminal.Core.Kitty_EBADF
                     else Terminal.Core.Kitty_EINVAL);
               end if;
            elsif Header.Kitty_Action = 'd' then
               Result.Image_ID := Resolved_ID;
               Result.Code := Terminal.Core.Kitty_OK;
            end if;

            if Header.Kitty_Action in 'T' | 'p'
              and then
                (Result.Code = Terminal.Core.Kitty_OK
                 or else
                   (Placement_Status in
                      Placement_Rejected | Placement_Parent_Missing
                        | Placement_Cycle | Placement_Too_Deep
                    and then Header.Kitty_Parent_ID /= 0))
            then
               if Result.Image_ID = 0
                 and then Header.Kitty_Image_Number /= 0
               then
                  declare
                     Stored : constant Image_Object_Access :=
                       Find_Image_Object_By_Number
                         (R, Event.Stream_ID, Header.Kitty_Image_Number);
                  begin
                     if Stored /= null then
                        Result.Image_ID := Stored.ID;
                     end if;
                  end;
               end if;

               if Geometry_Checked and then not Resolved_Geometry.Valid then
                  Result.Code := Terminal.Core.Kitty_EINVAL;
               elsif Header.Kitty_Virtual_Placement
                 and then Header.Kitty_Parent_ID /= 0
               then
                  Result.Code := Terminal.Core.Kitty_EINVAL;
               elsif Header.Kitty_Parent_ID /= 0 then
                  Result.Code :=
                    (case Validate_Relative_Placement
                       (R,
                        Event.Stream_ID,
                        Event.Alternate_Screen,
                        Event.Screen_Generation,
                        Result.Image_ID,
                        Header.Kitty_Placement_ID,
                        Header.Kitty_Parent_ID,
                        Header.Kitty_Parent_Placement_ID) is
                       when Relative_Valid => Terminal.Core.Kitty_OK,
                       when Relative_Parent_Missing =>
                         Terminal.Core.Kitty_ENOPARENT,
                       when Relative_Cycle => Terminal.Core.Kitty_ECYCLE,
                       when Relative_Too_Deep => Terminal.Core.Kitty_ETOODEEP);
               end if;

               if Result.Code = Terminal.Core.Kitty_OK
                 and then not Placement_Exists (Result.Image_ID)
               then
                  Result.Code :=
                    (if Placement_Status = Placement_Rejected
                     then Terminal.Core.Kitty_EINVAL
                     else Terminal.Core.Kitty_ENOMEM);
               elsif Result.Code = Terminal.Core.Kitty_OK
                 and then not Header.Kitty_No_Cursor_Move
                 and then not Header.Kitty_Virtual_Placement
                 and then Header.Kitty_Parent_ID = 0
               then
                  Result.Move_Cursor := True;
                  if Geometry_Checked and then Resolved_Geometry.Valid then
                     Result.Placement_Columns := Resolved_Geometry.Columns;
                     Result.Placement_Rows := Resolved_Geometry.Rows;
                  else
                     Result.Placement_Columns := Header.Placeholder_Cols;
                     Result.Placement_Rows := Header.Placeholder_Rows;
                  end if;
               end if;
            end if;
         end if;
         if Result.Code = Terminal.Core.Kitty_EINVAL
           and then Header.Kitty_Action in 't' | 'T' | 'f' | 'q'
           and then Header.Has_Data
           and then not R.Image_Transport_Failed
           and then not R.Image_Store_Allocation_Failed
         then
            R.Decode_Failure_Count := R.Decode_Failure_Count + 1;
         end if;
         Remember_Processed_Graphics_Event (R, Event, Result);
      elsif Replay_Guarded then
         --  Sixel and iTerm2 commands also install persistent image objects.
         --  A swapchain retry can render the same pending core event more
         --  than once before presentation commits it, so guard these
         --  side-effects exactly like stateful Kitty commands. iTerm2 can
         --  carry an internal cursor-commit result but emits no reply.
         Remember_Processed_Graphics_Event (R, Event, Result);
      end if;
   end Add_Image;

   procedure Add_Conventional_Images
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot)
   is
      Placement : Conventional_Placement_Access := R.Conventional_Placements;
      Cached_Storage_Order : Interfaces.Unsigned_64 := 0;
      Cached_Object : Image_Object_Access := null;
      Cached_Object_Checked : Boolean := False;
   begin
      if Frame_Image_Commands (R) = null then
         return;
      end if;

      while Placement /= null
        and then Frame_Image_Count (R) < Frame_Image_Capacity (R)
      loop
         declare
            Object : Image_Object_Access;
            Placement_Row : Integer := 0;
            Placement_Col : Integer := 0;
         begin
            if not Cached_Object_Checked
              or else Cached_Storage_Order /= Placement.Image_Storage_Order
            then
               Cached_Storage_Order := Placement.Image_Storage_Order;
               Cached_Object :=
                 Find_Image_Object_By_Storage_Order
                   (R,
                    Snapshot.Graphics_Stream,
                    Placement.Image_Storage_Order);
               Cached_Object_Checked := True;
            end if;
            Object := Cached_Object;
            if Placement.Stream_ID = Snapshot.Graphics_Stream
              and then Placement.Alternate_Screen = Snapshot.Alternate_Screen
              and then Placement.Screen_Generation = Snapshot.Screen_Generation
              and then Object /= null
              and then Resolve_Conventional_Placement_Origin
                (R,
                 Snapshot,
                 Placement,
                 Placement_Row,
                 Placement_Col)
              and then Placement_Row <= Snapshot.Rows
              and then Placement_Col <= Snapshot.Cols
              and then
                Long_Long_Integer (Placement_Row)
                  + Long_Long_Integer (Placement.Rows) - 1 >= 1
              and then
                Long_Long_Integer (Placement_Col)
                  + Long_Long_Integer (Placement.Columns) - 1 >= 1
              and then Placement.Source_X < Object.Pixel_Width
              and then Placement.Source_Y < Object.Pixel_Height
            then
               declare
                  Available_Width : constant Natural :=
                    Object.Pixel_Width - Placement.Source_X;
                  Available_Height : constant Natural :=
                    Object.Pixel_Height - Placement.Source_Y;
                  Source_Width : constant Natural :=
                    (if Placement.Source_Width = 0
                     then Available_Width
                     else Natural'Min
                       (Placement.Source_Width, Available_Width));
                  Source_Height : constant Natural :=
                    (if Placement.Source_Height = 0
                     then Available_Height
                     else Natural'Min
                       (Placement.Source_Height, Available_Height));
                  Frame_Bytes : constant RM.Image_Data_View :=
                    Display_Frame_Bytes (Object);
                  Frame_Format : constant Natural :=
                    Display_Frame_Format (Object);
                  Frame_Length : constant Natural :=
                    Display_Frame_Length (Object);
                  Preview_Length : constant Natural :=
                    Natural'Min
                      (Frame_Length, RM.Max_Image_Decoded_Preview_Length);
                  Frame_Stride : constant Natural :=
                    Display_Frame_Stride (Object);
                  Raw_X : constant Long_Long_Integer :=
                    Long_Long_Integer (Origin_X (R))
                    + Long_Long_Integer (Placement.Cell_X)
                    + Long_Long_Integer (Placement.Draw_Offset_X)
                    + Long_Long_Integer (Placement_Col - 1)
                      * Long_Long_Integer (R.CW);
                  Raw_Y : constant Long_Long_Integer :=
                    Long_Long_Integer (Origin_Y (R))
                    + Long_Long_Integer (Placement.Cell_Y)
                    + Long_Long_Integer (Placement.Draw_Offset_Y)
                    + Long_Long_Integer (Placement_Row - 1)
                      * Long_Long_Integer (R.CH);
                  View_Left : constant Long_Long_Integer :=
                    Long_Long_Integer (Origin_X (R));
                  View_Right : constant Long_Long_Integer :=
                    View_Left
                    + Long_Long_Integer (Snapshot.Cols)
                      * Long_Long_Integer (R.CW);
                  View_Top : constant Long_Long_Integer :=
                    Long_Long_Integer (Origin_Y (R));
                  View_Bottom : constant Long_Long_Integer :=
                    View_Top
                    + Long_Long_Integer (Snapshot.Rows)
                      * Long_Long_Integer (R.CH);
                  Region_Top : constant Long_Long_Integer :=
                    (if Placement.Clip_Top = 0
                     then View_Top
                     else Long_Long_Integer (Origin_Y (R))
                       + Long_Long_Integer (Placement.Clip_Top - 1)
                         * Long_Long_Integer (R.CH));
                  Region_Bottom : constant Long_Long_Integer :=
                    (if Placement.Clip_Bottom = 0
                     then View_Bottom
                     else Long_Long_Integer (Origin_Y (R))
                       + Long_Long_Integer (Placement.Clip_Bottom)
                         * Long_Long_Integer (R.CH));
                  Clip_X0 : constant Long_Long_Integer :=
                    Long_Long_Integer'Max (Raw_X, View_Left);
                  Clip_Y0 : constant Long_Long_Integer :=
                    Long_Long_Integer'Max
                      (Raw_Y, Long_Long_Integer'Max (View_Top, Region_Top));
                  Clip_X1 : constant Long_Long_Integer :=
                    Long_Long_Integer'Min
                      (Raw_X + Long_Long_Integer (Placement.Draw_Width),
                       View_Right);
                  Clip_Y1 : constant Long_Long_Integer :=
                    Long_Long_Integer'Min
                      (Raw_Y + Long_Long_Integer (Placement.Draw_Height),
                       Long_Long_Integer'Min (View_Bottom, Region_Bottom));
                  Base_U0 : constant Float := Float (Placement.Source_X)
                    / Float (Object.Pixel_Width);
                  Base_V0 : constant Float := Float (Placement.Source_Y)
                    / Float (Object.Pixel_Height);
                  U_Span : constant Float := Float (Source_Width)
                    / Float (Object.Pixel_Width);
                  V_Span : constant Float := Float (Source_Height)
                    / Float (Object.Pixel_Height);
               begin
                  if Frame_Bytes /= null
                    and then Clip_X0 < Clip_X1
                    and then Clip_Y0 < Clip_Y1
                  then
                     Append_Image_Command
                       (R,
                       (X => Float (Clip_X0),
                     Y => Float (Clip_Y0),
                     Width => Float (Clip_X1 - Clip_X0),
                     Height => Float (Clip_Y1 - Clip_Y0),
                     Protocol => Object.Protocol,
                     Placeholder => False,
                     Raw_Format => Frame_Format,
                     Pixel_Width => Object.Pixel_Width,
                     Pixel_Height => Object.Pixel_Height,
                     Payload_Length => 0,
                     Staging_Byte_Length => 0,
                     Payload_Preview_Complete => True,
                     Encoded_Preview_Length => 0,
                     Decoded_Byte_Length => Frame_Length,
                     Decoded_Row_Stride_Bytes =>
                       Frame_Stride,
                     Decoded_Source => RM.Image_Decoded_Source_Buffer,
                     Decoded_Bytes => Frame_Bytes,
                     Encoded_Source_Bytes => null,
                     Encoded_Source_Length => 0,
                     Decoded_Preview_Length => Preview_Length,
                     Decoded_Preview_Bytes => Frame_Bytes,
                     Preview_Decode_Complete => True,
                     Decode_Status => RM.Image_Decode_Ok,
                     U0 => Base_U0
                       + U_Span
                         * Float (Clip_X0 - Raw_X)
                         / Float (Placement.Draw_Width),
                     V0 => Base_V0
                       + V_Span
                         * Float (Clip_Y0 - Raw_Y)
                         / Float (Placement.Draw_Height),
                     U1 => Base_U0
                       + U_Span
                         * Float (Clip_X1 - Raw_X)
                         / Float (Placement.Draw_Width),
                     V1 => Base_V0
                       + V_Span
                         * Float (Clip_Y1 - Raw_Y)
                         / Float (Placement.Draw_Height),
                     Image_ID => Interfaces.Unsigned_32 (Placement.Image_ID),
                     Content_Serial => Object.Content_Serial,
                     Z_Index => Placement.Z_Index,
                     Tint => (R => 1.0, G => 1.0, B => 1.0, A => 1.0)));
                  end if;
               end;
            end if;
         end;
         Placement := Placement.Next;
      end loop;
   end Add_Conventional_Images;

   procedure Add_Placeholder_Images
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot)
   is
      Cached_Image_ID : Terminal.Core.Graphics_ID := 0;
      Cached_Placement_ID : Terminal.Core.Graphics_ID := 0;
      Cached_Placement : Virtual_Placement_Access := null;
      Cached_Placement_Checked : Boolean := False;
      Cached_Object_Storage_Order : Interfaces.Unsigned_64 := 0;
      Cached_Object : Image_Object_Access := null;
      Cached_Object_Checked : Boolean := False;
   begin
      if Frame_Image_Commands (R) = null
        or else Snapshot.Image_Cell_Count = 0
      then
         return;
      end if;

      for Row in 1 .. Snapshot.Rows loop
         for Col in 1 .. Snapshot.Cols loop
            declare
               Cell : constant Terminal.Core.Cell :=
                 Terminal.Core.Cell_At (Snapshot, Row, Col);
            begin
               if Cell.Image.Is_Placeholder
                 and then Cell.Image.Image_ID_Valid
                 and then Frame_Image_Count (R) < Frame_Image_Capacity (R)
               then
                  declare
                     Image_ID : constant Terminal.Core.Graphics_ID :=
                       Cell.Image.Image_ID;
                     Placement_ID : constant Terminal.Core.Graphics_ID :=
                       Cell.Image.Placement_ID;
                     Placement : Virtual_Placement_Access;
                     Object : Image_Object_Access;
                  begin
                     if not Cached_Placement_Checked
                       or else Cached_Image_ID /= Image_ID
                       or else Cached_Placement_ID /= Placement_ID
                     then
                        Cached_Image_ID := Image_ID;
                        Cached_Placement_ID := Placement_ID;
                        Cached_Placement :=
                          Find_Virtual_Placement_For_Cell
                            (R,
                             Snapshot.Graphics_Stream,
                             Snapshot.Alternate_Screen,
                             Snapshot.Screen_Generation,
                             Image_ID,
                             Placement_ID);
                        Cached_Placement_Checked := True;
                     end if;
                     Placement := Cached_Placement;

                     if Placement = null then
                        Object := null;
                     else
                        if not Cached_Object_Checked
                          or else Cached_Object_Storage_Order /=
                            Placement.Image_Storage_Order
                        then
                           Cached_Object_Storage_Order :=
                             Placement.Image_Storage_Order;
                           Cached_Object :=
                             Find_Image_Object_By_Storage_Order
                               (R,
                                Snapshot.Graphics_Stream,
                                Placement.Image_Storage_Order);
                           Cached_Object_Checked := True;
                        end if;
                        Object := Cached_Object;
                     end if;
                     if Placement /= null
                       and then Object /= null
                       and then Cell.Image.Image_Column < Placement.Columns
                       and then Cell.Image.Image_Row < Placement.Rows
                       and then Placement.Source_X < Object.Pixel_Width
                       and then Placement.Source_Y < Object.Pixel_Height
                     then
                        declare
                           Available_Width : constant Natural :=
                             Object.Pixel_Width - Placement.Source_X;
                           Available_Height : constant Natural :=
                             Object.Pixel_Height - Placement.Source_Y;
                           Source_Width : constant Natural :=
                             (if Placement.Source_Width = 0
                              then Available_Width
                              else Natural'Min
                                (Placement.Source_Width, Available_Width));
                           Source_Height : constant Natural :=
                             (if Placement.Source_Height = 0
                              then Available_Height
                              else Natural'Min
                                (Placement.Source_Height, Available_Height));
                           Column : constant Natural := Cell.Image.Image_Column;
                           Image_Row : constant Natural := Cell.Image.Image_Row;
                           Cell_Left : constant Float :=
                             Float (Column) * Float (R.CW);
                           Cell_Top : constant Float :=
                             Float (Image_Row) * Float (R.CH);
                           Cell_Right : constant Float :=
                             Cell_Left + Float (R.CW);
                           Cell_Bottom : constant Float :=
                             Cell_Top + Float (R.CH);
                           Draw_Left : constant Float :=
                             Float
                               (Placement.Cell_X + Placement.Draw_Offset_X);
                           Draw_Top : constant Float :=
                             Float
                               (Placement.Cell_Y + Placement.Draw_Offset_Y);
                           Draw_Right : constant Float :=
                             Draw_Left + Float (Placement.Draw_Width);
                           Draw_Bottom : constant Float :=
                             Draw_Top + Float (Placement.Draw_Height);
                           Clip_Left : constant Float :=
                             Float'Max (Cell_Left, Draw_Left);
                           Clip_Top : constant Float :=
                             Float'Max (Cell_Top, Draw_Top);
                           Clip_Right : constant Float :=
                             Float'Min (Cell_Right, Draw_Right);
                           Clip_Bottom : constant Float :=
                             Float'Min (Cell_Bottom, Draw_Bottom);
                           U0 : constant Float :=
                             (Float (Placement.Source_X)
                              + (Clip_Left - Draw_Left)
                                * Float (Source_Width)
                                / Float (Placement.Draw_Width))
                             / Float (Object.Pixel_Width);
                           V0 : constant Float :=
                             (Float (Placement.Source_Y)
                              + (Clip_Top - Draw_Top)
                                * Float (Source_Height)
                                / Float (Placement.Draw_Height))
                             / Float (Object.Pixel_Height);
                           U1 : constant Float :=
                             (Float (Placement.Source_X)
                              + (Clip_Right - Draw_Left)
                                * Float (Source_Width)
                                / Float (Placement.Draw_Width))
                             / Float (Object.Pixel_Width);
                           V1 : constant Float :=
                             (Float (Placement.Source_Y)
                              + (Clip_Bottom - Draw_Top)
                                * Float (Source_Height)
                                / Float (Placement.Draw_Height))
                             / Float (Object.Pixel_Height);
                           Frame_Bytes : constant RM.Image_Data_View :=
                             Display_Frame_Bytes (Object);
                           Frame_Format : constant Natural :=
                             Display_Frame_Format (Object);
                           Frame_Length : constant Natural :=
                             Display_Frame_Length (Object);
                           Preview_Length : constant Natural :=
                             Natural'Min
                               (Frame_Length,
                                RM.Max_Image_Decoded_Preview_Length);
                           Frame_Stride : constant Natural :=
                             Display_Frame_Stride (Object);
                        begin
                           if Frame_Bytes /= null
                             and then Clip_Right > Clip_Left
                             and then Clip_Bottom > Clip_Top
                           then
                              Append_Image_Command
                                (R,
                                (X => Float
                                   (Origin_X (R) + (Col - 1) * R.CW)
                                   + Clip_Left - Cell_Left,
                                 Y => Float
                                   (Origin_Y (R) + (Row - 1) * R.CH)
                                   + Clip_Top - Cell_Top,
                                 Width => Clip_Right - Clip_Left,
                                 Height => Clip_Bottom - Clip_Top,
                                 Protocol => Object.Protocol,
                                 Placeholder => False,
                                 Raw_Format => Frame_Format,
                                 Pixel_Width => Object.Pixel_Width,
                                 Pixel_Height => Object.Pixel_Height,
                                 Payload_Length => 0,
                                 Staging_Byte_Length => 0,
                                 Payload_Preview_Complete => True,
                                 Encoded_Preview_Length => 0,
                                 Decoded_Byte_Length => Frame_Length,
                                 Decoded_Row_Stride_Bytes =>
                                   Frame_Stride,
                                 Decoded_Source =>
                                   RM.Image_Decoded_Source_Buffer,
                                 Decoded_Bytes => Frame_Bytes,
                                 Encoded_Source_Bytes => null,
                                 Encoded_Source_Length => 0,
                                 Decoded_Preview_Length => Preview_Length,
                                 Decoded_Preview_Bytes => Frame_Bytes,
                                 Preview_Decode_Complete => True,
                                 Decode_Status => RM.Image_Decode_Ok,
                                 U0 => U0,
                                 V0 => V0,
                                 U1 => U1,
                                 V1 => V1,
                                 Image_ID =>
                                   Interfaces.Unsigned_32 (Placement.Image_ID),
                                 Content_Serial => Object.Content_Serial,
                                 Z_Index => Placement.Z_Index,
                                 Tint =>
                                   (R => 1.0, G => 1.0, B => 1.0, A => 1.0)));
                           end if;
                        end;
                     end if;
                  end;
               end if;
            end;
         end loop;
      end loop;
   end Add_Placeholder_Images;

   procedure Add_Underline
     (R      : in out Renderer;
      Kind   : Terminal.Core.Underline_Style;
      X      : Float;
      Y      : Float;
      Width  : Float;
      Color  : RM.Pixel_Color)
   is
      Base_Y : constant Float := Y + Float (R.CH - 2);
      Step   : constant Float := 4.0;
      Dash   : constant Float := 5.0;
      Pos    : Float := X;
      Index  : Natural := 0;
   begin
      case Kind is
         when Terminal.Core.Underline_Single =>
            Add_Rectangle (R, X, Base_Y, Width, 1.0, Color);
         when Terminal.Core.Underline_Double =>
            Add_Rectangle (R, X, Base_Y - 2.0, Width, 1.0, Color);
            Add_Rectangle (R, X, Base_Y, Width, 1.0, Color);
         when Terminal.Core.Underline_Curly =>
            while Pos < X + Width loop
               Add_Rectangle
                 (R,
                  Pos,
                  Base_Y - Float (Index mod 2),
                  Float'Min (2.0, X + Width - Pos),
                  1.0,
                  Color);
               Pos := Pos + 2.0;
               Index := Index + 1;
            end loop;
         when Terminal.Core.Underline_Dotted =>
            while Pos < X + Width loop
               Add_Rectangle
                 (R, Pos, Base_Y, Float'Min (1.0, X + Width - Pos), 1.0, Color);
               Pos := Pos + Step;
            end loop;
         when Terminal.Core.Underline_Dashed =>
            while Pos < X + Width loop
               Add_Rectangle
                 (R, Pos, Base_Y, Float'Min (Dash, X + Width - Pos), 1.0, Color);
               Pos := Pos + Dash + 3.0;
            end loop;
      end case;
   end Add_Underline;

   procedure Add_Glyph
     (R         : in out Renderer;
      Placement : Textrender.Glyph_Placement;
      Metric    : Textrender.Glyph_Metric;
      Color     : RM.Pixel_Color;
      Codepoint : Natural)
   is
   begin
      if R.Glyphs = null or else R.Glyph_Count >= R.Glyphs'Length then
         return;
      end if;

      R.Glyph_Count := R.Glyph_Count + 1;
      R.Glyphs (R.Glyph_Count) :=
        (X         => Placement.X,
         Y         => Placement.Y,
         Width     => Float (Metric.W),
         Height    => Float (Metric.H),
         U0        => Metric.U0,
         V0        => Metric.V0,
         U1        => Metric.U1,
         V1        => Metric.V1,
         Color     => Color,
         Codepoint => Codepoint);
   end Add_Glyph;

   function Is_Drawable (Cell : Terminal.Core.Cell) return Boolean;

   procedure Add_Text_Run
     (R       : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot;
      Row     : Positive;
      First_Col : Positive;
      Last_Col  : Positive;
      X       : Float;
      Y       : Float;
      Width   : Float;
      Height  : Float;
      Color   : RM.Pixel_Color)
   is
      Count : RM.Text_Run_Codepoint_Count := 0;
      Shape_Status : Terminal.App.Text_Shaper.Shape_Status;
      First_Cell : constant Terminal.Core.Cell :=
        Terminal.Core.Cell_At (Snapshot, Row, First_Col);
   begin
      if R.Text_Runs = null
        or else R.Text_Run_Count >= R.Text_Runs'Length
        or else First_Cell.Text.Code_Point = 0
      then
         return;
      end if;

      R.Text_Run_Count := R.Text_Run_Count + 1;
      R.Text_Runs (R.Text_Run_Count) :=
        (X               => X,
         Y               => Y,
         Cell_Width      => Width,
         Cell_Height     => Height,
         Cell_Span       => Last_Col - First_Col + Cell_Column_Span (First_Cell),
         Color           => Color,
         Bold            => First_Cell.Style.Bold,
         Italic          => First_Cell.Style.Italic,
         Codepoints      => (others => 0),
         Codepoint_Count => 0,
         Run_Kind        => RM.Invalid_Run,
         Shape_Status    => RM.Invalid_Run,
         Direction       => RM.Direction_Neutral,
         Script          => RM.Script_Common,
         Shaped_Glyphs   => (others => <>),
         Shaped_Glyph_Count => 0,
         Fallback_Glyphs => True);

      for Col in First_Col .. Last_Col loop
         declare
            Cell : constant Terminal.Core.Cell :=
              Terminal.Core.Cell_At (Snapshot, Row, Col);
         begin
            if Cell.Kind /= Terminal.Core.Wide_Continuation then
               exit when Count = RM.Max_Text_Run_Codepoints;
               Count := Count + 1;
               R.Text_Runs (R.Text_Run_Count).Codepoints (Count) :=
                 Natural (Cell.Text.Code_Point);

               for I in 1 .. Cell.Text.Attachment_Count loop
                  exit when Count = RM.Max_Text_Run_Codepoints;
                  Count := Count + 1;
                  R.Text_Runs (R.Text_Run_Count).Codepoints (Count) :=
                    Natural (Cell.Text.Attachments (I));
               end loop;
            end if;
         end;
      end loop;

      R.Text_Runs (R.Text_Run_Count).Codepoint_Count := Count;
      Terminal.App.Text_Shaper.Prepare
        (R.Text_Runs (R.Text_Run_Count),
         Shape_Status);
      R.Shaped_Glyph_Count :=
        R.Shaped_Glyph_Count
        + Natural (R.Text_Runs (R.Text_Run_Count).Shaped_Glyph_Count);
      if R.Text_Runs (R.Text_Run_Count).Fallback_Glyphs then
         R.Text_Fallback_Run_Count := R.Text_Fallback_Run_Count + 1;
      end if;
      if Shape_Status = RM.Needs_Shaping_Backend then
         R.Shaping_Fallback_Count := R.Shaping_Fallback_Count + 1;
      end if;
   end Add_Text_Run;

   procedure Cell_Properties
     (Cell      : Terminal.Core.Cell;
      Direction : out RM.Text_Run_Direction;
      Script    : out RM.Text_Run_Script) is
   begin
      Terminal.App.Text_Shaper.Properties_Of
        (Natural (Cell.Text.Code_Point), Direction, Script);
   end Cell_Properties;

   --  Whether the single cell at (Row, Col) may extend a text run whose first
   --  cell is Base and whose accumulated Direction/Script are carried in-out.
   --  This is Can_Coalesce_Range's per-cell body applied incrementally: the
   --  builder seeds Direction/Script from the run's first cell and calls this
   --  once per candidate cell, making run coalescing O(Cols) instead of the old
   --  O(Cols^2) of re-scanning First..Last on every extension. Direction/Script
   --  are committed only when the cell joins, so a rejected cell leaves them
   --  untouched -- the sequence of accepts yields exactly the same runs as the
   --  whole-range rescan did.
   function Cell_Joins_Run
     (Snapshot  : Terminal.Core.Render_Snapshot;
      Row       : Positive;
      Col       : Positive;
      Base      : Terminal.Core.Cell;
      Direction : in out RM.Text_Run_Direction;
      Script    : in out RM.Text_Run_Script) return Boolean
   is
      Cell     : constant Terminal.Core.Cell :=
        Terminal.Core.Cell_At (Snapshot, Row, Col);
      Cell_Dir : RM.Text_Run_Direction;
      Cell_Scr : RM.Text_Run_Script;
      New_Dir  : RM.Text_Run_Direction := Direction;
      New_Scr  : RM.Text_Run_Script := Script;
   begin
      if not Is_Drawable (Cell)
        or else Cell.Style.Conceal
        or else Cell.Kind = Terminal.Core.Wide_Continuation
        or else Cell.Text.Width /= Terminal.Core.Width_One
        or else Cell.Text.Attachment_Count /= 0
        or else Cell.Style /= Base.Style
        or else Is_Block_Cursor (Snapshot, Row, Col)
      then
         return False;
      end if;

      Cell_Properties (Cell, Cell_Dir, Cell_Scr);
      if Cell_Dir /= RM.Direction_Neutral then
         if New_Dir = RM.Direction_Neutral then
            New_Dir := Cell_Dir;
         elsif New_Dir /= Cell_Dir then
            return False;
         end if;
      end if;

      if Cell_Scr /= RM.Script_Common then
         if New_Scr = RM.Script_Common then
            New_Scr := Cell_Scr;
         elsif New_Scr /= Cell_Scr then
            return False;
         end if;
      end if;

      Direction := New_Dir;
      Script    := New_Scr;
      return True;
   end Cell_Joins_Run;

   procedure Reorder_Mixed_Bidi_Row
     (R     : in out Renderer;
      First : Positive;
      Last  : Natural;
      Right : Float)
   is
      Base : RM.Text_Run_Direction := RM.Direction_Left_To_Right;
   begin
      if Last < First then
         return;
      end if;

      for I in First .. Last loop
         if R.Text_Runs (I).Direction /= RM.Direction_Neutral then
            Base := R.Text_Runs (I).Direction;
            exit;
         end if;
      end loop;

      if Base = RM.Direction_Right_To_Left then
         declare
            Cursor : Float := Right;
         begin
            for I in First .. Last loop
               declare
                  Width : constant Float :=
                    R.Text_Runs (I).Cell_Width
                    * Float (R.Text_Runs (I).Cell_Span);
               begin
                  Cursor := Cursor - Width;
                  R.Text_Runs (I).X := Cursor;
               end;
            end loop;
         end;
      else
         declare
            I : Natural := First;
         begin
            while I <= Last loop
               if R.Text_Runs (I).Direction = RM.Direction_Right_To_Left then
                  declare
                     J : Natural := I;
                     Span_Left  : constant Float := R.Text_Runs (I).X;
                     Span_Right : Float := R.Text_Runs (I).X;
                     Cursor     : Float;
                  begin
                     while J <= Last
                       and then R.Text_Runs (J).Direction =
                         RM.Direction_Right_To_Left
                     loop
                        Span_Right := R.Text_Runs (J).X
                          + R.Text_Runs (J).Cell_Width
                            * Float (R.Text_Runs (J).Cell_Span);
                        J := J + 1;
                     end loop;

                     Cursor := Span_Right;
                     for K in I .. J - 1 loop
                        declare
                           Width : constant Float :=
                             R.Text_Runs (K).Cell_Width
                             * Float (R.Text_Runs (K).Cell_Span);
                        begin
                           Cursor := Cursor - Width;
                           R.Text_Runs (K).X := Cursor;
                        end;
                     end loop;

                     if Cursor < Span_Left then
                        for K in I .. J - 1 loop
                           R.Text_Runs (K).X :=
                             R.Text_Runs (K).X + (Span_Left - Cursor);
                        end loop;
                     end if;

                     I := J;
                  end;
               else
                  I := I + 1;
               end if;
            end loop;
         end;
      end if;
   end Reorder_Mixed_Bidi_Row;

   procedure Build_Text_Runs
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot)
   is
   begin
      for Row in 1 .. Snapshot.Rows loop
         declare
            Col : Positive := 1;
            Row_Has_LTR : Boolean := False;
            Row_Has_RTL : Boolean := False;
            Row_Run_First : constant Positive := R.Text_Run_Count + 1;
         begin
            while Col <= Snapshot.Cols loop
               declare
                  Cell : constant Terminal.Core.Cell :=
                    Terminal.Core.Cell_At (Snapshot, Row, Col);
                  First : constant Positive := Col;
                  Last  : Natural := Col;
               begin
                  if Is_Drawable (Cell)
                    and then not Cell.Style.Conceal
                    and then Cell.Kind /= Terminal.Core.Wide_Continuation
                  then
                     if Cell.Text.Width = Terminal.Core.Width_One
                       and then Cell.Text.Attachment_Count = 0
                       and then not Is_Block_Cursor (Snapshot, Row, Col)
                     then
                        declare
                           Run_Direction : RM.Text_Run_Direction;
                           Run_Script    : RM.Text_Run_Script;
                        begin
                           Cell_Properties (Cell, Run_Direction, Run_Script);
                           while Last < Snapshot.Cols
                             and then Last - First + 1
                                      < RM.Max_Text_Run_Codepoints
                             and then Cell_Joins_Run
                               (Snapshot, Row, Positive (Last + 1),
                                Cell, Run_Direction, Run_Script)
                           loop
                              Last := Last + 1;
                           end loop;
                        end;
                     end if;

                     Add_Text_Run
                       (R,
                        Snapshot  => Snapshot,
                        Row       => Row,
                        First_Col => First,
                        Last_Col  => Positive (Last),
                        X         =>
                          Float (Origin_X (R) + (First - 1) * R.CW),
                        Y         =>
                          Float (Origin_Y (R) + (Row - 1) * R.CH),
                        Width     => Float (R.CW),
                        Height    => Float (R.CH),
                        Color     =>
                          (if Is_Block_Cursor (Snapshot, Row, First)
                           then R.Color_Theme.Cursor_FG
                           else Foreground (R, Cell)));

                     if R.Text_Run_Count > 0 then
                        case R.Text_Runs (R.Text_Run_Count).Direction is
                           when RM.Direction_Left_To_Right =>
                              Row_Has_LTR := True;
                           when RM.Direction_Right_To_Left =>
                              Row_Has_RTL := True;
                           when RM.Direction_Neutral =>
                              null;
                        end case;
                     end if;

                     if Last + Cell_Column_Span (Cell) > Snapshot.Cols then
                        exit;
                     else
                        Col := Positive (Last + Cell_Column_Span (Cell));
                     end if;
                  elsif Col = Snapshot.Cols then
                     exit;
                  else
                     Col := Col + 1;
                  end if;
               end;
            end loop;

            if Row_Has_LTR and then Row_Has_RTL then
               Reorder_Mixed_Bidi_Row
                 (R,
                  First => Row_Run_First,
                  Last  => R.Text_Run_Count,
                  Right =>
                    Float (Origin_X (R) + Snapshot.Cols * R.CW));
            end if;
         end;
      end loop;
   end Build_Text_Runs;

   procedure Initialize_Text
     (R      : in out Renderer;
      Status  : out Init_Status)
   is
      Font_Path   : constant String := Terminal.App.Fonts.Default_Font_Path;
      Text_Status : Textrender.Status_Code;
      Shape_Backend_Status : Terminal.App.Text_Shaper.Backend_Status;
   begin
      R.CW := 8;
      R.CH := 16;
      R.Glyph_Count := 0;
      R.Colour_Glyph_Count := 0;
      R.Shaped_Glyph_Count := 0;
      R.Shaping_Fallback_Count := 0;
      R.Text_Fallback_Run_Count := 0;
      R.Color_Glyph_Count := 0;
      R.Color_Emoji_Fallback_Count := 0;
      R.Paragraph_Bidi_Fallback_Count := 0;
      R.Missing_Glyph_Count := 0;
      R.Rectangle_Count := 0;
      R.Vertex_Count := 0;
      R.Last_Cell_Count := 0;
      R.Last_Dirty_Rows := 0;
      R.Last_Frame_Width := 0;
      R.Last_Frame_Height := 0;
      R.Atlas_Dirty := False;
      R.Colour_Sheet_Dirty := False;

      if Font_Path = "" then
         R.Initialized := False;
         R.Text_Loaded := False;
         Status := Failed;
         return;
      end if;

      Text_Status :=
        Textrender.Load_Font
          (R            => R.Text,
           Path         => Font_Path,
           Pixel_Size   => Pixel_Size,
           Cell_Width   => R.CW,
           Cell_Height  => R.CH,
           Atlas_Width  => Atlas_Width,
           Atlas_Height => Atlas_Height);

      if Text_Status /= Textrender.Success then
         R.Initialized := False;
         R.Text_Loaded := False;
         Status := Failed;
         return;
      end if;

      Terminal.App.Text_Shaper.Configure_Font
        (Path       => Font_Path,
         Pixel_Size => Pixel_Size,
         Status     => Shape_Backend_Status);

      declare
         Measured_CW : constant Positive :=
           Measured_Cell_Width (R.Text, R.CW);
      begin
         if Measured_CW /= R.CW then
            R.CW := Measured_CW;
            Text_Status :=
              Textrender.Load_Font
                (R            => R.Text,
                 Path         => Font_Path,
                 Pixel_Size   => Pixel_Size,
                 Cell_Width   => R.CW,
                 Cell_Height  => R.CH,
                 Atlas_Width  => Atlas_Width,
                 Atlas_Height => Atlas_Height);

            if Text_Status /= Textrender.Success then
               R.Initialized := False;
               R.Text_Loaded := False;
               Status := Failed;
               return;
            end if;

            Terminal.App.Text_Shaper.Configure_Font
              (Path       => Font_Path,
               Pixel_Size => Pixel_Size,
               Status     => Shape_Backend_Status);
         end if;
      end;

      Textrender.Set_Image_Decoder
        (R      => R.Text,
         Extent => Colour_PNG_Extent'Access,
         Decode => Decode_Colour_PNG'Access);

      R.CH := Positive'Max
        (R.CH, Ceiling_Positive (Textrender.Line_Height (R.Text)));

      for Path of Terminal.App.Fonts.Fallback_Font_Paths loop
         declare
            Fallback_Status : constant Textrender.Status_Code :=
              Textrender.Add_Fallback_Font
                (R    => R.Text,
                 Path => Terminal.App.Fonts.To_String (Path));
         begin
            if Fallback_Status = Textrender.Success then
               Terminal.App.Text_Shaper.Add_Fallback_Font
                 (Path       => Terminal.App.Fonts.To_String (Path),
                  Pixel_Size => Pixel_Size,
                  Status     => Shape_Backend_Status);
            end if;
         end;
      end loop;

      declare
         Ignored : constant Textrender.Status_Code :=
           Textrender.Preload
             (R     => R.Text,
              First => 32,
              Last  => 126);
      begin
         null;
      end;

      R.Initialized := True;
      R.Text_Loaded := True;
      R.Atlas_Dirty := Textrender.Atlas_Dirty (R.Text);
      Status := Ok;
   end Initialize_Text;

   procedure Initialize
     (R       : out Renderer;
      Context : Terminal.App.Vulkan_Context.Context;
      Status  : out Init_Status) is
   begin
      R.Closed := False;
      R.Needs_Finalization := True;
      if not Terminal.App.Vulkan_Context.Is_Initialized (Context) then
         R.Initialized := False;
         R.Has_Context := False;
         Status := Failed;
         return;
      end if;

      R.Has_Context := True;
      Initialize_Text (R, Status);
      if Status /= Ok then
         R.Has_Context := False;
      end if;
   end Initialize;

   procedure Initialize_Headless
     (R      : out Renderer;
      Status : out Init_Status) is
   begin
      R.Closed := False;
      R.Needs_Finalization := True;
      R.Has_Context := False;
      Initialize_Text (R, Status);
   end Initialize_Headless;

   procedure Set_Graphics_Resource_Limits
     (R      : in out Renderer;
      Limits : Graphics_Resource_Limits)
   is
   begin
      Reset_Frame (R);
      R.Graphics_Limits := Limits;
      VS.Set_Image_Atlas_Limits
        (R.Batch,
         (Bytes     => Limits.GPU_Atlas_Bytes,
          Dimension => Limits.GPU_Atlas_Dimension));
      while
        (Stored_Image_Count (R) > Limits.Image_Objects
         or else Stored_Image_Bytes (R) > Limits.Image_Bytes
         or else Stored_Animation_Frame_Count (R) > Limits.Animation_Frames)
        and then Evict_One_Unplaced_Image (R, 0, 0)
      loop
         null;
      end loop;
   end Set_Graphics_Resource_Limits;

   function Graphics_Resource_Limit
     (R : Renderer) return Graphics_Resource_Limits is
     (R.Graphics_Limits);

   procedure Set_Graphics_Access_Policy
     (R      : in out Renderer;
      Policy : Terminal.App.Graphics_Transport.Access_Policy) is
   begin
      R.Graphics_Access := Policy;
   end Set_Graphics_Access_Policy;

   function Graphics_Access_Policy
     (R : Renderer) return Terminal.App.Graphics_Transport.Access_Policy is
     (R.Graphics_Access);

   procedure Set_ITerm2_Download_Policy
     (R      : in out Renderer;
      Policy : Terminal.App.ITerm2_Files.Download_Policy) is
   begin
      R.ITerm2_Downloads := Policy;
   end Set_ITerm2_Download_Policy;

   function ITerm2_Download_Policy
     (R : Renderer) return Terminal.App.ITerm2_Files.Download_Policy is
     (R.ITerm2_Downloads);

   function Is_Drawable (Cell : Terminal.Core.Cell) return Boolean is
   begin
      return Cell.Kind = Terminal.Core.Character
        and then Cell.Text.Width /= Terminal.Core.Width_Zero
        and then Natural (Cell.Text.Code_Point) /= 0
        and then not Cell.Image.Is_Placeholder;
   end Is_Drawable;

   --  Record a colour glyph's picture for this frame, if the font has one.
   --
   --  Returns False when the codepoint has no colour glyph, when no font is
   --  loaded, or when the picture is larger than a tile may be -- in every case
   --  the caller carries on and looks for an outline exactly as it always did.
   function Add_Colour_Glyph
     (R         : in out Renderer;
      Codepoint : Terminal.Common.Code_Point;
      X         : Float;
      Y         : Float)
      return Boolean;

   function Add_Colour_Glyph
     (R         : in out Renderer;
      Codepoint : Terminal.Common.Code_Point;
      X         : Float;
      Y         : Float)
      return Boolean
   is
      use type Textrender.Status_Code;

      Code   : constant Textrender.Codepoint :=
        Textrender.Codepoint (Natural (Codepoint));
      Colour : Textrender.Colour_Glyph;
   begin
      if not R.Text_Loaded
        or else R.Colour_Glyphs = null
        or else R.Colour_Glyph_Count >= R.Colour_Glyphs'Length
        or else not Textrender.Has_Colour_Glyph (R.Text, Code)
      then
         return False;
      end if;

      if Textrender.Get_Colour_Glyph (R.Text, Code, Colour) /= Textrender.Success
        or else Colour.Width = 0
        or else Colour.Height = 0
      then
         return False;
      end if;

      R.Colour_Glyph_Count := R.Colour_Glyph_Count + 1;

      declare
         Tile : RM.Colour_Glyph_Command renames
           R.Colour_Glyphs (R.Colour_Glyph_Count);
      begin
         Tile.X := X;

         --  Sits in the line the way an outline does: the metric centres the
         --  picture in the cell rather than resting it on the baseline.
         Tile.Y := Y + Textrender.Ascent (R.Text) - Colour.Bearing_Y;
         Tile.Width := Colour.Width;
         Tile.Height := Colour.Height;
         Tile.U0 := Colour.U0;
         Tile.V0 := Colour.V0;
         Tile.U1 := Colour.U1;
         Tile.V1 := Colour.V1;
      end;

      return True;
   end Add_Colour_Glyph;

   procedure Draw_Glyph
     (R         : in out Renderer;
      Codepoint : Terminal.Common.Code_Point;
      X         : Float;
      Y         : Float;
      Color     : RM.Pixel_Color;
      Bold      : Boolean;
      Italic    : Boolean;
      Status    : out Render_Status)
   is
      Metric       : Textrender.Glyph_Metric;
      Glyph_Status : Textrender.Status_Code;
      Placement : Textrender.Glyph_Placement;
   begin
      --  A codepoint the font holds as a picture leaves here as a tile rather
      --  than a glyph: the glyph atlas is one coverage channel, with nowhere to
      --  keep a colour. Tried first, because for such a codepoint the outline
      --  lookup below has nothing to find.
      if Add_Colour_Glyph (R, Codepoint, X, Y) then
         R.Color_Glyph_Count := R.Color_Glyph_Count + 1;
         Status := Ok;
         return;
      end if;

      if Is_Emoji_Scalar (Codepoint) then
         R.Color_Emoji_Fallback_Count := R.Color_Emoji_Fallback_Count + 1;
      end if;

      Glyph_Status :=
        Textrender.Get_Glyph
          (R     => R.Text,
           C     => Textrender.Codepoint (Natural (Codepoint)),
           M     => Metric,
           Style =>
             (if Italic then Textrender.Italic else Textrender.Regular));

      case Glyph_Status is
         when Textrender.Success | Textrender.Glyph_Missing =>
            if Glyph_Status = Textrender.Glyph_Missing then
               R.Missing_Glyph_Count := R.Missing_Glyph_Count + 1;
            end if;

            if Metric.W > 0 and then Metric.H > 0 then
               Placement :=
                 Textrender.Place_Glyph_In_Cell
                   (R      => R.Text,
                    M      => Metric,
                    Cell_X => X,
                    Cell_Y => Y);
               Add_Glyph
                 (R,
                  Placement => Placement,
                  Metric    => Metric,
                  Color     => Color,
                  Codepoint => Natural (Codepoint));
               if Bold then
                  Placement.X := Placement.X + 1.0;
                  Add_Glyph
                    (R,
                     Placement => Placement,
                     Metric    => Metric,
                     Color     => Color,
                     Codepoint => Natural (Codepoint));
               end if;
            end if;
            Status := Ok;
         when others =>
            Status := Glyph_Load_Failed;
      end case;
   end Draw_Glyph;

   function Draw_Emoji_Run_Color
     (R   : in out Renderer;
      Run : RM.Text_Run_Command)
      return Boolean
   is
      Pen_X  : Float := Run.X;
      Drawn  : Natural := 0;
      Missed : Natural := 0;
   begin
      if Run.Script /= RM.Script_Emoji then
         return False;
      end if;

      for I in 1 .. Run.Codepoint_Count loop
         declare
            C : constant Terminal.Common.Code_Point :=
              Terminal.Common.Code_Point (Run.Codepoints (I));
         begin
            if Is_Emoji_Scalar (C) then
               if Add_Colour_Glyph (R, C, Pen_X, Run.Y) then
                  R.Color_Glyph_Count := R.Color_Glyph_Count + 1;
                  Drawn := Drawn + 1;
                  Pen_X := Pen_X + Float (R.CW * 2);
               else
                  Missed := Missed + 1;
               end if;
            end if;
         end;
      end loop;

      R.Color_Emoji_Fallback_Count :=
        R.Color_Emoji_Fallback_Count + Missed;
      return Drawn > 0;
   end Draw_Emoji_Run_Color;

   procedure Add_Link_Overlay
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot;
      Status   : out Render_Status)
   is
      Label : constant String :=
        Terminal.App.Hyperlinks.Status_Label (R.Hovered_Link);
      Count : constant Natural :=
        Natural'Min
          (Natural'Min (Label'Length, Max_Link_Overlay_Chars),
           Snapshot.Cols);
      X : constant Float := Float (Origin_X (R));
      Y : constant Float :=
        Float (Origin_Y (R) + (Snapshot.Rows - 1) * R.CH);
   begin
      if Count = 0 then
         Status := Ok;
         return;
      end if;

      Add_Rectangle
        (R,
         X      => X,
         Y      => Y,
         Width  => Float (Count * R.CW),
         Height => Float (R.CH),
         Color  => (R => 0.0, G => 0.0, B => 0.0, A => 0.92));

      for Offset in 0 .. Count - 1 loop
         Draw_Glyph
           (R,
            Codepoint =>
              Terminal.Common.Code_Point
                (Character'Pos (Label (Label'First + Offset))),
            X      => X + Float (Offset * R.CW),
            Y      => Y,
            Color  => R.Color_Theme.Default_FG,
            Bold   => False,
            Italic => False,
            Status => Status);
         if Status /= Ok then
            return;
         end if;
      end loop;

      Status := Ok;
   end Add_Link_Overlay;

   procedure Draw_Label
     (R      : in out Renderer;
      Text   : String;
      X      : Float;
      Y      : Float;
      Limit  : Natural;
      Color  : RM.Pixel_Color;
      Status : out Render_Status)
   is
      Count : constant Natural := Natural'Min (Text'Length, Limit);
   begin
      for Offset in 0 .. Count - 1 loop
         Draw_Glyph
           (R,
            Codepoint =>
              Terminal.Common.Code_Point
                (Character'Pos (Text (Text'First + Offset))),
            X      => X + Float (Offset * R.CW),
            Y      => Y,
            Color  => Color,
            Bold   => False,
            Italic => False,
            Status => Status);
         if Status /= Ok then
            return;
         end if;
      end loop;

      Status := Ok;
   end Draw_Label;

   procedure Draw_Shaped_Run
     (R      : in out Renderer;
      Run    : RM.Text_Run_Command;
      Status : out Render_Status);

   procedure Build_Shaped_Run_Map
     (R         : in out Renderer;
      Snapshot  : Terminal.Core.Render_Snapshot;
      First_Run : Positive);

   function Shaped_Run_At
     (R    : Renderer;
      Cols : Positive;
      Row  : Positive;
      Col  : Positive) return Shaped_Run_Map_Entry;

   procedure Draw_Snapshot_Into
     (R            : in out Renderer;
      Snapshot     : Terminal.Core.Render_Snapshot;
      Show_Overlay : Boolean;
      Status       : out Render_Status)
   is
      First_Run : constant Positive := R.Text_Run_Count + 1;
   begin
      Build_Text_Runs (R, Snapshot);
      Build_Shaped_Run_Map (R, Snapshot, First_Run);

      for Row in 1 .. Snapshot.Rows loop
         for Col in 1 .. Snapshot.Cols loop
            declare
               Cell : constant Terminal.Core.Cell :=
                 Terminal.Core.Cell_At (Snapshot, Row, Col);
               X    : constant Float :=
                 Float (Origin_X (R) + (Col - 1) * R.CW);
               Y    : constant Float :=
                 Float (Origin_Y (R) + (Row - 1) * R.CH);
               Cell_W : constant Positive :=
                 (if Cell.Text.Width = Terminal.Core.Width_Two then R.CW * 2 else R.CW);
               Cursor_Cell : constant Boolean := Is_Cursor_Cell (Snapshot, Row, Col);
               Block_Cursor : constant Boolean :=
                 Is_Block_Cursor (Snapshot, Row, Col);
               FG : constant RM.Pixel_Color :=
                 (if Block_Cursor
                  then R.Color_Theme.Cursor_FG
                  else Foreground (R, Cell));
               BG : constant RM.Pixel_Color := Background (R, Cell);
            begin
               if Cell.Kind /= Terminal.Core.Wide_Continuation then
                  Add_Rectangle
                    (R,
                     X      => X,
                     Y      => Y,
                     Width  => Float (Cell_W),
                     Height => Float (R.CH),
                     Color  => BG,
                     Layer  =>
                       (if Has_Non_Default_Background (Cell)
                        then RM.Rectangle_Cell_Background
                        else RM.Rectangle_Base_Background));
                  if Cursor_Cell then
                     case Snapshot.Cursor.Shape is
                        when Terminal.Core.Cursor_Block =>
                           Add_Rectangle
                             (R,
                              X      => X,
                              Y      => Cursor_Block_Y (R, Y),
                              Width  => Float (Cell_W),
                              Height => Float (Cursor_Block_Height (R)),
                              Color  => R.Color_Theme.Cursor_BG);
                        when Terminal.Core.Cursor_Underline =>
                           Add_Rectangle
                             (R,
                              X      => X,
                              Y      =>
                                Y + Float (R.CH - Cursor_Underline_Height (R)),
                              Width  => Float (Cell_W),
                              Height => Float (Cursor_Underline_Height (R)),
                              Color  => R.Color_Theme.Cursor_BG);
                        when Terminal.Core.Cursor_Bar =>
                           Add_Rectangle
                             (R,
                              X      => X,
                              Y      => Cursor_Block_Y (R, Y),
                              Width  => Float (Cursor_Bar_Width (R)),
                              Height => Float (Cursor_Block_Height (R)),
                              Color  => R.Color_Theme.Cursor_BG);
                     end case;
                  end if;
               end if;

               if Is_Drawable (Cell) and then not Cell.Style.Conceal then
                  declare
                     Glyph_Render_Status : Render_Status;
                     Run_Entry           : constant Shaped_Run_Map_Entry :=
                       Shaped_Run_At (R, Snapshot.Cols, Row, Col);
                  begin
                     if Run_Entry.Starts_Here then
                        if not Draw_Emoji_Run_Color
                          (R, R.Text_Runs (Run_Entry.Run_Index))
                        then
                           Draw_Shaped_Run
                             (R,
                              Run    => R.Text_Runs (Run_Entry.Run_Index),
                              Status => Glyph_Render_Status);
                           if Glyph_Render_Status /= Ok then
                              Status := Glyph_Render_Status;
                              return;
                           end if;
                        end if;
                     elsif Run_Entry.Run_Index = 0 then
                        Draw_Glyph
                          (R,
                           Codepoint => Cell.Text.Code_Point,
                           X         => X,
                           Y         => Y,
                           Color     => FG,
                           Bold      => Cell.Style.Bold,
                           Italic    => Cell.Style.Italic,
                           Status    => Glyph_Render_Status);
                        if Glyph_Render_Status /= Ok then
                           Status := Glyph_Render_Status;
                           return;
                        end if;

                        for I in 1 .. Cell.Text.Attachment_Count loop
                           if Terminal.Core.Is_Renderable_Attachment
                             (Cell.Text.Attachments (I))
                           then
                              Draw_Glyph
                                (R,
                                 Codepoint => Cell.Text.Attachments (I),
                                 X         => X,
                                 Y         => Y,
                                 Color     => FG,
                                 Bold      => Cell.Style.Bold,
                                 Italic    => Cell.Style.Italic,
                                 Status    => Glyph_Render_Status);
                              if Glyph_Render_Status /= Ok then
                                 Status := Glyph_Render_Status;
                                 return;
                              end if;
                           end if;
                        end loop;
                     end if;
                  end;

                  if Cell.Style.Overline then
                     Add_Rectangle
                       (R,
                        X      => X,
                        Y      => Y,
                        Width  => Float (Cell_W),
                        Height => 1.0,
                        Color  => FG);
                  end if;

                  if Cell.Style.Underline or else Is_Hovered_Link_Cell (R, Cell) then
                     Add_Underline
                       (R,
                        (if Cell.Style.Underline
                         then Cell.Style.Underline_Kind
                         else Terminal.Core.Underline_Single),
                        X,
                        Y,
                        Float (Cell_W),
                        Underline_Color (R, Cell, FG));
                  end if;

                  if Cell.Style.Strikethrough then
                     Add_Rectangle
                       (R,
                        X      => X,
                        Y      => Y + Float (R.CH) / 2.0,
                        Width  => Float (Cell_W),
                        Height => 1.0,
                        Color  => FG);
                  end if;
               end if;
            end;
         end loop;
      end loop;

      Synchronize_Graphics_Screen (R, Snapshot);
      if Snapshot.Graphics.Pending then
         Synchronize_Graphics_Scroll
           (R, Snapshot, Snapshot.Graphics.Scroll_Sequence);
      end if;
      Add_Image (R, Snapshot.Graphics, Snapshot);
      if R.Graphics_Event_Tracking_Failed then
         Status := Allocation_Failed;
         return;
      end if;
      Synchronize_Graphics_Screen (R, Snapshot);
      Synchronize_Graphics_Scroll
        (R, Snapshot, Snapshot.Graphics_Scroll_Current);
      Add_Conventional_Images (R, Snapshot);
      Add_Placeholder_Images (R, Snapshot);

      if Show_Overlay then
         Add_Link_Overlay (R, Snapshot, Status);
      else
         Status := Ok;
      end if;
   end Draw_Snapshot_Into;

   procedure Draw_Shaped_Run
     (R      : in out Renderer;
      Run    : RM.Text_Run_Command;
      Status : out Render_Status)
   is
      Pen_X : Float :=
        (if Run.Direction = RM.Direction_Right_To_Left
         then Run.X + Run.Cell_Width * Float (Run.Cell_Span)
         else Run.X);
   begin
      if Run.Shape_Status /= RM.Shape_Ok
        or else Run.Fallback_Glyphs
        or else Run.Shaped_Glyph_Count = 0
      then
         Status := Glyph_Load_Failed;
         return;
      end if;

      for I in 1 .. Run.Shaped_Glyph_Count loop
         declare
            Glyph : constant RM.Shaped_Glyph_Command := Run.Shaped_Glyphs (I);
            Advance_X : constant Float := Glyph.X_Advance;
            Step_X    : constant Float :=
              (if Run.Direction = RM.Direction_Right_To_Left
                 and then Advance_X > 0.0
               then -Advance_X
               else Advance_X);
            Glyph_X   : constant Float :=
              (if Run.Direction = RM.Direction_Right_To_Left
               then Pen_X + Step_X
               else Pen_X);
            Metric : Textrender.Glyph_Metric;
            Glyph_Status : constant Textrender.Status_Code :=
              Textrender.Get_Glyph_By_Index
                (R           => R.Text,
                 Glyph_Index => Glyph.Glyph_ID,
                 M           => Metric,
                 Font_Index  => Glyph.Font_Index,
                 Style       =>
                   (if Run.Italic then Textrender.Italic else Textrender.Regular));
         begin
            case Glyph_Status is
               when Textrender.Success | Textrender.Glyph_Missing =>
                  if Glyph_Status = Textrender.Glyph_Missing then
                     R.Missing_Glyph_Count := R.Missing_Glyph_Count + 1;
                  end if;

                  if Metric.W > 0 and then Metric.H > 0 then
                     declare
                        Baseline_Y : constant Float :=
                          Run.Y + Textrender.Ascent (R.Text);
                        Placement  : Textrender.Glyph_Placement :=
                          (X => Glyph_X + Glyph.X_Offset + Metric.Bearing_X,
                           Y =>
                             Baseline_Y
                             - Metric.Bearing_Y
                             - Glyph.Y_Offset);
                     begin
                        Add_Glyph
                          (R,
                           Placement => Placement,
                           Metric    => Metric,
                           Color     => Run.Color,
                           Codepoint => Glyph.Codepoint);
                        if Run.Bold then
                           Placement.X := Placement.X + 1.0;
                           Add_Glyph
                             (R,
                              Placement => Placement,
                              Metric    => Metric,
                              Color     => Run.Color,
                              Codepoint => Glyph.Codepoint);
                        end if;
                     end;
                  end if;
               when others =>
                  Status := Glyph_Load_Failed;
                  return;
            end case;

            if Run.Direction = RM.Direction_Right_To_Left then
               Pen_X := Glyph_X;
            else
               Pen_X := Pen_X + Step_X;
            end if;
         end;
      end loop;

      Status := Ok;
   end Draw_Shaped_Run;

   function Is_Shaped_Draw_Run (Run : RM.Text_Run_Command) return Boolean is
     (Run.Shape_Status = RM.Shape_Ok
      and then not Run.Fallback_Glyphs
      and then Run.Shaped_Glyph_Count > 0);

   procedure Build_Shaped_Run_Map
     (R         : in out Renderer;
      Snapshot  : Terminal.Core.Render_Snapshot;
      First_Run : Positive)
   is
      Cell_Count : constant Natural := Snapshot.Rows * Snapshot.Cols;
   begin
      if R.Shaped_Run_Map = null
        or else R.Shaped_Run_Map'Length < Cell_Count
      then
         return;
      end if;

      R.Shaped_Run_Map (1 .. Cell_Count) := (others => <>);
      for I in First_Run .. R.Text_Run_Count loop
         if Is_Shaped_Draw_Run (R.Text_Runs (I)) then
            declare
               Run : RM.Text_Run_Command renames R.Text_Runs (I);
               Row_Number : constant Integer :=
                 Integer
                   ((Run.Y - Float (Origin_Y (R))) / Float (R.CH)) + 1;
               Start_Column : constant Integer :=
                 Integer
                   ((Run.X - Float (Origin_X (R))) / Float (R.CW)) + 1;
            begin
               if Row_Number in 1 .. Snapshot.Rows
                 and then Start_Column in 1 .. Snapshot.Cols
               then
                  declare
                     Row : constant Positive := Positive (Row_Number);
                     First_Col : constant Positive := Positive (Start_Column);
                     Last_Col : constant Positive := Positive'Min
                       (Snapshot.Cols, First_Col + Run.Cell_Span - 1);
                  begin
                     for Col in First_Col .. Last_Col loop
                        R.Shaped_Run_Map
                          ((Row - 1) * Snapshot.Cols + Col) :=
                            (Run_Index   => I,
                             Starts_Here => Col = First_Col);
                     end loop;
                  end;
               end if;
            end;
         end if;
      end loop;
   end Build_Shaped_Run_Map;

   function Shaped_Run_At
     (R : Renderer;
      Cols : Positive;
      Row  : Positive;
      Col  : Positive) return Shaped_Run_Map_Entry
   is
      Index : constant Positive := (Row - 1) * Cols + Col;
   begin
      if R.Shaped_Run_Map = null or else Index > R.Shaped_Run_Map'Length then
         return (others => <>);
      else
         return R.Shaped_Run_Map (Index);
      end if;
   end Shaped_Run_At;

   procedure Render
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot;
      Status   : out Render_Status)
   is
      Cell_Count     : Natural;
      Rect_Max       : Natural;
      Content_Width  : Natural;
      Content_Height : Natural;
      Capacity_Ok    : Boolean;
   begin
      if not R.Initialized or else not R.Text_Loaded then
         Set_Render_Status (R, Status, Not_Initialized);
         return;
      elsif Snapshot.Rows = 0 or else Snapshot.Cols = 0 then
         Set_Render_Status (R, Status, Invalid_Snapshot);
         return;
      end if;

      Reset_Frame (R);
      R.Graphics_Event_Tracking_Failed := False;
      R.Missing_Glyph_Count := 0;
      R.Shaped_Glyph_Count := 0;
      R.Shaping_Fallback_Count := 0;
      R.Text_Fallback_Run_Count := 0;
      R.Color_Glyph_Count := 0;
      R.Color_Emoji_Fallback_Count := 0;
      R.Paragraph_Bidi_Fallback_Count := 0;

      Cell_Count := Snapshot.Rows * Snapshot.Cols;
      Rect_Max := Cell_Count * 4 + 3;
      Ensure_Frame_Capacity
        (R,
         Rectangle_Count => Positive (Rect_Max),
         Glyph_Count => Positive
           (Cell_Count
            * Natural'Max
                (Terminal.Core.Max_Cluster_Attachments + 1,
                 RM.Max_Shaped_Glyphs_Per_Run)
            * 2
            + Max_Link_Overlay_Chars),
         --  One tile per cell is the most a frame can ask for, and emoji are
         --  rare enough that a smaller cap would be a cliff rather than a saving.
         Colour_Count => Positive (Cell_Count),
         Image_Count => Positive (Cell_Count + 1),
         Text_Run_Count => Positive (Cell_Count),
         Success => Capacity_Ok);
      if not Capacity_Ok then
         Release_Frame (R);
         Set_Render_Status (R, Status, Allocation_Failed);
         return;
      end if;
      R.Last_Cell_Count := Cell_Count;
      Content_Width := Snapshot.Cols * R.CW + Content_Margin * 2;
      Content_Height := Snapshot.Rows * R.CH + Content_Margin * 2;
      R.Last_Frame_Width := Natural'Max (Content_Width, R.Target_Frame_Width);
      R.Last_Frame_Height := Natural'Max (Content_Height, R.Target_Frame_Height);

      if Snapshot.Dirty /= null then
         for Row in 1 .. Snapshot.Rows loop
            if Snapshot.Dirty (Row) then
               R.Last_Dirty_Rows := R.Last_Dirty_Rows + 1;
            end if;
         end loop;
      end if;

      Add_Rectangle
        (R,
         X      => 0.0,
         Y      => 0.0,
         Width  => Float (R.Last_Frame_Width),
         Height => Float (R.Last_Frame_Height),
         Color  => R.Color_Theme.Default_BG,
         Layer  => RM.Rectangle_Base_Background);

      Build_Text_Runs (R, Snapshot);
      Build_Shaped_Run_Map (R, Snapshot, 1);

      for Row in 1 .. Snapshot.Rows loop
         for Col in 1 .. Snapshot.Cols loop
            declare
               Cell : constant Terminal.Core.Cell :=
                 Terminal.Core.Cell_At (Snapshot, Row, Col);
               X    : constant Float :=
                 Float (Origin_X (R) + (Col - 1) * R.CW);
               Y    : constant Float :=
                 Float (Origin_Y (R) + (Row - 1) * R.CH);
               Cell_W : constant Positive :=
                 (if Cell.Text.Width = Terminal.Core.Width_Two then R.CW * 2 else R.CW);
               Cursor_Cell : constant Boolean := Is_Cursor_Cell (Snapshot, Row, Col);
               Block_Cursor : constant Boolean :=
                 Is_Block_Cursor (Snapshot, Row, Col);
               FG : constant RM.Pixel_Color :=
                 (if Block_Cursor
                  then R.Color_Theme.Cursor_FG
                  else Foreground (R, Cell));
               BG : constant RM.Pixel_Color := Background (R, Cell);
            begin
               if Cell.Kind /= Terminal.Core.Wide_Continuation then
                  Add_Rectangle
                    (R,
                     X      => X,
                     Y      => Y,
                     Width  => Float (Cell_W),
                     Height => Float (R.CH),
                     Color  => BG,
                     Layer  =>
                       (if Has_Non_Default_Background (Cell)
                        then RM.Rectangle_Cell_Background
                        else RM.Rectangle_Base_Background));
                  if Cursor_Cell then
                     case Snapshot.Cursor.Shape is
                        when Terminal.Core.Cursor_Block =>
                           Add_Rectangle
                             (R,
                              X      => X,
                              Y      => Cursor_Block_Y (R, Y),
                              Width  => Float (Cell_W),
                              Height => Float (Cursor_Block_Height (R)),
                              Color  => R.Color_Theme.Cursor_BG);
                        when Terminal.Core.Cursor_Underline =>
                           Add_Rectangle
                             (R,
                              X      => X,
                              Y      =>
                                Y + Float (R.CH - Cursor_Underline_Height (R)),
                              Width  => Float (Cell_W),
                              Height => Float (Cursor_Underline_Height (R)),
                              Color  => R.Color_Theme.Cursor_BG);
                        when Terminal.Core.Cursor_Bar =>
                           Add_Rectangle
                             (R,
                              X      => X,
                              Y      => Cursor_Block_Y (R, Y),
                              Width  => Float (Cursor_Bar_Width (R)),
                              Height => Float (Cursor_Block_Height (R)),
                              Color  => R.Color_Theme.Cursor_BG);
                     end case;
                  end if;
               end if;

               if Is_Drawable (Cell) and then not Cell.Style.Conceal then
                  declare
                     Glyph_Render_Status : Render_Status;
                     Run_Entry           : constant Shaped_Run_Map_Entry :=
                       Shaped_Run_At (R, Snapshot.Cols, Row, Col);
                  begin
                     if Run_Entry.Starts_Here then
                        if not Draw_Emoji_Run_Color
                          (R, R.Text_Runs (Run_Entry.Run_Index))
                        then
                           Draw_Shaped_Run
                             (R,
                              Run    => R.Text_Runs (Run_Entry.Run_Index),
                              Status => Glyph_Render_Status);
                           if Glyph_Render_Status /= Ok then
                              Set_Render_Status (R, Status, Glyph_Render_Status);
                              return;
                           end if;
                        end if;
                     elsif Run_Entry.Run_Index = 0 then
                        Draw_Glyph
                          (R,
                           Codepoint => Cell.Text.Code_Point,
                           X         => X,
                           Y         => Y,
                           Color     => FG,
                           Bold      => Cell.Style.Bold,
                           Italic    => Cell.Style.Italic,
                           Status    => Glyph_Render_Status);
                        if Glyph_Render_Status /= Ok then
                           Set_Render_Status (R, Status, Glyph_Render_Status);
                           return;
                        end if;

                        for I in 1 .. Cell.Text.Attachment_Count loop
                           if Terminal.Core.Is_Renderable_Attachment
                             (Cell.Text.Attachments (I))
                           then
                              Draw_Glyph
                                (R,
                                 Codepoint => Cell.Text.Attachments (I),
                                 X         => X,
                                 Y         => Y,
                                 Color     => FG,
                                 Bold      => Cell.Style.Bold,
                                 Italic    => Cell.Style.Italic,
                                 Status    => Glyph_Render_Status);
                              if Glyph_Render_Status /= Ok then
                                 Set_Render_Status
                                   (R, Status, Glyph_Render_Status);
                                 return;
                              end if;
                           end if;
                        end loop;
                     end if;
                  end;

                  if Cell.Style.Overline then
                     Add_Rectangle
                       (R,
                        X      => X,
                        Y      => Y,
                        Width  => Float (Cell_W),
                        Height => 1.0,
                        Color  => FG);
                  end if;

                  if Cell.Style.Underline or else Is_Hovered_Link_Cell (R, Cell) then
                     Add_Underline
                       (R,
                        (if Cell.Style.Underline
                         then Cell.Style.Underline_Kind
                         else Terminal.Core.Underline_Single),
                        X,
                        Y,
                        Float (Cell_W),
                        Underline_Color (R, Cell, FG));
                  end if;

                  if Cell.Style.Strikethrough then
                     Add_Rectangle
                       (R,
                        X      => X,
                        Y      => Y + Float (R.CH) / 2.0,
                        Width  => Float (Cell_W),
                        Height => 1.0,
                        Color  => FG);
                  end if;
               end if;
            end;
         end loop;
      end loop;

      Synchronize_Graphics_Screen (R, Snapshot);
      if Snapshot.Graphics.Pending then
         Synchronize_Graphics_Scroll
           (R, Snapshot, Snapshot.Graphics.Scroll_Sequence);
      end if;
      Add_Image (R, Snapshot.Graphics, Snapshot);
      if R.Graphics_Event_Tracking_Failed then
         Release_Frame (R);
         Set_Render_Status (R, Status, Allocation_Failed);
         return;
      end if;
      Advance_Animations (R);
      Synchronize_Graphics_Screen (R, Snapshot);
      Synchronize_Graphics_Scroll
        (R, Snapshot, Snapshot.Graphics_Scroll_Current);
      Add_Conventional_Images (R, Snapshot);
      Add_Placeholder_Images (R, Snapshot);

      Add_Link_Overlay (R, Snapshot, Status);
      if Status /= Ok then
         Set_Render_Status (R, Status, Status);
         return;
      end if;

      R.Atlas_Dirty := R.Atlas_Dirty or else Textrender.Atlas_Dirty (R.Text);
      R.Colour_Sheet_Dirty :=
        R.Colour_Sheet_Dirty or else Textrender.Colour_Sheet_Dirty (R.Text);

      declare
         Batch_Status : VS.Build_Status;
      begin
         VS.Build (Last_Frame (R), R.Batch, Batch_Status);
         if Batch_Status /= VS.Ok then
            Set_Render_Status (R, Status, Batch_Build_Failed);
            return;
         end if;
         R.Vertex_Count := VS.Vertex_Count (R.Batch);
      end;

      --  The single-snapshot entry point has no separate presentation phase;
      --  a successful build is its commit boundary. The GUI uses Render_App
      --  and commits only after the presenter accepts the frame.
      Commit_Graphics_Events (R);
      Set_Render_Status (R, Status, Ok);
   end Render;

   procedure Render_App
     (R              : in out Renderer;
      Snapshots      : Snapshot_Array;
      Active_Index   : Positive;
      Tabs           : Terminal.App.Tabs.Tab_Snapshot;
      Splits         : Terminal.App.Splits.Split_Snapshot;
      Status         : out Render_Status)
   is
      Cell_Count : Natural := 0;
      Rect_Max   : Natural;
      Glyph_Max  : Natural;
      Text_Run_Max : Natural := 0;
      Colour_Max : Natural := 0;
      Image_Max  : Natural := Natural'Max (1, Snapshots'Length);
      Tab_Height : constant Natural :=
        (if Tabs.Count > 1 then R.CH + Pane_Border_Pixels else 0);
      Frame_W : Natural := 0;
      Frame_H : Natural := Tab_Height;
      Pane_X  : Natural := 0;
      Pane_Y  : Natural := Tab_Height;
      Draw_Status : Render_Status;
      Capacity_Ok : Boolean;

      function Pane_Width (S : Terminal.Core.Render_Snapshot) return Natural is
        (S.Cols * R.CW + Content_Margin * 2);

      function Pane_Height (S : Terminal.Core.Render_Snapshot) return Natural is
        (S.Rows * R.CH + Content_Margin * 2);

      procedure Draw_Pane_Border
        (X      : Natural;
         Y      : Natural;
         Width  : Natural;
         Height : Natural;
         Active : Boolean)
      is
         Color : constant RM.Pixel_Color :=
           (if Active then R.Color_Theme.Cursor_BG else
              (R => 0.22, G => 0.24, B => 0.27, A => 1.0));
         Thickness : constant Float := Float (Pane_Border_Pixels);
      begin
         if Width = 0 or else Height = 0 then
            return;
         end if;
         Add_Rectangle (R, Float (X), Float (Y), Float (Width), Thickness, Color);
         Add_Rectangle
           (R,
            Float (X),
            Float (Y + Height - Pane_Border_Pixels),
            Float (Width),
            Thickness,
            Color);
         Add_Rectangle (R, Float (X), Float (Y), Thickness, Float (Height), Color);
         Add_Rectangle
           (R,
            Float (X + Width - Pane_Border_Pixels),
            Float (Y),
            Thickness,
            Float (Height),
            Color);
      end Draw_Pane_Border;

      procedure Draw_Tab_Bar is
      begin
         if Tabs.Count <= 1 then
            return;
         end if;

         declare
            Count : constant Positive := Positive (Tabs.Count);
            Base  : constant Natural := Frame_W / Count;
            Extra : constant Natural := Frame_W mod Count;
            X     : Natural := 0;
         begin
            Add_Rectangle
              (R,
               X      => 0.0,
               Y      => 0.0,
               Width  => Float (Frame_W),
               Height => Float (Tab_Height),
               Color  => (R => 0.08, G => 0.09, B => 0.10, A => 1.0));

            for I in 1 .. Tabs.Count loop
               declare
                  Width : constant Natural :=
                    Base + (if Natural (I) <= Extra then 1 else 0);
                  Col_Width : constant Natural :=
                    (if Width = 0 then 0 else Width / R.CW);
                  Active : constant Boolean := I = Tabs.Active;
               begin
                  if Width > 0 then
                     Add_Rectangle
                       (R,
                        X      => Float (X),
                        Y      => 0.0,
                        Width  => Float (Width),
                        Height => Float (R.CH),
                        Color  =>
                          (if Active
                           then (R => 0.18, G => 0.25, B => 0.34, A => 1.0)
                           else (R => 0.12, G => 0.13, B => 0.15, A => 1.0)));
                     if Col_Width > 0 then
                        declare
                           Label : constant String :=
                             Terminal.App.Tabs.Fitted_Label
                               (Tabs.Labels (I), Col_Width);
                        begin
                           Draw_Label
                             (R,
                              Text   => Label,
                              X      => Float (X + 1),
                              Y      => 0.0,
                              Limit  => Col_Width,
                              Color  => R.Color_Theme.Default_FG,
                              Status => Draw_Status);
                        end;
                        if Draw_Status /= Ok then
                           Status := Draw_Status;
                           return;
                        end if;
                     end if;
                  end if;
                  X := X + Width;
               end;
            end loop;
         end;

         Status := Ok;
      end Draw_Tab_Bar;
   begin
      Status := Ok;
      if not R.Initialized or else not R.Text_Loaded then
         Set_Render_Status (R, Status, Not_Initialized);
         return;
      elsif Snapshots'Length = 0
        or else Active_Index < Snapshots'First
        or else Active_Index > Snapshots'Last
      then
         Set_Render_Status (R, Status, Invalid_Snapshot);
         return;
      end if;

      for I in Snapshots'Range loop
         if Snapshots (I).Rows = 0 or else Snapshots (I).Cols = 0 then
            Set_Render_Status (R, Status, Invalid_Snapshot);
            return;
         end if;
         Cell_Count := Cell_Count + Snapshots (I).Rows * Snapshots (I).Cols;
         Image_Max := Image_Max + Snapshots (I).Rows * Snapshots (I).Cols;
         Text_Run_Max := Text_Run_Max + Snapshots (I).Rows * Snapshots (I).Cols;
         Colour_Max := Colour_Max + Snapshots (I).Rows * Snapshots (I).Cols;

         if Splits.Orientation = Terminal.App.Splits.Vertical
           and then Snapshots'Length > 1
         then
            Frame_W := Frame_W + Pane_Width (Snapshots (I));
            Frame_H := Natural'Max (Frame_H, Tab_Height + Pane_Height (Snapshots (I)));
         else
            Frame_W := Natural'Max (Frame_W, Pane_Width (Snapshots (I)));
            Frame_H := Frame_H + Pane_Height (Snapshots (I));
         end if;
      end loop;

      Frame_W := Natural'Max (Frame_W, R.Target_Frame_Width);
      Frame_H := Natural'Max (Frame_H, R.Target_Frame_Height);

      Reset_Frame (R);
      R.Graphics_Event_Tracking_Failed := False;
      R.Missing_Glyph_Count := 0;
      R.Shaped_Glyph_Count := 0;
      R.Shaping_Fallback_Count := 0;
      R.Text_Fallback_Run_Count := 0;
      R.Color_Glyph_Count := 0;
      R.Color_Emoji_Fallback_Count := 0;
      R.Paragraph_Bidi_Fallback_Count := 0;
      R.Last_Cell_Count := Cell_Count;
      R.Last_Frame_Width := Frame_W;
      R.Last_Frame_Height := Frame_H;

      Rect_Max := Cell_Count * 4 + Snapshots'Length * 8 + Tabs.Count + 8;
      Glyph_Max :=
        Cell_Count
        * Natural'Max
            (Terminal.Core.Max_Cluster_Attachments + 1,
             RM.Max_Shaped_Glyphs_Per_Run)
        * 2
        + Max_Link_Overlay_Chars
        + Terminal.App.Tabs.Max_Tab_Label_Length * Natural (Tabs.Count);
      Ensure_Frame_Capacity
        (R,
         Rectangle_Count => Positive (Natural'Max (1, Rect_Max)),
         Glyph_Count => Positive (Natural'Max (1, Glyph_Max)),
         Colour_Count => Positive (Natural'Max (1, Colour_Max)),
         Image_Count => Positive (Image_Max),
         Text_Run_Count => Positive (Natural'Max (1, Text_Run_Max)),
         Success => Capacity_Ok);
      if not Capacity_Ok then
         Release_Frame (R);
         Set_Render_Status (R, Status, Allocation_Failed);
         return;
      end if;

      Advance_Animations (R);

      Add_Rectangle
        (R,
         X      => 0.0,
         Y      => 0.0,
         Width  => Float (R.Last_Frame_Width),
         Height => Float (R.Last_Frame_Height),
         Color  => R.Color_Theme.Default_BG,
         Layer  => RM.Rectangle_Base_Background);

      Draw_Tab_Bar;
      if Status /= Ok then
         Set_Render_Status (R, Status, Status);
         return;
      end if;

      for I in Snapshots'Range loop
         declare
            W : constant Natural := Pane_Width (Snapshots (I));
            H : constant Natural := Pane_Height (Snapshots (I));
         begin
            Draw_Pane_Border
              (Pane_X,
               Pane_Y,
               W,
               H,
               Active_Index = I);
            R.Draw_Offset_X := Pane_X;
            R.Draw_Offset_Y := Pane_Y;
            Draw_Snapshot_Into
              (R,
               Snapshots (I),
               Show_Overlay => Active_Index = I,
               Status       => Draw_Status);
            if Draw_Status /= Ok then
               R.Draw_Offset_X := 0;
               R.Draw_Offset_Y := 0;
               Set_Render_Status (R, Status, Draw_Status);
               return;
            end if;

            if Splits.Orientation = Terminal.App.Splits.Vertical
              and then Snapshots'Length > 1
            then
               Pane_X := Pane_X + W;
            else
               Pane_Y := Pane_Y + H;
            end if;
         end;
      end loop;

      R.Draw_Offset_X := 0;
      R.Draw_Offset_Y := 0;

      R.Atlas_Dirty := R.Atlas_Dirty or else Textrender.Atlas_Dirty (R.Text);
      R.Colour_Sheet_Dirty :=
        R.Colour_Sheet_Dirty or else Textrender.Colour_Sheet_Dirty (R.Text);

      declare
         Batch_Status : VS.Build_Status;
      begin
         VS.Build (Last_Frame (R), R.Batch, Batch_Status);
         if Batch_Status /= VS.Ok then
            Set_Render_Status (R, Status, Batch_Build_Failed);
            return;
         end if;
         R.Vertex_Count := VS.Vertex_Count (R.Batch);
      end;

      Set_Render_Status (R, Status, Ok);
   end Render_App;

   procedure Set_Framebuffer_Size
     (R      : in out Renderer;
      Width  : Natural;
      Height : Natural) is
   begin
      R.Target_Frame_Width := Width;
      R.Target_Frame_Height := Height;
   end Set_Framebuffer_Size;

   procedure Set_Theme
     (R : in out Renderer;
      T : Terminal.App.Theme.Theme;
      Status : out Theme_Update_Status) is separate;

   procedure Set_Hovered_Link
     (R    : in out Renderer;
      Link : Terminal.Core.Hyperlink) is
   begin
      R.Hovered_Link := Link;
   end Set_Hovered_Link;

   procedure Clear_Graphics_Event_Tracking (R : in out Renderer) is
      Staged : Staged_Graphics_Event_Access := R.Staged_Graphics_Events;
      Staged_Next : Staged_Graphics_Event_Access;
   begin
      R.Processed_Graphics_Events := (others => (others => <>));
      R.Processed_Graphics_Event_Count := 0;
      R.Graphics_Event_Tracking_Failed := False;
      while Staged /= null loop
         Staged_Next := Staged.Next;
         if Staged.Payload /= null then
            Free_String (Staged.Payload);
         end if;
         Free_Staged_Graphics_Event (Staged);
         Staged := Staged_Next;
      end loop;
      R.Staged_Graphics_Events := null;
   end Clear_Graphics_Event_Tracking;

   procedure Commit_Graphics_Events (R : in out Renderer) is
   begin
      --  Atlas changes remain dirty until the frame carrying them is accepted
      --  by the presentation backend.  A fence deferral or swapchain retry can
      --  therefore rebuild the batch without losing the required upload.
      if R.Atlas_Dirty then
         Textrender.Clear_Atlas_Dirty (R.Text);
         R.Atlas_Dirty := False;
      end if;
      if R.Colour_Sheet_Dirty then
         Textrender.Clear_Colour_Sheet_Dirty (R.Text);
         R.Colour_Sheet_Dirty := False;
      end if;
      Clear_Graphics_Event_Tracking (R);
   end Commit_Graphics_Events;

   procedure Commit_Offscreen_Graphics_Events (R : in out Renderer) is
   begin
      Clear_Graphics_Event_Tracking (R);
   end Commit_Offscreen_Graphics_Events;

   procedure Release_Graphics_Stream
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID)
   is
      Object_Current : Image_Object_Access :=
        Terminal.App.Image_Store.First (R.Image_Objects);
      Object_Next : Image_Object_Access;
      Palette_Previous : Sixel_Palette_Entry_Access := null;
      Palette_Current : Sixel_Palette_Entry_Access := R.Sixel_Palettes;
      Staged_Previous : Staged_Graphics_Event_Access := null;
      Staged_Current : Staged_Graphics_Event_Access :=
        R.Staged_Graphics_Events;
   begin
      --  Image commands borrow decoded storage from retained image objects.
      --  Invalidate the current frame before releasing any object owned by
      --  this stream so diagnostics and callers cannot dereference stale
      --  preview pointers between stream teardown and the next render.
      Reset_Frame (R);

      Delete_Virtual_Placements (R, Stream_ID, 0);
      Delete_Conventional_Placements
        (R, Stream_ID, 0, Match_Protocol => False);

      while Object_Current /= null loop
         Object_Next :=
           Terminal.App.Image_Store.Next_Object
             (Object_Current);
         if Object_Current.Stream_ID = Stream_ID then
            Delete_Image_Object_By_Storage_Order
              (R, Stream_ID, Object_Current.Storage_Order);
         end if;
         Object_Current := Object_Next;
      end loop;

      declare
         Kept : Natural := 0;
      begin
         for I in 1 .. R.Processed_Graphics_Event_Count loop
            if R.Processed_Graphics_Events (I).Stream_ID /= Stream_ID then
               Kept := Kept + 1;
               if Kept /= I then
                  R.Processed_Graphics_Events (Kept) :=
                    R.Processed_Graphics_Events (I);
               end if;
            end if;
         end loop;
         for I in Kept + 1 .. R.Processed_Graphics_Event_Count loop
            R.Processed_Graphics_Events (I) := (others => <>);
         end loop;
         R.Processed_Graphics_Event_Count := Kept;
      end;

      while Palette_Current /= null loop
         declare
            Palette_Next : constant Sixel_Palette_Entry_Access :=
              Palette_Current.Next;
         begin
            if Palette_Current.Stream_ID = Stream_ID then
               if Palette_Previous = null then
                  R.Sixel_Palettes := Palette_Next;
               else
                  Palette_Previous.Next := Palette_Next;
               end if;
               Free_Sixel_Palette_Entry (Palette_Current);
            else
               Palette_Previous := Palette_Current;
            end if;
            Palette_Current := Palette_Next;
         end;
      end loop;

      while Staged_Current /= null loop
         declare
            Staged_Next : constant Staged_Graphics_Event_Access :=
              Staged_Current.Next;
         begin
            if Staged_Current.Stream_ID = Stream_ID then
               if Staged_Previous = null then
                  R.Staged_Graphics_Events := Staged_Next;
               else
                  Staged_Previous.Next := Staged_Next;
               end if;
               if Staged_Current.Payload /= null then
                  Free_String (Staged_Current.Payload);
               end if;
               Free_Staged_Graphics_Event (Staged_Current);
            else
               Staged_Previous := Staged_Current;
            end if;
            Staged_Current := Staged_Next;
         end;
      end loop;
   end Release_Graphics_Stream;

   overriding procedure Finalize (R : in out Renderer) is
      Palette : Sixel_Palette_Entry_Access := R.Sixel_Palettes;
      Next : Sixel_Palette_Entry_Access;
      Cleanup_Failed : Boolean := False;

      procedure Release_Frame_Safely is
      begin
         Release_Frame (R);
      exception
         when others =>
            Cleanup_Failed := True;
      end Release_Frame_Safely;

      procedure Release_Images_Safely is
      begin
         Release_Image_Objects (R);
      exception
         when others =>
            Cleanup_Failed := True;
      end Release_Images_Safely;

      procedure Release_Events_Safely is
      begin
         Commit_Graphics_Events (R);
      exception
         when others =>
            Cleanup_Failed := True;
      end Release_Events_Safely;

      procedure Release_Text_Safely is
      begin
         Textrender.Reset (R.Text);
      exception
         when others =>
            Cleanup_Failed := True;
      end Release_Text_Safely;
   begin
      if not R.Needs_Finalization then
         R.Closed := True;
         return;
      end if;
      --  Close the public state immediately, but keep the finalization guard
      --  armed until every independent cleanup step has completed.  An
      --  explicit Finalize followed by automatic finalization can therefore
      --  retry a partially failed cleanup without permitting new allocations.
      R.Closed := True;
      R.Initialized := False;
      Release_Frame_Safely;
      Release_Images_Safely;
      Release_Events_Safely;
      while Palette /= null loop
         Next := Palette.Next;
         Free_Sixel_Palette_Entry (Palette);
         Palette := Next;
      end loop;
      R.Sixel_Palettes := null;
      Release_Text_Safely;
      if not Cleanup_Failed then
         R.Needs_Finalization := False;
      end if;
      R.Has_Context := False;
      R.Text_Loaded := False;
      R.Glyph_Count := 0;
      R.Colour_Glyph_Count := 0;
      R.Text_Run_Count := 0;
      R.Shaped_Glyph_Count := 0;
      R.Shaping_Fallback_Count := 0;
      R.Text_Fallback_Run_Count := 0;
      R.Color_Glyph_Count := 0;
      R.Color_Emoji_Fallback_Count := 0;
      R.Paragraph_Bidi_Fallback_Count := 0;
      R.Vertex_Count := 0;
      R.Missing_Glyph_Count := 0;
      R.Target_Frame_Width := 0;
      R.Target_Frame_Height := 0;
      R.Hovered_Link := (others => <>);
      R.Atlas_Dirty := False;
      R.Colour_Sheet_Dirty := False;
      R.Last_Render_Status := Not_Initialized;
   exception
      when others =>
         --  Finalization must never mask the exception that caused scope
         --  unwinding.  Keep Needs_Finalization armed for a possible explicit
         --  retry, but permanently close the public object.
         R.Closed := True;
         R.Initialized := False;
   end Finalize;

   procedure Present
     (R         : Renderer;
      Context   : Terminal.App.Vulkan_Context.Context;
      Presenter : in out Terminal.App.Vulkan_Presenter.Presenter;
      Status    : out Terminal.App.Vulkan_Presenter.Present_Status) is
   begin
      Terminal.App.Vulkan_Presenter.Present
        (P       => Presenter,
         Context => Context,
         Batch   => R.Batch,
         Status  => Status);
   end Present;

   procedure Present_Retained
     (R         : Renderer;
      Context   : Terminal.App.Vulkan_Context.Context;
      Presenter : in out Terminal.App.Vulkan_Presenter.Presenter;
      Status    : out Terminal.App.Vulkan_Presenter.Present_Status) is
      pragma Unreferenced (R);
   begin
      Terminal.App.Vulkan_Presenter.Present_Retained
        (P       => Presenter,
         Context => Context,
         Status  => Status);
   end Present_Retained;

   function Cell_Width (R : Renderer) return Positive is
   begin
      return R.CW;
   end Cell_Width;

   function Cell_Height (R : Renderer) return Positive is
   begin
      return R.CH;
   end Cell_Height;

   function Image_Preview
     (Image : RM.Image_Command) return Terminal.Common.Bytes.Byte_Array
   is
      Result : Terminal.Common.Bytes.Byte_Array
        (1 .. RM.Max_Image_Decoded_Preview_Length) := (others => 0);
   begin
      for I in 1 .. Natural'Min
        (Image.Decoded_Preview_Length, RM.Max_Image_Decoded_Preview_Length)
      loop
         Result (I) := RM.Image_Decoded_Preview_Byte (Image, I);
      end loop;
      return Result;
   end Image_Preview;

   function Diagnostics (R : Renderer) return Renderer_Diagnostics is
      Image_Count : constant Natural := Frame_Image_Count (R);
      Has_Image : constant Boolean := Image_Count > 0;
      Last_Image : constant RM.Image_Command :=
        (if Has_Image
         then FIS.Element (R.Frame_Images, Positive (Image_Count))
         else (others => <>));
   begin
      return
        (Initialized          => R.Initialized,
         Text_Loaded          => R.Text_Loaded,
         Last_Cell_Count      => R.Last_Cell_Count,
         Last_Dirty_Rows      => R.Last_Dirty_Rows,
         Last_Rectangle_Count => R.Rectangle_Count,
         Last_Glyph_Count     => R.Glyph_Count,
         Last_Image_Count     => Image_Count,
         Rectangle_Command_Capacity =>
           (if R.Rectangles = null then 0 else R.Rectangles'Length),
         Image_Command_Capacity =>
           Frame_Image_Capacity (R),
         Last_Image_Protocol  =>
           (if Has_Image then Last_Image.Protocol
            else Terminal.App.Render_Model.Image_Sixel),
         Last_Image_Width =>
           (if Has_Image then Natural (Last_Image.Width) else 0),
         Last_Image_Height =>
           (if Has_Image then Natural (Last_Image.Height) else 0),
         Last_Image_Raw_Format =>
           (if Has_Image then Last_Image.Raw_Format else 0),
         Last_Image_Pixel_Width =>
           (if Has_Image then Last_Image.Pixel_Width else 0),
         Last_Image_Pixel_Height =>
           (if Has_Image then Last_Image.Pixel_Height else 0),
         Last_Image_Payload_Length =>
           (if Has_Image then Last_Image.Payload_Length else 0),
         Last_Image_Staging_Byte_Length =>
           (if Has_Image then Last_Image.Staging_Byte_Length
            else 0),
         Last_Image_Payload_Preview_Complete =>
           Has_Image
           and then Last_Image.Payload_Preview_Complete,
         Last_Image_Encoded_Preview_Length =>
           (if Has_Image then Last_Image.Encoded_Preview_Length
            else 0),
         Last_Image_Decoded_Preview_Length =>
           (if Has_Image then Last_Image.Decoded_Preview_Length
            else 0),
         Last_Image_Decoded_Preview_Bytes =>
           (if Has_Image then Image_Preview (Last_Image)
            else (others => 0)),
         Last_Image_Preview_Decode_Complete =>
           Has_Image and then Last_Image.Preview_Decode_Complete,
         Last_Image_Decode_Status =>
           (if Has_Image then Last_Image.Decode_Status
            else RM.Image_Decode_Not_Attempted),
         Last_Media_Decode_Attempted => R.Last_Media.Attempted,
         Last_Media_Decode_Status => R.Last_Media.Status,
         Last_Media_Diagnostic => R.Last_Media.Error,
         Last_Media_Adapter_Buffer_Bytes =>
           R.Last_Media.Adapter_Buffer_Bytes,
         Last_Media_Decoder_Configured_Bytes =>
           R.Last_Media.Decoder_Configured_Bytes,
         Last_Media_Warning_Count => R.Last_Media.Warning_Count,
         Last_Media_First_Warning => R.Last_Media.First_Warning,
         Last_Image_Placeholder =>
           Has_Image and then Last_Image.Placeholder,
         Image_Object_Count => Stored_Image_Count (R),
         Image_Object_Bytes => Stored_Image_Bytes (R),
         Placement_Count => R.Kitty_Placement_Count,
         Kitty_Image_Object_Count => Stored_Image_Count (R),
         Kitty_Image_Object_Bytes => Stored_Image_Bytes (R),
         Kitty_Placement_Count => R.Kitty_Placement_Count,
         Kitty_Animation_Frame_Count => Stored_Animation_Frame_Count (R),
         Graphics_Event_Count => R.Graphics_Event_Count,
         Kitty_Command_Count => R.Kitty_Command_Count,
         Kitty_Success_Count => R.Kitty_Success_Count,
         Kitty_Error_Count => R.Kitty_Error_Count,
         Image_Install_Count => R.Image_Install_Count,
         Image_Installed_Bytes => R.Image_Installed_Bytes,
         Image_Eviction_Count => R.Image_Eviction_Count,
         Placement_Create_Count => R.Placement_Create_Count,
         Placement_Delete_Count => R.Placement_Delete_Count,
         Transport_Failure_Count => R.Transport_Failure_Count,
         Decode_Failure_Count => R.Decode_Failure_Count,
         Allocation_Failure_Count => R.Allocation_Failure_Count,
         Animation_Advance_Count => R.Animation_Advance_Count,
         Chunk_Cancel_Count => R.Chunk_Cancel_Count,
         Last_Text_Run_Count  => R.Text_Run_Count,
         Last_Shaped_Glyph_Count => R.Shaped_Glyph_Count,
         Last_Shaping_Fallback_Count => R.Shaping_Fallback_Count,
         Last_Text_Fallback_Run_Count => R.Text_Fallback_Run_Count,
         Last_Color_Glyph_Count => R.Color_Glyph_Count,
         Last_Color_Emoji_Fallback_Count => R.Color_Emoji_Fallback_Count,
         Last_Paragraph_Bidi_Fallback_Count =>
           R.Paragraph_Bidi_Fallback_Count,
         Last_Vertex_Count    => R.Vertex_Count,
         Missing_Glyph_Count  => R.Missing_Glyph_Count,
         Atlas_Dirty          => R.Atlas_Dirty,
         Last_Render_Status   => R.Last_Render_Status);
   end Diagnostics;

   function Color_Emoji_Status_Label
     (Diagnostics : Renderer_Diagnostics) return String is
   begin
      if Diagnostics.Last_Color_Glyph_Count > 0
        and then Diagnostics.Last_Color_Emoji_Fallback_Count = 0
      then
         return "Color emoji glyphs rendered";
      elsif Diagnostics.Last_Color_Glyph_Count > 0 then
         return "Color emoji glyphs rendered with fallback";
      elsif Diagnostics.Last_Color_Emoji_Fallback_Count = 0 then
         return "";
      else
         return "Color emoji rendered with monochrome fallback";
      end if;
   end Color_Emoji_Status_Label;

   function Paragraph_Bidi_Status_Label
     (Diagnostics : Renderer_Diagnostics) return String is
   begin
      if Diagnostics.Last_Paragraph_Bidi_Fallback_Count = 0 then
         return "";
      else
         return "Paragraph BiDi reordering not applied";
      end if;
   end Paragraph_Bidi_Status_Label;

   function Image_Status_Label
     (Diagnostics : Renderer_Diagnostics) return String
   is
      function Protocol_Name return String is
      begin
         case Diagnostics.Last_Image_Protocol is
            when Terminal.App.Render_Model.Image_Sixel =>
               return "sixel";
            when Terminal.App.Render_Model.Image_Kitty =>
               return "kitty";
            when Terminal.App.Render_Model.Image_ITerm2 =>
               return "iTerm2";
         end case;
      end Protocol_Name;
   begin
      if Diagnostics.Last_Image_Count = 0 then
         return "";
      end if;

      return Bounded_Status_Label
        ("image " & Protocol_Name
        & " size=" & Trimmed_Natural (Diagnostics.Last_Image_Width)
        & "x" & Trimmed_Natural (Diagnostics.Last_Image_Height)
        & (if Diagnostics.Last_Image_Pixel_Width > 0
           and then Diagnostics.Last_Image_Pixel_Height > 0
           then
             " pixels=" & Trimmed_Natural (Diagnostics.Last_Image_Pixel_Width)
             & "x" & Trimmed_Natural (Diagnostics.Last_Image_Pixel_Height)
             & " format=" & Trimmed_Natural (Diagnostics.Last_Image_Raw_Format)
           else "")
        & " payload=" & Trimmed_Natural (Diagnostics.Last_Image_Payload_Length)
        & RM.Image_Payload_Status_Suffix
            (Diagnostics.Last_Image_Payload_Preview_Complete)
        & " preview="
        & Trimmed_Natural (Diagnostics.Last_Image_Decoded_Preview_Length)
        & "/"
        & Trimmed_Natural (Diagnostics.Last_Image_Encoded_Preview_Length)
        & Terminal.Common.Status.Preview_Bytes_Label
            (Diagnostics.Last_Image_Decoded_Preview_Bytes,
             Diagnostics.Last_Image_Decoded_Preview_Length)
        & (if Diagnostics.Last_Image_Placeholder
           then " placeholder"
           else " textured")
        & (if Diagnostics.Last_Image_Preview_Decode_Complete
           then " decoded"
           else " partial")
         & RM.Image_Decode_Status_Suffix
             (Diagnostics.Last_Image_Decode_Status));
   end Image_Status_Label;

   function Media_Status_Label
     (Diagnostics : Renderer_Diagnostics) return String
   is
      Media : constant Terminal.App.Image_Rendering.Media_Diagnostics :=
        (Attempted => Diagnostics.Last_Media_Decode_Attempted,
         Status => Diagnostics.Last_Media_Decode_Status,
         Error => Diagnostics.Last_Media_Diagnostic,
         Adapter_Buffer_Bytes =>
           Diagnostics.Last_Media_Adapter_Buffer_Bytes,
         Decoder_Configured_Bytes =>
           Diagnostics.Last_Media_Decoder_Configured_Bytes,
         Warning_Count => Diagnostics.Last_Media_Warning_Count,
         First_Warning => Diagnostics.Last_Media_First_Warning);
   begin
      return Terminal.App.Image_Rendering.Status_Label (Media);
   end Media_Status_Label;

   function Last_Frame (R : Renderer) return RM.Frame_Commands is separate;
end Terminal.App.Renderer;

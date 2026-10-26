with Ada.Unchecked_Deallocation;
with Ada.Real_Time;
with Ada.Finalization;
with Interfaces;
with System;

with Terminal.Common;
with Terminal.Common.Bytes;
with Terminal.Common.Status;
with Terminal.App.Fonts;
with Terminal.App.Cleanup_Diagnostics;
with Terminal.App.Graphics;
with Terminal.App.Graphics_Transport;
with Terminal.App.Frame_Image_Storage;
with Terminal.App.Image_Animation;
with Terminal.App.Image_Colors;
with Terminal.App.Image_Ingestion;
with Terminal.App.Image_Media;
with Terminal.App.Image_Store;
with Terminal.App.Image_Store.Themes;
with Terminal.App.Image_Placements;
with Terminal.App.Image_Rendering;
with Terminal.App.ITerm2_Files;
with Terminal.App.Hyperlinks;
with Terminal.App.Placeholder_Index;
with Terminal.App.Render_Model;
with Terminal.App.Size_Arithmetic;
with Terminal.App.Text_Shaper;
with Terminal.App.Theme;
with Terminal.App.Vulkan_Submit;

package body Terminal.App.Renderer is
   package RM renames Terminal.App.Render_Model;
   package VS renames Terminal.App.Vulkan_Submit;
   package FIS renames Terminal.App.Frame_Image_Storage;
   package Themes renames Terminal.App.Image_Store.Themes;
   use Terminal.App.Image_Store.Themes;

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

   procedure Release_Unappended_Image_Buffers
     (Decoded : in out RM.Image_Data_Access;
      Encoded : in out RM.Image_Data_Access;
      Preview : in out RM.Image_Data_Access)
   is
      Decoded_Owner : RM.Image_Data_Access := Decoded;
      Encoded_Owner : RM.Image_Data_Access := Encoded;
      Preview_Owner : RM.Image_Data_Access := Preview;
      Encoded_Aliases_Decoded : constant Boolean :=
        Encoded_Owner = Decoded_Owner;
      Preview_Aliases_Decoded : constant Boolean :=
        Preview_Owner = Decoded_Owner;
      Preview_Aliases_Encoded : constant Boolean :=
        Preview_Owner = Encoded_Owner;
   begin
      Decoded := null;
      Encoded := null;
      Preview := null;
      if Decoded_Owner /= null then
         Free_Image_Data (Decoded_Owner);
      end if;
      if Encoded_Owner /= null and then not Encoded_Aliases_Decoded then
         Free_Image_Data (Encoded_Owner);
      end if;
      if Preview_Owner /= null
        and then not Preview_Aliases_Decoded
        and then not Preview_Aliases_Encoded
      then
         Free_Image_Data (Preview_Owner);
      end if;
   end Release_Unappended_Image_Buffers;

   procedure Append_Image_Command
     (R       : in out Renderer;
      Command : RM.Image_Command) is
   begin
      if FIS.Is_Full (R.Frame_Images) then
         R.Frame_Command_Overflowed := True;
      else
         FIS.Append (R.Frame_Images, Command);
      end if;
   end Append_Image_Command;

   procedure Append_Image_Command
     (R       : in out Renderer;
      Command : RM.Image_Command;
      Decoded : in out RM.Image_Data_Access;
      Encoded : in out RM.Image_Data_Access;
      Preview : in out RM.Image_Data_Access) is
   begin
      if FIS.Is_Full (R.Frame_Images) then
         R.Frame_Command_Overflowed := True;
         Release_Unappended_Image_Buffers (Decoded, Encoded, Preview);
      else
         FIS.Append (R.Frame_Images, Command, Decoded, Encoded, Preview);
      end if;
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
      Maximum : constant Positive := Max_Graphics_Pixel_Dimension - 1;
   begin
      if not (Value >= -Float'Last and then Value <= Float'Last)
        or else Value <= 1.0
      then
         return 1;
      elsif Value >= Float (Maximum) then
         return Maximum;
      else
         return Positive (Float'Ceiling (Value));
      end if;
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
   is separate;

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
   is separate;

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
   is separate;

   function Resolve_Virtual_Placement_Origin
     (R            : Renderer;
      Snapshot     : Terminal.Core.Render_Snapshot;
      Image_ID     : Terminal.Core.Graphics_ID;
      Placement_ID : Terminal.Core.Graphics_ID;
      Row           : out Integer;
      Col           : out Integer;
      Use_Index     : Boolean := False) return Boolean
   is separate;

   function Resolve_Conventional_Placement_Origin
     (R         : Renderer;
      Snapshot  : Terminal.Core.Render_Snapshot;
      Placement : Conventional_Placement_Access;
      Row       : out Integer;
      Col       : out Integer;
      Use_Index : Boolean := False) return Boolean
   is separate;

   function Store_Conventional_Placement
     (R      : in out Renderer;
      Event  : Terminal.Core.Graphics_Event;
      Header : Terminal.App.Graphics.Graphics_Header;
      Prepared : in out Conventional_Placement_Access)
      return Placement_Store_Status
   is separate;

   function Store_Auxiliary_Placement
     (R           : in out Renderer;
      Event       : Terminal.Core.Graphics_Event;
      Protocol    : RM.Image_Protocol;
      Draw_Width  : Positive;
      Draw_Height : Positive) return Boolean
   is separate;

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
   is separate;

   procedure Synchronize_Graphics_Scroll
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot;
      Through  : Terminal.Core.Graphics_Scroll_Sequence)
   is separate;

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
   is separate;

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
   is separate;

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

   function Additional_Frame_Image_Commands
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event) return Natural
   is
      Header : Terminal.App.Graphics.Graphics_Header;
      Image_ID : Terminal.Core.Graphics_ID;
      Numbered_Object : Image_Object_Access;
   begin
      if not Event.Pending or else Event.Protocol = Terminal.Core.No_Graphics then
         return 0;
      elsif Event.Protocol /= Terminal.Core.Kitty_Graphics then
         --  A malformed auxiliary image may remain a one-frame diagnostic
         --  placeholder instead of becoming a retained placement.
         return 1;
      end if;

      Header := Terminal.App.Graphics.Header (Event);
      if not Header.Recognized or else Header.Kitty_Action not in 'p' | 'T' then
         return 0;
      end if;
      Image_ID := Header.Kitty_ID;
      if Image_ID = 0 and then Header.Kitty_Image_Number > 0 then
         Numbered_Object := Find_Image_Object_By_Number
           (R, Event.Stream_ID, Header.Kitty_Image_Number);
         if Numbered_Object /= null then
            Image_ID := Numbered_Object.ID;
         end if;
      end if;
      if Header.Kitty_Placement_ID = 0
        or else Image_ID = 0
        or else
          (if Header.Kitty_Virtual_Placement
           then Find_Addressed_Virtual_Placement
             (R, Event.Stream_ID, Image_ID, Header.Kitty_Placement_ID) = null
           else Find_Addressed_Conventional_Placement
             (R, Event.Stream_ID, Image_ID, Header.Kitty_Placement_ID) = null)
      then
         return 1;
      end if;
      return 0;
   end Additional_Frame_Image_Commands;

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
   is separate;

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
   is separate;

   procedure Delete_Selected_Unplaced_Image_Objects
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Orders    : Image_Storage_Order_List;
      Count     : Natural)
   is separate;

   procedure Delete_Visible_Conventional_Placements
     (R           : in out Renderer;
      Snapshot    : Terminal.Core.Render_Snapshot;
      Delete_Data : Boolean)
   is separate;

   procedure Delete_Image_ID_Range
     (R           : in out Renderer;
      Stream_ID   : Terminal.Core.Graphics_Stream_ID;
      First_ID    : Terminal.Core.Graphics_ID;
      Last_ID     : Terminal.Core.Graphics_ID;
      Delete_Data : Boolean)
   is separate;

   function Evict_One_Unplaced_Image
     (R                 : in out Renderer;
      Preserve_Stream   : Terminal.Core.Graphics_Stream_ID;
      Preserve_Image_ID : Terminal.Core.Graphics_ID) return Boolean
   is separate;

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
   is separate;

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
      Themes.Release_Unowned (Head);
   end Release_Theme_Operation_List;

   procedure Clear_Theme_Operations
     (R      : in out Renderer;
      Object : Image_Object_Access) is
   begin
      if Object = null then
         return;
      end if;
      Themes.Clear
        (R.Image_Objects, Object);
   end Clear_Theme_Operations;

   procedure Archive_Root_Theme_Operations
     (R      : in out Renderer;
      Object : Image_Object_Access)
   is
   begin
      if Object = null
        or else Themes.First (Object) = null
      then
         return;
      end if;
      Themes.Archive_Root
        (R.Image_Objects, Object, Max_Theme_Operations);
   end Archive_Root_Theme_Operations;

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
            (Themes.Count (Object),
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
      Control : Terminal.App.Image_Animation.Animation_Control;
      Result  : Terminal.App.Image_Animation.Control_Result;
   begin
      if Header.Kitty_Animation_State > 3 then
         R.Last_Animation_Result := Terminal.Core.Kitty_EINVAL;
         return;
      end if;
      Control :=
        (Frame_Number => Header.Kitty_Frame_Number,
         Frame_Gap    => Header.Kitty_Frame_Gap,
         Start_Frame  => Header.Kitty_Base_Frame,
         Loop_Count   => Header.Kitty_Loop_Count,
         State        =>
           (case Header.Kitty_Animation_State is
               when 1 => Terminal.App.Image_Animation.Stopped,
               when 2 => Terminal.App.Image_Animation.Loading,
               when 3 => Terminal.App.Image_Animation.Running,
               when others => Terminal.App.Image_Animation.Unchanged));
      Result := Terminal.App.Image_Animation.Apply_Control (Object, Control);
      R.Last_Animation_Result :=
        (case Result is
            when Terminal.App.Image_Animation.Control_Ok =>
              Terminal.Core.Kitty_OK,
            when Terminal.App.Image_Animation.Control_Invalid =>
              Terminal.Core.Kitty_EINVAL,
            when Terminal.App.Image_Animation.Control_Not_Found =>
              Terminal.Core.Kitty_ENOENT);
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

   function Animation_Frame_Due (R : Renderer) return Boolean is
      Now : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Object : Image_Object_Access :=
        Terminal.App.Image_Store.First (R.Image_Objects);
   begin
      while Object /= null loop
         declare
            Playback : constant Animation_Playback_State :=
              Terminal.App.Image_Store.Playback (Object.all);
            Frame_Count : constant Positive :=
              Terminal.App.Image_Store.Frame_Count_Of (Object);
            Deadline_Set : constant Boolean :=
              Terminal.App.Image_Store.Deadline_Set (Object.all);
         begin
            if Playback /= Animation_Stopped
              and then Frame_Count > 1
              and then Has_Image_Placement (R, Object)
              and then
                (if Deadline_Set
                 then Now >= Terminal.App.Image_Store.Next_Frame_At (Object.all)
                 else Playback = Animation_Running
                   or else
                     Terminal.App.Image_Store.Current_Frame (Object.all) <
                       Frame_Count)
            then
               return True;
            end if;
         end;
         Object := Terminal.App.Image_Store.Next_Object (Object);
      end loop;
      return False;
   end Animation_Frame_Due;

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
         R.Frame_Command_Overflowed := True;
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
   is separate;

   procedure Prepare_Placement_Index
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot)
   is
   begin
      if R.Placement_Index_Dirty then
         Terminal.App.Placeholder_Index.Build
           (R.Placement_Index,
            R.Virtual_Placements,
            R.Conventional_Placements,
            R.Image_Objects);
         R.Placement_Index_Dirty := False;
      end if;
      Terminal.App.Placeholder_Index.Index_Cells
        (R.Placement_Index, Snapshot);
   exception
      when Storage_Error =>
         R.Placement_Index_Dirty := True;
         R.Graphics_Event_Tracking_Failed := True;
   end Prepare_Placement_Index;

   procedure Add_Conventional_Images
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot)
   is separate;

   procedure Add_Placeholder_Images
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot)
   is separate;

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
         R.Frame_Command_Overflowed := True;
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
   is separate;

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
   is separate;

   procedure Build_Text_Runs
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot)
   is separate;

   procedure Initialize_Text
     (R      : in out Renderer;
      Status  : out Init_Status)
   is separate;

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
   is separate;

   function Draw_Emoji_Run_Color
     (R   : in out Renderer;
      Run : RM.Text_Run_Command)
      return Boolean
   is separate;

   procedure Add_Link_Overlay
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot;
      Status   : out Render_Status)
   is separate;

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
   is separate;

   procedure Draw_Shaped_Run
     (R      : in out Renderer;
      Run    : RM.Text_Run_Command;
      Status : out Render_Status)
   is separate;

   function Is_Shaped_Draw_Run (Run : RM.Text_Run_Command) return Boolean is
     (Run.Shape_Status = RM.Shape_Ok
      and then not Run.Fallback_Glyphs
      and then Run.Shaped_Glyph_Count > 0);

   procedure Build_Shaped_Run_Map
     (R         : in out Renderer;
      Snapshot  : Terminal.Core.Render_Snapshot;
      First_Run : Positive)
   is separate;

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
   is separate;

   procedure Render_App
     (R              : in out Renderer;
      Snapshots      : Snapshot_Array;
      Active_Index   : Positive;
      Tabs           : Terminal.App.Tabs.Tab_Snapshot;
      Splits         : Terminal.App.Splits.Split_Snapshot;
      Status         : out Render_Status)
   is separate;

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
   is separate;

   overriding procedure Finalize (R : in out Renderer) is separate;

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

   function Diagnostics (R : Renderer) return Renderer_Diagnostics is separate;

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

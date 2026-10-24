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
with Terminal.App.Image_Media;
with Terminal.App.ITerm2_Files;
with Terminal.App.Hyperlinks;
with Terminal.App.Render_Model;
with Terminal.App.Text_Shaper;
with Terminal.App.Theme;
with Terminal.App.Vulkan_Submit;

package body Terminal.App.Renderer is
   package RM renames Terminal.App.Render_Model;
   package VS renames Terminal.App.Vulkan_Submit;

   use type Terminal.Core.Cell_Kind;
   use type Terminal.App.ITerm2_Files.Save_Status;
   use type Terminal.App.Image_Media.Decode_Status;
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
   use type RM.Image_Data_Access;
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

   procedure Free_Rectangles is new Ada.Unchecked_Deallocation
     (RM.Rectangle_Array, RM.Rectangle_Array_Access);
   procedure Free_Glyphs is new Ada.Unchecked_Deallocation
     (RM.Glyph_Array, RM.Glyph_Array_Access);
   procedure Free_Images is new Ada.Unchecked_Deallocation
     (RM.Image_Array, RM.Image_Array_Access);
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
   procedure Free_Image_Object is new Ada.Unchecked_Deallocation
     (Image_Object, Image_Object_Access);
   procedure Free_Image_Frame is new Ada.Unchecked_Deallocation
     (Image_Frame, Image_Frame_Access);
   procedure Free_Theme_Operation is new Ada.Unchecked_Deallocation
     (Theme_Operation, Theme_Operation_Access);
   procedure Free_Virtual_Placement is new Ada.Unchecked_Deallocation
     (Virtual_Placement, Virtual_Placement_Access);
   procedure Free_Conventional_Placement is new Ada.Unchecked_Deallocation
     (Conventional_Placement, Conventional_Placement_Access);
   procedure Free_Staged_Graphics_Event is new Ada.Unchecked_Deallocation
     (Staged_Graphics_Event, Staged_Graphics_Event_Access);
   procedure Free_Sixel_Palette_Entry is new Ada.Unchecked_Deallocation
     (Sixel_Palette_Entry, Sixel_Palette_Entry_Access);

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
      if not Event.Pending
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
      when others =>
         Width := 0;
         Height := 0;
         Terminal.App.Graphics.Release (Result);
         return False;
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
      when others =>
         Terminal.App.Graphics.Release (Result);
         return False;
   end Decode_Colour_PNG;

   function XTerm_Cube_Component (Value : Natural) return Float is
   begin
      if Value = 0 then
         return 0.0;
      else
         return Float (55 + Value * 40) / 255.0;
      end if;
   end XTerm_Cube_Component;

   function XTerm_Indexed_Color
     (R     : Renderer;
      Index : Natural) return RM.Pixel_Color
   is
   begin
      if Index <= R.Color_Theme.Palette'Last then
         return R.Color_Theme.Palette (Index);
      elsif Index <= 231 then
         declare
            Offset : constant Natural := Index - 16;
         begin
            return
              (R => XTerm_Cube_Component (Offset / 36),
               G => XTerm_Cube_Component ((Offset / 6) mod 6),
               B => XTerm_Cube_Component (Offset mod 6),
               A => 1.0);
         end;
      else
         declare
            Level : constant Float := Float (8 + (Index - 232) * 10) / 255.0;
         begin
            return (Level, Level, Level, 1.0);
         end;
      end if;
   end XTerm_Indexed_Color;

   function Kitty_Indexed_Color
     (R     : Renderer;
      Index : Natural) return RM.Pixel_Color
   is
   begin
      case Index is
         when 0 .. 247 =>
            return XTerm_Indexed_Color (R, Index);
         when 248 =>
            return R.Color_Theme.Default_BG;
         when 249 | 255 =>
            return R.Color_Theme.Default_FG;
         when 250 =>
            return R.Color_Theme.Selection_BG;
         when 251 =>
            return R.Color_Theme.Selection_FG;
         when 252 =>
            return R.Color_Theme.Cursor_BG;
         when 253 =>
            return R.Color_Theme.Cursor_FG;
         when 254 =>
            return R.Color_Theme.URL_Highlight;
         when others =>
            return R.Color_Theme.Default_FG;
      end case;
   end Kitty_Indexed_Color;

   function Color_Byte (Value : Float) return Terminal.Common.Bytes.Byte is
      Scaled : constant Float := Float'Max (0.0, Float'Min (1.0, Value)) * 255.0;
   begin
      return Terminal.Common.Bytes.Byte (Natural (Scaled));
   end Color_Byte;

   function Expand_Kitty_Indexed
     (R            : Renderer;
      Indexed_Format : Natural;
      Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Source       : RM.Image_Data_Access;
      Target       : RM.Image_Data_Access) return Boolean
   is
      Source_BPP : constant Natural :=
        (if Indexed_Format = 8 then 1
         elsif Indexed_Format = 16 then 2
         else 0);
      Pixels : Natural := 0;
   begin
      if Source_BPP = 0
        or else Pixel_Width = 0
        or else Pixel_Height = 0
        or else Pixel_Width > Natural'Last / Pixel_Height
        or else Source = null
        or else Target = null
      then
         return False;
      end if;
      Pixels := Pixel_Width * Pixel_Height;
      if Pixels > Natural'Last / 4
        or else Pixels > Natural'Last / Source_BPP
        or else Source'Length < Pixels * Source_BPP
        or else Target'Length < Pixels * 4
      then
         return False;
      end if;

      for Pixel in 0 .. Pixels - 1 loop
         declare
            Source_At : constant Positive :=
              Source'First + Pixel * Source_BPP;
            Target_At : constant Positive := Target'First + Pixel * 4;
            Color : constant RM.Pixel_Color :=
              Kitty_Indexed_Color (R, Natural (Source (Source_At)));
            Alpha : constant Terminal.Common.Bytes.Byte :=
              (if Indexed_Format = 16
               then Source (Source_At + 1)
               else 255);
         begin
            Target (Target_At) := Color_Byte (Color.R);
            Target (Target_At + 1) := Color_Byte (Color.G);
            Target (Target_At + 2) := Color_Byte (Color.B);
            Target (Target_At + 3) := Alpha;
         end;
      end loop;
      return True;
   end Expand_Kitty_Indexed;

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

   procedure Reset_Frame (R : in out Renderer) is
   begin
      if R.Images /= null then
         for I in 1 .. R.Image_Count loop
            if R.Images (I).Decoded_Preview_Bytes /= null
              and then R.Images (I).Decoded_Preview_Bytes_Owned
            then
               Free_Image_Data (R.Images (I).Decoded_Preview_Bytes);
            end if;
            R.Images (I).Decoded_Preview_Bytes := null;
            R.Images (I).Decoded_Preview_Bytes_Owned := False;
            if R.Images (I).Decoded_Bytes /= null
              and then R.Images (I).Decoded_Bytes_Owned
            then
               Free_Image_Data (R.Images (I).Decoded_Bytes);
            end if;
            R.Images (I).Decoded_Bytes := null;
            R.Images (I).Decoded_Bytes_Owned := False;
            if R.Images (I).Encoded_Source_Bytes /= null
              and then R.Images (I).Encoded_Source_Bytes_Owned
            then
               Free_Image_Data (R.Images (I).Encoded_Source_Bytes);
            end if;
            R.Images (I).Encoded_Source_Bytes := null;
            R.Images (I).Encoded_Source_Bytes_Owned := False;
            R.Images (I).Encoded_Source_Length := 0;
         end loop;
      end if;
      R.Rectangle_Count := 0;
      R.Glyph_Count := 0;
      R.Colour_Glyph_Count := 0;
      R.Image_Count := 0;
      R.Text_Run_Count := 0;
      R.Shaped_Glyph_Count := 0;
      R.Shaping_Fallback_Count := 0;
      R.Text_Fallback_Run_Count := 0;
      R.Color_Glyph_Count := 0;
      R.Color_Emoji_Fallback_Count := 0;
      R.Paragraph_Bidi_Fallback_Count := 0;
      R.Vertex_Count := 0;
      R.Last_Cell_Count := 0;
      R.Last_Dirty_Rows := 0;
      R.Last_Frame_Width := 0;
      R.Last_Frame_Height := 0;
   end Reset_Frame;

   procedure Release_Frame (R : in out Renderer) is
   begin
      Reset_Frame (R);
      R.Graphics_Event_Tracking_Failed := False;
      if R.Rectangles /= null then
         Free_Rectangles (R.Rectangles);
      end if;
      if R.Glyphs /= null then
         Free_Glyphs (R.Glyphs);
      end if;
      if R.Images /= null then
         Free_Images (R.Images);
      end if;
      if R.Text_Runs /= null then
         Free_Text_Runs (R.Text_Runs);
      end if;
      if R.Colour_Glyphs /= null then
         Free_Colour_Glyphs (R.Colour_Glyphs);
      end if;
      if R.Shaped_Run_Map /= null then
         Free_Shaped_Run_Map (R.Shaped_Run_Map);
      end if;
      VS.Release (R.Batch);
   end Release_Frame;

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
      Success         : out Boolean)
   is
   begin
      if R.Rectangles = null
        or else R.Rectangles'Length < Rectangle_Count
      then
         declare
            Replacement : RM.Rectangle_Array_Access :=
              new RM.Rectangle_Array
                (1 .. Grown_Capacity
                  ((if R.Rectangles = null then 0 else R.Rectangles'Length),
                   Rectangle_Count));
         begin
            if R.Rectangles /= null then
               Free_Rectangles (R.Rectangles);
            end if;
            R.Rectangles := Replacement;
         end;
      end if;
      if R.Glyphs = null or else R.Glyphs'Length < Glyph_Count then
         declare
            Replacement : RM.Glyph_Array_Access :=
              new RM.Glyph_Array
                (1 .. Grown_Capacity
                  ((if R.Glyphs = null then 0 else R.Glyphs'Length),
                   Glyph_Count));
         begin
            if R.Glyphs /= null then
               Free_Glyphs (R.Glyphs);
            end if;
            R.Glyphs := Replacement;
         end;
      end if;
      if R.Colour_Glyphs = null
        or else R.Colour_Glyphs'Length < Colour_Count
      then
         declare
            Replacement : RM.Colour_Glyph_Array_Access :=
              new RM.Colour_Glyph_Array
                (1 .. Grown_Capacity
                  ((if R.Colour_Glyphs = null
                    then 0
                    else R.Colour_Glyphs'Length),
                   Colour_Count));
         begin
            if R.Colour_Glyphs /= null then
               Free_Colour_Glyphs (R.Colour_Glyphs);
            end if;
            R.Colour_Glyphs := Replacement;
         end;
      end if;
      if R.Images = null or else R.Images'Length < Image_Count then
         declare
            Replacement : RM.Image_Array_Access :=
              new RM.Image_Array
                (1 .. Grown_Capacity
                  ((if R.Images = null then 0 else R.Images'Length),
                   Image_Count));
         begin
            if R.Images /= null then
               Free_Images (R.Images);
            end if;
            R.Images := Replacement;
         end;
      end if;
      if R.Text_Runs = null or else R.Text_Runs'Length < Text_Run_Count then
         declare
            Replacement : RM.Text_Run_Array_Access :=
              new RM.Text_Run_Array
                (1 .. Grown_Capacity
                  ((if R.Text_Runs = null then 0 else R.Text_Runs'Length),
                   Text_Run_Count));
         begin
            if R.Text_Runs /= null then
               Free_Text_Runs (R.Text_Runs);
            end if;
            R.Text_Runs := Replacement;
         end;
      end if;
      if R.Shaped_Run_Map = null
        or else R.Shaped_Run_Map'Length < Text_Run_Count
      then
         declare
            Replacement : Shaped_Run_Map_Array_Access :=
              new Shaped_Run_Map_Array
                (1 .. Grown_Capacity
                  ((if R.Shaped_Run_Map = null
                    then 0
                    else R.Shaped_Run_Map'Length),
                   Text_Run_Count));
         begin
            if R.Shaped_Run_Map /= null then
               Free_Shaped_Run_Map (R.Shaped_Run_Map);
            end if;
            R.Shaped_Run_Map := Replacement;
         end;
      end if;
      Success := True;
   exception
      when Storage_Error =>
         Success := False;
   end Ensure_Frame_Capacity;


   procedure Clear_Image_Object (Object : in out Image_Object) is
      Frame : Image_Frame_Access := Object.Frames;
      Next  : Image_Frame_Access;
      Operation : Theme_Operation_Access := Object.Theme_Operations;
      Next_Operation : Theme_Operation_Access;
   begin
      while Frame /= null loop
         Next := Frame.Next;
         if Frame.Bytes /= null then
            Free_Image_Data (Frame.Bytes);
         end if;
         Free_Image_Frame (Frame);
         Frame := Next;
      end loop;
      while Operation /= null loop
         Next_Operation := Operation.Next;
         if Operation.Bytes /= null then
            Free_Image_Data (Operation.Bytes);
         end if;
         Free_Theme_Operation (Operation);
         Operation := Next_Operation;
      end loop;
      if Object.Bytes /= null then
         Free_Image_Data (Object.Bytes);
         Object.Bytes := null;
      end if;
      if Object.Indexed_Bytes /= null then
         Free_Image_Data (Object.Indexed_Bytes);
         Object.Indexed_Bytes := null;
      end if;
      Object :=
        (Stream_ID      => 0,
         ID             => 0,
         Number         => 0,
         Protocol       => RM.Image_Kitty,
         Raw_Format     => 0,
         Pixel_Width    => 0,
         Pixel_Height   => 0,
         Decoded_Length => 0,
         Decoded_Row_Stride_Bytes => 0,
         Usage_Hint     => 0,
         Storage_Order  => 0,
         Content_Serial => 0,
         Bytes          => null,
         Indexed_Format => 0,
         Indexed_Length => 0,
         Indexed_Row_Stride_Bytes => 0,
         Indexed_Bytes  => null,
         Frames         => null,
         Frame_Count    => 1,
         Frame_Bytes    => 0,
         Theme_Operations => null,
         Theme_Operations_Tail => null,
         Theme_Operation_Count => 0,
         Theme_Operation_Bytes => 0,
         Root_Gap_MS    => 0,
         Current_Frame  => 1,
         Playback       => Animation_Stopped,
         Loop_Count     => 1,
         Loops_Completed => 0,
         Next_Frame_At  => Ada.Real_Time.Time_First,
         Deadline_Set   => False,
         Next           => null);
   end Clear_Image_Object;

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

   type Placement_Geometry is record
      Valid         : Boolean := False;
      Columns       : Positive := 1;
      Rows          : Positive := 1;
      Draw_Offset_X : Natural := 0;
      Draw_Offset_Y : Natural := 0;
      Draw_Width    : Positive := 1;
      Draw_Height   : Positive := 1;
   end record;

   function Resolve_Placement_Geometry
     (R      : Renderer;
      Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Header : Terminal.App.Graphics.Graphics_Header)
      return Placement_Geometry
   is
      use type Long_Long_Integer;
      Result : Placement_Geometry;
      Source_Width  : Natural;
      Source_Height : Natural;
      Source_W : Long_Long_Integer;
      Source_H : Long_Long_Integer;
      Cell_W   : constant Long_Long_Integer := Long_Long_Integer (R.CW);
      Cell_H   : constant Long_Long_Integer := Long_Long_Integer (R.CH);
      Cols     : Long_Long_Integer := 1;
      Rows     : Long_Long_Integer := 1;
      Box_W    : Long_Long_Integer := 1;
      Box_H    : Long_Long_Integer := 1;
      Draw_W   : Long_Long_Integer := 1;
      Draw_H   : Long_Long_Integer := 1;

      function Ceiling_Divide
        (Dividend : Long_Long_Integer;
         Divisor  : Long_Long_Integer) return Long_Long_Integer is
        ((Dividend + Divisor - 1) / Divisor);

      function Fits_Natural (Value : Long_Long_Integer) return Boolean is
        (Value >= 0
         and then Value <= Long_Long_Integer (Natural'Last));

      function Fits_Positive (Value : Long_Long_Integer) return Boolean is
        (Value >= 1
         and then Value <= Long_Long_Integer (Positive'Last));
   begin
      if Pixel_Width = 0
        or else Pixel_Height = 0
        or else R.CW = 0
        or else R.CH = 0
        or else not Header.Kitty_Columns_Valid
        or else not Header.Kitty_Rows_Valid
        or else not Header.Kitty_Geometry_Controls_Valid
        or else Header.Kitty_Cell_X >= R.CW
        or else Header.Kitty_Cell_Y >= R.CH
        or else Header.Kitty_Source_X >= Pixel_Width
        or else Header.Kitty_Source_Y >= Pixel_Height
      then
         return Result;
      end if;

      Source_Width := Pixel_Width - Header.Kitty_Source_X;
      Source_Height := Pixel_Height - Header.Kitty_Source_Y;
      if Header.Kitty_Source_Width > 0 then
         Source_Width := Natural'Min
           (Source_Width, Header.Kitty_Source_Width);
      end if;
      if Header.Kitty_Source_Height > 0 then
         Source_Height := Natural'Min
           (Source_Height, Header.Kitty_Source_Height);
      end if;
      if Source_Width = 0 or else Source_Height = 0 then
         return Result;
      end if;

      Source_W := Long_Long_Integer (Source_Width);
      Source_H := Long_Long_Integer (Source_Height);
      if Header.Kitty_Columns_Specified then
         Cols := Long_Long_Integer (Header.Placeholder_Cols);
      end if;
      if Header.Kitty_Rows_Specified then
         Rows := Long_Long_Integer (Header.Placeholder_Rows);
      end if;

      if not Header.Kitty_Columns_Specified
        and then not Header.Kitty_Rows_Specified
      then
         Draw_W := Source_W;
         Draw_H := Source_H;
         Cols := Ceiling_Divide (Draw_W, Cell_W);
         Rows := Ceiling_Divide (Draw_H, Cell_H);
         Box_W := Cols * Cell_W;
         Box_H := Rows * Cell_H;
      elsif Header.Kitty_Columns_Specified
        and then not Header.Kitty_Rows_Specified
      then
         Box_W := Cols * Cell_W;
         Draw_W := Box_W;
         Draw_H := Long_Long_Integer'Max
           (1, (Box_W * Source_H) / Source_W);
         Rows := Ceiling_Divide (Draw_H, Cell_H);
         Box_H := Rows * Cell_H;
      elsif not Header.Kitty_Columns_Specified
        and then Header.Kitty_Rows_Specified
      then
         Box_H := Rows * Cell_H;
         Draw_H := Box_H;
         Draw_W := Long_Long_Integer'Max
           (1, (Box_H * Source_W) / Source_H);
         Cols := Ceiling_Divide (Draw_W, Cell_W);
         Box_W := Cols * Cell_W;
      else
         Box_W := Cols * Cell_W;
         Box_H := Rows * Cell_H;
         if Source_W * Box_H >= Source_H * Box_W then
            Draw_W := Box_W;
            Draw_H := Long_Long_Integer'Max
              (1, (Box_W * Source_H) / Source_W);
         else
            Draw_H := Box_H;
            Draw_W := Long_Long_Integer'Max
              (1, (Box_H * Source_W) / Source_H);
         end if;
      end if;

      if not Fits_Positive (Cols)
        or else not Fits_Positive (Rows)
        or else not Fits_Positive (Draw_W)
        or else not Fits_Positive (Draw_H)
        or else not Fits_Natural (Box_W)
        or else not Fits_Natural (Box_H)
      then
         return Result;
      end if;

      Result :=
        (Valid         => True,
         Columns       => Positive (Cols),
         Rows          => Positive (Rows),
         Draw_Offset_X => Natural ((Box_W - Draw_W) / 2),
         Draw_Offset_Y => Natural ((Box_H - Draw_H) / 2),
         Draw_Width    => Positive (Draw_W),
         Draw_Height   => Positive (Draw_H));
      return Result;
   exception
      when Constraint_Error =>
         return (others => <>);
   end Resolve_Placement_Geometry;

   function Resolve_Placement_Geometry
     (R      : Renderer;
      Object : Image_Object_Access;
      Header : Terminal.App.Graphics.Graphics_Header)
      return Placement_Geometry is
     (if Object = null
      then (others => <>)
      else Resolve_Placement_Geometry
        (R, Object.Pixel_Width, Object.Pixel_Height, Header));

   procedure Store_Virtual_Placement
     (R         : in out Renderer;
      Event     : Terminal.Core.Graphics_Event;
      Header    : Terminal.App.Graphics.Graphics_Header)
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
         return;
      end if;

      if Placement = null then
         if R.Kitty_Placement_Count >= R.Graphics_Limits.Placements then
            return;
         end if;
         Placement := new Virtual_Placement;
         Placement.Next := R.Virtual_Placements;
         R.Virtual_Placements := Placement;
         R.Kitty_Placement_Count := R.Kitty_Placement_Count + 1;
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
   exception
      when Storage_Error =>
         null;
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

   procedure Store_Conventional_Placement
     (R      : in out Renderer;
      Event  : Terminal.Core.Graphics_Event;
      Header : Terminal.App.Graphics.Graphics_Header)
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
         return;
      end if;

      --  Anonymous transmissions cannot subsequently be addressed, so a
      --  supplied placement identifier has no protocol meaning.
      if Header.Kitty_ID = 0 and then Header.Kitty_Parent_ID /= 0 then
         return;
      end if;

      if Validate_Relative_Placement
        (R,
         Event.Stream_ID,
         Event.Alternate_Screen,
         Event.Screen_Generation,
         Header.Kitty_ID,
         Header.Kitty_Placement_ID,
         Header.Kitty_Parent_ID,
         Header.Kitty_Parent_Placement_ID) /= Relative_Valid
      then
         return;
      end if;

      if Placement = null then
         if R.Kitty_Placement_Count >= R.Graphics_Limits.Placements then
            return;
         end if;
         Placement := new Conventional_Placement;
         Placement.Next := R.Conventional_Placements;
         R.Conventional_Placements := Placement;
         R.Kitty_Placement_Count := R.Kitty_Placement_Count + 1;
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
   exception
      when Storage_Error =>
         null;
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
   is
      Current : Image_Object_Access := R.Image_Objects;
   begin
      if ID = 0 then
         return null;
      end if;

      while Current /= null loop
         if Current.Stream_ID = Stream_ID and then Current.ID = ID then
            return Current;
         end if;
         Current := Current.Next;
      end loop;
      return null;
   end Find_Image_Object;

   function Find_Image_Object_By_Storage_Order
     (R             : Renderer;
      Stream_ID     : Terminal.Core.Graphics_Stream_ID;
      Storage_Order : Interfaces.Unsigned_64) return Image_Object_Access
   is
      Current : Image_Object_Access := R.Image_Objects;
   begin
      if Storage_Order = 0 then
         return null;
      end if;
      while Current /= null loop
         if Current.Stream_ID = Stream_ID
           and then Current.Storage_Order = Storage_Order
         then
            return Current;
         end if;
         Current := Current.Next;
      end loop;
      return null;
   end Find_Image_Object_By_Storage_Order;

   function Find_Image_Object_By_Number
     (R      : Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Number : Terminal.Core.Graphics_ID) return Image_Object_Access
   is
      Current : Image_Object_Access := R.Image_Objects;
   begin
      if Number = 0 then
         return null;
      end if;

      --  New objects are inserted at the head, so the first match is the
      --  protocol-defined newest image carrying this non-unique number.
      while Current /= null loop
         if Current.Stream_ID = Stream_ID
           and then Current.Number = Number
         then
            return Current;
         end if;
         Current := Current.Next;
      end loop;
      return null;
   end Find_Image_Object_By_Number;

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
      Current : Image_Object_Access := R.Image_Objects;
      Next    : Image_Object_Access;
   begin
      while Current /= null loop
         Next := Current.Next;
         R.Animation_Frame_Count :=
           R.Animation_Frame_Count - (Current.Frame_Count - 1);
         R.Image_Object_Bytes :=
           R.Image_Object_Bytes
           - Current.Decoded_Length
           - Current.Indexed_Length
           - Current.Frame_Bytes
           - Current.Theme_Operation_Bytes;
         R.Image_Object_Count := R.Image_Object_Count - 1;
         Clear_Image_Object (Current.all);
         Free_Image_Object (Current);
         Current := Next;
      end loop;
      R.Image_Objects := null;
      Release_Virtual_Placements (R);
      Release_Conventional_Placements (R);
   end Release_Image_Objects;

   procedure Delete_Image_Object_By_Storage_Order
     (R             : in out Renderer;
      Stream_ID     : Terminal.Core.Graphics_Stream_ID;
      Storage_Order : Interfaces.Unsigned_64)
   is
      Previous : Image_Object_Access := null;
      Current  : Image_Object_Access := R.Image_Objects;
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
         Previous := Current;
         Current := Current.Next;
      end loop;
      if Current = null then
         return;
      end if;

      if Previous = null then
         R.Image_Objects := Current.Next;
      else
         Previous.Next := Current.Next;
      end if;
      R.Image_Object_Bytes :=
        R.Image_Object_Bytes
        - Current.Decoded_Length
        - Current.Indexed_Length
        - Current.Frame_Bytes
        - Current.Theme_Operation_Bytes;
      R.Animation_Frame_Count :=
        R.Animation_Frame_Count - (Current.Frame_Count - 1);
      R.Image_Object_Count := R.Image_Object_Count - 1;
      Clear_Image_Object (Current.all);
      Free_Image_Object (Current);

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
   end Delete_Image_Object_By_Storage_Order;

   procedure Delete_Image_Object
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      ID        : Terminal.Core.Graphics_ID)
   is
      Current  : Image_Object_Access := R.Image_Objects;
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
         Current := Current.Next;
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
      Object_Current : Image_Object_Access := R.Image_Objects;
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
               Next : constant Image_Object_Access := Object_Current.Next;
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
      Current   : Image_Object_Access := R.Image_Objects;
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
         Current := Current.Next;
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
      if Object = null then
         return;
      end if;
      Object.Content_Serial := R.Next_Content_Serial;
      R.Next_Content_Serial := R.Next_Content_Serial + 1;
      if R.Next_Content_Serial = 0 then
         R.Next_Content_Serial := 1;
      end if;
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
      Stored_Bytes   : out RM.Image_Data_Access;
      Additional_Bytes : Natural := 0)
   is
      Object : Image_Object_Access := Find_Image_Object (R, Stream_ID, ID);
      Previous_Length : constant Natural :=
        (if Object = null
         then 0
         else
           Object.Decoded_Length
             + Object.Indexed_Length
             + Object.Frame_Bytes
             + Object.Theme_Operation_Bytes);
      Stored_Length : Natural := 0;
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

      if Additional_Bytes > Natural'Last - Decoded_Length then
         R.Image_Store_Allocation_Failed := True;
         return;
      end if;
      Stored_Length := Decoded_Length + Additional_Bytes;

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

      while R.Image_Object_Bytes - Previous_Length >
          R.Graphics_Limits.Image_Bytes - Stored_Length
        or else
          (Object = null
           and then R.Image_Object_Count >=
             R.Graphics_Limits.Image_Objects)
      loop
         if not Evict_One_Unplaced_Image (R, Stream_ID, ID) then
            R.Image_Store_Allocation_Failed := True;
            return;
         end if;
         Object := Find_Image_Object (R, Stream_ID, ID);
      end loop;

      if Object = null then
         Object := new Image_Object;
         Object.Next := R.Image_Objects;
         R.Image_Objects := Object;
         R.Image_Object_Count := R.Image_Object_Count + 1;
      else
         --  Retransmitting an explicit ID replaces both its data and every
         --  placement made from the previous object.
         Delete_Virtual_Placements (R, Stream_ID, ID);
         Delete_Conventional_Placements (R, Stream_ID, ID);
      end if;

      declare
         Next : constant Image_Object_Access := Object.Next;
      begin
         R.Image_Object_Bytes :=
           R.Image_Object_Bytes - Previous_Length;
         R.Animation_Frame_Count :=
           R.Animation_Frame_Count - (Object.Frame_Count - 1);
         Clear_Image_Object (Object.all);
         Object.all :=
           (Stream_ID      => Stream_ID,
            ID             => ID,
            Number         => Image_Number,
            Protocol       => Protocol,
            Raw_Format     => Raw_Format,
            Pixel_Width    => Pixel_Width,
            Pixel_Height   => Pixel_Height,
            Decoded_Length => Decoded_Length,
            Decoded_Row_Stride_Bytes => Decoded_Row_Stride_Bytes,
            Usage_Hint     => Usage_Hint,
            Storage_Order  => R.Next_Storage_Order,
            Content_Serial => R.Next_Content_Serial,
            Bytes          => Bytes,
            Indexed_Format => 0,
            Indexed_Length => 0,
            Indexed_Row_Stride_Bytes => 0,
            Indexed_Bytes  => null,
            Frames         => null,
            Frame_Count    => 1,
            Frame_Bytes    => 0,
            Theme_Operations => null,
            Theme_Operations_Tail => null,
            Theme_Operation_Count => 0,
            Theme_Operation_Bytes => 0,
            Root_Gap_MS    => 0,
            Current_Frame  => 1,
            Playback       => Animation_Stopped,
            Loop_Count     => 1,
            Loops_Completed => 0,
            Next_Frame_At  => Ada.Real_Time.Time_First,
            Deadline_Set   => False,
            Next           => Next);
         R.Next_Storage_Order := R.Next_Storage_Order + 1;
         if R.Next_Storage_Order = 0 then
            R.Next_Storage_Order := 1;
         end if;
         R.Next_Content_Serial := R.Next_Content_Serial + 1;
         if R.Next_Content_Serial = 0 then
            R.Next_Content_Serial := 1;
         end if;
         R.Image_Object_Bytes := R.Image_Object_Bytes + Stored_Length;
         R.Image_Install_Count := R.Image_Install_Count + 1;
         R.Image_Installed_Bytes :=
           R.Image_Installed_Bytes + Interfaces.Unsigned_64 (Stored_Length);
         R.Last_Stored_Image_Order := Object.Storage_Order;
         R.Last_Stored_Image_Content_Serial := Object.Content_Serial;
         Stored_Bytes := Bytes;
         Bytes := null;
      end;
      Delete_Orphaned_Relative_Placements
        (R, Stream_ID, Preserve_Image_ID => ID);
   exception
      when Storage_Error =>
         R.Image_Store_Allocation_Failed := True;
         Stored_Bytes := null;
   end Take_Image_Object;

   function Find_Image_Frame
     (Object : Image_Object_Access;
      Number : Positive) return Image_Frame_Access
   is
      Current : Image_Frame_Access :=
        (if Object = null then null else Object.Frames);
   begin
      if Number = 1 then
         return null;
      end if;
      while Current /= null loop
         if Current.Number = Number then
            return Current;
         end if;
         Current := Current.Next;
      end loop;
      return null;
   end Find_Image_Frame;

   function Animation_Frame_Exists
     (Object : Image_Object_Access;
      Number : Natural) return Boolean is
     (Object /= null
      and then Number in 1 .. Object.Frame_Count
      and then
        (Number = 1
         or else Find_Image_Frame (Object, Positive (Number)) /= null));

   function Animation_Frame_Bytes
     (Object : Image_Object_Access;
      Number : Positive) return RM.Image_Data_Access
   is
      Frame : constant Image_Frame_Access := Find_Image_Frame (Object, Number);
   begin
      if Object = null then
         return null;
      elsif Number = 1 then
         return Object.Bytes;
      else
         return (if Frame = null then null else Frame.Bytes);
      end if;
   end Animation_Frame_Bytes;

   function Animation_Frame_Gap
     (Object : Image_Object_Access;
      Number : Positive) return Integer
   is
      Frame : constant Image_Frame_Access := Find_Image_Frame (Object, Number);
   begin
      if Object = null then
         return 0;
      elsif Number = 1 then
         return Object.Root_Gap_MS;
      else
         return (if Frame = null then 0 else Frame.Gap_MS);
      end if;
   end Animation_Frame_Gap;

   function Set_Animation_Frame_Gap
     (Object : Image_Object_Access;
      Number : Positive;
      Gap    : Integer) return Boolean
   is
      Frame : constant Image_Frame_Access := Find_Image_Frame (Object, Number);
   begin
      if Object = null then
         return False;
      elsif Number = 1 then
         Object.Root_Gap_MS := Gap;
         return True;
      elsif Frame /= null then
         Frame.Gap_MS := Gap;
         return True;
      end if;
      return False;
   end Set_Animation_Frame_Gap;

   procedure Copy_Frame_To_RGBA
     (Object : Image_Object_Access;
      Number : Positive;
      Target : in out Terminal.Common.Bytes.Byte_Array;
      Valid  : out Boolean)
   is
      Source : constant RM.Image_Data_Access :=
        Animation_Frame_Bytes (Object, Number);
      Pixels : Natural;
   begin
      Valid := False;
      if Object = null
        or else Source = null
        or else Object.Pixel_Width = 0
        or else Object.Pixel_Height = 0
        or else Object.Pixel_Width > Natural'Last / Object.Pixel_Height
      then
         return;
      end if;
      Pixels := Object.Pixel_Width * Object.Pixel_Height;
      if Target'Length /= Pixels * 4 then
         return;
      end if;
      if Number /= 1 or else Object.Raw_Format = 32 then
         if Source'Length < Target'Length then
            return;
         end if;
         Target := Source (Source'First .. Source'First + Target'Length - 1);
      elsif Object.Raw_Format = 24 then
         if Source'Length < Pixels * 3 then
            return;
         end if;
         for Pixel in 0 .. Pixels - 1 loop
            Target (Target'First + Pixel * 4) :=
              Source (Source'First + Pixel * 3);
            Target (Target'First + Pixel * 4 + 1) :=
              Source (Source'First + Pixel * 3 + 1);
            Target (Target'First + Pixel * 4 + 2) :=
              Source (Source'First + Pixel * 3 + 2);
            Target (Target'First + Pixel * 4 + 3) := 255;
         end loop;
      else
         return;
      end if;
      Valid := True;
   end Copy_Frame_To_RGBA;

   Max_Theme_Operations : constant Natural :=
     Max_Kitty_Animation_Frames * 4;

   procedure Release_Theme_Operation_List
     (Head : in out Theme_Operation_Access)
   is
      Current : Theme_Operation_Access := Head;
   begin
      while Current /= null loop
         declare
            Next : constant Theme_Operation_Access := Current.Next;
         begin
            Free_Image_Data (Current.Bytes);
            Free_Theme_Operation (Current);
            Current := Next;
         end;
      end loop;
      Head := null;
   end Release_Theme_Operation_List;

   procedure Clear_Theme_Operations
     (R      : in out Renderer;
      Object : Image_Object_Access) is
   begin
      if Object = null then
         return;
      end if;
      R.Image_Object_Bytes :=
        R.Image_Object_Bytes - Object.Theme_Operation_Bytes;
      Release_Theme_Operation_List (Object.Theme_Operations);
      Object.Theme_Operations_Tail := null;
      Object.Theme_Operation_Count := 0;
      Object.Theme_Operation_Bytes := 0;
   end Clear_Theme_Operations;

   procedure Archive_Root_Theme_Operations
     (R      : in out Renderer;
      Object : Image_Object_Access)
   is
      type Operation_Array is
        array (Positive range 1 .. Max_Theme_Operations) of
          Theme_Operation_Access;
      type Keep_Array is
        array (Positive range 1 .. Max_Theme_Operations) of Boolean;
      type Frame_Array is
        array (Positive range 1 .. Max_Theme_Operations) of Positive;

      Operations : Operation_Array := (others => null);
      Keep       : Keep_Array := (others => False);
      Needed     : Frame_Array := (others => 1);
      Operation_Count : Natural := 0;
      Needed_Count    : Natural := 1;
      Current         : Theme_Operation_Access;
      New_Head        : Theme_Operation_Access := null;
      New_Tail        : Theme_Operation_Access := null;
      New_Count       : Natural := 0;
      New_Bytes       : Natural := 0;
      Old_Bytes       : Natural;

      function Is_Needed (Frame : Positive) return Boolean is
      begin
         for I in 1 .. Needed_Count loop
            if Needed (I) = Frame then
               return True;
            end if;
         end loop;
         return False;
      end Is_Needed;

      procedure Add_Needed (Frame : Positive) is
      begin
         if not Is_Needed (Frame)
           and then Needed_Count < Max_Theme_Operations
         then
            Needed_Count := Needed_Count + 1;
            Needed (Needed_Count) := Frame;
         end if;
      end Add_Needed;

      procedure Remove_Needed (Frame : Positive) is
      begin
         for I in 1 .. Needed_Count loop
            if Needed (I) = Frame then
               Needed (I) := Needed (Needed_Count);
               Needed_Count := Needed_Count - 1;
               return;
            end if;
         end loop;
      end Remove_Needed;
   begin
      if Object = null or else Object.Theme_Operations = null then
         return;
      end if;

      Current := Object.Theme_Operations;
      while Current /= null and then Operation_Count < Max_Theme_Operations loop
         Operation_Count := Operation_Count + 1;
         Operations (Operation_Count) := Current;
         Current := Current.Next;
      end loop;

      --  Walk history backwards.  An operation is retained only when its
      --  target contributes to the final root image.  A new-frame operation
      --  cuts the dependency on the target's previous incarnation, while a
      --  base frame or composition source introduces another dependency.
      if Operation_Count > 0 then
         for I in reverse 1 .. Operation_Count loop
            Current := Operations (I);
            if Is_Needed (Current.Target_Frame) then
               Keep (I) := True;
               if Current.Is_Composition then
                  if Current.Source_Frame > 0 then
                     Add_Needed (Positive (Current.Source_Frame));
                  end if;
               elsif Current.New_Frame then
                  Remove_Needed (Current.Target_Frame);
                  if Current.Base_Frame > 0 then
                     Add_Needed (Positive (Current.Base_Frame));
                  end if;
               end if;
            end if;
         end loop;
      end if;

      Old_Bytes := Object.Theme_Operation_Bytes;
      for I in 1 .. Operation_Count loop
         Current := Operations (I);
         Current.Next := null;
         if Keep (I) then
            Current.Archived_Frames := True;
            if New_Tail = null then
               New_Head := Current;
            else
               New_Tail.Next := Current;
            end if;
            New_Tail := Current;
            New_Count := New_Count + 1;
            New_Bytes := New_Bytes + Current.Length;
         else
            Free_Image_Data (Current.Bytes);
            Free_Theme_Operation (Current);
         end if;
      end loop;

      Object.Theme_Operations := New_Head;
      Object.Theme_Operations_Tail := New_Tail;
      Object.Theme_Operation_Count := New_Count;
      Object.Theme_Operation_Bytes := New_Bytes;
      R.Image_Object_Bytes := R.Image_Object_Bytes - (Old_Bytes - New_Bytes);
   end Archive_Root_Theme_Operations;

   procedure Append_Theme_Operation
     (R         : in out Renderer;
      Object    : Image_Object_Access;
      Operation : in out Theme_Operation_Access)
   is
   begin
      if Object = null or else Operation = null then
         return;
      end if;
      if Object.Theme_Operations_Tail = null then
         Object.Theme_Operations := Operation;
      else
         Object.Theme_Operations_Tail.Next := Operation;
      end if;
      Object.Theme_Operations_Tail := Operation;
      Object.Theme_Operation_Count := Object.Theme_Operation_Count + 1;
      Object.Theme_Operation_Bytes :=
        Object.Theme_Operation_Bytes + Operation.Length;
      R.Image_Object_Bytes := R.Image_Object_Bytes + Operation.Length;
      Operation := null;
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
          Natural'Min (Object.Theme_Operation_Count, Max_Theme_Operations)
      then
         return False;
      end if;
      Existing :=
        Object.Decoded_Length
        + Object.Indexed_Length
        + Object.Frame_Bytes
        + Object.Theme_Operation_Bytes;
      if Byte_Count > R.Graphics_Limits.Per_Image_Bytes
        or else Existing > R.Graphics_Limits.Per_Image_Bytes - Byte_Count
        or else Byte_Count > R.Graphics_Limits.Image_Bytes
      then
         return False;
      end if;
      while R.Image_Object_Bytes >
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
   is
      Required_Bytes : Natural := 0;
      Required_Count : Natural := 1;
      Root_Source : RM.Image_Data_Access;
      Root_Length : Natural;
      Root_Format : Natural;
      Root_Stride : Natural;
      Frame : Image_Frame_Access;
      Head : Theme_Operation_Access := null;
      Tail : Theme_Operation_Access := null;

      procedure Add_Baseline
        (Target : Positive;
         Format : Natural;
         Stride : Natural;
         Source : RM.Image_Data_Access;
         Length : Natural)
      is
         Op : Theme_Operation_Access := null;
      begin
         Op := new Theme_Operation'
           (New_Frame            => True,
            Target_Frame         => Target,
            Raw_Format           => Format,
            Data_Width           => Object.Pixel_Width,
            Data_Height          => Object.Pixel_Height,
            Data_Row_Stride_Bytes => Stride,
            Composition_Mode     => 1,
            Length               => Length,
            others               => <>);
         Op.Bytes := new Terminal.Common.Bytes.Byte_Array (1 .. Length);
         Op.Bytes.all := Source (Source'First .. Source'First + Length - 1);
         if Tail = null then
            Head := Op;
         else
            Tail.Next := Op;
         end if;
         Tail := Op;
      end Add_Baseline;
   begin
      if Object = null then
         return False;
      elsif Object.Theme_Operations /= null then
         return True;
      elsif Object.Bytes = null then
         return False;
      end if;

      if Object.Indexed_Bytes /= null
        and then Object.Indexed_Format in 8 | 16
      then
         Root_Source := Object.Indexed_Bytes;
         Root_Length := Object.Indexed_Length;
         Root_Format := Object.Indexed_Format;
         Root_Stride := Object.Indexed_Row_Stride_Bytes;
      else
         Root_Source := Object.Bytes;
         Root_Length := Object.Decoded_Length;
         Root_Format := Object.Raw_Format;
         Root_Stride := Object.Decoded_Row_Stride_Bytes;
      end if;
      if Root_Source = null or else Root_Length = 0 then
         return False;
      end if;
      Required_Bytes := Root_Length;
      Frame := Object.Frames;
      while Frame /= null loop
         if Frame.Bytes = null
           or else Frame.Length > Natural'Last - Required_Bytes
         then
            return False;
         end if;
         Required_Bytes := Required_Bytes + Frame.Length;
         Required_Count := Required_Count + 1;
         Frame := Frame.Next;
      end loop;
      if not Reserve_Theme_Operation_Bytes
        (R, Object, Required_Bytes, Required_Count)
      then
         return False;
      end if;

      Add_Baseline
        (1, Root_Format, Root_Stride, Root_Source, Root_Length);
      Frame := Object.Frames;
      while Frame /= null loop
         Add_Baseline
           (Frame.Number,
            32,
            Object.Pixel_Width * 4,
            Frame.Bytes,
            Frame.Length);
         Frame := Frame.Next;
      end loop;

      Object.Theme_Operations := Head;
      Object.Theme_Operations_Tail := Tail;
      Object.Theme_Operation_Count := Required_Count;
      Object.Theme_Operation_Bytes := Required_Bytes;
      R.Image_Object_Bytes := R.Image_Object_Bytes + Required_Bytes;
      return True;
   exception
      when Storage_Error | Constraint_Error =>
         Release_Theme_Operation_List (Head);
         return False;
   end Ensure_Theme_Baseline;

   function Prepare_Theme_Frame_Operation
     (R             : in out Renderer;
      Object        : Image_Object_Access;
      Header        : Terminal.App.Graphics.Graphics_Header;
      Data          : Terminal.App.Graphics.Graphics_Data_Preview;
      Target_Number : Positive;
      New_Frame     : Boolean;
      Operation     : out Theme_Operation_Access) return Boolean
   is
      Length : constant Natural :=
        (if Data.Bytes = null then 0 else Data.Bytes'Length);
   begin
      Operation := null;
      if Object = null
        or else
          (Object.Theme_Operations = null
           and then Object.Indexed_Bytes = null
           and then Data.Raw_Format not in 8 | 16)
      then
         return True;
      end if;
      if not Ensure_Theme_Baseline (R, Object)
        or else Length = 0
        or else not Reserve_Theme_Operation_Bytes (R, Object, Length, 1)
      then
         return False;
      end if;
      Operation := new Theme_Operation'
        (New_Frame             => New_Frame,
         Target_Frame          => Target_Number,
         Base_Frame            => Header.Kitty_Base_Frame,
         Raw_Format            => Data.Raw_Format,
         Data_Width            => Data.Pixel_Width,
         Data_Height           => Data.Pixel_Height,
         Data_Row_Stride_Bytes => Data.Decoded_Row_Stride_Bytes,
         Target_X              => Header.Kitty_Source_X,
         Target_Y              => Header.Kitty_Source_Y,
         Composition_Mode      => Header.Kitty_Composition_Mode,
         Background_Color      => Header.Kitty_Background_Color,
         Length                => Length,
         others                => <>);
      Operation.Bytes := new Terminal.Common.Bytes.Byte_Array (1 .. Length);
      Operation.Bytes.all := Data.Bytes.all;
      return True;
   exception
      when Storage_Error | Constraint_Error =>
         if Operation /= null then
            Free_Image_Data (Operation.Bytes);
            Free_Theme_Operation (Operation);
         end if;
         return False;
   end Prepare_Theme_Frame_Operation;

   function Prepare_Theme_Composition_Operation
     (R           : in out Renderer;
      Object      : Image_Object_Access;
      Header      : Terminal.App.Graphics.Graphics_Header;
      Source      : Positive;
      Target      : Positive;
      Width       : Natural;
      Height      : Natural;
      Operation   : out Theme_Operation_Access) return Boolean
   is
   begin
      Operation := null;
      if Object = null
        or else
          (Object.Theme_Operations = null and then Object.Indexed_Bytes = null)
      then
         return True;
      end if;
      if not Ensure_Theme_Baseline (R, Object)
        or else not Reserve_Theme_Operation_Bytes (R, Object, 0, 1)
      then
         return False;
      end if;
      Operation := new Theme_Operation'
        (Is_Composition       => True,
         Target_Frame         => Target,
         Source_Frame         => Source,
         Target_X             => Header.Kitty_Source_X,
         Target_Y             => Header.Kitty_Source_Y,
         Source_X             => Header.Kitty_Cell_X,
         Source_Y             => Header.Kitty_Cell_Y,
         Region_Width         => Width,
         Region_Height        => Height,
         Composition_Mode     => Header.Kitty_Composition_Mode,
         others               => <>);
      return True;
   exception
      when Storage_Error =>
         if Operation /= null then
            Free_Theme_Operation (Operation);
         end if;
         return False;
   end Prepare_Theme_Composition_Operation;

   function Replay_Theme_Operations
     (R      : in out Renderer;
      Object : Image_Object_Access) return Boolean
   is
      Canvas_Length : Natural;
      Canvas_A : RM.Image_Data_Access := null;
      Canvas_B : RM.Image_Data_Access := null;
      Operation : Theme_Operation_Access;
      Valid : Boolean := False;

      type Archived_Frame_State;
      type Archived_Frame_State_Access is access Archived_Frame_State;
      type Archived_Frame_State is record
         Number : Positive;
         Bytes  : RM.Image_Data_Access := null;
         Next   : Archived_Frame_State_Access := null;
      end record;
      Archived_Frames : Archived_Frame_State_Access := null;
      procedure Free_Archived_Frame is new Ada.Unchecked_Deallocation
        (Archived_Frame_State, Archived_Frame_State_Access);

      procedure Release_Archived_Frames is
         Current : Archived_Frame_State_Access := Archived_Frames;
      begin
         while Current /= null loop
            declare
               Next : constant Archived_Frame_State_Access := Current.Next;
            begin
               Free_Image_Data (Current.Bytes);
               Free_Archived_Frame (Current);
               Current := Next;
            end;
         end loop;
         Archived_Frames := null;
      end Release_Archived_Frames;

      function Target_Bytes
        (Number   : Positive;
         Archived : Boolean;
         Create    : Boolean := False) return RM.Image_Data_Access
      is
         Current : Archived_Frame_State_Access;
      begin
         if Number = 1 then
            return Object.Bytes;
         elsif Archived then
            Current := Archived_Frames;
            while Current /= null loop
               if Current.Number = Number then
                  return Current.Bytes;
               end if;
               Current := Current.Next;
            end loop;
            if not Create then
               return null;
            end if;
            Current := new Archived_Frame_State'
              (Number => Number,
               Bytes  => new Terminal.Common.Bytes.Byte_Array
                 (1 .. Canvas_Length),
               Next   => Archived_Frames);
            Current.Bytes.all := (others => 0);
            Archived_Frames := Current;
            return Current.Bytes;
         else
            declare
               Frame : constant Image_Frame_Access :=
                 Find_Image_Frame (Object, Number);
            begin
               return (if Frame = null then null else Frame.Bytes);
            end;
         end if;
      end Target_Bytes;

      procedure Copy_Replay_Frame_To_RGBA
        (Number   : Positive;
         Archived : Boolean;
         Target   : in out Terminal.Common.Bytes.Byte_Array;
         Valid    : out Boolean)
      is
         Source : constant RM.Image_Data_Access :=
           Target_Bytes (Number, Archived);
      begin
         Valid := False;
         if Source = null or else Source'Length /= Target'Length then
            return;
         end if;
         Target := Source.all;
         Valid := True;
      end Copy_Replay_Frame_To_RGBA;

      procedure Fill_Background
        (Target : in out Terminal.Common.Bytes.Byte_Array;
         Color  : Terminal.Core.Graphics_ID)
      is
         Red : constant Terminal.Common.Bytes.Byte :=
           Terminal.Common.Bytes.Byte
             (Interfaces.Shift_Right (Interfaces.Unsigned_32 (Color), 24));
         Green : constant Terminal.Common.Bytes.Byte :=
           Terminal.Common.Bytes.Byte
             (Interfaces.Shift_Right (Interfaces.Unsigned_32 (Color), 16)
              and 16#FF#);
         Blue : constant Terminal.Common.Bytes.Byte :=
           Terminal.Common.Bytes.Byte
             (Interfaces.Shift_Right (Interfaces.Unsigned_32 (Color), 8)
              and 16#FF#);
         Alpha : constant Terminal.Common.Bytes.Byte :=
           Terminal.Common.Bytes.Byte
             (Interfaces.Unsigned_32 (Color) and 16#FF#);
      begin
         for Pixel in 0 .. Object.Pixel_Width * Object.Pixel_Height - 1 loop
            Target (Target'First + Pixel * 4) := Red;
            Target (Target'First + Pixel * 4 + 1) := Green;
            Target (Target'First + Pixel * 4 + 2) := Blue;
            Target (Target'First + Pixel * 4 + 3) := Alpha;
         end loop;
      end Fill_Background;

      procedure Composite_Pixel
        (Target : in out Terminal.Common.Bytes.Byte_Array;
         Index  : Positive;
         SR     : Natural;
         SG     : Natural;
         SB     : Natural;
         SA     : Natural;
         Mode   : Natural)
      is
      begin
         if Mode = 1 or else SA = 255 then
            Target (Index) := Terminal.Common.Bytes.Byte (SR);
            Target (Index + 1) := Terminal.Common.Bytes.Byte (SG);
            Target (Index + 2) := Terminal.Common.Bytes.Byte (SB);
            Target (Index + 3) := Terminal.Common.Bytes.Byte (SA);
         elsif SA > 0 then
            declare
               DR : constant Natural := Natural (Target (Index));
               DG : constant Natural := Natural (Target (Index + 1));
               DB : constant Natural := Natural (Target (Index + 2));
               DA : constant Natural := Natural (Target (Index + 3));
               OA : constant Natural := SA + (DA * (255 - SA) + 127) / 255;
               Denom : constant Natural := Natural'Max (1, OA * 255);
            begin
               Target (Index) := Terminal.Common.Bytes.Byte
                 ((SR * SA * 255 + DR * DA * (255 - SA) + Denom / 2) /
                    Denom);
               Target (Index + 1) := Terminal.Common.Bytes.Byte
                 ((SG * SA * 255 + DG * DA * (255 - SA) + Denom / 2) /
                    Denom);
               Target (Index + 2) := Terminal.Common.Bytes.Byte
                 ((SB * SA * 255 + DB * DA * (255 - SA) + Denom / 2) /
                    Denom);
               Target (Index + 3) := Terminal.Common.Bytes.Byte (OA);
            end;
         end if;
      end Composite_Pixel;
   begin
      if Object = null or else Object.Theme_Operations = null then
         return True;
      elsif Object.Pixel_Width = 0
        or else Object.Pixel_Height = 0
        or else Object.Pixel_Width > Natural'Last / Object.Pixel_Height
        or else Object.Pixel_Width * Object.Pixel_Height > Natural'Last / 4
      then
         return False;
      end if;
      Canvas_Length := Object.Pixel_Width * Object.Pixel_Height * 4;
      Canvas_A := new Terminal.Common.Bytes.Byte_Array (1 .. Canvas_Length);
      Canvas_B := new Terminal.Common.Bytes.Byte_Array (1 .. Canvas_Length);
      Operation := Object.Theme_Operations;
      while Operation /= null loop
         if Operation.Is_Composition then
            declare
               Source_Data : constant RM.Image_Data_Access :=
                 Target_Bytes
                   (Positive (Operation.Source_Frame),
                    Operation.Archived_Frames);
               Target_Data : constant RM.Image_Data_Access :=
                 Target_Bytes
                   (Operation.Target_Frame,
                    Operation.Archived_Frames);
            begin
               if Source_Data /= null and then Target_Data /= null then
                  Copy_Replay_Frame_To_RGBA
                    (Positive (Operation.Source_Frame),
                     Operation.Archived_Frames,
                     Canvas_A.all,
                     Valid);
                  if not Valid then
                     Free_Image_Data (Canvas_A);
                     Free_Image_Data (Canvas_B);
                     Release_Archived_Frames;
                     return False;
                  end if;
                  Copy_Replay_Frame_To_RGBA
                    (Operation.Target_Frame,
                     Operation.Archived_Frames,
                     Canvas_B.all,
                     Valid);
                  if not Valid then
                     Free_Image_Data (Canvas_A);
                     Free_Image_Data (Canvas_B);
                     Release_Archived_Frames;
                     return False;
                  end if;
                  for Y in 0 .. Operation.Region_Height - 1 loop
                     for X in 0 .. Operation.Region_Width - 1 loop
                        declare
                           SI : constant Positive := Positive
                             (((Operation.Source_Y + Y) * Object.Pixel_Width
                               + Operation.Source_X + X) * 4 + 1);
                           DI : constant Positive := Positive
                             (((Operation.Target_Y + Y) * Object.Pixel_Width
                               + Operation.Target_X + X) * 4 + 1);
                        begin
                           Composite_Pixel
                             (Canvas_B.all,
                              DI,
                              Natural (Canvas_A (SI)),
                              Natural (Canvas_A (SI + 1)),
                              Natural (Canvas_A (SI + 2)),
                              Natural (Canvas_A (SI + 3)),
                              Operation.Composition_Mode);
                        end;
                     end loop;
                  end loop;
                  if Target_Data'Length /= Canvas_Length then
                     Free_Image_Data (Canvas_A);
                     Free_Image_Data (Canvas_B);
                     Release_Archived_Frames;
                     return False;
                  end if;
                  Target_Data.all := Canvas_B.all;
               end if;
            end;
         else
            declare
               Target_Data : constant RM.Image_Data_Access :=
                 Target_Bytes
                   (Operation.Target_Frame,
                    Operation.Archived_Frames,
                    Create => Operation.New_Frame);
               Bytes_Per_Pixel : constant Natural :=
                 (if Operation.Raw_Format = 8 then 1
                  elsif Operation.Raw_Format = 16 then 2
                  elsif Operation.Raw_Format in 24 | 32
                  then Operation.Raw_Format / 8
                  else 0);
            begin
               if Target_Data /= null then
                  if Operation.New_Frame then
                     if Operation.Base_Frame > 0
                       and then
                         (if Operation.Archived_Frames
                          then Target_Bytes
                            (Positive (Operation.Base_Frame), True) /= null
                          else Animation_Frame_Exists
                            (Object, Operation.Base_Frame))
                     then
                        Copy_Replay_Frame_To_RGBA
                          (Positive (Operation.Base_Frame),
                           Operation.Archived_Frames,
                           Canvas_A.all,
                           Valid);
                        if not Valid then
                           Free_Image_Data (Canvas_A);
                           Free_Image_Data (Canvas_B);
                           Release_Archived_Frames;
                           return False;
                        end if;
                     else
                        Fill_Background
                          (Canvas_A.all, Operation.Background_Color);
                     end if;
                  else
                     Copy_Replay_Frame_To_RGBA
                       (Operation.Target_Frame,
                        Operation.Archived_Frames,
                        Canvas_A.all,
                        Valid);
                     if not Valid then
                        Free_Image_Data (Canvas_A);
                        Free_Image_Data (Canvas_B);
                        Release_Archived_Frames;
                        return False;
                     end if;
                  end if;
                  if Bytes_Per_Pixel = 0
                    or else Operation.Bytes = null
                    or else Operation.Target_X > Object.Pixel_Width
                    or else Operation.Target_Y > Object.Pixel_Height
                    or else Operation.Data_Width >
                      Object.Pixel_Width - Operation.Target_X
                    or else Operation.Data_Height >
                      Object.Pixel_Height - Operation.Target_Y
                  then
                     Free_Image_Data (Canvas_A);
                     Free_Image_Data (Canvas_B);
                     Release_Archived_Frames;
                     return False;
                  end if;
                  for Y in 0 .. Operation.Data_Height - 1 loop
                     for X in 0 .. Operation.Data_Width - 1 loop
                        declare
                           SI : constant Positive := Positive
                             (Y * Operation.Data_Row_Stride_Bytes
                              + X * Bytes_Per_Pixel + 1);
                           DI : constant Positive := Positive
                             (((Operation.Target_Y + Y) * Object.Pixel_Width
                               + Operation.Target_X + X) * 4 + 1);
                           Palette : constant RM.Pixel_Color :=
                             (if Operation.Raw_Format in 8 | 16
                              then Kitty_Indexed_Color
                                (R, Natural (Operation.Bytes (SI)))
                              else (0.0, 0.0, 0.0, 1.0));
                           SR : constant Natural :=
                             (if Operation.Raw_Format in 8 | 16
                              then Natural (Color_Byte (Palette.R))
                              else Natural (Operation.Bytes (SI)));
                           SG : constant Natural :=
                             (if Operation.Raw_Format in 8 | 16
                              then Natural (Color_Byte (Palette.G))
                              else Natural (Operation.Bytes (SI + 1)));
                           SB : constant Natural :=
                             (if Operation.Raw_Format in 8 | 16
                              then Natural (Color_Byte (Palette.B))
                              else Natural (Operation.Bytes (SI + 2)));
                           SA : constant Natural :=
                             (if Operation.Raw_Format = 16
                              then Natural (Operation.Bytes (SI + 1))
                              elsif Operation.Raw_Format = 32
                              then Natural (Operation.Bytes (SI + 3))
                              else 255);
                        begin
                           Composite_Pixel
                             (Canvas_A.all,
                              DI,
                              SR,
                              SG,
                              SB,
                              SA,
                              Operation.Composition_Mode);
                        end;
                     end loop;
                  end loop;
                  if Target_Data'Length /= Canvas_Length then
                     Free_Image_Data (Canvas_A);
                     Free_Image_Data (Canvas_B);
                     Release_Archived_Frames;
                     return False;
                  end if;
                  Target_Data.all := Canvas_A.all;
               end if;
            end;
         end if;
         Operation := Operation.Next;
      end loop;
      Free_Image_Data (Canvas_A);
      Free_Image_Data (Canvas_B);
      Release_Archived_Frames;
      return True;
   exception
      when Storage_Error | Constraint_Error =>
         Free_Image_Data (Canvas_A);
         Free_Image_Data (Canvas_B);
         Release_Archived_Frames;
         return False;
   end Replay_Theme_Operations;

   procedure Apply_Animation_Frame
     (R      : in out Renderer;
      Event  : Terminal.Core.Graphics_Event;
      Header : Terminal.App.Graphics.Graphics_Header;
      Text   : String;
      Allow_Unknown_Compressed_PNG_Size : Boolean := False)
   is
      Object : constant Image_Object_Access :=
        Find_Image_Object (R, Event.Stream_ID, Header.Kitty_ID);
      Data : Terminal.App.Graphics.Graphics_Data_Preview :=
        (Header_Recognized => Header.Recognized,
         Has_Data          => Header.Has_Data,
         Raw_Format        => Header.Raw_Format,
         Pixel_Width       => Header.Pixel_Width,
         Pixel_Height      => Header.Pixel_Height,
         others            => <>);
      Canvas_Length : Natural := 0;
      Target_Number : Natural := Header.Kitty_Frame_Number;
      Existing : Image_Frame_Access := null;
      Canvas : RM.Image_Data_Access := null;
      Canvas_Owned : Boolean := False;
      Base_Valid : Boolean := False;
      New_Frame : Boolean := False;
      Compressed_Bytes : RM.Image_Data_Access := null;
      Compressed_Bytes_Owned : Boolean := False;
      Row_Copy_Failed : Boolean := False;
      Row_Quota_Failed : Boolean := False;
      Row_Allocation_Failed : Boolean := False;
      Prepared_Operation : Theme_Operation_Access := null;

      function Data_Start return Natural is
      begin
         for I in Text'Range loop
            if Text (I) = ';' then
               return (if I < Text'Last then I + 1 else 0);
            end if;
         end loop;
         return 0;
      end Data_Start;

      function One_Chunk (Index : Positive) return String is
         First : constant Natural := Data_Start;
      begin
         if Index /= 1 or else First = 0 then
            return "";
         end if;
         return Text (First .. Text'Last);
      end One_Chunk;

      procedure Capture_Compressed_Row
        (Y        : Natural;
         Row      : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean)
      is
         Required : Natural := 0;
         Offset : Natural := 0;
      begin
         if Data.Pixel_Height = 0
           or else Row'Length = 0
           or else Data.Pixel_Height > Natural'Last / Row'Length
         then
            Continue := False;
            Row_Copy_Failed := True;
            return;
         end if;
         Required := Data.Pixel_Height * Row'Length;
         if Required > R.Graphics_Limits.Per_Image_Bytes
           or else Data.Pixel_Width > R.Graphics_Limits.Pixel_Dimension
           or else Data.Pixel_Height > R.Graphics_Limits.Pixel_Dimension
           or else Y >= Data.Pixel_Height
         then
            Continue := False;
            Row_Copy_Failed := True;
            Row_Quota_Failed := True;
            return;
         end if;
         if Compressed_Bytes = null then
            Compressed_Bytes :=
              new Terminal.Common.Bytes.Byte_Array (1 .. Required);
            Compressed_Bytes.all := (others => 0);
            Compressed_Bytes_Owned := True;
         elsif Compressed_Bytes'Length /= Required then
            Continue := False;
            Row_Copy_Failed := True;
            return;
         end if;
         Offset := Y * Row'Length + 1;
         Compressed_Bytes (Offset .. Offset + Row'Length - 1) := Row;
         Continue := True;
      exception
         when Storage_Error =>
            Continue := False;
            Row_Copy_Failed := True;
            Row_Allocation_Failed := True;
      end Capture_Compressed_Row;

      procedure Fail (Code : Terminal.Core.Kitty_Graphics_Result_Code) is
      begin
         R.Last_Animation_Result := Code;
      end Fail;

      procedure Release_Local is
      begin
         Terminal.App.Graphics.Release (Data);
         if Canvas /= null and then Canvas_Owned then
            Free_Image_Data (Canvas);
         end if;
         Canvas := null;
         if Prepared_Operation /= null then
            Free_Image_Data (Prepared_Operation.Bytes);
            Free_Theme_Operation (Prepared_Operation);
         end if;
      end Release_Local;
   begin
      R.Last_Animation_Result := Terminal.Core.Kitty_EINVAL;
      if Header.Kitty_Format in 8 | 16 | 24 | 32 then
         if Header.Kitty_Compression = 'z' then
            Terminal.App.Graphics.Decode_Base64_Zlib_Raw_Chunk_Rows
              (1,
               One_Chunk'Access,
               Header.Kitty_Format,
               Header.Pixel_Width,
               Header.Pixel_Height,
               Capture_Compressed_Row'Access,
               Data);
         else
            Terminal.App.Graphics.Decode_Base64_Raw_Chunk_Rows
              (1,
               One_Chunk'Access,
               Header.Kitty_Format,
               Header.Pixel_Width,
               Header.Pixel_Height,
               Capture_Compressed_Row'Access,
               Data);
         end if;
      elsif Header.Kitty_Format = 100 then
         if Header.Kitty_Compression = 'z'
           and then
             (Header.Kitty_Data_Size > 0
              or else Allow_Unknown_Compressed_PNG_Size)
         then
            declare
               Encoded_Length : Natural := 0;
            begin
               Terminal.App.Graphics.Decode_Base64_Zlib_PNG_Chunk_Rows
                 (1,
                  One_Chunk'Access,
                  Header.Kitty_Data_Size,
                  Encoded_Length,
                  Capture_Compressed_Row'Access,
                  Data);
            end;
         elsif Header.Kitty_Compression = ASCII.NUL then
            declare
               Encoded_Length : Natural := 0;
               PNG_Length : Natural := 0;
            begin
               Terminal.App.Graphics.Decode_Base64_PNG_Chunk_Rows
                 (1,
                  One_Chunk'Access,
                  Encoded_Length,
                  PNG_Length,
                  Capture_Compressed_Row'Access,
                  Data);
            end;
         end if;
      end if;
      if Data.Bytes /= null then
         Terminal.App.Graphics.Release (Data);
      end if;
      Data.Bytes := Compressed_Bytes;
      Compressed_Bytes := null;
      Compressed_Bytes_Owned := False;
      if Row_Allocation_Failed then
         Fail (Terminal.Core.Kitty_ENOMEM);
         Terminal.App.Graphics.Release (Data);
         return;
      elsif Row_Quota_Failed then
         Fail (Terminal.Core.Kitty_ENOSPC);
         Terminal.App.Graphics.Release (Data);
         return;
      elsif Object = null then
         Fail (Terminal.Core.Kitty_ENOENT);
         Terminal.App.Graphics.Release (Data);
         return;
      elsif Header.Kitty_ID = 0
        or else not Header.Has_Data
        or else Header.Kitty_Compression not in ASCII.NUL | 'z'
        or else Row_Copy_Failed
        or else not Data.Decode_Complete
        or else Data.Bytes = null
        or else Data.Pixel_Width = 0
        or else Data.Pixel_Height = 0
        or else Data.Raw_Format not in 8 | 16 | 24 | 32
        or else Object.Pixel_Width > Natural'Last / Object.Pixel_Height
        or else Object.Pixel_Width * Object.Pixel_Height > Natural'Last / 4
      then
         Terminal.App.Graphics.Release (Data);
         return;
      end if;
      Canvas_Length := Object.Pixel_Width * Object.Pixel_Height * 4;
      if Canvas_Length > R.Graphics_Limits.Per_Image_Bytes
        or else Object.Pixel_Width > R.Graphics_Limits.Pixel_Dimension
        or else Object.Pixel_Height > R.Graphics_Limits.Pixel_Dimension
      then
         Fail (Terminal.Core.Kitty_ENOSPC);
         Terminal.App.Graphics.Release (Data);
         return;
      end if;
      if Target_Number = 0 then
         if Object.Frame_Count >= Max_Kitty_Animation_Frames
           or else R.Animation_Frame_Count >=
             R.Graphics_Limits.Animation_Frames
         then
            Fail (Terminal.Core.Kitty_ENOSPC);
            Terminal.App.Graphics.Release (Data);
            return;
         end if;
         Target_Number := Object.Frame_Count + 1;
         New_Frame := True;
      elsif not Animation_Frame_Exists (Object, Target_Number) then
         Fail (Terminal.Core.Kitty_ENOENT);
         Terminal.App.Graphics.Release (Data);
         return;
      end if;
      if Target_Number > 1 then
         Existing := Find_Image_Frame (Object, Positive (Target_Number));
      end if;

      if Header.Kitty_Source_X > Object.Pixel_Width
        or else Header.Kitty_Source_Y > Object.Pixel_Height
        or else Data.Pixel_Width > Object.Pixel_Width - Header.Kitty_Source_X
        or else Data.Pixel_Height > Object.Pixel_Height - Header.Kitty_Source_Y
      then
         Terminal.App.Graphics.Release (Data);
         return;
      end if;

      if New_Frame
        and then
          (Object.Decoded_Length
             + Object.Indexed_Length
             + Object.Frame_Bytes
             + Object.Theme_Operation_Bytes >
             R.Graphics_Limits.Per_Image_Bytes - Canvas_Length)
      then
         Fail (Terminal.Core.Kitty_ENOSPC);
         Terminal.App.Graphics.Release (Data);
         return;
      end if;

      if New_Frame
        and then R.Image_Object_Bytes >
          R.Graphics_Limits.Image_Bytes - Natural'Min
            (Canvas_Length, R.Graphics_Limits.Image_Bytes)
      then
         while R.Image_Object_Bytes >
           R.Graphics_Limits.Image_Bytes - Natural'Min
             (Canvas_Length, R.Graphics_Limits.Image_Bytes)
         loop
            if Canvas_Length > R.Graphics_Limits.Image_Bytes
              or else not Evict_One_Unplaced_Image
                (R, Event.Stream_ID, Header.Kitty_ID)
            then
               Fail (Terminal.Core.Kitty_ENOSPC);
               Terminal.App.Graphics.Release (Data);
               return;
            end if;
         end loop;
      end if;

      Canvas := new Terminal.Common.Bytes.Byte_Array (1 .. Canvas_Length);
      Canvas_Owned := True;
      if New_Frame then
         if Header.Kitty_Base_Frame > 0 then
            if not Animation_Frame_Exists (Object, Header.Kitty_Base_Frame) then
               Fail (Terminal.Core.Kitty_ENOENT);
               Release_Local;
               return;
            end if;
            Copy_Frame_To_RGBA
              (Object, Positive (Header.Kitty_Base_Frame), Canvas.all, Base_Valid);
            if not Base_Valid then
               Release_Local;
               return;
            end if;
         else
            declare
               Color : constant Terminal.Core.Graphics_ID :=
                 Header.Kitty_Background_Color;
               Red   : constant Terminal.Common.Bytes.Byte :=
                 Terminal.Common.Bytes.Byte (Interfaces.Shift_Right
                   (Interfaces.Unsigned_32 (Color), 24));
               Green : constant Terminal.Common.Bytes.Byte :=
                 Terminal.Common.Bytes.Byte (Interfaces.Shift_Right
                   (Interfaces.Unsigned_32 (Color), 16) and 16#FF#);
               Blue  : constant Terminal.Common.Bytes.Byte :=
                 Terminal.Common.Bytes.Byte (Interfaces.Shift_Right
                   (Interfaces.Unsigned_32 (Color), 8) and 16#FF#);
               Alpha : constant Terminal.Common.Bytes.Byte :=
                 Terminal.Common.Bytes.Byte
                   (Interfaces.Unsigned_32 (Color) and 16#FF#);
            begin
               for Pixel in 0 .. Object.Pixel_Width * Object.Pixel_Height - 1 loop
                  Canvas (Pixel * 4 + 1) := Red;
                  Canvas (Pixel * 4 + 2) := Green;
                  Canvas (Pixel * 4 + 3) := Blue;
                  Canvas (Pixel * 4 + 4) := Alpha;
               end loop;
            end;
         end if;
      else
         Copy_Frame_To_RGBA
           (Object, Positive (Target_Number), Canvas.all, Base_Valid);
         if not Base_Valid then
            Release_Local;
            return;
         end if;
      end if;

      if not Prepare_Theme_Frame_Operation
        (R,
         Object,
         Header,
         Data,
         Positive (Target_Number),
         New_Frame,
         Prepared_Operation)
      then
         Fail (Terminal.Core.Kitty_ENOSPC);
         Release_Local;
         return;
      end if;

      declare
         Current_Total : constant Natural :=
           Object.Decoded_Length
           + Object.Indexed_Length
           + Object.Frame_Bytes
           + Object.Theme_Operation_Bytes;
         Removed : constant Natural :=
           (if Target_Number = 1
            then Object.Decoded_Length + Object.Indexed_Length
            elsif New_Frame then 0
            else Existing.Length);
         Operation_Length : constant Natural :=
           (if Prepared_Operation = null then 0
            else Prepared_Operation.Length);
         Added : Natural;
      begin
         if Operation_Length > Natural'Last - Canvas_Length then
            Fail (Terminal.Core.Kitty_ENOSPC);
            Release_Local;
            return;
         end if;
         Added := Canvas_Length + Operation_Length;
         if Added > R.Graphics_Limits.Per_Image_Bytes
           or else Current_Total - Removed >
             R.Graphics_Limits.Per_Image_Bytes - Added
           or else Added > R.Graphics_Limits.Image_Bytes
         then
            Fail (Terminal.Core.Kitty_ENOSPC);
            Release_Local;
            return;
         end if;
         while R.Image_Object_Bytes - Removed >
           R.Graphics_Limits.Image_Bytes - Added
         loop
            if not Evict_One_Unplaced_Image
              (R, Event.Stream_ID, Header.Kitty_ID)
            then
               Fail (Terminal.Core.Kitty_ENOSPC);
               Release_Local;
               return;
            end if;
         end loop;
      end;

      for Y in 0 .. Data.Pixel_Height - 1 loop
         for X in 0 .. Data.Pixel_Width - 1 loop
            declare
               Source_Index : constant Positive :=
                 Positive
                   (Y * Data.Decoded_Row_Stride_Bytes
                    + X
                      * (if Data.Raw_Format = 8 then 1
                         elsif Data.Raw_Format = 16 then 2
                         else Data.Raw_Format / 8)
                    + 1);
               Target_Index : constant Positive :=
                 Positive
                   (((Header.Kitty_Source_Y + Y) * Object.Pixel_Width
                     + Header.Kitty_Source_X + X) * 4 + 1);
               Palette_Color : constant RM.Pixel_Color :=
                 (if Data.Raw_Format in 8 | 16
                  then Kitty_Indexed_Color
                    (R, Natural (Data.Bytes (Source_Index)))
                  else (0.0, 0.0, 0.0, 1.0));
               SR : constant Natural :=
                 (if Data.Raw_Format in 8 | 16
                  then Natural (Color_Byte (Palette_Color.R))
                  else Natural (Data.Bytes (Source_Index)));
               SG : constant Natural :=
                 (if Data.Raw_Format in 8 | 16
                  then Natural (Color_Byte (Palette_Color.G))
                  else Natural (Data.Bytes (Source_Index + 1)));
               SB : constant Natural :=
                 (if Data.Raw_Format in 8 | 16
                  then Natural (Color_Byte (Palette_Color.B))
                  else Natural (Data.Bytes (Source_Index + 2)));
               SA : constant Natural :=
                 (if Data.Raw_Format = 16
                  then Natural (Data.Bytes (Source_Index + 1))
                  elsif Data.Raw_Format = 32
                  then Natural (Data.Bytes (Source_Index + 3))
                  else 255);
            begin
               if Header.Kitty_Composition_Mode = 1 or else SA = 255 then
                  Canvas (Target_Index) := Terminal.Common.Bytes.Byte (SR);
                  Canvas (Target_Index + 1) := Terminal.Common.Bytes.Byte (SG);
                  Canvas (Target_Index + 2) := Terminal.Common.Bytes.Byte (SB);
                  Canvas (Target_Index + 3) := Terminal.Common.Bytes.Byte (SA);
               elsif SA > 0 then
                  declare
                     DR : constant Natural := Natural (Canvas (Target_Index));
                     DG : constant Natural := Natural (Canvas (Target_Index + 1));
                     DB : constant Natural := Natural (Canvas (Target_Index + 2));
                     DA : constant Natural := Natural (Canvas (Target_Index + 3));
                     OA : constant Natural := SA + (DA * (255 - SA) + 127) / 255;
                     Denom : constant Natural := Natural'Max (1, OA * 255);
                  begin
                     Canvas (Target_Index) := Terminal.Common.Bytes.Byte
                       ((SR * SA * 255 + DR * DA * (255 - SA) + Denom / 2)
                        / Denom);
                     Canvas (Target_Index + 1) := Terminal.Common.Bytes.Byte
                       ((SG * SA * 255 + DG * DA * (255 - SA) + Denom / 2)
                        / Denom);
                     Canvas (Target_Index + 2) := Terminal.Common.Bytes.Byte
                       ((SB * SA * 255 + DB * DA * (255 - SA) + Denom / 2)
                        / Denom);
                     Canvas (Target_Index + 3) := Terminal.Common.Bytes.Byte (OA);
                  end;
               end if;
            end;
         end loop;
      end loop;

      if Target_Number = 1 then
         declare
            Old_Length : constant Natural := Object.Decoded_Length;
            Old_Indexed_Length : constant Natural := Object.Indexed_Length;
         begin
            if Object.Frame_Bytes >
              R.Graphics_Limits.Per_Image_Bytes - Canvas_Length
            then
               Fail (Terminal.Core.Kitty_ENOMEM);
               Release_Local;
               return;
            end if;
            if Canvas_Length > Old_Length + Old_Indexed_Length
              and then R.Image_Object_Bytes >
                R.Graphics_Limits.Image_Bytes
                  - (Canvas_Length - Old_Length - Old_Indexed_Length)
            then
               Fail (Terminal.Core.Kitty_ENOMEM);
               Release_Local;
               return;
            end if;
            Free_Image_Data (Object.Bytes);
            if Object.Indexed_Bytes /= null then
               Free_Image_Data (Object.Indexed_Bytes);
            end if;
            Object.Bytes := Canvas;
            Canvas_Owned := False;
            Object.Raw_Format := 32;
            Object.Decoded_Row_Stride_Bytes := Object.Pixel_Width * 4;
            Object.Decoded_Length := Canvas_Length;
            Object.Indexed_Format := 0;
            Object.Indexed_Length := 0;
            Object.Indexed_Row_Stride_Bytes := 0;
            Object.Indexed_Bytes := null;
            R.Image_Object_Bytes :=
              R.Image_Object_Bytes
              - Old_Length
              - Old_Indexed_Length
              + Canvas_Length;
            if Header.Kitty_Frame_Gap /= 0 then
               Object.Root_Gap_MS := Header.Kitty_Frame_Gap;
            end if;
         end;
      elsif New_Frame then
         declare
            Frame : constant Image_Frame_Access := new Image_Frame'
              (Number     => Positive (Target_Number),
               Gap_MS     =>
                 (if Header.Kitty_Frame_Gap = 0
                  then 40
                  else Header.Kitty_Frame_Gap),
               Usage_Hint =>
                 (if Header.Kitty_Usage_Hint = 1
                    or else
                      (Header.Kitty_Base_Frame > 0
                       and then
                         (if Header.Kitty_Base_Frame = 1
                          then Object.Usage_Hint = 1
                          else Find_Image_Frame
                            (Object, Positive (Header.Kitty_Base_Frame)).
                              Usage_Hint = 1))
                  then 1
                  else Header.Kitty_Usage_Hint),
               Bytes      => Canvas,
               Length     => Canvas_Length,
               Next       => null);
            Tail : Image_Frame_Access := Object.Frames;
         begin
            Canvas_Owned := False;
            if Tail = null then
               Object.Frames := Frame;
            else
               while Tail.Next /= null loop
                  Tail := Tail.Next;
               end loop;
               Tail.Next := Frame;
            end if;
            Object.Frame_Count := Object.Frame_Count + 1;
            R.Animation_Frame_Count := R.Animation_Frame_Count + 1;
            Object.Frame_Bytes := Object.Frame_Bytes + Canvas_Length;
            R.Image_Object_Bytes := R.Image_Object_Bytes + Canvas_Length;
         end;
      else
         Free_Image_Data (Existing.Bytes);
         Existing.Bytes := Canvas;
         Canvas_Owned := False;
         if Header.Kitty_Frame_Gap /= 0 then
            Existing.Gap_MS := Header.Kitty_Frame_Gap;
         end if;
         if Header.Kitty_Usage_Hint = 1 then
            Existing.Usage_Hint := 1;
         end if;
      end if;
      Append_Theme_Operation (R, Object, Prepared_Operation);
      Touch_Image_Object (R, Object);
      R.Last_Animation_Result := Terminal.Core.Kitty_OK;
      Release_Local;
   exception
      when Storage_Error =>
         if Compressed_Bytes /= null and then Compressed_Bytes_Owned then
            Free_Image_Data (Compressed_Bytes);
         end if;
         Release_Local;
         R.Last_Animation_Result := Terminal.Core.Kitty_ENOMEM;
      when others =>
         if Compressed_Bytes /= null and then Compressed_Bytes_Owned then
            Free_Image_Data (Compressed_Bytes);
         end if;
         Release_Local;
         R.Last_Animation_Result := Terminal.Core.Kitty_EINVAL;
   end Apply_Animation_Frame;

   procedure Delete_Animation_Frames
     (R      : in out Renderer;
      Object : Image_Object_Access)
   is
      Current : Image_Frame_Access :=
        (if Object = null then null else Object.Frames);
   begin
      if Object = null then
         return;
      end if;
      R.Image_Object_Bytes := R.Image_Object_Bytes - Object.Frame_Bytes;
      R.Animation_Frame_Count :=
        R.Animation_Frame_Count - (Object.Frame_Count - 1);
      while Current /= null loop
         declare
            Next : constant Image_Frame_Access := Current.Next;
         begin
            Free_Image_Data (Current.Bytes);
            Free_Image_Frame (Current);
            Current := Next;
         end;
      end loop;
      Object.Frames := null;
      Object.Frame_Count := 1;
      Object.Frame_Bytes := 0;
      --  Keep only palette-sensitive history that contributed to the
      --  surviving root.  Archived non-root references replay through
      --  temporary canvases, so later frames may safely reuse their numbers.
      Archive_Root_Theme_Operations (R, Object);
      Object.Root_Gap_MS := 0;
      Object.Current_Frame := 1;
      Object.Playback := Animation_Stopped;
      Object.Loop_Count := 1;
      Object.Loops_Completed := 0;
      Object.Deadline_Set := False;
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
      R.Last_Animation_Result := Terminal.Core.Kitty_EINVAL;
      if Object = null then
         R.Last_Animation_Result := Terminal.Core.Kitty_ENOENT;
         return;
      elsif Header.Kitty_Animation_State > 3 then
         return;
      elsif Header.Kitty_Frame_Number > 0
        and then not Animation_Frame_Exists
          (Object, Header.Kitty_Frame_Number)
      then
         R.Last_Animation_Result := Terminal.Core.Kitty_ENOENT;
         return;
      elsif Header.Kitty_Base_Frame > 0
        and then not Animation_Frame_Exists
          (Object, Header.Kitty_Base_Frame)
      then
         R.Last_Animation_Result := Terminal.Core.Kitty_ENOENT;
         return;
      end if;

      if Header.Kitty_Frame_Number > 0
        and then Header.Kitty_Frame_Gap /= 0
      then
         if not Set_Animation_Frame_Gap
           (Object,
            Positive (Header.Kitty_Frame_Number),
            Header.Kitty_Frame_Gap)
         then
            R.Last_Animation_Result := Terminal.Core.Kitty_ENOENT;
            return;
         end if;
      end if;
      if Header.Kitty_Base_Frame > 0 then
         Object.Current_Frame := Positive (Header.Kitty_Base_Frame);
         Object.Deadline_Set := False;
      end if;
      if Header.Kitty_Loop_Count > 0 then
         Object.Loop_Count := Positive (Header.Kitty_Loop_Count);
         Object.Loops_Completed := 0;
      end if;
      case Header.Kitty_Animation_State is
         when 1 =>
            Object.Playback := Animation_Stopped;
            Object.Loops_Completed := 0;
            Object.Deadline_Set := False;
         when 2 =>
            Object.Playback := Animation_Loading;
            Object.Deadline_Set := False;
         when 3 =>
            Object.Playback := Animation_Running;
            Object.Deadline_Set := False;
         when others =>
            null;
      end case;
      Touch_Image_Object (R, Object);
      R.Last_Animation_Result := Terminal.Core.Kitty_OK;
   exception
      when others =>
         R.Last_Animation_Result := Terminal.Core.Kitty_EINVAL;
   end Apply_Animation_Control;

   procedure Apply_Animation_Composition
     (R      : in out Renderer;
      Event  : Terminal.Core.Graphics_Event;
      Header : Terminal.App.Graphics.Graphics_Header)
   is
      Object : constant Image_Object_Access :=
        Find_Image_Object (R, Event.Stream_ID, Header.Kitty_ID);
      Source : RM.Image_Data_Access := null;
      Target : RM.Image_Data_Access := null;
      Source_Valid : Boolean := False;
      Target_Valid : Boolean := False;
      Width  : Natural := Header.Kitty_Source_Width;
      Height : Natural := Header.Kitty_Source_Height;
      Source_Frame : Positive := 1;
      Target_Frame : Positive := 1;
      Prepared_Operation : Theme_Operation_Access := null;

      procedure Release_Local is
      begin
         Free_Image_Data (Source);
         Free_Image_Data (Target);
         if Prepared_Operation /= null then
            Free_Theme_Operation (Prepared_Operation);
         end if;
      end Release_Local;
   begin
      R.Last_Animation_Result := Terminal.Core.Kitty_EINVAL;
      if Object = null then
         R.Last_Animation_Result := Terminal.Core.Kitty_ENOENT;
         return;
      elsif Header.Kitty_Base_Frame = 0
        or else Header.Kitty_Frame_Number = 0
        or else not Animation_Frame_Exists
          (Object, Header.Kitty_Base_Frame)
        or else not Animation_Frame_Exists
          (Object, Header.Kitty_Frame_Number)
      then
         R.Last_Animation_Result := Terminal.Core.Kitty_ENOENT;
         return;
      elsif Object.Pixel_Width = 0
        or else Object.Pixel_Height = 0
        or else Object.Pixel_Width > Natural'Last / Object.Pixel_Height
        or else Object.Pixel_Width * Object.Pixel_Height > Natural'Last / 4
        or else Header.Kitty_Composition_Mode > 1
      then
         return;
      end if;
      Source_Frame := Positive (Header.Kitty_Base_Frame);
      Target_Frame := Positive (Header.Kitty_Frame_Number);
      if Width = 0 then
         Width := Object.Pixel_Width;
      end if;
      if Height = 0 then
         Height := Object.Pixel_Height;
      end if;
      if Width = 0 or else Height = 0
        or else Header.Kitty_Cell_X > Object.Pixel_Width
        or else Header.Kitty_Cell_Y > Object.Pixel_Height
        or else Header.Kitty_Source_X > Object.Pixel_Width
        or else Header.Kitty_Source_Y > Object.Pixel_Height
        or else Width > Object.Pixel_Width - Header.Kitty_Cell_X
        or else Height > Object.Pixel_Height - Header.Kitty_Cell_Y
        or else Width > Object.Pixel_Width - Header.Kitty_Source_X
        or else Height > Object.Pixel_Height - Header.Kitty_Source_Y
      then
         return;
      end if;
      if Source_Frame = Target_Frame
        and then Header.Kitty_Cell_X < Header.Kitty_Source_X + Width
        and then Header.Kitty_Source_X < Header.Kitty_Cell_X + Width
        and then Header.Kitty_Cell_Y < Header.Kitty_Source_Y + Height
        and then Header.Kitty_Source_Y < Header.Kitty_Cell_Y + Height
      then
         return;
      end if;

      Source := new Terminal.Common.Bytes.Byte_Array
        (1 .. Object.Pixel_Width * Object.Pixel_Height * 4);
      Target := new Terminal.Common.Bytes.Byte_Array
        (1 .. Object.Pixel_Width * Object.Pixel_Height * 4);
      Copy_Frame_To_RGBA (Object, Source_Frame, Source.all, Source_Valid);
      Copy_Frame_To_RGBA (Object, Target_Frame, Target.all, Target_Valid);
      if not Source_Valid or else not Target_Valid then
         Release_Local;
         return;
      end if;
      if not Prepare_Theme_Composition_Operation
        (R,
         Object,
         Header,
         Source_Frame,
         Target_Frame,
         Width,
         Height,
         Prepared_Operation)
      then
         Release_Local;
         R.Last_Animation_Result := Terminal.Core.Kitty_ENOSPC;
         return;
      end if;

      for Y in 0 .. Height - 1 loop
         for X in 0 .. Width - 1 loop
            declare
               SI : constant Positive := Positive
                 (((Header.Kitty_Cell_Y + Y) * Object.Pixel_Width
                   + Header.Kitty_Cell_X + X) * 4 + 1);
               DI : constant Positive := Positive
                 (((Header.Kitty_Source_Y + Y) * Object.Pixel_Width
                   + Header.Kitty_Source_X + X) * 4 + 1);
               SA : constant Natural := Natural (Source (SI + 3));
            begin
               if Header.Kitty_Composition_Mode = 1 or else SA = 255 then
                  Target (DI .. DI + 3) := Source (SI .. SI + 3);
               elsif SA > 0 then
                  declare
                     DA : constant Natural := Natural (Target (DI + 3));
                     OA : constant Natural :=
                       SA + (DA * (255 - SA) + 127) / 255;
                     Denom : constant Natural := Natural'Max (1, OA * 255);
                  begin
                     for C in 0 .. 2 loop
                        Target (DI + C) := Terminal.Common.Bytes.Byte
                          ((Natural (Source (SI + C)) * SA * 255
                            + Natural (Target (DI + C)) * DA * (255 - SA)
                            + Denom / 2) / Denom);
                     end loop;
                     Target (DI + 3) := Terminal.Common.Bytes.Byte (OA);
                  end;
               end if;
            end;
         end loop;
      end loop;

      if Target_Frame = 1 then
         declare
            Old_Length : constant Natural := Object.Decoded_Length;
            Old_Indexed_Length : constant Natural := Object.Indexed_Length;
            New_Length : constant Natural := Target'Length;
         begin
            if New_Length > Old_Length + Old_Indexed_Length
              and then R.Image_Object_Bytes >
                R.Graphics_Limits.Image_Bytes - Natural'Min
                  (New_Length - Old_Length - Old_Indexed_Length,
                   R.Graphics_Limits.Image_Bytes)
            then
               Release_Local;
               R.Last_Animation_Result := Terminal.Core.Kitty_ENOSPC;
               return;
            end if;
            Free_Image_Data (Object.Bytes);
            if Object.Indexed_Bytes /= null then
               Free_Image_Data (Object.Indexed_Bytes);
            end if;
            Object.Bytes := Target;
            Target := null;
            Object.Raw_Format := 32;
            Object.Decoded_Length := New_Length;
            Object.Decoded_Row_Stride_Bytes := Object.Pixel_Width * 4;
            Object.Indexed_Format := 0;
            Object.Indexed_Length := 0;
            Object.Indexed_Row_Stride_Bytes := 0;
            Object.Indexed_Bytes := null;
            R.Image_Object_Bytes :=
              R.Image_Object_Bytes
              - Old_Length
              - Old_Indexed_Length
              + New_Length;
            if Source_Frame = 1 then
               null;
            elsif Find_Image_Frame (Object, Source_Frame).Usage_Hint = 1 then
               Object.Usage_Hint := 1;
            end if;
         end;
      else
         declare
            Frame : constant Image_Frame_Access :=
              Find_Image_Frame (Object, Target_Frame);
         begin
            Free_Image_Data (Frame.Bytes);
            Frame.Bytes := Target;
            Target := null;
            Frame.Length := Object.Pixel_Width * Object.Pixel_Height * 4;
            if Frame.Usage_Hint = 1
              or else
                (if Source_Frame = 1
                 then Object.Usage_Hint = 1
                 else Find_Image_Frame (Object, Source_Frame).Usage_Hint = 1)
            then
               Frame.Usage_Hint := 1;
            end if;
         end;
      end if;
      Append_Theme_Operation (R, Object, Prepared_Operation);
      Touch_Image_Object (R, Object);
      Release_Local;
      R.Last_Animation_Result := Terminal.Core.Kitty_OK;
   exception
      when Storage_Error =>
         Release_Local;
         R.Last_Animation_Result := Terminal.Core.Kitty_ENOSPC;
      when others =>
         Release_Local;
         R.Last_Animation_Result := Terminal.Core.Kitty_EINVAL;
   end Apply_Animation_Composition;

   function Display_Frame_Bytes
     (Object : Image_Object_Access) return RM.Image_Data_Access is
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
      Object : Image_Object_Access := R.Image_Objects;
   begin
      while Object /= null loop
         if Object.Playback /= Animation_Stopped
           and then Object.Frame_Count > 1
         then
            if not Object.Deadline_Set then
               declare
                  Gap : constant Integer :=
                    Animation_Frame_Gap (Object, Object.Current_Frame);
               begin
                  Object.Next_Frame_At :=
                    Now + Ada.Real_Time.Milliseconds (Integer'Max (0, Gap));
                  Object.Deadline_Set := True;
               end;
            end if;
            --  Bound work even if thousands of gapless frames were supplied.
            for Step in 1 .. Object.Frame_Count loop
               exit when Object.Playback = Animation_Stopped
                 or else not Object.Deadline_Set
                 or else Now < Object.Next_Frame_At;
               if Object.Current_Frame < Object.Frame_Count then
                  Object.Current_Frame := Object.Current_Frame + 1;
               elsif Object.Playback = Animation_Loading then
                  Object.Deadline_Set := False;
                  exit;
               elsif Object.Loop_Count /= 1
                 and then Object.Loops_Completed + 1 >= Object.Loop_Count
               then
                  Object.Playback := Animation_Stopped;
                  Object.Loops_Completed := 0;
                  Object.Deadline_Set := False;
                  exit;
               else
                  Object.Current_Frame := 1;
                  Object.Loops_Completed := Object.Loops_Completed + 1;
               end if;
               Touch_Image_Object (R, Object);
               R.Animation_Advance_Count := R.Animation_Advance_Count + 1;
               declare
                  Gap : constant Integer :=
                    Animation_Frame_Gap (Object, Object.Current_Frame);
               begin
                  Object.Next_Frame_At :=
                    Object.Next_Frame_At
                    + Ada.Real_Time.Milliseconds (Integer'Max (0, Gap));
               end;
            end loop;
         end if;
         Object := Object.Next;
      end loop;
   end Advance_Animations;

   function Validate_Kitty_Query_Data
     (Header : Terminal.App.Graphics.Graphics_Header;
      Text   : String;
      Policy : Terminal.App.Graphics_Transport.Access_Policy;
      Maximum_Bytes : Positive;
      Local_Source : Boolean := False)
      return Terminal.Core.Kitty_Graphics_Result_Code
   is
      Data : Terminal.App.Graphics.Graphics_Data_Preview :=
        Terminal.App.Graphics.Data_Preview_Text
          (Terminal.Core.Kitty_Graphics, Text);
      Row_Failed : Boolean := False;
      Row_Count : Natural := 0;

      function Data_Start return Natural is
      begin
         for I in Text'Range loop
            if Text (I) = ';' then
               return (if I < Text'Last then I + 1 else 0);
            end if;
         end loop;
         return 0;
      end Data_Start;

      function One_Chunk (Index : Positive) return String is
         First : constant Natural := Data_Start;
      begin
         if Index /= 1 or else First = 0 then
            return "";
         end if;
         return Text (First .. Text'Last);
      end One_Chunk;

      procedure Discard_Row
        (Y        : Natural;
         Row      : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean)
      is
         pragma Unreferenced (Y);
      begin
         if Row'Length = 0
           or else Row_Count = Natural'Last
           or else Row_Count + 1 > RM.Max_Image_Decoded_Data_Length
         then
            Row_Failed := True;
            Continue := False;
         else
            Row_Count := Row_Count + 1;
            Continue := True;
         end if;
      end Discard_Row;

      function Encode_Base64
        (Bytes  : Terminal.App.Graphics_Transport.Byte_Array_Access;
         Length : Natural) return String
      is
         Alphabet : constant String :=
           "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
         Result : String (1 .. ((Length + 2) / 3) * 4);
         Source : Natural := 1;
         Target : Natural := 1;
         A, B, C : Natural;
      begin
         if Bytes = null or else Length = 0 or else Length > Bytes'Length then
            return "";
         end if;
         while Source <= Length loop
            A := Natural (Bytes (Source));
            B := (if Source + 1 <= Length then Natural (Bytes (Source + 1)) else 0);
            C := (if Source + 2 <= Length then Natural (Bytes (Source + 2)) else 0);
            Result (Target) := Alphabet (A / 4 + 1);
            Result (Target + 1) := Alphabet ((A mod 4) * 16 + B / 16 + 1);
            Result (Target + 2) :=
              (if Source + 1 <= Length
               then Alphabet ((B mod 16) * 4 + C / 64 + 1)
               else '=');
            Result (Target + 3) :=
              (if Source + 2 <= Length
               then Alphabet (C mod 64 + 1)
               else '=');
            Source := Source + 3;
            Target := Target + 4;
         end loop;
         return Result;
      end Encode_Base64;
   begin
      if Header.Kitty_Transmission in 'f' | 't' | 's' then
         declare
            First : constant Natural := Data_Start;
            Loaded : Terminal.App.Graphics_Transport.Byte_Array_Access := null;
            Loaded_Length : Natural := 0;
            Load_Status : Terminal.App.Graphics_Transport.Load_Status;
         begin
            if First = 0
              or else not Header.Kitty_Data_Size_Valid
              or else not Header.Kitty_Data_Offset_Valid
              or else Header.Kitty_More_Specified
            then
               Terminal.App.Graphics.Release (Data);
               return Terminal.Core.Kitty_EINVAL;
            end if;
            Terminal.App.Graphics_Transport.Load
              (Medium           => Header.Kitty_Transmission,
               Encoded_Location => Text (First .. Text'Last),
               Offset           => Header.Kitty_Data_Offset,
               Size             => Header.Kitty_Data_Size,
               Size_Specified   => Header.Kitty_Data_Size_Specified,
               Policy           => Policy,
               Maximum_Bytes    => Maximum_Bytes,
               Bytes            => Loaded,
               Length           => Loaded_Length,
               Status           => Load_Status);
            if Load_Status /= Terminal.App.Graphics_Transport.Load_Ok then
               Terminal.App.Graphics.Release (Data);
               return
                 (if Load_Status in
                       Terminal.App.Graphics_Transport.Load_Too_Large
                       | Terminal.App.Graphics_Transport.Load_Allocation_Failed
                  then Terminal.Core.Kitty_ENOMEM
                  else Terminal.Core.Kitty_EBADF);
            end if;
            declare
               Encoded : constant String := Encode_Base64 (Loaded, Loaded_Length);
               Synthetic : constant String :=
                 Text (Text'First .. First - 1) & Encoded;
               Direct_Header : Terminal.App.Graphics.Graphics_Header := Header;
               Outcome : Terminal.Core.Kitty_Graphics_Result_Code;
            begin
               Terminal.App.Graphics_Transport.Release (Loaded);
               Direct_Header.Kitty_Transmission := 'd';
               Direct_Header.Kitty_Transmission_Specified := True;
               --  For local media S is the compressed byte range to read. It
               --  is not the inflated PNG size required for a direct
               --  compressed PNG transmission, so let the bounded inflater
               --  discover that size.
               if Direct_Header.Kitty_Format = 100
                 and then Direct_Header.Kitty_Compression = 'z'
               then
                  Direct_Header.Kitty_Data_Size := 0;
                  Direct_Header.Kitty_Data_Size_Specified := False;
               end if;
               Outcome :=
                 Validate_Kitty_Query_Data
                   (Direct_Header,
                    Synthetic,
                    Policy,
                    Maximum_Bytes,
                    Local_Source => True);
               Terminal.App.Graphics.Release (Data);
               return Outcome;
            end;
         end;
      end if;

      if not Header.Has_Data
        or else Header.Kitty_Format not in 8 | 16 | 24 | 32 | 100
        or else Header.Kitty_Compression not in ASCII.NUL | 'z'
      then
         Terminal.App.Graphics.Release (Data);
         return Terminal.Core.Kitty_EINVAL;
      end if;
      if Header.Kitty_Compression = 'z' then
         if Header.Kitty_Format in 8 | 16 | 24 | 32 then
            Terminal.App.Graphics.Decode_Base64_Zlib_Raw_Chunk_Rows
              (1,
               One_Chunk'Access,
               Header.Kitty_Format,
               Header.Pixel_Width,
               Header.Pixel_Height,
               Discard_Row'Access,
               Data);
         elsif Header.Kitty_Data_Size > 0 or else Local_Source then
            declare
               Encoded_Length : Natural := 0;
            begin
               Terminal.App.Graphics.Decode_Base64_Zlib_PNG_Chunk_Rows
                 (1,
                  One_Chunk'Access,
                  Header.Kitty_Data_Size,
                  Encoded_Length,
                  Discard_Row'Access,
                  Data);
            end;
         end if;
      end if;
      declare
         Valid : constant Boolean :=
           not Row_Failed
           and then Data.Decode_Complete
           and then Data.Raw_Format in 8 | 16 | 24 | 32
           and then Data.Pixel_Width > 0
           and then Data.Pixel_Height > 0;
      begin
         Terminal.App.Graphics.Release (Data);
         return
           (if Valid then Terminal.Core.Kitty_OK
            else Terminal.Core.Kitty_EINVAL);
      end;
   exception
      when Storage_Error =>
         Terminal.App.Graphics.Release (Data);
         return Terminal.Core.Kitty_ENOMEM;
      when others =>
         Terminal.App.Graphics.Release (Data);
         return Terminal.Core.Kitty_EINVAL;
   end Validate_Kitty_Query_Data;

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
     (Source         : RM.Image_Data_Access;
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

   function Image_Preview_Source
     (Decoded        : RM.Image_Data_Access;
      Preview_Length : Natural;
      Preview_Bytes  : Terminal.Common.Bytes.Byte_Array)
      return RM.Image_Data_Access
   is
      Result : RM.Image_Data_Access;
   begin
      if Decoded /= null then
         return Decoded;
      elsif Preview_Length = 0 then
         return null;
      end if;

      Result := new Terminal.Common.Bytes.Byte_Array (1 .. Preview_Length);
      Result.all := Preview_Bytes
        (Preview_Bytes'First .. Preview_Bytes'First + Preview_Length - 1);
      return Result;
   end Image_Preview_Source;

   function Copy_Text_Bytes (Text : String) return RM.Image_Data_Access is
      Result : RM.Image_Data_Access;
   begin
      if Text'Length = 0 then
         return null;
      end if;

      Result := new Terminal.Common.Bytes.Byte_Array (1 .. Text'Length);
      for I in Text'Range loop
         Result (I - Text'First + 1) :=
           Terminal.Common.Bytes.Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   exception
      when Storage_Error =>
         return null;
   end Copy_Text_Bytes;

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
      Resolved_Image_Number : Terminal.Core.Graphics_ID := 0)
   is
      function Resolved_Header
        (Value : Terminal.App.Graphics.Graphics_Header)
         return Terminal.App.Graphics.Graphics_Header
      is
         Result : Terminal.App.Graphics.Graphics_Header := Value;
      begin
         if Resolved_Image_ID > 0 then
            Result.Kitty_ID := Resolved_Image_ID;
         end if;
         if Resolved_Image_Number > 0 then
            Result.Kitty_Image_Number := Resolved_Image_Number;
         end if;
         return Result;
      end Resolved_Header;

      function Event_Text
        (Item : Terminal.Core.Graphics_Event) return String is
      begin
         return Complete_Event_Text (R, Item);
      end Event_Text;

      function Kitty_Data_Start (Text : String) return Natural is
      begin
         for I in Text'Range loop
            if Text (I) = ';' then
               return (if I < Text'Last then I + 1 else 0);
            end if;
         end loop;
         return 0;
      end Kitty_Data_Start;

      function Emit_Raw_Kitty
        (Item       : Terminal.Core.Graphics_Event;
         Header     : Terminal.App.Graphics.Graphics_Header;
         Image_Text : String) return Boolean
      is
            Raw_Format : constant Natural := Header.Raw_Format;
            Bytes_Per_Pixel : constant Natural :=
              (if Raw_Format = 8 then 1
               elsif Raw_Format = 16 then 2
               elsif Raw_Format = 24 then 3
               elsif Raw_Format = 32 then 4
               else 0);
            Row_Stride : constant Natural :=
              (if Bytes_Per_Pixel > 0
                 and then Header.Pixel_Width <= Natural'Last / Bytes_Per_Pixel
               then Header.Pixel_Width * Bytes_Per_Pixel
               else 0);
            Expected_Length : constant Natural :=
              Image_Buffer_Extent
                (Raw_Format,
                 Header.Pixel_Width,
                 Header.Pixel_Height,
                 Row_Stride);
         First_Data : constant Natural := Kitty_Data_Start (Image_Text);
         X : constant Float :=
           Float (Origin_X (R) + (Item.Col - 1) * R.CW);
         Y : constant Float :=
           Float (Origin_Y (R) + (Item.Row - 1) * R.CH);
         Encoded_Length : Natural := 0;
         Data : Terminal.App.Graphics.Graphics_Data_Preview;
         Image_Bytes : RM.Image_Data_Access := null;
         Image_Bytes_Owned : Boolean := False;
         Indexed_Bytes : RM.Image_Data_Access := null;
         Indexed_Bytes_Owned : Boolean := False;
         Render_Format : Natural := Raw_Format;
         Render_Length : Natural := Expected_Length;
         Render_Stride : Natural := Row_Stride;
         Encoded_Source : RM.Image_Data_Access := null;
         Encoded_Source_Owned : Boolean := False;
         Borrowed_From_Object : Boolean := False;
         Store_Decoded : constant Boolean :=
           Header.Kitty_ID > 0
           or else Header.Kitty_Action = 'T'
           or else Header.Kitty_Compression = 'z'
           or else Raw_Format in 8 | 16;
         Row_Copy_Failed : Boolean := False;
         Preview_Length : Natural := 0;
         Preview_Bytes : Terminal.Common.Bytes.Byte_Array
           (1 .. RM.Max_Image_Decoded_Preview_Length) := (others => 0);
         procedure Capture_Raw_Row
           (Row_Y : Natural;
            Row : Terminal.Common.Bytes.Byte_Array;
            Continue : in out Boolean)
         is
         begin
            if Store_Decoded then
               Capture_Image_Row
                 (Data,
                  Image_Bytes,
                  Image_Bytes_Owned,
                  Row_Y,
                  Row,
                  R.Graphics_Limits.Per_Image_Bytes,
                  R.Graphics_Limits.Pixel_Dimension,
                  Continue);
            else
               Capture_Image_Preview_Row
                 (Preview_Length, Preview_Bytes, Row_Y, Row, Continue);
            end if;
            if not Continue then
               Row_Copy_Failed := True;
            end if;
         end Capture_Raw_Row;

         procedure Release_Local is
         begin
            Terminal.App.Graphics.Release (Data);
            if Image_Bytes /= null and then Image_Bytes_Owned then
               Free_Image_Data (Image_Bytes);
            end if;
            if Indexed_Bytes /= null and then Indexed_Bytes_Owned then
               Free_Image_Data (Indexed_Bytes);
            end if;
            if Encoded_Source /= null and then Encoded_Source_Owned then
               Free_Image_Data (Encoded_Source);
            end if;
            Image_Bytes := null;
            Image_Bytes_Owned := False;
            Indexed_Bytes := null;
            Indexed_Bytes_Owned := False;
            Encoded_Source := null;
            Encoded_Source_Owned := False;
         end Release_Local;
      begin
         if not Header.Recognized
           or else not Header.Has_Data
           or else Bytes_Per_Pixel = 0
           or else Header.Pixel_Width = 0
           or else Header.Pixel_Height = 0
           or else Expected_Length = 0
           or else Expected_Length > RM.Max_Image_Decoded_Data_Length
           or else First_Data = 0
           or else R.Image_Count >= R.Images'Length
           or else Item.Payload_Length = 0
           or else Image_Text'Length /= Item.Payload_Length
           or else Header.Kitty_Compression not in ASCII.NUL | 'z'
         then
            return False;
         end if;

         Encoded_Length := Image_Text'Last - First_Data + 1;
         if Header.Kitty_Compression = 'z' then
            declare
               function Single_Chunk (Index : Positive) return String is
                 (if Index = 1
                  then Image_Text (First_Data .. Image_Text'Last)
                  else "");
            begin
               Terminal.App.Graphics.Decode_Base64_Zlib_Raw_Chunk_Rows
                 (1,
                  Single_Chunk'Access,
                  Raw_Format,
                  Header.Pixel_Width,
                  Header.Pixel_Height,
                  Capture_Raw_Row'Access,
                  Data);
            end;
         else
            Terminal.App.Graphics.Decode_Base64_Raw_Rows
              (Image_Text (First_Data .. Image_Text'Last),
               Raw_Format,
               Header.Pixel_Width,
               Header.Pixel_Height,
               Capture_Raw_Row'Access,
               Data);
         end if;

         if Row_Copy_Failed
           or else Data.Decoded_Length /= Expected_Length
           or else (Store_Decoded
                    and then not Image_Buffer_Ready (Data, Image_Bytes))
         then
            Release_Local;
            return False;
         end if;

         if Raw_Format in 8 | 16 then
            if Header.Pixel_Width > Natural'Last / Header.Pixel_Height
              or else Header.Pixel_Width * Header.Pixel_Height > Natural'Last / 4
              or else Header.Pixel_Width * Header.Pixel_Height * 4 >
                R.Graphics_Limits.Per_Image_Bytes
            then
               Release_Local;
               return False;
            end if;
            Indexed_Bytes := Image_Bytes;
            Indexed_Bytes_Owned := Image_Bytes_Owned;
            Image_Bytes :=
              new Terminal.Common.Bytes.Byte_Array
                (1 .. Header.Pixel_Width * Header.Pixel_Height * 4);
            Image_Bytes_Owned := True;
            if not Expand_Kitty_Indexed
              (R,
               Raw_Format,
               Header.Pixel_Width,
               Header.Pixel_Height,
               Indexed_Bytes,
               Image_Bytes)
            then
               Release_Local;
               return False;
            end if;
            Render_Format := 32;
            Render_Length := Header.Pixel_Width * Header.Pixel_Height * 4;
            Render_Stride := Header.Pixel_Width * 4;
         end if;

         if Header.Kitty_ID > 0 or else Header.Kitty_Action = 'T' then
            declare
               Stored_Bytes : RM.Image_Data_Access;
            begin
               Take_Image_Object
                 (R              => R,
                  Stream_ID      => Item.Stream_ID,
                  ID             => Header.Kitty_ID,
                  Image_Number   => Header.Kitty_Image_Number,
                  Usage_Hint     => Header.Kitty_Usage_Hint,
                  Protocol       => RM.Image_Kitty,
                  Raw_Format     => Render_Format,
                  Pixel_Width    => Header.Pixel_Width,
                  Pixel_Height   => Header.Pixel_Height,
                  Decoded_Length => Render_Length,
                  Decoded_Row_Stride_Bytes =>
                    Render_Stride,
                  Bytes          => Image_Bytes,
                  Stored_Bytes   => Stored_Bytes,
                  Additional_Bytes =>
                    (if Raw_Format in 8 | 16 then Data.Decoded_Length else 0));
               if Stored_Bytes /= null then
                  Image_Bytes := Stored_Bytes;
                  Image_Bytes_Owned := False;
                  Borrowed_From_Object := True;
                  if Raw_Format in 8 | 16 then
                     declare
                        Object : constant Image_Object_Access :=
                          Find_Image_Object_By_Storage_Order
                            (R, Item.Stream_ID, R.Last_Stored_Image_Order);
                     begin
                        if Object = null then
                           Release_Local;
                           return False;
                        end if;
                        Object.Indexed_Format := Raw_Format;
                        Object.Indexed_Length := Data.Decoded_Length;
                        Object.Indexed_Row_Stride_Bytes :=
                          Data.Decoded_Row_Stride_Bytes;
                        Object.Indexed_Bytes := Indexed_Bytes;
                        Indexed_Bytes := null;
                        Indexed_Bytes_Owned := False;
                     end;
                  end if;
               end if;
            end;
         end if;

         if Header.Kitty_ID = 0
           and then Header.Kitty_Compression = ASCII.NUL
           and then Raw_Format not in 8 | 16
           and then not Borrowed_From_Object
         then
            Encoded_Source :=
              Copy_Text_Bytes (Image_Text (First_Data .. Image_Text'Last));
            Encoded_Source_Owned := Encoded_Source /= null;
            if Encoded_Source = null then
               Release_Local;
               return False;
            end if;
         end if;

         declare
            Geometry : constant Placement_Geometry :=
              Resolve_Placement_Geometry
                (R, Header.Pixel_Width, Header.Pixel_Height, Header);
            Available_Width : constant Natural :=
              (if Header.Kitty_Source_X < Header.Pixel_Width
               then Header.Pixel_Width - Header.Kitty_Source_X
               else 0);
            Available_Height : constant Natural :=
              (if Header.Kitty_Source_Y < Header.Pixel_Height
               then Header.Pixel_Height - Header.Kitty_Source_Y
               else 0);
            Source_Width : constant Natural :=
              (if Header.Kitty_Source_Width = 0
               then Available_Width
               else Natural'Min
                 (Header.Kitty_Source_Width, Available_Width));
            Source_Height : constant Natural :=
              (if Header.Kitty_Source_Height = 0
               then Available_Height
               else Natural'Min
                 (Header.Kitty_Source_Height, Available_Height));
            Source_Kind : constant RM.Image_Decoded_Source_Kind :=
              (if Header.Kitty_ID = 0
                 and then Header.Kitty_Compression = ASCII.NUL
                 and then Raw_Format not in 8 | 16
                 and then not Borrowed_From_Object
               then RM.Image_Decoded_Source_Raw_Base64
               else RM.Image_Decoded_Source_Buffer);
         begin
            if Header.Kitty_Action = 'T' and then not Geometry.Valid then
               Release_Local;
               return False;
            end if;
            if Store_Decoded then
               Copy_Image_Preview
                 (Image_Bytes, Render_Length, Preview_Length, Preview_Bytes);
            end if;

            R.Image_Count := R.Image_Count + 1;
            R.Images (R.Image_Count) :=
              (X              => X
                 + Float (Header.Kitty_Cell_X + Geometry.Draw_Offset_X),
               Y              => Y
                 + Float (Header.Kitty_Cell_Y + Geometry.Draw_Offset_Y),
               Width          =>
                 (if Geometry.Valid
                  then Float (Geometry.Draw_Width)
                  else Float (R.CW * Header.Placeholder_Cols)),
               Height         =>
                 (if Geometry.Valid
                  then Float (Geometry.Draw_Height)
                  else Float (R.CH * Header.Placeholder_Rows)),
               Protocol       => RM.Image_Kitty,
               Placeholder    => False,
               Raw_Format     => Render_Format,
               Pixel_Width    => Header.Pixel_Width,
               Pixel_Height   => Header.Pixel_Height,
               Payload_Length => Item.Payload_Length,
               Staging_Byte_Length => 0,
               Payload_Preview_Complete => True,
               Encoded_Preview_Length => Encoded_Length,
               Decoded_Byte_Length => Render_Length,
               Decoded_Row_Stride_Bytes =>
                 Render_Stride,
               Decoded_Source => Source_Kind,
               Decoded_Bytes => Image_Bytes,
               Decoded_Bytes_Owned =>
                 Image_Bytes /= null and then not Borrowed_From_Object,
               Encoded_Source_Bytes => Encoded_Source,
               Encoded_Source_Bytes_Owned => Encoded_Source_Owned,
               Encoded_Source_Length => Encoded_Length,
               Decoded_Preview_Length => Preview_Length,
               Decoded_Preview_Bytes =>
                 Image_Preview_Source
                   (Image_Bytes, Preview_Length, Preview_Bytes),
               Decoded_Preview_Bytes_Owned =>
                 Image_Bytes = null and then Preview_Length > 0,
               Preview_Decode_Complete => True,
               Decode_Status =>
                 Terminal.App.Graphics.Image_Decode_Status
                   (Data.Decode_Status),
               U0             => Float (Header.Kitty_Source_X)
                 / Float (Header.Pixel_Width),
               V0             => Float (Header.Kitty_Source_Y)
                 / Float (Header.Pixel_Height),
               U1             => Float (Header.Kitty_Source_X + Source_Width)
                 / Float (Header.Pixel_Width),
               V1             => Float (Header.Kitty_Source_Y + Source_Height)
                 / Float (Header.Pixel_Height),
               Image_ID       => Interfaces.Unsigned_32 (Header.Kitty_ID),
               Content_Serial =>
                 (if R.Last_Stored_Image_Content_Serial /= 0
                  then R.Last_Stored_Image_Content_Serial
                  else Interfaces.Unsigned_64 (Item.Sequence)),
               Z_Index        => Header.Kitty_Z_Index,
               Tint           => Graphics_Tint (Terminal.Core.Kitty_Graphics));
         end;
         Encoded_Source_Owned := False;
         if Indexed_Bytes /= null and then Indexed_Bytes_Owned then
            Free_Image_Data (Indexed_Bytes);
            Indexed_Bytes := null;
            Indexed_Bytes_Owned := False;
         end if;
         return True;
      exception
         when Storage_Error =>
            Release_Local;
            return False;
      end Emit_Raw_Kitty;


      function Emit_Image_Object
        (Item   : Terminal.Core.Graphics_Event;
         Header : Terminal.App.Graphics.Graphics_Header) return Boolean
      is
         Object : constant Image_Object_Access :=
           Find_Image_Object (R, Item.Stream_ID, Header.Kitty_ID);
         X : constant Float :=
           Float (Origin_X (R) + (Item.Col - 1) * R.CW);
         Y : constant Float :=
           Float (Origin_Y (R) + (Item.Row - 1) * R.CH);
         Preview_Length : Natural := 0;
         Preview_Bytes : Terminal.Common.Bytes.Byte_Array
           (1 .. RM.Max_Image_Decoded_Preview_Length) := (others => 0);
         Frame_Bytes : constant RM.Image_Data_Access :=
           Display_Frame_Bytes (Object);
         Frame_Format : constant Natural := Display_Frame_Format (Object);
         Frame_Length : constant Natural := Display_Frame_Length (Object);
         Frame_Stride : constant Natural := Display_Frame_Stride (Object);
      begin
         if Object = null
           or else Frame_Bytes = null
           or else R.Image_Count >= R.Images'Length
         then
            return False;
         end if;

         Copy_Image_Preview
           (Frame_Bytes, Frame_Length, Preview_Length, Preview_Bytes);

         R.Image_Count := R.Image_Count + 1;
         R.Images (R.Image_Count) :=
           (X              => X,
            Y              => Y,
            Width          =>
              Float (R.CW * Header.Placeholder_Cols),
            Height         =>
              Float (R.CH * Header.Placeholder_Rows),
            Protocol       => Object.Protocol,
            Placeholder    => False,
            Raw_Format     => Frame_Format,
            Pixel_Width    => Object.Pixel_Width,
            Pixel_Height   => Object.Pixel_Height,
            Payload_Length => Item.Payload_Length,
            Staging_Byte_Length => 0,
            Payload_Preview_Complete => True,
            Encoded_Preview_Length => 0,
            Decoded_Byte_Length => Frame_Length,
            Decoded_Row_Stride_Bytes => Frame_Stride,
            Decoded_Source => RM.Image_Decoded_Source_Buffer,
            Decoded_Bytes => Frame_Bytes,
            Decoded_Bytes_Owned => False,
            Encoded_Source_Bytes => null,
            Encoded_Source_Bytes_Owned => False,
            Encoded_Source_Length => 0,
            Decoded_Preview_Length => Preview_Length,
            Decoded_Preview_Bytes => Frame_Bytes,
            Decoded_Preview_Bytes_Owned => False,
            Preview_Decode_Complete => True,
            Decode_Status => RM.Image_Decode_Ok,
            U0             => 0.0,
            V0             => 0.0,
            U1             => 1.0,
            V1             => 1.0,
            Image_ID       => Interfaces.Unsigned_32 (Header.Kitty_ID),
            Content_Serial => Object.Content_Serial,
            Z_Index        => Header.Kitty_Z_Index,
            Tint           => Graphics_Tint (Item.Protocol));

         return True;
      end Emit_Image_Object;

      function Emit_PNG_Rows
        (Item       : Terminal.Core.Graphics_Event;
         Header     : Terminal.App.Graphics.Graphics_Header;
         Image_Text : String;
         Allow_Unknown_Compressed_Size : Boolean := False) return Boolean
      is
         From : Natural := 0;
         X : constant Float :=
           Float (Origin_X (R) + (Item.Col - 1) * R.CW);
         Y : constant Float :=
           Float (Origin_Y (R) + (Item.Row - 1) * R.CH);
         Encoded_Length : Natural := 0;
         PNG_Length : Natural := 0;
         Data : Terminal.App.Graphics.Graphics_Data_Preview :=
           (Header_Recognized => Header.Recognized,
            Has_Data          => Header.Has_Data,
            Raw_Format        => 0,
            Pixel_Width       => 0,
            Pixel_Height      => 0,
            others            => <>);
         Image_Bytes : RM.Image_Data_Access := null;
         Image_Bytes_Owned : Boolean := False;
         Media : Terminal.App.Image_Media.Decoded_Image;
         Media_Used : Boolean := False;
         Encoded_Source : RM.Image_Data_Access := null;
         Encoded_Source_Owned : Boolean := False;
         Borrowed_From_Object : Boolean := False;
         Store_Decoded : constant Boolean :=
           Item.Protocol = Terminal.Core.ITerm2_Graphics
           or else
             (Item.Protocol = Terminal.Core.Kitty_Graphics
              and then
                (Header.Kitty_ID > 0
                 or else Header.Kitty_Action = 'T'
                 or else Header.Kitty_Compression = 'z'));
         Row_Copy_Failed : Boolean := False;
         Preview_Length : Natural := 0;
         Preview_Bytes : Terminal.Common.Bytes.Byte_Array
           (1 .. RM.Max_Image_Decoded_Preview_Length) := (others => 0);

         function PNG_Text (Index : Positive) return String is
         begin
            if Index = 1 and then From /= 0 then
               return Image_Text (From .. Image_Text'Last);
            else
               return "";
            end if;
         end PNG_Text;

         procedure Release_Local is
         begin
            if Image_Bytes /= null and then Image_Bytes_Owned then
               Free_Image_Data (Image_Bytes);
               Image_Bytes := null;
               Image_Bytes_Owned := False;
            end if;
            if Encoded_Source /= null and then Encoded_Source_Owned then
               Free_Image_Data (Encoded_Source);
               Encoded_Source := null;
               Encoded_Source_Owned := False;
            end if;
            Terminal.App.Image_Media.Release (Media);
            Terminal.App.Graphics.Release (Data);
         end Release_Local;

         procedure Capture_PNG_Row
           (Row_Y : Natural;
            Row   : Terminal.Common.Bytes.Byte_Array;
            Continue : in out Boolean)
         is
         begin
            if Store_Decoded then
               Capture_Image_Row
                 (Data,
                  Image_Bytes,
                  Image_Bytes_Owned,
                  Row_Y,
                  Row,
                  R.Graphics_Limits.Per_Image_Bytes,
                  R.Graphics_Limits.Pixel_Dimension,
                  Continue);
            else
               Capture_Image_Preview_Row
                 (Preview_Length, Preview_Bytes, Row_Y, Row, Continue);
            end if;
            if not Continue then
               Row_Copy_Failed := True;
            end if;
         end Capture_PNG_Row;
      begin
         if not Header.Recognized
           or else not Header.Has_Data
           or else R.Image_Count >= R.Images'Length
           or else Item.Payload_Length = 0
           or else Image_Text'Length /= Item.Payload_Length
         then
            return False;
         elsif Item.Protocol = Terminal.Core.Kitty_Graphics then
            if Header.Kitty_Format /= 100
              or else Header.Kitty_Compression not in ASCII.NUL | 'z'
              or else
                (Header.Kitty_Compression = 'z'
                 and then Header.Kitty_Data_Size = 0
                 and then not Allow_Unknown_Compressed_Size)
            then
               return False;
            end if;
            From := Kitty_Data_Start (Image_Text);
         elsif Item.Protocol = Terminal.Core.ITerm2_Graphics then
            for I in Image_Text'Range loop
               if Image_Text (I) = ':' then
                  From := (if I < Image_Text'Last then I + 1 else 0);
                  exit;
               end if;
            end loop;
         else
            return False;
         end if;

         if From = 0 then
            return False;
         end if;

         Encoded_Length := Image_Text'Last - From + 1;
         if Encoded_Length = 0 then
            return False;
         end if;

         if Item.Protocol = Terminal.Core.ITerm2_Graphics then
            --  Attempt PNG through the bounded row decoder first.  JPEG uses
            --  a header-bounded decoder so neither format allocates its full
            --  decoded image before the configured limits are checked.
            Terminal.App.Graphics.Decode_Base64_PNG_Chunk_Rows
              (1,
               PNG_Text'Access,
               Encoded_Length,
               PNG_Length,
               Capture_PNG_Row'Access,
               Data);
            if Data.Decode_Status =
              Terminal.App.Graphics.Decode_Unsupported_Format
            then
               Terminal.App.Graphics.Release (Data);
               Data := Terminal.App.Graphics.JPEG_Data_Preview_Text
                 (Image_Text,
                  R.Graphics_Limits.Per_Image_Bytes,
                  R.Graphics_Limits.Pixel_Dimension);
               if Data.Bytes /= null then
                  Image_Bytes := Data.Bytes;
                  Data.Bytes := null;
                  Image_Bytes_Owned := True;
                  Copy_Image_Preview
                    (Image_Bytes,
                     Data.Decoded_Length,
                     Preview_Length,
                     Preview_Bytes);
               end if;
            end if;
            if Data.Decode_Status =
                Terminal.App.Graphics.Decode_Unsupported_Format
              and then Terminal.App.Image_Media.Available
            then
               declare
                  Blob : RM.Image_Data_Access := null;
                  Blob_Length : Natural := 0;
                  Base64_Status : Terminal.App.Graphics.Data_Decode_Status;
                  Media_Status : Terminal.App.Image_Media.Decode_Status;
               begin
                  Terminal.App.Graphics.Decode_Base64_Data
                    (Image_Text (From .. Image_Text'Last),
                     R.Graphics_Limits.Per_Image_Bytes,
                     Blob,
                     Blob_Length,
                     Base64_Status);
                  if Base64_Status = Terminal.App.Graphics.Decode_Ok
                    and then Blob /= null
                  then
                     Terminal.App.Image_Media.Decode
                       (Blob.all,
                        Blob_Length,
                        R.Graphics_Limits.Per_Image_Bytes,
                        R.Graphics_Limits.Pixel_Dimension,
                        Media,
                        Media_Status);
                     R.Last_Media_Diagnostic := Media.Diagnostic;
                     R.Last_Media_Peak_Working_Bytes :=
                       Media.Peak_Working_Bytes;
                     Free_Image_Data (Blob);
                     if Media_Status = Terminal.App.Image_Media.Decode_Ok
                       and then Media.Bytes /= null
                       and then Media.Frame_Count > 0
                       and then Media.Frame_Count - 1 <=
                         R.Graphics_Limits.Animation_Frames
                            - R.Animation_Frame_Count
                     then
                        Terminal.App.Graphics.Release (Data);
                        Data :=
                          (Header_Recognized => True,
                           Has_Data => True,
                           Encoded_Length => Encoded_Length,
                           Raw_Format => 32,
                           Pixel_Width => Media.Pixel_Width,
                           Pixel_Height => Media.Pixel_Height,
                           Decoded_Length => Media.Frame_Bytes,
                           Decoded_Row_Stride_Bytes => Media.Pixel_Width * 4,
                           Decode_Complete => True,
                           Decode_Status => Terminal.App.Graphics.Decode_Ok,
                           Bytes => null);
                        if Media.Frame_Count = 1 then
                           --  Static native media already has the exact buffer
                           --  layout the image store owns. Transfer it instead
                           --  of briefly retaining a second full RGBA copy.
                           Image_Bytes := Media.Bytes;
                           Media.Bytes := null;
                        else
                           Image_Bytes :=
                             new Terminal.Common.Bytes.Byte_Array
                               (1 .. Media.Frame_Bytes);
                           Image_Bytes.all :=
                             Media.Bytes
                               (Media.Bytes'First
                                .. Media.Bytes'First
                                  + Media.Frame_Bytes - 1);
                        end if;
                        Image_Bytes_Owned := True;
                        Media_Used := True;
                        Copy_Image_Preview
                          (Image_Bytes,
                           Media.Frame_Bytes,
                           Preview_Length,
                           Preview_Bytes);
                     end if;
                  elsif Blob /= null then
                     Free_Image_Data (Blob);
                  end if;
               end;
            end if;
         elsif Header.Kitty_Compression = 'z' then
            Terminal.App.Graphics.Decode_Base64_Zlib_PNG_Chunk_Rows
              (1,
               PNG_Text'Access,
               Header.Kitty_Data_Size,
               Encoded_Length,
               Capture_PNG_Row'Access,
               Data);
            PNG_Length := Header.Kitty_Data_Size;
         else
            Terminal.App.Graphics.Decode_Base64_PNG_Chunk_Rows
              (1,
               PNG_Text'Access,
               Encoded_Length,
               PNG_Length,
               Capture_PNG_Row'Access,
               Data);
         end if;

         if Row_Copy_Failed
           or else not Data.Decode_Complete
           or else Data.Decoded_Length = 0
           or else Data.Decoded_Row_Stride_Bytes = 0
           or else
             (Item.Protocol = Terminal.Core.ITerm2_Graphics
              and then not Image_Buffer_Ready (Data, Image_Bytes))
           or else
             (Store_Decoded
              and then not Image_Buffer_Ready (Data, Image_Bytes))
         then
            Release_Local;
            return False;
         end if;

         if Item.Protocol = Terminal.Core.Kitty_Graphics
           and then
             (Header.Kitty_ID > 0 or else Header.Kitty_Action = 'T')
         then
            declare
               Stored_Bytes : RM.Image_Data_Access;
            begin
               Take_Image_Object
                 (R              => R,
                  Stream_ID      => Item.Stream_ID,
                  ID             => Header.Kitty_ID,
                  Image_Number   => Header.Kitty_Image_Number,
                  Usage_Hint     => Header.Kitty_Usage_Hint,
                  Protocol       => RM.Image_Kitty,
                  Raw_Format     => Data.Raw_Format,
                  Pixel_Width    => Data.Pixel_Width,
                  Pixel_Height   => Data.Pixel_Height,
                  Decoded_Length => Data.Decoded_Length,
                  Decoded_Row_Stride_Bytes => Data.Decoded_Row_Stride_Bytes,
                  Bytes          => Image_Bytes,
                  Stored_Bytes   => Stored_Bytes);
               if Stored_Bytes /= null then
                  Image_Bytes := Stored_Bytes;
                  Image_Bytes_Owned := False;
                  Borrowed_From_Object := True;
               end if;
            end;
         elsif Item.Protocol = Terminal.Core.ITerm2_Graphics then
            declare
               Stored_Bytes : RM.Image_Data_Access := null;
            begin
               Take_Image_Object
                 (R              => R,
                  Stream_ID      => Item.Stream_ID,
                  ID             => 0,
                  Image_Number   => 0,
                  Usage_Hint     => 0,
                  Protocol       => RM.Image_ITerm2,
                  Raw_Format     => Data.Raw_Format,
                  Pixel_Width    => Data.Pixel_Width,
                  Pixel_Height   => Data.Pixel_Height,
                  Decoded_Length => Data.Decoded_Length,
                  Decoded_Row_Stride_Bytes =>
                    Data.Decoded_Row_Stride_Bytes,
                  Bytes          => Image_Bytes,
                  Stored_Bytes   => Stored_Bytes,
                  Additional_Bytes =>
                    (if Media_Used
                     then Media.Total_Bytes - Media.Frame_Bytes
                     else 0));
               if Stored_Bytes = null then
                  Release_Local;
                  return False;
               end if;
               Image_Bytes := Stored_Bytes;
               Image_Bytes_Owned := False;
               Borrowed_From_Object := True;
               if Media_Used and then Media.Frame_Count > 1 then
                  declare
                     Object : constant Image_Object_Access :=
                       Find_Image_Object_By_Storage_Order
                         (R, Item.Stream_ID, R.Last_Stored_Image_Order);
                     Tail : Image_Frame_Access := null;
                  begin
                     if Object = null then
                        Release_Local;
                        return False;
                     end if;
                     Object.Frame_Count := Positive (Media.Frame_Count);
                     Object.Frame_Bytes := Media.Total_Bytes - Media.Frame_Bytes;
                     Object.Root_Gap_MS := Integer (Media.Delays_MS (1));
                     Object.Playback :=
                       (if Media.Loop_Count = 0
                        then Animation_Loading
                        else Animation_Running);
                     Object.Loop_Count :=
                       (if Media.Loop_Count = 0
                        then 1
                        else Positive'Max
                          (1,
                           Positive'Min
                             (Positive'Last, Media.Loop_Count)));
                     R.Animation_Frame_Count :=
                       R.Animation_Frame_Count + (Media.Frame_Count - 1);
                     for Number in 2 .. Media.Frame_Count loop
                        declare
                           Frame_Data : RM.Image_Data_Access := null;
                           First : constant Positive :=
                             Media.Bytes'First
                             + (Number - 1) * Media.Frame_Bytes;
                           Frame : Image_Frame_Access;
                        begin
                           Frame_Data :=
                             new Terminal.Common.Bytes.Byte_Array
                               (1 .. Media.Frame_Bytes);
                           Frame_Data.all :=
                             Media.Bytes (First .. First + Media.Frame_Bytes - 1);
                           Frame := new Image_Frame'
                             (Number => Number,
                              Gap_MS => Integer (Media.Delays_MS (Number)),
                              Usage_Hint => 0,
                              Bytes => Frame_Data,
                              Length => Media.Frame_Bytes,
                              Next => null);
                           Frame_Data := null;
                           if Tail = null then
                              Object.Frames := Frame;
                           else
                              Tail.Next := Frame;
                           end if;
                           Tail := Frame;
                        exception
                           when Storage_Error =>
                              if Frame_Data /= null then
                                 Free_Image_Data (Frame_Data);
                              end if;
                              raise;
                        end;
                     end loop;
                     Touch_Image_Object (R, Object);
                  exception
                     when Storage_Error =>
                        Delete_Image_Object_By_Storage_Order
                          (R, Item.Stream_ID, R.Last_Stored_Image_Order);
                        Release_Local;
                        return False;
                  end;
               end if;
            end;
         end if;

         if Item.Protocol /= Terminal.Core.Kitty_Graphics
           or else
             (Header.Kitty_ID = 0
              and then Header.Kitty_Compression = ASCII.NUL
              and then not Borrowed_From_Object)
         then
            Encoded_Source := Copy_Text_Bytes (Image_Text (From .. Image_Text'Last));
            Encoded_Source_Owned := Encoded_Source /= null;
            if Encoded_Source = null then
               Release_Local;
               return False;
            end if;

            if PNG_Length = 0 and then Data.Decode_Complete then
               PNG_Length := Data.Decoded_Length;
            end if;
         end if;

         declare
            Geometry : constant Placement_Geometry :=
              (if Item.Protocol = Terminal.Core.Kitty_Graphics
               then Resolve_Placement_Geometry
                 (R, Data.Pixel_Width, Data.Pixel_Height, Header)
               else (others => <>));
            Available_Width : constant Natural :=
              (if Header.Kitty_Source_X < Data.Pixel_Width
               then Data.Pixel_Width - Header.Kitty_Source_X
               else 0);
            Available_Height : constant Natural :=
              (if Header.Kitty_Source_Y < Data.Pixel_Height
               then Data.Pixel_Height - Header.Kitty_Source_Y
               else 0);
            Source_Width : constant Natural :=
              (if Header.Kitty_Source_Width = 0
               then Available_Width
               else Natural'Min
                 (Header.Kitty_Source_Width, Available_Width));
            Source_Height : constant Natural :=
              (if Header.Kitty_Source_Height = 0
               then Available_Height
               else Natural'Min
                 (Header.Kitty_Source_Height, Available_Height));
            Source_Kind : constant RM.Image_Decoded_Source_Kind :=
              (if Item.Protocol = Terminal.Core.ITerm2_Graphics
               then RM.Image_Decoded_Source_Buffer
               elsif Item.Protocol = Terminal.Core.Kitty_Graphics
                 and then
                   (Header.Kitty_ID > 0
                    or else Borrowed_From_Object
                    or else Header.Kitty_Compression = 'z')
               then RM.Image_Decoded_Source_Buffer
               else RM.Image_Decoded_Source_PNG_Base64);
            function Requested_ITerm2_Size
              (Specified : Boolean;
               Value     : Natural;
               Unit      : Terminal.App.Graphics.ITerm2_Size_Unit;
               Intrinsic : Natural;
               Cell_Size : Positive;
               View_Size : Natural) return Float
            is
            begin
               if not Specified
                 or else Unit = Terminal.App.Graphics.ITerm2_Auto
               then
                  return Float (Intrinsic);
               end if;
               case Unit is
                  when Terminal.App.Graphics.ITerm2_Cells =>
                     return Float (Value) * Float (Cell_Size);
                  when Terminal.App.Graphics.ITerm2_Pixels =>
                     return Float (Value);
                  when Terminal.App.Graphics.ITerm2_Percent =>
                     return Float (View_Size) * Float (Value) / 100.0;
                  when Terminal.App.Graphics.ITerm2_Auto =>
                     return Float (Intrinsic);
               end case;
            end Requested_ITerm2_Size;
            ITerm2_Box_Width : constant Float := Requested_ITerm2_Size
              (Header.ITerm2_Width_Specified,
               Header.ITerm2_Width_Value,
               Header.ITerm2_Width_Unit,
               Data.Pixel_Width,
               R.CW,
               (if R.Last_Frame_Width > Content_Margin * 2
                then R.Last_Frame_Width - Content_Margin * 2
                else R.CW));
            ITerm2_Box_Height : constant Float := Requested_ITerm2_Size
              (Header.ITerm2_Height_Specified,
               Header.ITerm2_Height_Value,
               Header.ITerm2_Height_Unit,
               Data.Pixel_Height,
               R.CH,
               (if R.Last_Frame_Height > Content_Margin * 2
                then R.Last_Frame_Height - Content_Margin * 2
                else R.CH));
            ITerm2_Scale : constant Float :=
              (if not Header.ITerm2_Preserve_Aspect_Ratio
               then 1.0
               elsif Header.ITerm2_Width_Specified
                 and then Header.ITerm2_Height_Specified
               then Float'Min
                 (ITerm2_Box_Width / Float (Data.Pixel_Width),
                  ITerm2_Box_Height / Float (Data.Pixel_Height))
               elsif Header.ITerm2_Width_Specified
               then ITerm2_Box_Width / Float (Data.Pixel_Width)
               elsif Header.ITerm2_Height_Specified
               then ITerm2_Box_Height / Float (Data.Pixel_Height)
               else 1.0);
            ITerm2_Draw_Width : constant Float := Float'Max
              (1.0,
               (if Header.ITerm2_Preserve_Aspect_Ratio
                then Float (Data.Pixel_Width) * ITerm2_Scale
                else ITerm2_Box_Width));
            ITerm2_Draw_Height : constant Float := Float'Max
              (1.0,
               (if Header.ITerm2_Preserve_Aspect_Ratio
                then Float (Data.Pixel_Height) * ITerm2_Scale
                else ITerm2_Box_Height));
         begin
            if Item.Protocol = Terminal.Core.Kitty_Graphics
              and then Header.Kitty_Action = 'T'
              and then not Geometry.Valid
            then
               Release_Local;
               return False;
            end if;
            if Store_Decoded then
               Copy_Image_Preview
                 (Image_Bytes, Data.Decoded_Length, Preview_Length, Preview_Bytes);
            end if;

            if Item.Protocol = Terminal.Core.ITerm2_Graphics
              and then not Store_Auxiliary_Placement
                (R,
                 Item,
                 RM.Image_ITerm2,
                 Positive (Float'Ceiling (ITerm2_Draw_Width)),
                 Positive (Float'Ceiling (ITerm2_Draw_Height)))
            then
               Delete_Image_Object_By_Storage_Order
                 (R, Item.Stream_ID, R.Last_Stored_Image_Order);
               Release_Local;
               return False;
            end if;

            R.Image_Count := R.Image_Count + 1;
            R.Images (R.Image_Count) :=
              (X              => X
                 + (if Geometry.Valid
                    then Float
                      (Header.Kitty_Cell_X + Geometry.Draw_Offset_X)
                    else 0.0),
               Y              => Y
                 + (if Geometry.Valid
                    then Float
                      (Header.Kitty_Cell_Y + Geometry.Draw_Offset_Y)
                    else 0.0),
               Width          =>
                 (if Geometry.Valid
                  then Float (Geometry.Draw_Width)
                  elsif Item.Protocol = Terminal.Core.ITerm2_Graphics
                  then ITerm2_Draw_Width
                  else Float (R.CW * Header.Placeholder_Cols)),
               Height         =>
                 (if Geometry.Valid
                  then Float (Geometry.Draw_Height)
                  elsif Item.Protocol = Terminal.Core.ITerm2_Graphics
                  then ITerm2_Draw_Height
                  else Float (R.CH * Header.Placeholder_Rows)),
               Protocol       => Graphics_Protocol (Item.Protocol),
               Placeholder    => False,
               Raw_Format     => Data.Raw_Format,
               Pixel_Width    => Data.Pixel_Width,
               Pixel_Height   => Data.Pixel_Height,
               Payload_Length => Item.Payload_Length,
               Staging_Byte_Length => PNG_Length,
               Payload_Preview_Complete => True,
               Encoded_Preview_Length => Encoded_Length,
               Decoded_Byte_Length => Data.Decoded_Length,
               Decoded_Row_Stride_Bytes => Data.Decoded_Row_Stride_Bytes,
               Decoded_Source => Source_Kind,
               Decoded_Bytes => Image_Bytes,
               Decoded_Bytes_Owned =>
                 Image_Bytes /= null and then not Borrowed_From_Object,
               Encoded_Source_Bytes => Encoded_Source,
               Encoded_Source_Bytes_Owned => Encoded_Source_Owned,
               Encoded_Source_Length => Encoded_Length,
               Decoded_Preview_Length => Preview_Length,
               Decoded_Preview_Bytes =>
                 Image_Preview_Source
                   (Image_Bytes, Preview_Length, Preview_Bytes),
               Decoded_Preview_Bytes_Owned =>
                 Image_Bytes = null and then Preview_Length > 0,
               Preview_Decode_Complete => True,
               Decode_Status => RM.Image_Decode_Ok,
               U0             =>
                 (if Item.Protocol = Terminal.Core.Kitty_Graphics
                  then Float (Header.Kitty_Source_X)
                    / Float (Data.Pixel_Width)
                  else 0.0),
               V0             =>
                 (if Item.Protocol = Terminal.Core.Kitty_Graphics
                  then Float (Header.Kitty_Source_Y)
                    / Float (Data.Pixel_Height)
                  else 0.0),
               U1             =>
                 (if Item.Protocol = Terminal.Core.Kitty_Graphics
                  then Float (Header.Kitty_Source_X + Source_Width)
                    / Float (Data.Pixel_Width)
                  else 1.0),
               V1             =>
                 (if Item.Protocol = Terminal.Core.Kitty_Graphics
                  then Float (Header.Kitty_Source_Y + Source_Height)
                    / Float (Data.Pixel_Height)
                  else 1.0),
               Image_ID       =>
                 (if Item.Protocol = Terminal.Core.Kitty_Graphics
                  then Interfaces.Unsigned_32 (Header.Kitty_ID)
                  else 0),
               Content_Serial =>
                 (if R.Last_Stored_Image_Content_Serial /= 0
                  then R.Last_Stored_Image_Content_Serial
                  else Interfaces.Unsigned_64 (Item.Sequence)),
               Z_Index        =>
                 (if Item.Protocol = Terminal.Core.Kitty_Graphics
                  then Header.Kitty_Z_Index
                  else 0),
               Tint           => Graphics_Tint (Item.Protocol));
         end;
         Encoded_Source_Owned := False;

         Terminal.App.Image_Media.Release (Media);
         Terminal.App.Graphics.Release (Data);
         return True;
      exception
         when Storage_Error =>
            Release_Local;
            return False;
      end Emit_PNG_Rows;

      function Encode_Base64
        (Bytes  : Terminal.App.Graphics_Transport.Byte_Array_Access;
         Length : Natural) return String
      is
         Alphabet : constant String :=
           "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
         Result : String (1 .. ((Length + 2) / 3) * 4);
         Source : Natural := 1;
         Target : Natural := 1;
         A, B, C : Natural;
      begin
         if Bytes = null or else Length = 0 or else Length > Bytes'Length then
            return "";
         end if;
         while Source <= Length loop
            A := Natural (Bytes (Source));
            B := (if Source + 1 <= Length then Natural (Bytes (Source + 1)) else 0);
            C := (if Source + 2 <= Length then Natural (Bytes (Source + 2)) else 0);
            Result (Target) := Alphabet (A / 4 + 1);
            Result (Target + 1) := Alphabet ((A mod 4) * 16 + B / 16 + 1);
            Result (Target + 2) :=
              (if Source + 1 <= Length
               then Alphabet ((B mod 16) * 4 + C / 64 + 1)
               else '=');
            Result (Target + 3) :=
              (if Source + 2 <= Length
               then Alphabet (C mod 64 + 1)
               else '=');
            Source := Source + 3;
            Target := Target + 4;
         end loop;
         return Result;
      end Encode_Base64;

      function Emit_Local_Kitty
        (Item       : Terminal.Core.Graphics_Event;
         Header     : Terminal.App.Graphics.Graphics_Header;
         Image_Text : String) return Boolean
      is
         Data_First : constant Natural := Kitty_Data_Start (Image_Text);
         Loaded : Terminal.App.Graphics_Transport.Byte_Array_Access := null;
         Loaded_Length : Natural := 0;
         Load_Status : Terminal.App.Graphics_Transport.Load_Status;
      begin
         if Header.Kitty_Transmission not in 'f' | 't' | 's'
           or else Data_First = 0
           or else not Header.Kitty_Data_Size_Valid
           or else not Header.Kitty_Data_Offset_Valid
           or else Header.Kitty_More_Specified
         then
            R.Image_Transport_Failed := True;
            return False;
         end if;

         Terminal.App.Graphics_Transport.Load
           (Medium           => Header.Kitty_Transmission,
            Encoded_Location => Image_Text (Data_First .. Image_Text'Last),
            Offset           => Header.Kitty_Data_Offset,
            Size             => Header.Kitty_Data_Size,
            Size_Specified   => Header.Kitty_Data_Size_Specified,
            Policy           => R.Graphics_Access,
            Maximum_Bytes    => R.Graphics_Limits.Per_Image_Bytes,
            Bytes            => Loaded,
            Length           => Loaded_Length,
            Status           => Load_Status);
         if Load_Status /= Terminal.App.Graphics_Transport.Load_Ok then
            R.Image_Transport_Failed := True;
            if Load_Status in
              Terminal.App.Graphics_Transport.Load_Too_Large
              | Terminal.App.Graphics_Transport.Load_Allocation_Failed
            then
               R.Image_Store_Allocation_Failed := True;
            end if;
            return False;
         end if;

         declare
            Encoded : constant String := Encode_Base64 (Loaded, Loaded_Length);
            Synthetic : constant String :=
              Image_Text (Image_Text'First .. Data_First - 1) & Encoded;
            Synthetic_Event : Terminal.Core.Graphics_Event := Item;
            Synthetic_Header : Terminal.App.Graphics.Graphics_Header := Header;
            Emitted : Boolean := False;
         begin
            Terminal.App.Graphics_Transport.Release (Loaded);
            Synthetic_Event.Payload_Length := Synthetic'Length;
            Synthetic_Header.Kitty_Transmission := 'd';
            Synthetic_Header.Kitty_Transmission_Specified := True;
            if Synthetic_Header.Kitty_Format = 100
              and then Synthetic_Header.Kitty_Compression = 'z'
            then
               --  S selected the compressed byte range in the local object;
               --  it does not describe the inflated PNG stream.
               Synthetic_Header.Kitty_Data_Size := 0;
               Synthetic_Header.Kitty_Data_Size_Specified := False;
            end if;
            if Synthetic_Header.Kitty_Action = 'f' then
               Apply_Animation_Frame
                 (R,
                  Synthetic_Event,
                  Synthetic_Header,
                  Synthetic,
                  Allow_Unknown_Compressed_PNG_Size => True);
               Emitted := R.Last_Animation_Result = Terminal.Core.Kitty_OK;
            elsif Synthetic_Header.Kitty_Format in 8 | 16 | 24 | 32 then
               Emitted :=
                 Emit_Raw_Kitty (Synthetic_Event, Synthetic_Header, Synthetic);
            elsif Synthetic_Header.Kitty_Format = 100 then
               Emitted :=
                 Emit_PNG_Rows
                   (Synthetic_Event,
                    Synthetic_Header,
                    Synthetic,
                    Allow_Unknown_Compressed_Size => True);
            end if;
            return Emitted;
         end;
      exception
         when Storage_Error =>
            Terminal.App.Graphics_Transport.Release (Loaded);
            R.Image_Store_Allocation_Failed := True;
            return False;
         when others =>
            Terminal.App.Graphics_Transport.Release (Loaded);
            R.Image_Transport_Failed := True;
            return False;
      end Emit_Local_Kitty;

      function Emit_Sixel_Rows
        (Item       : Terminal.Core.Graphics_Event;
         Header     : Terminal.App.Graphics.Graphics_Header;
         Image_Text : String) return Boolean
      is
         X : constant Float :=
           Float (Origin_X (R) + (Item.Col - 1) * R.CW);
         Y : constant Float :=
           Float (Origin_Y (R) + (Item.Row - 1) * R.CH);
         Data : Terminal.App.Graphics.Graphics_Data_Preview :=
           (Header_Recognized => Header.Recognized,
            Has_Data          => Header.Has_Data,
            Raw_Format        => Header.Raw_Format,
            Pixel_Width       => Header.Pixel_Width,
            Pixel_Height      => Header.Pixel_Height,
            others            => <>);
         Image_Bytes : RM.Image_Data_Access := null;
         Image_Bytes_Owned : Boolean := False;
         Encoded_Source : RM.Image_Data_Access := null;
         Encoded_Source_Owned : Boolean := False;
         Row_Copy_Failed : Boolean := False;
         Preview_Length : Natural := 0;
         Preview_Bytes : Terminal.Common.Bytes.Byte_Array
           (1 .. RM.Max_Image_Decoded_Preview_Length) := (others => 0);
         Private_Palette : Terminal.App.Graphics.Sixel_Palette_State :=
           Terminal.App.Graphics.Default_Sixel_Palette;
         Shared_Palette : Sixel_Palette_Entry_Access := null;

         function Sixel_Encoded_Length return Natural is
         begin
            for I in Image_Text'Range loop
               if Image_Text (I) = 'q' then
                  return (if I < Image_Text'Last then Image_Text'Last - I else 0);
               end if;
            end loop;
            return Image_Text'Length;
         end Sixel_Encoded_Length;

         procedure Release_Local is
         begin
            if Image_Bytes /= null and then Image_Bytes_Owned then
               Free_Image_Data (Image_Bytes);
               Image_Bytes := null;
               Image_Bytes_Owned := False;
            end if;
            if Encoded_Source /= null and then Encoded_Source_Owned then
               Free_Image_Data (Encoded_Source);
               Encoded_Source := null;
               Encoded_Source_Owned := False;
            end if;
            Terminal.App.Graphics.Release (Data);
         end Release_Local;

         procedure Capture_Sixel_Row
           (Row_Y : Natural;
            Row   : Terminal.Common.Bytes.Byte_Array;
            Continue : in out Boolean)
         is
         begin
            Capture_Image_Row
              (Data,
               Image_Bytes,
               Image_Bytes_Owned,
               Row_Y,
               Row,
               R.Graphics_Limits.Per_Image_Bytes,
               R.Graphics_Limits.Pixel_Dimension,
               Continue);
            if Continue then
               Capture_Image_Preview_Row
                 (Preview_Length, Preview_Bytes, Row_Y, Row, Continue);
            end if;
            if not Continue then
               Row_Copy_Failed := True;
            end if;
         end Capture_Sixel_Row;
      begin
         if not Header.Recognized
           or else not Header.Has_Data
           or else Header.Raw_Format /= 32
           or else Header.Pixel_Width = 0
           or else Header.Pixel_Height = 0
           or else R.Image_Count >= R.Images'Length
           or else Item.Payload_Length = 0
           or else Image_Text'Length /= Item.Payload_Length
         then
            return False;
         end if;

         if Item.Sixel_Private_Colors then
            Terminal.App.Graphics.Decode_Sixel_Rows
              (Image_Text,
               Capture_Sixel_Row'Access,
               Private_Palette,
               Reset_Palette => False,
               Result => Data,
               Maximum_Decoded_Bytes => R.Graphics_Limits.Per_Image_Bytes,
               Maximum_Pixel_Dimension => R.Graphics_Limits.Pixel_Dimension);
         else
            Shared_Palette := Sixel_Palette_For (R, Item.Stream_ID);
            if Shared_Palette = null then
               return False;
            end if;
            Terminal.App.Graphics.Decode_Sixel_Rows
              (Image_Text,
               Capture_Sixel_Row'Access,
               Shared_Palette.Palette,
               Reset_Palette => False,
               Result => Data,
               Maximum_Decoded_Bytes => R.Graphics_Limits.Per_Image_Bytes,
               Maximum_Pixel_Dimension => R.Graphics_Limits.Pixel_Dimension);
         end if;
         if Row_Copy_Failed
           or else not Data.Decode_Complete
           or else Data.Decoded_Length = 0
           or else Data.Decoded_Row_Stride_Bytes = 0
           or else not Image_Buffer_Ready (Data, Image_Bytes)
         then
            Release_Local;
            return False;
         end if;

         declare
            Stored_Bytes : RM.Image_Data_Access := null;
            Stored_Order : Interfaces.Unsigned_64;
         begin
            Take_Image_Object
              (R              => R,
               Stream_ID      => Item.Stream_ID,
               ID             => 0,
               Image_Number   => 0,
               Usage_Hint     => 0,
               Protocol       => RM.Image_Sixel,
               Raw_Format     => Data.Raw_Format,
               Pixel_Width    => Data.Pixel_Width,
               Pixel_Height   => Data.Pixel_Height,
               Decoded_Length => Data.Decoded_Length,
               Decoded_Row_Stride_Bytes => Data.Decoded_Row_Stride_Bytes,
               Bytes          => Image_Bytes,
               Stored_Bytes   => Stored_Bytes);
            Stored_Order := R.Last_Stored_Image_Order;
            if Stored_Bytes = null
              or else not Store_Auxiliary_Placement
                (R,
                 Item,
                 RM.Image_Sixel,
                 Positive (Data.Pixel_Width),
                 Positive (Data.Pixel_Height))
            then
               if Stored_Order /= 0 then
                  Delete_Image_Object_By_Storage_Order
                    (R, Item.Stream_ID, Stored_Order);
               end if;
               Release_Local;
               return False;
            end if;
            Image_Bytes := Stored_Bytes;
            Image_Bytes_Owned := False;
         end;

         Encoded_Source := Copy_Text_Bytes (Image_Text);
         Encoded_Source_Owned := Encoded_Source /= null;
         if Encoded_Source = null then
            Release_Local;
            return False;
         end if;

         declare
         begin
            R.Image_Count := R.Image_Count + 1;
            R.Images (R.Image_Count) :=
              (X              => X,
               Y              => Y,
               Width          =>
                 Float (Data.Pixel_Width),
               Height         =>
                 Float (Data.Pixel_Height),
               Protocol       => RM.Image_Sixel,
               Placeholder    => False,
               Raw_Format     => Data.Raw_Format,
               Pixel_Width    => Data.Pixel_Width,
               Pixel_Height   => Data.Pixel_Height,
               Payload_Length => Item.Payload_Length,
               Staging_Byte_Length => 0,
               Payload_Preview_Complete => True,
               Encoded_Preview_Length => Sixel_Encoded_Length,
               Decoded_Byte_Length => Data.Decoded_Length,
               Decoded_Row_Stride_Bytes => Data.Decoded_Row_Stride_Bytes,
               Decoded_Source => RM.Image_Decoded_Source_Buffer,
               Decoded_Bytes => Image_Bytes,
               Decoded_Bytes_Owned => Image_Bytes_Owned,
               Encoded_Source_Bytes => Encoded_Source,
               Encoded_Source_Bytes_Owned => Encoded_Source_Owned,
               Encoded_Source_Length => Image_Text'Length,
               Decoded_Preview_Length => Preview_Length,
               Decoded_Preview_Bytes => Image_Bytes,
               Decoded_Preview_Bytes_Owned => False,
               Preview_Decode_Complete => True,
               Decode_Status => RM.Image_Decode_Ok,
               U0             => 0.0,
               V0             => 0.0,
               U1             => 1.0,
               V1             => 1.0,
               Image_ID       => 0,
               Content_Serial => R.Last_Stored_Image_Content_Serial,
               Z_Index        => 0,
               Tint           => Graphics_Tint (Terminal.Core.Sixel_Graphics));
         end;
         Image_Bytes_Owned := False;
         Encoded_Source_Owned := False;

         Terminal.App.Graphics.Release (Data);
         return True;
      exception
         when Storage_Error =>
            Release_Local;
            return False;
      end Emit_Sixel_Rows;

      procedure Emit_Image
        (Item       : Terminal.Core.Graphics_Event;
         Image_Text : String)
      is
         X : constant Float :=
           Float (Origin_X (R) + (Item.Col - 1) * R.CW);
         Y : constant Float :=
           Float (Origin_Y (R) + (Item.Row - 1) * R.CH);
         Data : Terminal.App.Graphics.Graphics_Data_Preview :=
           Terminal.App.Graphics.Data_Preview_Text (Item.Protocol, Image_Text);
         Header : constant Terminal.App.Graphics.Graphics_Header :=
           Terminal.App.Graphics.Header_Text (Item.Protocol, Image_Text);
         Raw_Format : constant Natural :=
           (if Data.Raw_Format > 0 then Data.Raw_Format else Header.Raw_Format);
         Pixel_Width : constant Natural :=
           (if Data.Pixel_Width > 0 then Data.Pixel_Width else Header.Pixel_Width);
         Pixel_Height : constant Natural :=
           (if Data.Pixel_Height > 0 then Data.Pixel_Height else Header.Pixel_Height);
         Payload_Complete : constant Boolean :=
           Item.Payload_Length > 0
           and then Image_Text'Length = Item.Payload_Length;
         Bytes_Per_Pixel : constant Natural :=
           (if Raw_Format = 24 then 3
            elsif Raw_Format = 32 then 4
            else 0);
         Row_Stride_Bytes : constant Natural :=
           (if Data.Decoded_Row_Stride_Bytes > 0
            then Data.Decoded_Row_Stride_Bytes
            elsif Bytes_Per_Pixel > 0
              and then Pixel_Width <= Natural'Last / Bytes_Per_Pixel
            then Pixel_Width * Bytes_Per_Pixel
            else 0);
         Expected_Decoded_Length : constant Natural :=
           Image_Buffer_Extent
             (Raw_Format, Pixel_Width, Pixel_Height, Row_Stride_Bytes);
         Raw_Texture_Ready : constant Boolean :=
           (Item.Protocol = Terminal.Core.Kitty_Graphics
            or else Item.Protocol = Terminal.Core.Sixel_Graphics
            or else Item.Protocol = Terminal.Core.ITerm2_Graphics)
           and then Pixel_Width > 0
           and then Pixel_Height > 0
           and then Bytes_Per_Pixel > 0
           and then Payload_Complete
           and then Data.Decode_Complete
           and then Expected_Decoded_Length > 0
           and then Data.Decoded_Length = Expected_Decoded_Length;
         Preview_Length : Natural := 0;
         Preview_Bytes : Terminal.Common.Bytes.Byte_Array
           (1 .. RM.Max_Image_Decoded_Preview_Length) := (others => 0);
         Image_Bytes : RM.Image_Data_Access := null;
         Image_Bytes_Owned : Boolean := False;
         Borrowed_From_Object : Boolean := False;
      begin
         if not Item.Pending
           or else Item.Protocol = Terminal.Core.No_Graphics
           or else R.Images = null
           or else R.Image_Count >= R.Images'Length
         then
            Terminal.App.Graphics.Release (Data);
            return;
         end if;

         if Data.Decoded_Length > R.Graphics_Limits.Per_Image_Bytes
           or else Data.Pixel_Width > R.Graphics_Limits.Pixel_Dimension
           or else Data.Pixel_Height > R.Graphics_Limits.Pixel_Dimension
         then
            Terminal.App.Graphics.Release (Data);
            R.Image_Store_Allocation_Failed := True;
            return;
         end if;

         Copy_Image_Preview
           (Data.Bytes, Data.Decoded_Length, Preview_Length, Preview_Bytes);

         if Data.Decoded_Length > 0
           and then Data.Decode_Complete
           and then Data.Bytes /= null
         then
            Image_Bytes := Data.Bytes;
            Data.Bytes := null;
         end if;

         if Item.Protocol = Terminal.Core.Kitty_Graphics
           and then
             (Header.Kitty_ID > 0 or else Header.Kitty_Action = 'T')
           and then Raw_Texture_Ready
           and then Image_Bytes /= null
         then
            declare
               Stored_Bytes : RM.Image_Data_Access;
            begin
               Take_Image_Object
                 (R              => R,
                  Stream_ID      => Item.Stream_ID,
                  ID             => Header.Kitty_ID,
                  Image_Number   => Header.Kitty_Image_Number,
                  Usage_Hint     => Header.Kitty_Usage_Hint,
                  Protocol       => Graphics_Protocol (Item.Protocol),
                  Raw_Format     => Raw_Format,
                  Pixel_Width    => Pixel_Width,
                  Pixel_Height   => Pixel_Height,
                  Decoded_Length => Data.Decoded_Length,
                  Decoded_Row_Stride_Bytes => Row_Stride_Bytes,
                  Bytes          => Image_Bytes,
                  Stored_Bytes   => Stored_Bytes);
               if Stored_Bytes /= null then
                  Image_Bytes := Stored_Bytes;
                  Borrowed_From_Object := True;
               end if;
            end;
         end if;
         Image_Bytes_Owned := Image_Bytes /= null
           and then not Borrowed_From_Object;

         R.Image_Count := R.Image_Count + 1;
         R.Images (R.Image_Count) :=
           (X              => X,
            Y              => Y,
            Width          =>
              Float (R.CW * Header.Placeholder_Cols),
            Height         =>
              Float (R.CH * Header.Placeholder_Rows),
            Protocol       => Graphics_Protocol (Item.Protocol),
            Placeholder    => not Raw_Texture_Ready,
            Raw_Format     => Raw_Format,
            Pixel_Width    => Pixel_Width,
            Pixel_Height   => Pixel_Height,
            Payload_Length => Item.Payload_Length,
            Staging_Byte_Length => 0,
            Payload_Preview_Complete => Payload_Complete,
            Encoded_Preview_Length => Data.Encoded_Length,
            Decoded_Byte_Length => Data.Decoded_Length,
            Decoded_Row_Stride_Bytes => Row_Stride_Bytes,
            Decoded_Source =>
              (if Raw_Texture_Ready
               then RM.Image_Decoded_Source_Buffer
               else RM.Image_Decoded_Source_None),
            Decoded_Bytes => Image_Bytes,
            Decoded_Bytes_Owned => Image_Bytes_Owned,
            Encoded_Source_Bytes => null,
            Encoded_Source_Bytes_Owned => False,
            Encoded_Source_Length => 0,
            Decoded_Preview_Length => Preview_Length,
            Decoded_Preview_Bytes =>
              Image_Preview_Source
                (Image_Bytes, Preview_Length, Preview_Bytes),
            Decoded_Preview_Bytes_Owned =>
              Image_Bytes = null and then Preview_Length > 0,
            Preview_Decode_Complete => Data.Decode_Complete,
            Decode_Status =>
              Terminal.App.Graphics.Image_Decode_Status (Data.Decode_Status),
            U0             => 0.0,
            V0             => 0.0,
            U1             => 1.0,
            V1             => 1.0,
            Image_ID       =>
              (if Item.Protocol = Terminal.Core.Kitty_Graphics
               then Interfaces.Unsigned_32 (Header.Kitty_ID)
               else 0),
            Content_Serial =>
              (if R.Last_Stored_Image_Content_Serial /= 0
               then R.Last_Stored_Image_Content_Serial
               else Interfaces.Unsigned_64 (Item.Sequence)),
            Z_Index        =>
              (if Item.Protocol = Terminal.Core.Kitty_Graphics
               then Header.Kitty_Z_Index
               else 0),
            Tint           => Graphics_Tint (Item.Protocol));
         Terminal.App.Graphics.Release (Data);
      end Emit_Image;

      Text : constant String := Event_Text (Event);
      Header : constant Terminal.App.Graphics.Graphics_Header :=
        Resolved_Header (Terminal.App.Graphics.Header (Event));
   begin
      if not Event.Pending
        or else Event.Protocol = Terminal.Core.No_Graphics
        or else R.Images = null
        or else R.Image_Count >= R.Images'Length
      then
         return;
      end if;

      if Event.Protocol = Terminal.Core.ITerm2_Graphics
        and then
          (not Header.ITerm2_Control_Data_Valid
           or else not Header.ITerm2_Inline
           or else not Header.ITerm2_Width_Valid
           or else not Header.ITerm2_Height_Valid)
      then
         --  Non-inline transfers are downloads, which this terminal does not
         --  perform. Invalid display dimensions are ignored atomically.
         return;
      end if;

      if Event.Protocol = Terminal.Core.Kitty_Graphics
        and then Header.Recognized
        and then Header.Kitty_Action = 'd'
        and then not Header.Has_Data
      then
         if Header.Kitty_ID > 0 then
            Delete_Image_Object (R, Event.Stream_ID, Header.Kitty_ID);
         else
            Delete_Virtual_Placements (R, Event.Stream_ID, 0);
            Delete_Conventional_Placements (R, Event.Stream_ID, 0);
         end if;
         return;
      end if;

      if Event.Protocol = Terminal.Core.Kitty_Graphics
        and then Header.Recognized
        and then Header.Kitty_ID > 0
        and then not Header.Has_Data
      then
         if Emit_Image_Object (Event, Header) then
            return;
         end if;
      end if;

      if Event.Protocol = Terminal.Core.Kitty_Graphics
        and then Header.Recognized
        and then Header.Has_Data
        and then Event.Protocol = Terminal.Core.Kitty_Graphics
        and then Header.Kitty_Transmission in 'f' | 't' | 's'
      then
         if Emit_Local_Kitty (Event, Header, Text) then
            null;
         end if;
         return;
      end if;

      if Header.Recognized
        and then Header.Has_Data
        and then Event.Protocol = Terminal.Core.Kitty_Graphics
        and then Header.Kitty_Action = 'f'
      then
         Apply_Animation_Frame (R, Event, Header, Text);
         return;
      end if;

      if Header.Recognized
        and then Header.Has_Data
        and then Event.Protocol = Terminal.Core.Kitty_Graphics
        and then Header.Kitty_Format in 8 | 16 | 24 | 32
        and then Emit_Raw_Kitty (Event, Header, Text)
      then
         return;
      end if;

      if Header.Recognized
        and then Header.Has_Data
        and then
          (Event.Protocol = Terminal.Core.ITerm2_Graphics
           or else
             (Event.Protocol = Terminal.Core.Kitty_Graphics
              and then Header.Kitty_Format = 100))
        and then Emit_PNG_Rows (Event, Header, Text)
      then
         return;
      end if;

      if Header.Recognized
        and then Header.Has_Data
        and then Event.Protocol = Terminal.Core.Sixel_Graphics
        and then Emit_Sixel_Rows (Event, Header, Text)
      then
         return;
      end if;

      Emit_Image (Event, Text);
   end Add_Image_Event;

   procedure Apply_Image_Event
     (R      : in out Renderer;
      Event  : Terminal.Core.Graphics_Event;
      Snapshot : Terminal.Core.Render_Snapshot)
   is
      Event_Header : constant Terminal.App.Graphics.Graphics_Header :=
        Terminal.App.Graphics.Header (Event);
      Header : Terminal.App.Graphics.Graphics_Header :=
        Event_Header;
      Image_Count_Before : constant Natural := R.Image_Count;
   begin
      if Event.Protocol = Terminal.Core.Kitty_Graphics
        and then Header.Recognized
        and then Header.Kitty_ID > 0
        and then Header.Kitty_Image_Number > 0
      then
         --  The protocol makes i= and I= mutually exclusive for every
         --  command. Do not let an invalid command mutate either store.
         return;
      end if;

      if Event.Protocol = Terminal.Core.Kitty_Graphics
        and then Header.Recognized
        and then
          (not Header.Kitty_Control_Data_Valid
           or else not Header.Kitty_Action_Controls_Valid
           or else not Header.Kitty_Transmission_Valid
           or else not Header.Kitty_Compression_Valid
           or else
             (Header.Kitty_Transmission in 'f' | 't' | 's'
              and then
                (not Header.Kitty_Data_Size_Valid
                 or else not Header.Kitty_Data_Offset_Valid
                 or else Header.Kitty_More_Specified)))
      then
         R.Image_Count := Image_Count_Before;
         return;
      end if;

      if Event.Protocol = Terminal.Core.Kitty_Graphics
        and then Header.Recognized
        and then Header.Kitty_Image_Number > 0
      then
         if Header.Kitty_Action in 't' | 'T' and then Header.Has_Data then
            --  Allocate once the complete transmission is available. The
            --  first m=1 chunk is retained without consuming an ID.
            if not Event_Header.Kitty_More then
               Header.Kitty_ID := Allocate_Image_ID (R, Event.Stream_ID);
               if Header.Kitty_ID = 0 then
                  return;
               end if;
            end if;
         else
            declare
               Object : constant Image_Object_Access :=
                 Find_Image_Object_By_Number
                   (R, Event.Stream_ID, Header.Kitty_Image_Number);
            begin
               Header.Kitty_ID :=
                 (if Object = null then 0 else Object.ID);
            end;
         end if;
      end if;

      if Event.Protocol = Terminal.Core.Kitty_Graphics
        and then Header.Recognized
        and then Header.Kitty_Action = 'd'
      then
         --  Chunk assembly is core-owned, so a delete reaches the renderer
         --  only after any partial transfer has already been cancelled.
         --  Lowercase selectors retain reusable data; uppercase selectors
         --  may release it once no retained placement references it.
         declare
            Selector : constant Character :=
              (if Header.Kitty_Delete = ASCII.NUL
               then 'a'
               else Header.Kitty_Delete);
            Delete_Data : constant Boolean := Selector in 'A' .. 'Z';
         begin
            case Selector is
               when 'a' | 'A' =>
                  Delete_Visible_Conventional_Placements
                    (R, Snapshot, Delete_Data);
               when 'i' | 'I' =>
                  if Header.Kitty_ID > 0 then
                     Delete_Virtual_Placements
                       (R,
                        Event.Stream_ID,
                        Header.Kitty_ID,
                        Header.Kitty_Placement_ID,
                        Header.Kitty_Placement_ID > 0);
                     Delete_Conventional_Placements
                       (R,
                        Event.Stream_ID,
                        Header.Kitty_ID,
                        Header.Kitty_Placement_ID,
                        Header.Kitty_Placement_ID > 0);
                     if Delete_Data
                       and then not Has_Image_Placement
                         (R, Event.Stream_ID, Header.Kitty_ID)
                     then
                        Delete_Image_Object
                          (R, Event.Stream_ID, Header.Kitty_ID);
                     end if;
                  end if;
               when 'n' | 'N' =>
                  if Header.Kitty_ID > 0 then
                     Delete_Virtual_Placements
                       (R,
                        Event.Stream_ID,
                        Header.Kitty_ID,
                        Header.Kitty_Placement_ID,
                        Header.Kitty_Placement_ID > 0);
                     Delete_Conventional_Placements
                       (R,
                        Event.Stream_ID,
                        Header.Kitty_ID,
                        Header.Kitty_Placement_ID,
                        Header.Kitty_Placement_ID > 0);
                     if Delete_Data
                       and then not Has_Image_Placement
                         (R, Event.Stream_ID, Header.Kitty_ID)
                     then
                        Delete_Image_Object
                          (R, Event.Stream_ID, Header.Kitty_ID);
                     end if;
                  end if;
               when 'z' | 'Z' =>
                  Delete_Conventional_Placements_By_Z
                    (R,
                     Event.Stream_ID,
                     Header.Kitty_Z_Index,
                     Event.Alternate_Screen,
                     Event.Screen_Generation,
                     Delete_Data);
               when 'c' | 'C' =>
                  Delete_Conventional_Placements_Intersecting
                    (R,
                     Event.Stream_ID,
                     Event.Row,
                     Event.Col,
                     Match_Screen => True,
                     Alternate_Screen => Event.Alternate_Screen,
                     Screen_Generation => Event.Screen_Generation,
                     Snapshot => Snapshot,
                     Delete_Data => Delete_Data);
               when 'p' | 'P' | 'q' | 'Q' =>
                  if Header.Kitty_Source_X > 0
                    and then Header.Kitty_Source_Y > 0
                  then
                     Delete_Conventional_Placements_Intersecting
                       (R,
                        Event.Stream_ID,
                        Positive (Header.Kitty_Source_Y),
                        Positive (Header.Kitty_Source_X),
                        Match_Z => Selector in 'q' | 'Q',
                        Z_Index => Header.Kitty_Z_Index,
                        Match_Screen => True,
                        Alternate_Screen => Event.Alternate_Screen,
                        Screen_Generation => Event.Screen_Generation,
                        Snapshot => Snapshot,
                        Delete_Data => Delete_Data);
                  end if;
               when 'x' | 'X' =>
                  if Header.Kitty_Source_X > 0 then
                     Delete_Conventional_Placements_Intersecting
                       (R,
                        Stream_ID => Event.Stream_ID,
                        Row       => 1,
                        Col       => Positive (Header.Kitty_Source_X),
                        Match_Row => False,
                        Match_Screen => True,
                        Alternate_Screen => Event.Alternate_Screen,
                        Screen_Generation => Event.Screen_Generation,
                        Snapshot => Snapshot,
                        Delete_Data => Delete_Data);
                  end if;
               when 'y' | 'Y' =>
                  if Header.Kitty_Source_Y > 0 then
                     Delete_Conventional_Placements_Intersecting
                       (R,
                        Stream_ID => Event.Stream_ID,
                        Row       => Positive (Header.Kitty_Source_Y),
                        Col       => 1,
                        Match_Col => False,
                        Match_Screen => True,
                        Alternate_Screen => Event.Alternate_Screen,
                        Screen_Generation => Event.Screen_Generation,
                        Snapshot => Snapshot,
                        Delete_Data => Delete_Data);
                  end if;
               when 'r' | 'R' =>
                  Delete_Image_ID_Range
                    (R,
                     Event.Stream_ID,
                     Header.Kitty_Delete_Range_First,
                     Header.Kitty_Delete_Range_Last,
                     Delete_Data);
               when 'f' | 'F' =>
                  if Header.Kitty_ID > 0 then
                     declare
                        Object : constant Image_Object_Access :=
                          Find_Image_Object
                            (R, Event.Stream_ID, Header.Kitty_ID);
                     begin
                        Delete_Animation_Frames (R, Object);
                     end;
                  end if;
               when others =>
                  null;
            end case;
            Delete_Orphaned_Relative_Placements
              (R, Event.Stream_ID, Delete_Data => Delete_Data);
         end;
         R.Image_Count := Image_Count_Before;
         return;
      end if;

      if Event.Protocol = Terminal.Core.Kitty_Graphics
        and then Header.Recognized
        and then Header.Kitty_Action = 'a'
        and then not Header.Has_Data
      then
         Apply_Animation_Control (R, Event, Header);
         R.Image_Count := Image_Count_Before;
         return;
      elsif Event.Protocol = Terminal.Core.Kitty_Graphics
        and then Header.Recognized
        and then Header.Kitty_Action = 'c'
        and then not Header.Has_Data
      then
         Apply_Animation_Composition (R, Event, Header);
         R.Image_Count := Image_Count_Before;
         return;
      end if;

      if Event.Protocol = Terminal.Core.Kitty_Graphics
        and then Header.Recognized
        and then
          (Header.Kitty_Action not in 't' | 'T' | 'p' | 'f'
           or else
             (Header.Kitty_Action in 't' | 'T' and then not Header.Has_Data)
           or else
             (Header.Kitty_Action = 'p' and then Header.Has_Data)
           or else
             (Header.Kitty_Action = 'f' and then not Header.Has_Data))
      then
         --  Unsupported animation/control actions and invalid action/data
         --  combinations must not accidentally replace an image object or
         --  become visible through the generic image fallback.
         R.Image_Count := Image_Count_Before;
         return;
      end if;

      R.Last_Stored_Image_Order := 0;
      Add_Image_Event
        (R,
         Event,
         Resolved_Image_ID     => Header.Kitty_ID,
         Resolved_Image_Number => Header.Kitty_Image_Number);

      if Event.Protocol in
        Terminal.Core.Sixel_Graphics | Terminal.Core.ITerm2_Graphics
        and then R.Last_Stored_Image_Order /= 0
      then
         --  The retained placement is emitted later in this same frame and
         --  on subsequent frames. Drop the decoder's transient command to
         --  avoid drawing the newly installed image twice.
         R.Image_Count := Image_Count_Before;
      end if;

      if Event.Protocol = Terminal.Core.Kitty_Graphics
        and then Header.Recognized
        and then
          (Header.Kitty_Action = 'p'
           or else Header.Kitty_Action = 'T')
      then
         --  Placement commands persist after their APC event is consumed.
         --  U=1 defines an invisible prototype whose cells are supplied by
         --  Unicode placeholders; ordinary placements retain their terminal
         --  cursor anchor and are emitted on every frame.
         if (Header.Kitty_ID > 0
             and then Find_Image_Object
               (R, Event.Stream_ID, Header.Kitty_ID) /= null)
           or else
             (Header.Kitty_ID = 0
              and then Header.Kitty_Action = 'T'
              and then Find_Image_Object_By_Storage_Order
                (R, Event.Stream_ID, R.Last_Stored_Image_Order) /= null)
         then
            R.Image_Count := Image_Count_Before;
            if Header.Kitty_Virtual_Placement then
               Store_Virtual_Placement (R, Event, Header);
            else
               Store_Conventional_Placement (R, Event, Header);
            end if;
         elsif Header.Kitty_ID > 0 then
            --  An addressed combined command must not leave a transient
            --  fallback drawable behind when object installation failed.
            R.Image_Count := Image_Count_Before;
         end if;
      elsif Event.Protocol = Terminal.Core.Kitty_Graphics
        and then Header.Recognized
        and then Header.Kitty_Action in 't' | 'f'
      then
         --  Transmit-only installs or replaces an image object without
         --  creating a visible placement.
         R.Image_Count := Image_Count_Before;
      end if;
   end Apply_Image_Event;

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
      Image_Count_Before : constant Natural := R.Image_Count;
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
            return R.Image_Count > Image_Count_Before;
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
         R.Image_Count := Image_Count_Before;
         if Track_Result and then Header.Recognized then
            Result.Code := Terminal.Core.Kitty_EINVAL;
            Remember_Processed_Graphics_Event (R, Event, Result);
         end if;
         return;
      end if;

      if Invalid_Chunk_Transition then
         R.Chunk_Cancel_Count := R.Chunk_Cancel_Count + 1;
         R.Image_Count := Image_Count_Before;
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
                 Validate_Kitty_Query_Data
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
                 when Terminal.App.ITerm2_Files.Save_Disabled =>
                   Terminal.Core.Kitty_ENOTSUP,
                 when Terminal.App.ITerm2_Files.Save_Invalid_Command
                    | Terminal.App.ITerm2_Files.Save_Invalid_Name
                    | Terminal.App.ITerm2_Files.Save_Invalid_Data =>
                   Terminal.Core.Kitty_EINVAL,
                 when others => Terminal.Core.Kitty_EBADF);
            if Save_Status /= Terminal.App.ITerm2_Files.Save_Ok then
               R.Transport_Failure_Count := R.Transport_Failure_Count + 1;
            end if;
            Remember_Processed_Graphics_Event (R, Event, Result);
            return;
         end;
      end if;

      R.Image_Store_Allocation_Failed := False;
      R.Image_Transport_Failed := False;
      R.Last_Animation_Result := Terminal.Core.Kitty_No_Response;
      Apply_Image_Event (R, Event, Snapshot);
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
           and then R.Images /= null
           and then R.Image_Count > Image_Count_Before
         then
            Resolved_Geometry :=
              Resolve_Placement_Geometry
                (R,
                 R.Images (R.Image_Count).Pixel_Width,
                 R.Images (R.Image_Count).Pixel_Height,
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
               if Resolved_ID = 0
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
               else
                  Result.Code := Terminal.Core.Kitty_OK;
               end if;
            elsif Header.Kitty_Action in 't' | 'T' then
               if Header.Kitty_Image_Number /= 0 then
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
                       or else R.Image_Count > Image_Count_Before
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
              and then Result.Code = Terminal.Core.Kitty_OK
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
                  Result.Code := Terminal.Core.Kitty_ENOMEM;
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
      if R.Images = null then
         return;
      end if;

      while Placement /= null and then R.Image_Count < R.Images'Length loop
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
                  Frame_Bytes : constant RM.Image_Data_Access :=
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
                     R.Image_Count := R.Image_Count + 1;
                     R.Images (R.Image_Count) :=
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
                     Decoded_Bytes_Owned => False,
                     Encoded_Source_Bytes => null,
                     Encoded_Source_Bytes_Owned => False,
                     Encoded_Source_Length => 0,
                     Decoded_Preview_Length => Preview_Length,
                     Decoded_Preview_Bytes => Frame_Bytes,
                     Decoded_Preview_Bytes_Owned => False,
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
                     Tint => (R => 1.0, G => 1.0, B => 1.0, A => 1.0));
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
      if R.Images = null or else Snapshot.Image_Cell_Count = 0 then
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
                 and then R.Image_Count < R.Images'Length
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
                           Frame_Bytes : constant RM.Image_Data_Access :=
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
                              R.Image_Count := R.Image_Count + 1;
                              R.Images (R.Image_Count) :=
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
                                 Decoded_Bytes_Owned => False,
                                 Encoded_Source_Bytes => null,
                                 Encoded_Source_Bytes_Owned => False,
                                 Encoded_Source_Length => 0,
                                 Decoded_Preview_Length => Preview_Length,
                                 Decoded_Preview_Bytes => Frame_Bytes,
                                 Decoded_Preview_Bytes_Owned => False,
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
                                   (R => 1.0, G => 1.0, B => 1.0, A => 1.0));
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
      R.Has_Context := False;
      Initialize_Text (R, Status);
   end Initialize_Headless;

   procedure Set_Graphics_Resource_Limits
     (R      : in out Renderer;
      Limits : Graphics_Resource_Limits)
   is
   begin
      R.Graphics_Limits := Limits;
      VS.Set_Image_Atlas_Limits
        (R.Batch,
         (Bytes     => Limits.GPU_Atlas_Bytes,
          Dimension => Limits.GPU_Atlas_Dimension));
      while
        (R.Image_Object_Count > Limits.Image_Objects
         or else R.Image_Object_Bytes > Limits.Image_Bytes
         or else R.Animation_Frame_Count > Limits.Animation_Frames)
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
      T : Terminal.App.Theme.Theme)
   is
      Object : Image_Object_Access;
   begin
      R.Color_Theme := T;
      Object := R.Image_Objects;
      while Object /= null loop
         declare
            Recolored : constant Boolean :=
              (if Object.Theme_Operations /= null
               then Replay_Theme_Operations (R, Object)
               else
                 Object.Indexed_Format in 8 | 16
                 and then Object.Indexed_Bytes /= null
                 and then Object.Bytes /= null
                 and then Expand_Kitty_Indexed
                   (R,
                    Object.Indexed_Format,
                    Object.Pixel_Width,
                    Object.Pixel_Height,
                    Object.Indexed_Bytes,
                    Object.Bytes));
         begin
            if Recolored then
               Touch_Image_Object (R, Object);
               R.Atlas_Dirty := True;
            end if;
         end;
         Object := Object.Next;
      end loop;
   end Set_Theme;

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
      Object_Current : Image_Object_Access := R.Image_Objects;
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
         Object_Next := Object_Current.Next;
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

   procedure Finalize (R : in out Renderer) is
      Palette : Sixel_Palette_Entry_Access := R.Sixel_Palettes;
      Next : Sixel_Palette_Entry_Access;
   begin
      Release_Frame (R);
      Release_Image_Objects (R);
      Commit_Graphics_Events (R);
      while Palette /= null loop
         Next := Palette.Next;
         Free_Sixel_Palette_Entry (Palette);
         Palette := Next;
      end loop;
      R.Sixel_Palettes := null;
      Textrender.Reset (R.Text);
      R.Initialized := False;
      R.Has_Context := False;
      R.Text_Loaded := False;
      R.Glyph_Count := 0;
      R.Colour_Glyph_Count := 0;
      R.Image_Count := 0;
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
      Has_Image : constant Boolean := R.Images /= null and then R.Image_Count > 0;
   begin
      return
        (Initialized          => R.Initialized,
         Text_Loaded          => R.Text_Loaded,
         Last_Cell_Count      => R.Last_Cell_Count,
         Last_Dirty_Rows      => R.Last_Dirty_Rows,
         Last_Rectangle_Count => R.Rectangle_Count,
         Last_Glyph_Count     => R.Glyph_Count,
         Last_Image_Count     => R.Image_Count,
         Last_Image_Protocol  =>
           (if Has_Image then R.Images (R.Image_Count).Protocol
            else Terminal.App.Render_Model.Image_Sixel),
         Last_Image_Width =>
           (if Has_Image then Natural (R.Images (R.Image_Count).Width) else 0),
         Last_Image_Height =>
           (if Has_Image then Natural (R.Images (R.Image_Count).Height) else 0),
         Last_Image_Raw_Format =>
           (if Has_Image then R.Images (R.Image_Count).Raw_Format else 0),
         Last_Image_Pixel_Width =>
           (if Has_Image then R.Images (R.Image_Count).Pixel_Width else 0),
         Last_Image_Pixel_Height =>
           (if Has_Image then R.Images (R.Image_Count).Pixel_Height else 0),
         Last_Image_Payload_Length =>
           (if Has_Image then R.Images (R.Image_Count).Payload_Length else 0),
         Last_Image_Staging_Byte_Length =>
           (if Has_Image then R.Images (R.Image_Count).Staging_Byte_Length
            else 0),
         Last_Image_Payload_Preview_Complete =>
           Has_Image
           and then R.Images (R.Image_Count).Payload_Preview_Complete,
         Last_Image_Encoded_Preview_Length =>
           (if Has_Image then R.Images (R.Image_Count).Encoded_Preview_Length
            else 0),
         Last_Image_Decoded_Preview_Length =>
           (if Has_Image then R.Images (R.Image_Count).Decoded_Preview_Length
            else 0),
         Last_Image_Decoded_Preview_Bytes =>
           (if Has_Image then Image_Preview (R.Images (R.Image_Count))
            else (others => 0)),
         Last_Image_Preview_Decode_Complete =>
           Has_Image and then R.Images (R.Image_Count).Preview_Decode_Complete,
         Last_Image_Decode_Status =>
           (if Has_Image then R.Images (R.Image_Count).Decode_Status
            else RM.Image_Decode_Not_Attempted),
         Last_Media_Diagnostic => R.Last_Media_Diagnostic,
         Last_Media_Peak_Working_Bytes => R.Last_Media_Peak_Working_Bytes,
         Last_Image_Placeholder =>
           Has_Image and then R.Images (R.Image_Count).Placeholder,
         Image_Object_Count => R.Image_Object_Count,
         Image_Object_Bytes => R.Image_Object_Bytes,
         Placement_Count => R.Kitty_Placement_Count,
         Kitty_Image_Object_Count => R.Image_Object_Count,
         Kitty_Image_Object_Bytes => R.Image_Object_Bytes,
         Kitty_Placement_Count => R.Kitty_Placement_Count,
         Kitty_Animation_Frame_Count => R.Animation_Frame_Count,
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

      return
        "image " & Protocol_Name
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
            (Diagnostics.Last_Image_Decode_Status);
   end Image_Status_Label;

   function Last_Frame (R : Renderer) return RM.Frame_Commands is
      Pixels : constant access constant Textrender.Alpha_Buffer :=
        (if R.Text_Loaded then Textrender.Atlas_Pixels (R.Text) else null);
      Address : constant System.Address :=
        (if Pixels = null then System.Null_Address else Pixels.all'Address);
      Width   : constant Natural :=
        (if R.Text_Loaded then Textrender.Atlas_Width (R.Text) else 0);
      Height  : constant Natural :=
        (if R.Text_Loaded then Textrender.Atlas_Height (R.Text) else 0);
   begin
      return
        (Width           => R.Last_Frame_Width,
         Height          => R.Last_Frame_Height,
         Rectangles      => R.Rectangles,
         Rectangle_Count => R.Rectangle_Count,
         Glyphs          => R.Glyphs,
         Glyph_Count     => R.Glyph_Count,
         Colour_Glyphs   => R.Colour_Glyphs,
         Colour_Glyph_Count => R.Colour_Glyph_Count,
         Colour_Sheet_Width => Textrender.Colour_Sheet_Width (R.Text),
         Colour_Sheet_Height => Textrender.Colour_Sheet_Height (R.Text),
         Colour_Sheet_Pixels =>
           (if Textrender.Colour_Sheet_Pixels (R.Text) = null
            then System.Null_Address
            else Textrender.Colour_Sheet_Pixels (R.Text).all'Address),
         Colour_Sheet_Dirty => R.Colour_Sheet_Dirty,
         Images          => R.Images,
         Image_Count     => R.Image_Count,
         Text_Runs       => R.Text_Runs,
         Text_Run_Count  => R.Text_Run_Count,
         Atlas_Width     => Width,
         Atlas_Height    => Height,
         Atlas_Pixels    => Address,
         Atlas_Bytes     => Width * Height,
         Atlas_Dirty     => R.Atlas_Dirty);
   end Last_Frame;
end Terminal.App.Renderer;

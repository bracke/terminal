with Ada.Unchecked_Deallocation;
with System;

with Terminal.Common;
with Terminal.Common.Bytes;
with Terminal.Common.Status;
with Terminal.App.Fonts;
with Terminal.App.Graphics;
with Terminal.App.Hyperlinks;
with Terminal.App.Render_Model;
with Terminal.App.Text_Shaper;
with Terminal.App.Theme;
with Terminal.App.Vulkan_Submit;

package body Terminal.App.Renderer is
   package RM renames Terminal.App.Render_Model;
   package VS renames Terminal.App.Vulkan_Submit;

   use type Terminal.Core.Cell_Kind;
   use type Terminal.Core.Cell_Width;
   use type Terminal.Core.Color_Kind;
   use type Terminal.Core.Cursor_Shape;
   use type Terminal.Core.Dirty_Row_Array_Access;
   use type Terminal.Core.Ignored_Graphics_Protocol;
   use type Terminal.Core.Style;
   use type Terminal.Common.Code_Point;
   use type RM.Glyph_Array_Access;
   use type RM.Image_Array_Access;
   use type RM.Image_Data_Access;
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
   procedure Free_Image_Data is new Ada.Unchecked_Deallocation
     (Terminal.Common.Bytes.Byte_Array, RM.Image_Data_Access);
   procedure Free_String is new Ada.Unchecked_Deallocation
     (String, String_Access);
   procedure Free_Kitty_Chunk_Segment is new Ada.Unchecked_Deallocation
     (Kitty_Chunk_Segment, Kitty_Chunk_Segment_Access);
   procedure Free_Image_Object is new Ada.Unchecked_Deallocation
     (Image_Object, Image_Object_Access);

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

   procedure Release_Frame (R : in out Renderer) is
   begin
      if R.Rectangles /= null then
         Free_Rectangles (R.Rectangles);
         R.Rectangles := null;
      end if;
      if R.Glyphs /= null then
         Free_Glyphs (R.Glyphs);
         R.Glyphs := null;
      end if;
      if R.Images /= null then
         for I in 1 .. R.Image_Count loop
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
         Free_Images (R.Images);
         R.Images := null;
      end if;
      if R.Text_Runs /= null then
         Free_Text_Runs (R.Text_Runs);
         R.Text_Runs := null;
      end if;
      R.Rectangle_Count := 0;
      R.Glyph_Count := 0;
      R.Image_Count := 0;
      R.Text_Run_Count := 0;
      R.Shaped_Glyph_Count := 0;
      R.Shaping_Fallback_Count := 0;
      R.Text_Fallback_Run_Count := 0;
      R.Color_Emoji_Fallback_Count := 0;
      R.Paragraph_Bidi_Fallback_Count := 0;
      R.Vertex_Count := 0;
      R.Last_Cell_Count := 0;
      R.Last_Dirty_Rows := 0;
      R.Last_Frame_Width := 0;
      R.Last_Frame_Height := 0;
      VS.Release (R.Batch);
   end Release_Frame;

   procedure Clear_Kitty_Chunks (R : in out Renderer) is
      Current : Kitty_Chunk_Segment_Access := R.Kitty_Chunk_Head;
      Next    : Kitty_Chunk_Segment_Access;
   begin
      while Current /= null loop
         Next := Current.Next;
         if Current.Text /= null then
            Free_String (Current.Text);
            Current.Text := null;
         end if;
         Free_Kitty_Chunk_Segment (Current);
         Current := Next;
      end loop;
      R.Kitty_Chunk_Head := null;
      R.Kitty_Chunk_Tail := null;
      R.Kitty_Chunk_Length := 0;
   end Clear_Kitty_Chunks;

   procedure Clear_Image_Object (Object : in out Image_Object) is
   begin
      if Object.Bytes /= null then
         Free_Image_Data (Object.Bytes);
         Object.Bytes := null;
      end if;
      Object :=
        (ID             => 0,
         Protocol       => RM.Image_Kitty,
         Raw_Format     => 0,
         Pixel_Width    => 0,
         Pixel_Height   => 0,
         Decoded_Length => 0,
         Decoded_Row_Stride_Bytes => 0,
         Bytes          => null,
         Next           => null);
   end Clear_Image_Object;

   function Find_Image_Object
     (R  : Renderer;
      ID : Natural) return Image_Object_Access
   is
      Current : Image_Object_Access := R.Image_Objects;
   begin
      if ID = 0 then
         return null;
      end if;

      while Current /= null loop
         if Current.ID = ID then
            return Current;
         end if;
         Current := Current.Next;
      end loop;
      return null;
   end Find_Image_Object;

   procedure Release_Image_Objects (R : in out Renderer) is
      Current : Image_Object_Access := R.Image_Objects;
      Next    : Image_Object_Access;
   begin
      while Current /= null loop
         Next := Current.Next;
         Clear_Image_Object (Current.all);
         Free_Image_Object (Current);
         Current := Next;
      end loop;
      R.Image_Objects := null;
   end Release_Image_Objects;

   procedure Delete_Image_Object
     (R  : in out Renderer;
      ID : Natural)
   is
      Previous : Image_Object_Access := null;
      Current  : Image_Object_Access := R.Image_Objects;
   begin
      if ID = 0 then
         return;
      end if;

      while Current /= null loop
         if Current.ID = ID then
            declare
               Next : constant Image_Object_Access := Current.Next;
            begin
               if Previous = null then
                  R.Image_Objects := Next;
               else
                  Previous.Next := Next;
               end if;
               Clear_Image_Object (Current.all);
               Free_Image_Object (Current);
            end;
            return;
         end if;

         Previous := Current;
         Current := Current.Next;
      end loop;
   end Delete_Image_Object;

   procedure Take_Image_Object
     (R              : in out Renderer;
      ID             : Natural;
      Protocol       : RM.Image_Protocol;
      Raw_Format     : Natural;
      Pixel_Width    : Natural;
      Pixel_Height   : Natural;
      Decoded_Length : Natural;
      Decoded_Row_Stride_Bytes : Natural;
      Bytes          : in out RM.Image_Data_Access;
      Stored_Bytes   : out RM.Image_Data_Access)
   is
      Object : Image_Object_Access := Find_Image_Object (R, ID);
   begin
      Stored_Bytes := null;
      if ID = 0
        or else Bytes = null
        or else Decoded_Length = 0
        or else Raw_Format = 0
        or else Pixel_Width = 0
        or else Pixel_Height = 0
      then
         return;
      end if;

      if Object = null then
         Object := new Image_Object;
         Object.Next := R.Image_Objects;
         R.Image_Objects := Object;
      end if;

      declare
         Next : constant Image_Object_Access := Object.Next;
      begin
         Clear_Image_Object (Object.all);
         Object.all :=
           (ID             => ID,
            Protocol       => Protocol,
            Raw_Format     => Raw_Format,
            Pixel_Width    => Pixel_Width,
            Pixel_Height   => Pixel_Height,
            Decoded_Length => Decoded_Length,
            Decoded_Row_Stride_Bytes => Decoded_Row_Stride_Bytes,
            Bytes          => Bytes,
            Next           => Next);
         Stored_Bytes := Bytes;
         Bytes := null;
      end;
   exception
      when Storage_Error =>
         Stored_Bytes := null;
   end Take_Image_Object;

   function Image_Buffer_Extent
     (Raw_Format     : Natural;
      Pixel_Width    : Natural;
      Pixel_Height   : Natural;
      Row_Stride     : Natural) return Natural
   is
      Bytes_Per_Pixel : constant Natural :=
        (if Raw_Format = 24 then 3
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
      Color  : RM.Pixel_Color)
   is
   begin
      if R.Rectangles = null or else R.Rectangle_Count >= R.Rectangles'Length then
         return;
      end if;

      R.Rectangle_Count := R.Rectangle_Count + 1;
      R.Rectangles (R.Rectangle_Count) :=
        (X => X, Y => Y, Width => Width, Height => Height, Color => Color);
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

   procedure Add_Image
     (R      : in out Renderer;
      Event  : Terminal.Core.Graphics_Event)
   is
      function Event_Text
        (Item : Terminal.Core.Graphics_Event) return String is
      begin
         if Item.Preview_Length = 0 then
            return "";
         end if;
         return Item.Preview (1 .. Item.Preview_Length);
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

      procedure Clear_Kitty_Chunk is
      begin
         Clear_Kitty_Chunks (R);
      end Clear_Kitty_Chunk;

      procedure Append_Kitty_Text (Text : String) is
         Segment : Kitty_Chunk_Segment_Access;
      begin
         if Text'Length = 0 then
            return;
         end if;

         Segment := new Kitty_Chunk_Segment'
           (Text => new String'(Text),
            Next => null);
         if R.Kitty_Chunk_Tail = null then
            R.Kitty_Chunk_Head := Segment;
         else
            R.Kitty_Chunk_Tail.Next := Segment;
         end if;
         R.Kitty_Chunk_Tail := Segment;
         R.Kitty_Chunk_Length := R.Kitty_Chunk_Length + Text'Length;
      exception
         when Storage_Error =>
            Clear_Kitty_Chunk;
      end Append_Kitty_Text;

      procedure Store_Kitty_Chunk (Text : String) is
      begin
         Clear_Kitty_Chunk;
         Append_Kitty_Text (Text);
      end Store_Kitty_Chunk;

      procedure Append_Kitty_Chunk (Chunk : String) is
         From : constant Natural := Kitty_Data_Start (Chunk);
      begin
         if From = 0 then
            return;
         end if;
         Append_Kitty_Text (Chunk (From .. Chunk'Last));
      end Append_Kitty_Chunk;

      function Flatten_Kitty_Chunk return String_Access is
         Result  : String_Access;
         Current : Kitty_Chunk_Segment_Access := R.Kitty_Chunk_Head;
         Offset  : Natural := 0;
      begin
         if R.Kitty_Chunk_Length = 0 then
            return null;
         end if;

         Result := new String (1 .. R.Kitty_Chunk_Length);
         while Current /= null loop
            if Current.Text /= null then
               Result
                 (Offset + 1 .. Offset + Current.Text'Length) :=
                   Current.Text.all;
               Offset := Offset + Current.Text'Length;
            end if;
            Current := Current.Next;
         end loop;
         return Result;
      exception
         when Storage_Error =>
            return null;
      end Flatten_Kitty_Chunk;

      function Emit_Raw_Kitty_Chunked
        (Item : Terminal.Core.Graphics_Event) return Boolean
      is
         First : constant Kitty_Chunk_Segment_Access := R.Kitty_Chunk_Head;
      begin
         if First = null or else First.Text = null then
            return False;
         end if;

         declare
            First_Text : String renames First.Text.all;
            Header : constant Terminal.App.Graphics.Graphics_Header :=
              Terminal.App.Graphics.Header_Text
                (Terminal.Core.Kitty_Graphics, First_Text);
            Raw_Format : constant Natural := Header.Raw_Format;
            Bytes_Per_Pixel : constant Natural :=
              (if Raw_Format = 24 then 3
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
            First_Data : constant Natural := Kitty_Data_Start (First_Text);
            X : constant Float :=
              Float (Content_Margin + (Item.Col - 1) * R.CW);
            Y : constant Float :=
              Float (Content_Margin + (Item.Row - 1) * R.CH);
            Segment_Count : Natural := 0;
            Data : Terminal.App.Graphics.Graphics_Data_Preview;
            Image_Bytes : RM.Image_Data_Access := null;
            Image_Bytes_Owned : Boolean := False;
            Encoded_Source : RM.Image_Data_Access := null;
            Encoded_Source_Owned : Boolean := False;
            Borrowed_From_Object : Boolean := False;
            Row_Copy_Failed : Boolean := False;
            Preview_Length : Natural := 0;
            Preview_Bytes : Terminal.Common.Bytes.Byte_Array
              (1 .. RM.Max_Image_Decoded_Preview_Length) := (others => 0);

            function Chunk_Text (Index : Positive) return String is
               Current : Kitty_Chunk_Segment_Access := R.Kitty_Chunk_Head;
               Current_Index : Positive := 1;
            begin
               while Current /= null loop
                  if Current.Text /= null then
                     if Current_Index = Index then
                        if Index = 1 then
                           return Current.Text (First_Data .. Current.Text'Last);
                        else
                           return Current.Text.all;
                        end if;
                     end if;
                     Current_Index := Current_Index + 1;
                  end if;
                  Current := Current.Next;
               end loop;
               return "";
            end Chunk_Text;

            procedure Capture_Raw_Row
              (Row_Y : Natural;
               Row : Terminal.Common.Bytes.Byte_Array;
               Continue : in out Boolean)
            is
            begin
               if Header.Kitty_ID > 0 then
                  Capture_Image_Row
                    (Data,
                     Image_Bytes,
                     Image_Bytes_Owned,
                     Row_Y,
                     Row,
                     Continue);
               else
                  Capture_Image_Preview_Row
                    (Preview_Length, Preview_Bytes, Row_Y, Row, Continue);
               end if;
               if not Continue then
                  Row_Copy_Failed := True;
               end if;
            end Capture_Raw_Row;

            function Copy_Chunk_Source return RM.Image_Data_Access is
               Result : RM.Image_Data_Access;
               Offset : Natural := 0;
            begin
               if Data.Encoded_Length = 0 then
                  return null;
               end if;

               Result :=
                 new Terminal.Common.Bytes.Byte_Array (1 .. Data.Encoded_Length);
               for Index in 1 .. Segment_Count loop
                  declare
                     Text : constant String := Chunk_Text (Index);
                  begin
                     for I in Text'Range loop
                        if Offset < Result'Length then
                           Offset := Offset + 1;
                           Result (Offset) :=
                             Terminal.Common.Bytes.Byte
                               (Character'Pos (Text (I)));
                        end if;
                     end loop;
                  end;
               end loop;
               return Result;
            exception
               when Storage_Error =>
                  return null;
            end Copy_Chunk_Source;

            procedure Release_Local is
            begin
               Terminal.App.Graphics.Release (Data);
               if Image_Bytes /= null and then Image_Bytes_Owned then
                  Free_Image_Data (Image_Bytes);
               end if;
               if Encoded_Source /= null and then Encoded_Source_Owned then
                  Free_Image_Data (Encoded_Source);
               end if;
               Image_Bytes := null;
               Image_Bytes_Owned := False;
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
            then
               return False;
            end if;

            declare
               Current : Kitty_Chunk_Segment_Access := R.Kitty_Chunk_Head;
            begin
               while Current /= null loop
                  if Current.Text /= null then
                     Segment_Count := Segment_Count + 1;
                  end if;
                  Current := Current.Next;
               end loop;
            end;

            Terminal.App.Graphics.Decode_Base64_Raw_Chunk_Rows
              (Segment_Count,
               Chunk_Text'Access,
               Raw_Format,
               Header.Pixel_Width,
               Header.Pixel_Height,
               Capture_Raw_Row'Access,
               Data);

            if Row_Copy_Failed
              or else Data.Decoded_Length /= Expected_Length
              or else (Header.Kitty_ID > 0
                       and then not Image_Buffer_Ready (Data, Image_Bytes))
            then
               Release_Local;
               return False;
            end if;

            if Header.Kitty_ID > 0 then
               declare
                  Stored_Bytes : RM.Image_Data_Access;
               begin
                  Take_Image_Object
                    (R              => R,
                     ID             => Header.Kitty_ID,
                     Protocol       => RM.Image_Kitty,
                     Raw_Format     => Raw_Format,
                     Pixel_Width    => Header.Pixel_Width,
                     Pixel_Height   => Header.Pixel_Height,
                     Decoded_Length => Data.Decoded_Length,
                     Decoded_Row_Stride_Bytes =>
                       Data.Decoded_Row_Stride_Bytes,
                     Bytes          => Image_Bytes,
                     Stored_Bytes   => Stored_Bytes);
                  if Stored_Bytes /= null then
                     Image_Bytes := Stored_Bytes;
                     Image_Bytes_Owned := False;
                     Borrowed_From_Object := True;
                  end if;
               end;
            end if;

            if Header.Kitty_ID = 0 then
               Encoded_Source := Copy_Chunk_Source;
               Encoded_Source_Owned := Encoded_Source /= null;
               if Encoded_Source = null then
                  Release_Local;
                  return False;
               end if;
            end if;

            declare
               Source_Kind : constant RM.Image_Decoded_Source_Kind :=
                 (if Header.Kitty_ID = 0
                  then RM.Image_Decoded_Source_Raw_Base64
                  else RM.Image_Decoded_Source_Buffer);
            begin
               if Header.Kitty_ID > 0 then
                  Copy_Image_Preview
                    (Image_Bytes,
                     Data.Decoded_Length,
                     Preview_Length,
                     Preview_Bytes);
               end if;
               R.Image_Count := R.Image_Count + 1;
               R.Images (R.Image_Count) :=
                 (X              => X,
                  Y              => Y,
                  Width          =>
                    Float (R.CW * Header.Placeholder_Cols),
                  Height         =>
                    Float (R.CH * Header.Placeholder_Rows),
                  Protocol       => RM.Image_Kitty,
                  Placeholder    => False,
                  Raw_Format     => Raw_Format,
                  Pixel_Width    => Header.Pixel_Width,
                  Pixel_Height   => Header.Pixel_Height,
                  Payload_Length => R.Kitty_Chunk_Length,
                  Staging_Byte_Length => 0,
                  Payload_Preview_Complete => True,
                  Encoded_Preview_Length => Data.Encoded_Length,
                  Decoded_Byte_Length => Data.Decoded_Length,
                  Decoded_Row_Stride_Bytes =>
                    Data.Decoded_Row_Stride_Bytes,
                  Decoded_Source => Source_Kind,
                  Decoded_Bytes => Image_Bytes,
                  Decoded_Bytes_Owned =>
                    Image_Bytes /= null and then not Borrowed_From_Object,
                  Encoded_Source_Bytes => Encoded_Source,
                  Encoded_Source_Bytes_Owned => Encoded_Source_Owned,
                  Encoded_Source_Length => Data.Encoded_Length,
                  Decoded_Preview_Length => Preview_Length,
                  Decoded_Preview_Bytes => Preview_Bytes,
                  Preview_Decode_Complete => True,
                  Decode_Status =>
                    Terminal.App.Graphics.Image_Decode_Status
                      (Data.Decode_Status),
                  Tint           => Graphics_Tint (Terminal.Core.Kitty_Graphics));
            end;
            Encoded_Source_Owned := False;
            return True;
         exception
            when Storage_Error =>
               Release_Local;
               return False;
         end;
      end Emit_Raw_Kitty_Chunked;

      function Emit_Raw_Kitty
        (Item       : Terminal.Core.Graphics_Event;
         Header     : Terminal.App.Graphics.Graphics_Header;
         Image_Text : String) return Boolean
      is
            Raw_Format : constant Natural := Header.Raw_Format;
            Bytes_Per_Pixel : constant Natural :=
              (if Raw_Format = 24 then 3
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
           Float (Content_Margin + (Item.Col - 1) * R.CW);
         Y : constant Float :=
           Float (Content_Margin + (Item.Row - 1) * R.CH);
         Encoded_Length : Natural := 0;
         Data : Terminal.App.Graphics.Graphics_Data_Preview;
         Image_Bytes : RM.Image_Data_Access := null;
         Image_Bytes_Owned : Boolean := False;
         Encoded_Source : RM.Image_Data_Access := null;
         Encoded_Source_Owned : Boolean := False;
         Borrowed_From_Object : Boolean := False;
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
            if Header.Kitty_ID > 0 then
               Capture_Image_Row
                 (Data,
                  Image_Bytes,
                  Image_Bytes_Owned,
                  Row_Y,
                  Row,
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
            if Encoded_Source /= null and then Encoded_Source_Owned then
               Free_Image_Data (Encoded_Source);
            end if;
            Image_Bytes := null;
            Image_Bytes_Owned := False;
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
         then
            return False;
         end if;

         Encoded_Length := Image_Text'Last - First_Data + 1;
         Terminal.App.Graphics.Decode_Base64_Raw_Rows
           (Image_Text (First_Data .. Image_Text'Last),
            Raw_Format,
            Header.Pixel_Width,
            Header.Pixel_Height,
            Capture_Raw_Row'Access,
            Data);

         if Row_Copy_Failed
           or else Data.Decoded_Length /= Expected_Length
           or else (Header.Kitty_ID > 0
                    and then not Image_Buffer_Ready (Data, Image_Bytes))
         then
            Release_Local;
            return False;
         end if;

         if Header.Kitty_ID > 0 then
            declare
               Stored_Bytes : RM.Image_Data_Access;
            begin
               Take_Image_Object
                 (R              => R,
                  ID             => Header.Kitty_ID,
                  Protocol       => RM.Image_Kitty,
                  Raw_Format     => Raw_Format,
                  Pixel_Width    => Header.Pixel_Width,
                  Pixel_Height   => Header.Pixel_Height,
                  Decoded_Length => Data.Decoded_Length,
                  Decoded_Row_Stride_Bytes =>
                    Data.Decoded_Row_Stride_Bytes,
                  Bytes          => Image_Bytes,
                  Stored_Bytes   => Stored_Bytes);
               if Stored_Bytes /= null then
                  Image_Bytes := Stored_Bytes;
                  Image_Bytes_Owned := False;
                  Borrowed_From_Object := True;
               end if;
            end;
         end if;

         if Header.Kitty_ID = 0 then
            Encoded_Source :=
              Copy_Text_Bytes (Image_Text (First_Data .. Image_Text'Last));
            Encoded_Source_Owned := Encoded_Source /= null;
            if Encoded_Source = null then
               Release_Local;
               return False;
            end if;
         end if;

         declare
            Source_Kind : constant RM.Image_Decoded_Source_Kind :=
              (if Header.Kitty_ID = 0
               then RM.Image_Decoded_Source_Raw_Base64
               else RM.Image_Decoded_Source_Buffer);
         begin
            if Header.Kitty_ID > 0 then
               Copy_Image_Preview
                 (Image_Bytes, Data.Decoded_Length, Preview_Length, Preview_Bytes);
            end if;

            R.Image_Count := R.Image_Count + 1;
            R.Images (R.Image_Count) :=
              (X              => X,
               Y              => Y,
               Width          =>
                 Float (R.CW * Header.Placeholder_Cols),
               Height         =>
                 Float (R.CH * Header.Placeholder_Rows),
               Protocol       => RM.Image_Kitty,
               Placeholder    => False,
               Raw_Format     => Raw_Format,
               Pixel_Width    => Header.Pixel_Width,
               Pixel_Height   => Header.Pixel_Height,
               Payload_Length => Item.Payload_Length,
               Staging_Byte_Length => 0,
               Payload_Preview_Complete => True,
               Encoded_Preview_Length => Encoded_Length,
               Decoded_Byte_Length => Data.Decoded_Length,
               Decoded_Row_Stride_Bytes =>
                 Data.Decoded_Row_Stride_Bytes,
               Decoded_Source => Source_Kind,
               Decoded_Bytes => Image_Bytes,
               Decoded_Bytes_Owned =>
                 Image_Bytes /= null and then not Borrowed_From_Object,
               Encoded_Source_Bytes => Encoded_Source,
               Encoded_Source_Bytes_Owned => Encoded_Source_Owned,
               Encoded_Source_Length => Encoded_Length,
               Decoded_Preview_Length => Preview_Length,
               Decoded_Preview_Bytes => Preview_Bytes,
               Preview_Decode_Complete => True,
               Decode_Status =>
                 Terminal.App.Graphics.Image_Decode_Status
                   (Data.Decode_Status),
               Tint           => Graphics_Tint (Terminal.Core.Kitty_Graphics));
         end;
         Encoded_Source_Owned := False;
         return True;
      exception
         when Storage_Error =>
            Release_Local;
            return False;
      end Emit_Raw_Kitty;

      function Emit_PNG_Kitty_Chunked
        (Item : Terminal.Core.Graphics_Event) return Boolean
      is
         First : constant Kitty_Chunk_Segment_Access := R.Kitty_Chunk_Head;
      begin
         if First = null or else First.Text = null then
            return False;
         end if;

         declare
            First_Text : String renames First.Text.all;
            Header : constant Terminal.App.Graphics.Graphics_Header :=
              Terminal.App.Graphics.Header_Text
                (Terminal.Core.Kitty_Graphics, First_Text);
            First_Data : constant Natural := Kitty_Data_Start (First_Text);
            X : constant Float :=
              Float (Content_Margin + (Item.Col - 1) * R.CW);
            Y : constant Float :=
              Float (Content_Margin + (Item.Row - 1) * R.CH);
            Segment_Count : Natural := 0;
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
            Encoded_Source : RM.Image_Data_Access := null;
            Encoded_Source_Owned : Boolean := False;
            Borrowed_From_Object : Boolean := False;
            Row_Copy_Failed : Boolean := False;
            Preview_Length : Natural := 0;
            Preview_Bytes : Terminal.Common.Bytes.Byte_Array
              (1 .. RM.Max_Image_Decoded_Preview_Length) := (others => 0);

            function Chunk_Text (Index : Positive) return String is
               Current : Kitty_Chunk_Segment_Access := R.Kitty_Chunk_Head;
               Current_Index : Positive := 1;
            begin
               while Current /= null loop
                  if Current.Text /= null then
                     if Current_Index = Index then
                        if Index = 1 then
                           return Current.Text (First_Data .. Current.Text'Last);
                        else
                           return Current.Text.all;
                        end if;
                     end if;
                     Current_Index := Current_Index + 1;
                  end if;
                  Current := Current.Next;
               end loop;
               return "";
            end Chunk_Text;

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

            function Copy_Chunk_Source return RM.Image_Data_Access is
               Result : RM.Image_Data_Access;
               Offset : Natural := 0;
            begin
               if Encoded_Length = 0 then
                  return null;
               end if;

               Result :=
                 new Terminal.Common.Bytes.Byte_Array (1 .. Encoded_Length);
               for Index in 1 .. Segment_Count loop
                  declare
                     Text : constant String := Chunk_Text (Index);
                  begin
                     for I in Text'Range loop
                        if Offset < Result'Length then
                           Offset := Offset + 1;
                           Result (Offset) :=
                             Terminal.Common.Bytes.Byte
                               (Character'Pos (Text (I)));
                        end if;
                     end loop;
                  end;
               end loop;
               return Result;
            exception
               when Storage_Error =>
                  return null;
            end Copy_Chunk_Source;

            procedure Capture_PNG_Row
              (Row_Y : Natural;
               Row   : Terminal.Common.Bytes.Byte_Array;
               Continue : in out Boolean)
            is
            begin
               if Header.Kitty_ID > 0 then
                  Capture_Image_Row
                    (Data,
                     Image_Bytes,
                     Image_Bytes_Owned,
                     Row_Y,
                     Row,
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
              or else Header.Kitty_Format /= 100
              or else First_Data = 0
              or else R.Image_Count >= R.Images'Length
            then
               return False;
            end if;

            declare
               Current : Kitty_Chunk_Segment_Access := R.Kitty_Chunk_Head;
            begin
               while Current /= null loop
                  if Current.Text /= null then
                     Segment_Count := Segment_Count + 1;
                     Encoded_Length := Encoded_Length + Current.Text'Length;
                  end if;
                  Current := Current.Next;
               end loop;
            end;

            if Segment_Count = 0 or else Encoded_Length = 0 then
               return False;
            end if;

            Terminal.App.Graphics.Decode_Base64_PNG_Chunk_Rows
              (Segment_Count,
               Chunk_Text'Access,
               Encoded_Length,
               PNG_Length,
               Capture_PNG_Row'Access,
               Data);

            if Row_Copy_Failed
              or else not Data.Decode_Complete
              or else Data.Decoded_Length = 0
              or else Data.Decoded_Row_Stride_Bytes = 0
              or else
                (Header.Kitty_ID > 0
                 and then not Image_Buffer_Ready (Data, Image_Bytes))
            then
               Release_Local;
               return False;
            end if;

            if Header.Kitty_ID > 0 then
               declare
                  Stored_Bytes : RM.Image_Data_Access;
               begin
                  Take_Image_Object
                    (R              => R,
                     ID             => Header.Kitty_ID,
                     Protocol       => RM.Image_Kitty,
                     Raw_Format     => Data.Raw_Format,
                     Pixel_Width    => Data.Pixel_Width,
                     Pixel_Height   => Data.Pixel_Height,
                     Decoded_Length => Data.Decoded_Length,
                     Decoded_Row_Stride_Bytes =>
                       Data.Decoded_Row_Stride_Bytes,
                     Bytes          => Image_Bytes,
                     Stored_Bytes   => Stored_Bytes);
                  if Stored_Bytes /= null then
                     Image_Bytes := Stored_Bytes;
                     Image_Bytes_Owned := False;
                     Borrowed_From_Object := True;
                  end if;
               end;
            end if;

            if Header.Kitty_ID = 0 then
               Encoded_Source := Copy_Chunk_Source;
               Encoded_Source_Owned := Encoded_Source /= null;
               if Encoded_Source = null then
                  Release_Local;
                  return False;
               end if;
            end if;

            declare
               Source_Kind : constant RM.Image_Decoded_Source_Kind :=
                 (if Header.Kitty_ID = 0
                  then RM.Image_Decoded_Source_PNG_Base64
                  else RM.Image_Decoded_Source_Buffer);
            begin
               if Header.Kitty_ID > 0 then
                  Copy_Image_Preview
                    (Image_Bytes,
                     Data.Decoded_Length,
                     Preview_Length,
                     Preview_Bytes);
               end if;

               R.Image_Count := R.Image_Count + 1;
               R.Images (R.Image_Count) :=
                 (X              => X,
                  Y              => Y,
                  Width          =>
                    Float (R.CW * Header.Placeholder_Cols),
                  Height         =>
                    Float (R.CH * Header.Placeholder_Rows),
                  Protocol       => RM.Image_Kitty,
                  Placeholder    => False,
                  Raw_Format     => Data.Raw_Format,
                  Pixel_Width    => Data.Pixel_Width,
                  Pixel_Height   => Data.Pixel_Height,
                  Payload_Length => R.Kitty_Chunk_Length,
                  Staging_Byte_Length => PNG_Length,
                  Payload_Preview_Complete => True,
                  Encoded_Preview_Length => Encoded_Length,
                  Decoded_Byte_Length => Data.Decoded_Length,
                  Decoded_Row_Stride_Bytes =>
                    Data.Decoded_Row_Stride_Bytes,
                  Decoded_Source => Source_Kind,
                  Decoded_Bytes => Image_Bytes,
                  Decoded_Bytes_Owned =>
                    Image_Bytes /= null and then not Borrowed_From_Object,
                  Encoded_Source_Bytes => Encoded_Source,
                  Encoded_Source_Bytes_Owned => Encoded_Source_Owned,
                  Encoded_Source_Length => Encoded_Length,
                  Decoded_Preview_Length => Preview_Length,
                  Decoded_Preview_Bytes => Preview_Bytes,
                  Preview_Decode_Complete => True,
                  Decode_Status => RM.Image_Decode_Ok,
                  Tint           => Graphics_Tint (Terminal.Core.Kitty_Graphics));
            end;
            Encoded_Source_Owned := False;

            Terminal.App.Graphics.Release (Data);
            return True;
         exception
            when Storage_Error =>
               Release_Local;
               return False;
         end;
      end Emit_PNG_Kitty_Chunked;

      function Emit_Image_Object
        (Item   : Terminal.Core.Graphics_Event;
         Header : Terminal.App.Graphics.Graphics_Header) return Boolean
      is
         Object : constant Image_Object_Access :=
           Find_Image_Object (R, Header.Kitty_ID);
         X : constant Float :=
           Float (Content_Margin + (Item.Col - 1) * R.CW);
         Y : constant Float :=
           Float (Content_Margin + (Item.Row - 1) * R.CH);
         Preview_Length : Natural := 0;
         Preview_Bytes : Terminal.Common.Bytes.Byte_Array
           (1 .. RM.Max_Image_Decoded_Preview_Length) := (others => 0);
      begin
         if Object = null
           or else R.Image_Count >= R.Images'Length
         then
            return False;
         end if;

         Copy_Image_Preview
           (Object.Bytes, Object.Decoded_Length, Preview_Length, Preview_Bytes);

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
            Raw_Format     => Object.Raw_Format,
            Pixel_Width    => Object.Pixel_Width,
            Pixel_Height   => Object.Pixel_Height,
            Payload_Length => Item.Payload_Length,
            Staging_Byte_Length => 0,
            Payload_Preview_Complete => True,
            Encoded_Preview_Length => 0,
            Decoded_Byte_Length => Object.Decoded_Length,
            Decoded_Row_Stride_Bytes => Object.Decoded_Row_Stride_Bytes,
            Decoded_Source => RM.Image_Decoded_Source_Buffer,
            Decoded_Bytes => Object.Bytes,
            Decoded_Bytes_Owned => False,
            Encoded_Source_Bytes => null,
            Encoded_Source_Bytes_Owned => False,
            Encoded_Source_Length => 0,
            Decoded_Preview_Length => Preview_Length,
            Decoded_Preview_Bytes => Preview_Bytes,
            Preview_Decode_Complete => True,
            Decode_Status => RM.Image_Decode_Ok,
            Tint           => Graphics_Tint (Item.Protocol));

         return True;
      end Emit_Image_Object;

      function Emit_PNG_Rows
        (Item       : Terminal.Core.Graphics_Event;
         Header     : Terminal.App.Graphics.Graphics_Header;
         Image_Text : String) return Boolean
      is
         From : Natural := 0;
         X : constant Float :=
           Float (Content_Margin + (Item.Col - 1) * R.CW);
         Y : constant Float :=
           Float (Content_Margin + (Item.Row - 1) * R.CH);
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
         Encoded_Source : RM.Image_Data_Access := null;
         Encoded_Source_Owned : Boolean := False;
         Borrowed_From_Object : Boolean := False;
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
            Terminal.App.Graphics.Release (Data);
         end Release_Local;

         procedure Capture_PNG_Row
           (Row_Y : Natural;
            Row   : Terminal.Common.Bytes.Byte_Array;
            Continue : in out Boolean)
         is
         begin
            if Item.Protocol = Terminal.Core.Kitty_Graphics
              and then Header.Kitty_ID > 0
            then
               Capture_Image_Row
                 (Data,
                  Image_Bytes,
                  Image_Bytes_Owned,
                  Row_Y,
                  Row,
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
            if Header.Kitty_Format /= 100 then
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

         Terminal.App.Graphics.Decode_Base64_PNG_Chunk_Rows
           (1,
            PNG_Text'Access,
            Encoded_Length,
            PNG_Length,
            Capture_PNG_Row'Access,
            Data);

         if Row_Copy_Failed
           or else not Data.Decode_Complete
           or else Data.Decoded_Length = 0
           or else Data.Decoded_Row_Stride_Bytes = 0
           or else
             (Item.Protocol = Terminal.Core.Kitty_Graphics
              and then Header.Kitty_ID > 0
              and then not Image_Buffer_Ready (Data, Image_Bytes))
         then
            Release_Local;
            return False;
         end if;

         if Item.Protocol = Terminal.Core.Kitty_Graphics
           and then Header.Kitty_ID > 0
         then
            declare
               Stored_Bytes : RM.Image_Data_Access;
            begin
               Take_Image_Object
                 (R              => R,
                  ID             => Header.Kitty_ID,
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
         end if;

         if Item.Protocol /= Terminal.Core.Kitty_Graphics
           or else Header.Kitty_ID = 0
         then
            Encoded_Source := Copy_Text_Bytes (Image_Text (From .. Image_Text'Last));
            Encoded_Source_Owned := Encoded_Source /= null;
            if Encoded_Source = null then
               Release_Local;
               return False;
            end if;
         end if;

         declare
            Source_Kind : constant RM.Image_Decoded_Source_Kind :=
              (if Item.Protocol = Terminal.Core.Kitty_Graphics
                 and then Header.Kitty_ID > 0
               then RM.Image_Decoded_Source_Buffer
               else RM.Image_Decoded_Source_PNG_Base64);
         begin
            if Item.Protocol = Terminal.Core.Kitty_Graphics
              and then Header.Kitty_ID > 0
            then
               Copy_Image_Preview
                 (Image_Bytes, Data.Decoded_Length, Preview_Length, Preview_Bytes);
            end if;

            R.Image_Count := R.Image_Count + 1;
            R.Images (R.Image_Count) :=
              (X              => X,
               Y              => Y,
               Width          =>
                 Float (R.CW * Header.Placeholder_Cols),
               Height         =>
                 Float (R.CH * Header.Placeholder_Rows),
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
               Decoded_Preview_Bytes => Preview_Bytes,
               Preview_Decode_Complete => True,
               Decode_Status => RM.Image_Decode_Ok,
               Tint           => Graphics_Tint (Item.Protocol));
         end;
         Encoded_Source_Owned := False;

         Terminal.App.Graphics.Release (Data);
         return True;
      exception
         when Storage_Error =>
            Release_Local;
            return False;
      end Emit_PNG_Rows;

      function Emit_Sixel_Rows
        (Item       : Terminal.Core.Graphics_Event;
         Header     : Terminal.App.Graphics.Graphics_Header;
         Image_Text : String) return Boolean
      is
         X : constant Float :=
           Float (Content_Margin + (Item.Col - 1) * R.CW);
         Y : constant Float :=
           Float (Content_Margin + (Item.Row - 1) * R.CH);
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
            Capture_Image_Preview_Row
              (Preview_Length, Preview_Bytes, Row_Y, Row, Continue);
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

         Terminal.App.Graphics.Decode_Sixel_Rows
           (Image_Text, Capture_Sixel_Row'Access, Data);
         if Row_Copy_Failed
           or else not Data.Decode_Complete
           or else Data.Decoded_Length = 0
           or else Data.Decoded_Row_Stride_Bytes = 0
         then
            Release_Local;
            return False;
         end if;

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
                 Float (R.CW * Header.Placeholder_Cols),
               Height         =>
                 Float (R.CH * Header.Placeholder_Rows),
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
               Decoded_Source => RM.Image_Decoded_Source_Sixel_Text,
               Decoded_Bytes => Image_Bytes,
               Decoded_Bytes_Owned => False,
               Encoded_Source_Bytes => Encoded_Source,
               Encoded_Source_Bytes_Owned => Encoded_Source_Owned,
               Encoded_Source_Length => Image_Text'Length,
               Decoded_Preview_Length => Preview_Length,
               Decoded_Preview_Bytes => Preview_Bytes,
               Preview_Decode_Complete => True,
               Decode_Status => RM.Image_Decode_Ok,
               Tint           => Graphics_Tint (Terminal.Core.Sixel_Graphics));
         end;
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
           Float (Content_Margin + (Item.Col - 1) * R.CW);
         Y : constant Float :=
           Float (Content_Margin + (Item.Row - 1) * R.CH);
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
           and then Header.Kitty_ID > 0
           and then Raw_Texture_Ready
           and then Image_Bytes /= null
         then
            declare
               Stored_Bytes : RM.Image_Data_Access;
            begin
               Take_Image_Object
                 (R              => R,
                  ID             => Header.Kitty_ID,
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
            Decoded_Preview_Bytes => Preview_Bytes,
            Preview_Decode_Complete => Data.Decode_Complete,
            Decode_Status =>
              Terminal.App.Graphics.Image_Decode_Status (Data.Decode_Status),
            Tint           => Graphics_Tint (Item.Protocol));
         Terminal.App.Graphics.Release (Data);
      end Emit_Image;

      Text : constant String := Event_Text (Event);
      Header : constant Terminal.App.Graphics.Graphics_Header :=
        Terminal.App.Graphics.Header (Event);
   begin
      if not Event.Pending
        or else Event.Protocol = Terminal.Core.No_Graphics
        or else R.Images = null
        or else R.Image_Count >= R.Images'Length
      then
         return;
      end if;

      if Event.Protocol = Terminal.Core.Kitty_Graphics
        and then Header.Recognized
        and then Header.Kitty_Action = 'd'
        and then not Header.Has_Data
      then
         if Header.Kitty_ID > 0 then
            Delete_Image_Object (R, Header.Kitty_ID);
         else
            Release_Image_Objects (R);
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
      then
         if Header.Kitty_More then
            if R.Kitty_Chunk_Head /= null then
               Append_Kitty_Chunk (Text);
            else
               Store_Kitty_Chunk (Text);
            end if;
            return;
         elsif R.Kitty_Chunk_Head /= null then
            Append_Kitty_Chunk (Text);
            if R.Kitty_Chunk_Head /= null then
               declare
                  Chunked : Terminal.Core.Graphics_Event := Event;
                  Flattened : String_Access := null;
               begin
                  Chunked.Payload_Length := R.Kitty_Chunk_Length;
                  if Emit_Raw_Kitty_Chunked (Chunked) then
                     null;
                  elsif Emit_PNG_Kitty_Chunked (Chunked) then
                     null;
                  else
                     Flattened := Flatten_Kitty_Chunk;
                  end if;
                  if Flattened /= null then
                     Chunked.Payload_Length := R.Kitty_Chunk_Length;
                     Emit_Image (Chunked, Flattened.all);
                     Free_String (Flattened);
                  end if;
               end;
               Clear_Kitty_Chunk;
               return;
            end if;
            return;
         end if;
      elsif R.Kitty_Chunk_Head /= null then
         Clear_Kitty_Chunk;
      end if;

      if Header.Recognized
        and then Header.Has_Data
        and then Event.Protocol = Terminal.Core.Kitty_Graphics
        and then (Header.Kitty_Format = 24 or else Header.Kitty_Format = 32)
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
   end Add_Image;

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
      if R.Text_Runs (R.Text_Run_Count).Script = RM.Script_Emoji then
         R.Color_Emoji_Fallback_Count := R.Color_Emoji_Fallback_Count + 1;
      end if;
   end Add_Text_Run;

   function Cell_Direction
     (Cell : Terminal.Core.Cell) return RM.Text_Run_Direction
   is
      Run : RM.Text_Run_Command :=
        (X                  => 0.0,
         Y                  => 0.0,
         Cell_Width         => Float (Cell_Column_Span (Cell)),
         Cell_Height        => 1.0,
         Cell_Span          => Cell_Column_Span (Cell),
         Color              =>
           Terminal.App.Theme.Built_In
             (Terminal.App.Theme.Default_Dark).Default_FG,
         Bold               => Cell.Style.Bold,
         Italic             => Cell.Style.Italic,
         Codepoints         => (1 => Natural (Cell.Text.Code_Point), others => 0),
         Codepoint_Count    => 1,
         Run_Kind           => RM.Invalid_Run,
         Shape_Status       => RM.Invalid_Run,
         Direction          => RM.Direction_Neutral,
         Script             => RM.Script_Common,
         Shaped_Glyphs      => (others => <>),
         Shaped_Glyph_Count => 0,
         Fallback_Glyphs    => True);
   begin
      return Terminal.App.Text_Shaper.Direction_Of (Run);
   end Cell_Direction;

   function Cell_Script
     (Cell : Terminal.Core.Cell) return RM.Text_Run_Script
   is
      Run : RM.Text_Run_Command :=
        (X                  => 0.0,
         Y                  => 0.0,
         Cell_Width         => Float (Cell_Column_Span (Cell)),
         Cell_Height        => 1.0,
         Cell_Span          => Cell_Column_Span (Cell),
         Color              =>
           Terminal.App.Theme.Built_In
             (Terminal.App.Theme.Default_Dark).Default_FG,
         Bold               => Cell.Style.Bold,
         Italic             => Cell.Style.Italic,
         Codepoints         => (1 => Natural (Cell.Text.Code_Point), others => 0),
         Codepoint_Count    => 1,
         Run_Kind           => RM.Invalid_Run,
         Shape_Status       => RM.Invalid_Run,
         Direction          => RM.Direction_Neutral,
         Script             => RM.Script_Common,
         Shaped_Glyphs      => (others => <>),
         Shaped_Glyph_Count => 0,
         Fallback_Glyphs    => True);
   begin
      return Terminal.App.Text_Shaper.Script_Of (Run);
   end Cell_Script;

   function Can_Coalesce_Range
     (Snapshot : Terminal.Core.Render_Snapshot;
      Row      : Positive;
      First    : Positive;
      Last     : Positive) return Boolean
   is
      Base : constant Terminal.Core.Cell :=
        Terminal.Core.Cell_At (Snapshot, Row, First);
      Effective_Direction : RM.Text_Run_Direction := RM.Direction_Neutral;
      Effective_Script    : RM.Text_Run_Script := RM.Script_Common;
   begin
      for Col in First .. Last loop
         declare
            Cell : constant Terminal.Core.Cell :=
              Terminal.Core.Cell_At (Snapshot, Row, Col);
            Direction : RM.Text_Run_Direction;
            Script    : RM.Text_Run_Script;
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

            Direction := Cell_Direction (Cell);
            if Direction /= RM.Direction_Neutral then
               if Effective_Direction = RM.Direction_Neutral then
                  Effective_Direction := Direction;
               elsif Effective_Direction /= Direction then
                  return False;
               end if;
            end if;

            Script := Cell_Script (Cell);
            if Script /= RM.Script_Common then
               if Effective_Script = RM.Script_Common then
                  Effective_Script := Script;
               elsif Effective_Script /= Script then
                  return False;
               end if;
            end if;
         end;
      end loop;

      return True;
   end Can_Coalesce_Range;

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
                        while Last < Snapshot.Cols
                          and then Last - First + 1 < RM.Max_Text_Run_Codepoints
                          and then Can_Coalesce_Range
                            (Snapshot, Row, First, Positive (Last + 1))
                        loop
                           Last := Last + 1;
                        end loop;
                     end if;

                     Add_Text_Run
                       (R,
                        Snapshot  => Snapshot,
                        Row       => Row,
                        First_Col => First,
                        Last_Col  => Positive (Last),
                        X         =>
                          Float (Content_Margin + (First - 1) * R.CW),
                        Y         =>
                          Float (Content_Margin + (Row - 1) * R.CH),
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
               R.Paragraph_Bidi_Fallback_Count :=
                 R.Paragraph_Bidi_Fallback_Count + 1;
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
      R.Shaped_Glyph_Count := 0;
      R.Shaping_Fallback_Count := 0;
      R.Text_Fallback_Run_Count := 0;
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

   function Is_Drawable (Cell : Terminal.Core.Cell) return Boolean is
   begin
      return Cell.Kind = Terminal.Core.Character
        and then Cell.Text.Width /= Terminal.Core.Width_Zero
        and then Natural (Cell.Text.Code_Point) /= 0;
   end Is_Drawable;

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
      Glyph_Status : constant Textrender.Status_Code :=
        Textrender.Get_Glyph
          (R     => R.Text,
           C     => Textrender.Codepoint (Natural (Codepoint)),
           M     => Metric,
           Style =>
             (if Italic then Textrender.Italic else Textrender.Regular));
      Placement : Textrender.Glyph_Placement;
   begin
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

   function Shaped_Run_Start
     (R : Renderer;
      X : Float;
      Y : Float) return Natural
   is
   begin
      for I in 1 .. R.Text_Run_Count loop
         if Is_Shaped_Draw_Run (R.Text_Runs (I))
           and then R.Text_Runs (I).X = X
           and then R.Text_Runs (I).Y = Y
         then
            return I;
         end if;
      end loop;

      return 0;
   end Shaped_Run_Start;

   function Covered_By_Shaped_Run
     (R : Renderer;
      X : Float;
      Y : Float) return Boolean
   is
   begin
      for I in 1 .. R.Text_Run_Count loop
         if Is_Shaped_Draw_Run (R.Text_Runs (I))
           and then R.Text_Runs (I).Y = Y
           and then X >= R.Text_Runs (I).X
           and then X <
             R.Text_Runs (I).X
             + R.Text_Runs (I).Cell_Width * Float (R.Text_Runs (I).Cell_Span)
         then
            return True;
         end if;
      end loop;

      return False;
   end Covered_By_Shaped_Run;

   procedure Render
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot;
      Status   : out Render_Status)
   is
      Cell_Count     : Natural;
      Rect_Max       : Natural;
      Content_Width  : Natural;
      Content_Height : Natural;
   begin
      if not R.Initialized or else not R.Text_Loaded then
         Set_Render_Status (R, Status, Not_Initialized);
         return;
      elsif Snapshot.Rows = 0 or else Snapshot.Cols = 0 then
         Set_Render_Status (R, Status, Invalid_Snapshot);
         return;
      end if;

      Release_Frame (R);
      R.Missing_Glyph_Count := 0;
      R.Shaped_Glyph_Count := 0;
      R.Shaping_Fallback_Count := 0;
      R.Text_Fallback_Run_Count := 0;
      R.Color_Emoji_Fallback_Count := 0;
      R.Paragraph_Bidi_Fallback_Count := 0;

      Cell_Count := Snapshot.Rows * Snapshot.Cols;
      Rect_Max := Cell_Count * 4 + 2;
      begin
         R.Rectangles := new RM.Rectangle_Array (1 .. Rect_Max);
         R.Glyphs := new RM.Glyph_Array
           (1 ..
              Cell_Count
              * Natural'Max
                  (Terminal.Core.Max_Cluster_Attachments + 1,
                   RM.Max_Shaped_Glyphs_Per_Run)
              * 2);
         R.Images := new RM.Image_Array (1 .. 1);
         R.Text_Runs := new RM.Text_Run_Array (1 .. Cell_Count);
      exception
         when Storage_Error =>
            Release_Frame (R);
            Set_Render_Status (R, Status, Allocation_Failed);
            return;
      end;
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
         Color  => R.Color_Theme.Default_BG);

      Build_Text_Runs (R, Snapshot);

      for Row in 1 .. Snapshot.Rows loop
         for Col in 1 .. Snapshot.Cols loop
            declare
               Cell : constant Terminal.Core.Cell :=
                 Terminal.Core.Cell_At (Snapshot, Row, Col);
               X    : constant Float :=
                 Float (Content_Margin + (Col - 1) * R.CW);
               Y    : constant Float :=
                 Float (Content_Margin + (Row - 1) * R.CH);
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
                     Color  => BG);
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
                     Run_Index           : constant Natural :=
                       Shaped_Run_Start (R, X, Y);
                  begin
                     if Run_Index > 0 then
                        Draw_Shaped_Run
                          (R,
                           Run    => R.Text_Runs (Run_Index),
                           Status => Glyph_Render_Status);
                        if Glyph_Render_Status /= Ok then
                           Set_Render_Status (R, Status, Glyph_Render_Status);
                           return;
                        end if;
                     elsif not Covered_By_Shaped_Run (R, X, Y) then
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

      Add_Image (R, Snapshot.Graphics);

      R.Atlas_Dirty := Textrender.Atlas_Dirty (R.Text);
      if R.Atlas_Dirty then
         Textrender.Clear_Atlas_Dirty (R.Text);
      end if;

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
   end Render;

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
      T : Terminal.App.Theme.Theme) is
   begin
      R.Color_Theme := T;
   end Set_Theme;

   procedure Set_Hovered_Link
     (R    : in out Renderer;
      Link : Terminal.Core.Hyperlink) is
   begin
      R.Hovered_Link := Link;
   end Set_Hovered_Link;

   procedure Finalize (R : in out Renderer) is
   begin
      Release_Frame (R);
      Clear_Kitty_Chunks (R);
      Release_Image_Objects (R);
      Textrender.Reset (R.Text);
      R.Initialized := False;
      R.Has_Context := False;
      R.Text_Loaded := False;
      R.Glyph_Count := 0;
      R.Image_Count := 0;
      R.Text_Run_Count := 0;
      R.Shaped_Glyph_Count := 0;
      R.Shaping_Fallback_Count := 0;
      R.Text_Fallback_Run_Count := 0;
      R.Color_Emoji_Fallback_Count := 0;
      R.Paragraph_Bidi_Fallback_Count := 0;
      R.Vertex_Count := 0;
      R.Missing_Glyph_Count := 0;
      R.Target_Frame_Width := 0;
      R.Target_Frame_Height := 0;
      R.Hovered_Link := (others => <>);
      R.Atlas_Dirty := False;
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

   function Cell_Width (R : Renderer) return Positive is
   begin
      return R.CW;
   end Cell_Width;

   function Cell_Height (R : Renderer) return Positive is
   begin
      return R.CH;
   end Cell_Height;

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
           (if Has_Image then R.Images (R.Image_Count).Decoded_Preview_Bytes
            else (others => 0)),
         Last_Image_Preview_Decode_Complete =>
           Has_Image and then R.Images (R.Image_Count).Preview_Decode_Complete,
         Last_Image_Decode_Status =>
           (if Has_Image then R.Images (R.Image_Count).Decode_Status
            else RM.Image_Decode_Not_Attempted),
         Last_Image_Placeholder =>
           Has_Image and then R.Images (R.Image_Count).Placeholder,
         Last_Text_Run_Count  => R.Text_Run_Count,
         Last_Shaped_Glyph_Count => R.Shaped_Glyph_Count,
         Last_Shaping_Fallback_Count => R.Shaping_Fallback_Count,
         Last_Text_Fallback_Run_Count => R.Text_Fallback_Run_Count,
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
      if Diagnostics.Last_Color_Emoji_Fallback_Count = 0 then
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

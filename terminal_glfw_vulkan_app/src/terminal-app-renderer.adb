with Ada.Unchecked_Deallocation;
with System;

with Terminal.App.Fonts;
with Terminal.App.Render_Model;
with Terminal.App.Vulkan_Submit;

package body Terminal.App.Renderer is
   package RM renames Terminal.App.Render_Model;
   package VS renames Terminal.App.Vulkan_Submit;

   use type Terminal.Core.Cell_Kind;
   use type Terminal.Core.Cell_Width;
   use type Terminal.Core.Color_Kind;
   use type Terminal.Core.Dirty_Row_Array_Access;
   use type RM.Glyph_Array_Access;
   use type RM.Rectangle_Array_Access;
   use type Textrender.Status_Code;
   use type VS.Build_Status;

   Pixel_Size   : constant Positive := 16;
   Atlas_Width  : constant Positive := 1024;
   Atlas_Height : constant Positive := 1024;

   procedure Free_Rectangles is new Ada.Unchecked_Deallocation
     (RM.Rectangle_Array, RM.Rectangle_Array_Access);
   procedure Free_Glyphs is new Ada.Unchecked_Deallocation
     (RM.Glyph_Array, RM.Glyph_Array_Access);

   Palette : constant array (Natural range 0 .. 15) of RM.Pixel_Color :=
     [0  => (0.05, 0.05, 0.06, 1.0),
      1  => (0.80, 0.18, 0.18, 1.0),
      2  => (0.22, 0.68, 0.30, 1.0),
      3  => (0.78, 0.62, 0.22, 1.0),
      4  => (0.25, 0.45, 0.86, 1.0),
      5  => (0.70, 0.36, 0.80, 1.0),
      6  => (0.22, 0.67, 0.72, 1.0),
      7  => (0.78, 0.80, 0.82, 1.0),
      8  => (0.36, 0.38, 0.40, 1.0),
      9  => (1.00, 0.36, 0.32, 1.0),
      10 => (0.45, 0.88, 0.45, 1.0),
      11 => (0.95, 0.78, 0.30, 1.0),
      12 => (0.45, 0.62, 1.00, 1.0),
      13 => (0.88, 0.50, 1.00, 1.0),
      14 => (0.38, 0.88, 0.92, 1.0),
      15 => (0.95, 0.95, 0.95, 1.0)];

   Default_FG : constant RM.Pixel_Color := (0.86, 0.88, 0.88, 1.0);
   Default_BG : constant RM.Pixel_Color := (0.03, 0.035, 0.04, 1.0);
   Cursor_BG  : constant RM.Pixel_Color := (0.86, 0.88, 0.88, 1.0);
   Cursor_FG  : constant RM.Pixel_Color := (0.03, 0.035, 0.04, 1.0);

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

   function XTerm_Indexed_Color (Index : Natural) return RM.Pixel_Color is
   begin
      if Index <= Palette'Last then
         return Palette (Index);
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
     (Color      : Terminal.Core.Color;
      Default    : RM.Pixel_Color)
      return RM.Pixel_Color
   is
   begin
      case Color.Kind is
         when Terminal.Core.Default =>
            return Default;
         when Terminal.Core.Indexed =>
            return XTerm_Indexed_Color (Color.Index);
         when Terminal.Core.RGB =>
            return
              (R => Float (Color.R) / 255.0,
               G => Float (Color.G) / 255.0,
               B => Float (Color.B) / 255.0,
               A => 1.0);
      end case;
   end Resolve_Color;

   function Foreground (Cell : Terminal.Core.Cell) return RM.Pixel_Color is
   begin
      if Cell.Style.Inverse then
         return Resolve_Color (Cell.Style.Background, Default_BG);
      else
         return Resolve_Color (Cell.Style.Foreground, Default_FG);
      end if;
   end Foreground;

   function Background (Cell : Terminal.Core.Cell) return RM.Pixel_Color is
   begin
      if Cell.Style.Inverse then
         return Resolve_Color (Cell.Style.Foreground, Default_FG);
      else
         return Resolve_Color (Cell.Style.Background, Default_BG);
      end if;
   end Background;

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
      R.Rectangle_Count := 0;
      R.Glyph_Count := 0;
      R.Vertex_Count := 0;
      R.Last_Cell_Count := 0;
      R.Last_Dirty_Rows := 0;
      R.Last_Frame_Width := 0;
      R.Last_Frame_Height := 0;
      VS.Release (R.Batch);
   end Release_Frame;

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

   procedure Initialize_Text
     (R      : in out Renderer;
      Status  : out Init_Status)
   is
      Font_Path   : constant String := Terminal.App.Fonts.Default_Font_Path;
      Text_Status : Textrender.Status_Code;
   begin
      R.CW := 8;
      R.CH := 16;
      R.Glyph_Count := 0;
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
         end if;
      end;

      R.CH := Positive'Max
        (R.CH, Ceiling_Positive (Textrender.Line_Height (R.Text)));

      for Path of Terminal.App.Fonts.Fallback_Font_Paths loop
         declare
            Ignored : constant Textrender.Status_Code :=
              Textrender.Add_Fallback_Font
                (R    => R.Text,
                 Path => Terminal.App.Fonts.To_String (Path));
         begin
            null;
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

      Cell_Count := Snapshot.Rows * Snapshot.Cols;
      Rect_Max := Cell_Count * 2 + 2;
      begin
         R.Rectangles := new RM.Rectangle_Array (1 .. Rect_Max);
         R.Glyphs := new RM.Glyph_Array (1 .. Cell_Count * 2);
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
         Color  => Default_BG);

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
               FG : constant RM.Pixel_Color :=
                 (if Cursor_Cell then Cursor_FG else Foreground (Cell));
               BG : constant RM.Pixel_Color := Background (Cell);
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
                     Add_Rectangle
                       (R,
                        X      => X,
                        Y      => Cursor_Block_Y (R, Y),
                        Width  => Float (Cell_W),
                        Height => Float (Cursor_Block_Height (R)),
                        Color  => Cursor_BG);
                  end if;
               end if;

               if Is_Drawable (Cell) then
                  declare
                     Metric       : Textrender.Glyph_Metric;
                     Glyph_Status : constant Textrender.Status_Code :=
                       Textrender.Get_Glyph
                         (R     => R.Text,
                          C     => Textrender.Codepoint (Natural (Cell.Text.Code_Point)),
                          M     => Metric,
                          Style =>
                            (if Cell.Style.Italic
                             then Textrender.Italic
                             else Textrender.Regular));
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
                                   Color     => FG,
                                   Codepoint => Natural (Cell.Text.Code_Point));
                              if Cell.Style.Bold then
                                 Placement.X := Placement.X + 1.0;
                                 Add_Glyph
                                    (R,
                                     Placement => Placement,
                                     Metric    => Metric,
                                     Color     => FG,
                                     Codepoint => Natural (Cell.Text.Code_Point));
                              end if;
                           end if;
                        when others =>
                           Set_Render_Status (R, Status, Glyph_Load_Failed);
                           return;
                     end case;
                  end;

                  if Cell.Style.Underline then
                     Add_Rectangle
                       (R,
                        X      => X,
                        Y      => Y + Float (R.CH - 2),
                        Width  => Float (Cell_W),
                        Height => 1.0,
                        Color  => FG);
                  end if;
               end if;
            end;
         end loop;
      end loop;

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

   procedure Finalize (R : in out Renderer) is
   begin
      Release_Frame (R);
      Textrender.Reset (R.Text);
      R.Initialized := False;
      R.Has_Context := False;
      R.Text_Loaded := False;
      R.Glyph_Count := 0;
      R.Vertex_Count := 0;
      R.Missing_Glyph_Count := 0;
      R.Target_Frame_Width := 0;
      R.Target_Frame_Height := 0;
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
   begin
      return
        (Initialized          => R.Initialized,
         Text_Loaded          => R.Text_Loaded,
         Last_Cell_Count      => R.Last_Cell_Count,
         Last_Dirty_Rows      => R.Last_Dirty_Rows,
         Last_Rectangle_Count => R.Rectangle_Count,
         Last_Glyph_Count     => R.Glyph_Count,
         Last_Vertex_Count    => R.Vertex_Count,
         Missing_Glyph_Count  => R.Missing_Glyph_Count,
         Atlas_Dirty          => R.Atlas_Dirty,
         Last_Render_Status   => R.Last_Render_Status);
   end Diagnostics;

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
         Atlas_Width     => Width,
         Atlas_Height    => Height,
         Atlas_Pixels    => Address,
         Atlas_Bytes     => Width * Height,
         Atlas_Dirty     => R.Atlas_Dirty);
   end Last_Frame;
end Terminal.App.Renderer;

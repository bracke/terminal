with Terminal.App.Hyperlinks;
with Terminal.App.Image_Colors;

package body Terminal.App.Renderer.Visual_Style is
   package RM renames Terminal.App.Render_Model;

   use type Terminal.Core.Cell_Width;
   use type Terminal.Core.Color_Kind;
   use type Terminal.Core.Cursor_Shape;

   function Graphics_Protocol
     (Protocol : Terminal.Core.Graphics_Protocol_Kind)
      return RM.Image_Protocol is
     (case Protocol is
         when Terminal.Core.Sixel_Graphics  => RM.Image_Sixel,
         when Terminal.Core.Kitty_Graphics  => RM.Image_Kitty,
         when Terminal.Core.ITerm2_Graphics => RM.Image_ITerm2,
         when Terminal.Core.No_Graphics     => RM.Image_Sixel);

   function Graphics_Tint
     (Protocol : Terminal.Core.Graphics_Protocol_Kind)
      return RM.Pixel_Color is
     (case Protocol is
         when Terminal.Core.Sixel_Graphics =>
           (R => 0.10, G => 0.55, B => 0.90, A => 1.0),
         when Terminal.Core.Kitty_Graphics =>
           (R => 0.30, G => 0.75, B => 0.30, A => 1.0),
         when Terminal.Core.ITerm2_Graphics =>
           (R => 0.85, G => 0.35, B => 0.70, A => 1.0),
         when Terminal.Core.No_Graphics =>
           (R => 0.50, G => 0.50, B => 0.50, A => 1.0));

   function XTerm_Indexed_Color
     (R : Renderer; Index : Natural) return RM.Pixel_Color is
     (Terminal.App.Image_Colors.XTerm_Indexed
        (R.View_State.Color_Theme, Index));

   function Kitty_Indexed_Color
     (R : Renderer; Index : Natural) return RM.Pixel_Color is
     (Terminal.App.Image_Colors.Kitty_Indexed
        (R.View_State.Color_Theme, Index));

   function Color_Byte
     (Value : Float) return Terminal.Common.Bytes.Byte
   renames Terminal.App.Image_Colors.Color_Byte;

   function Expand_Kitty_Indexed
     (R              : Renderer;
      Indexed_Format : Natural;
      Pixel_Width    : Natural;
      Pixel_Height   : Natural;
      Source         : Terminal.Common.Bytes.Byte_Array;
      Target         : in out Terminal.Common.Bytes.Byte_Array) return Boolean
   is (Terminal.App.Image_Colors.Expand_Kitty_Indexed
         (R.View_State.Color_Theme,
          Indexed_Format,
          Pixel_Width,
          Pixel_Height,
          Source,
          Target));

   function Resolve_Color
     (R       : Renderer;
      Color   : Terminal.Core.Color;
      Default : RM.Pixel_Color) return RM.Pixel_Color
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
     (R : Renderer; Cell : Terminal.Core.Cell_Content) return RM.Pixel_Color
   is
      Color : RM.Pixel_Color;
   begin
      if not Cell.Style.Inverse
        and then Cell.Style.Bold
        and then Cell.Style.Foreground.Kind = Terminal.Core.Indexed
        and then Cell.Style.Foreground.Index <= 7
      then
         Color := XTerm_Indexed_Color (R, Cell.Style.Foreground.Index + 8);
      elsif Cell.Style.Inverse then
         Color := Resolve_Color
           (R, Cell.Style.Background, R.View_State.Color_Theme.Default_BG);
      else
         Color := Resolve_Color
           (R, Cell.Style.Foreground, R.View_State.Color_Theme.Default_FG);
      end if;
      return (if Cell.Style.Faint then Dim_Color (Color) else Color);
   end Foreground;

   function Background
     (R : Renderer; Cell : Terminal.Core.Cell_Content) return RM.Pixel_Color is
     (if Cell.Style.Inverse
      then Resolve_Color
        (R, Cell.Style.Foreground, R.View_State.Color_Theme.Default_FG)
      else Resolve_Color
        (R, Cell.Style.Background, R.View_State.Color_Theme.Default_BG));

   function Has_Non_Default_Background
     (Cell : Terminal.Core.Cell_Content) return Boolean is
     (Cell.Style.Inverse
      or else Cell.Style.Background.Kind /= Terminal.Core.Default);

   function Underline_Color
     (R          : Renderer;
      Cell       : Terminal.Core.Cell_Content;
      Foreground : RM.Pixel_Color) return RM.Pixel_Color is
     (Resolve_Color (R, Cell.Style.Underline_Color, Foreground));

   function Is_Cursor_Cell
     (Snapshot : Terminal.Core.Render_Snapshot;
      Row      : Positive;
      Col      : Positive) return Boolean is
     (Snapshot.Cursor.Visible
      and then Snapshot.Cursor.Row = Row
      and then Snapshot.Cursor.Col = Col);

   function Cursor_Block_Height (R : Renderer) return Positive is
     (Positive'Min (R.Text_State.CH, Default_Font_Pixel_Size));

   function Cursor_Block_Y (R : Renderer; Cell_Y : Float) return Float is
     (Cell_Y + Float (R.Text_State.CH - Cursor_Block_Height (R)) / 2.0);

   function Cursor_Bar_Width (R : Renderer) return Positive is
     (Positive'Max (1, Positive'Min (3, R.Text_State.CW)));

   function Cursor_Underline_Height (R : Renderer) return Positive is
     (Positive'Max (1, Positive'Min (3, R.Text_State.CH)));

   function Is_Block_Cursor
     (Snapshot : Terminal.Core.Render_Snapshot;
      Row      : Positive;
      Col      : Positive) return Boolean is
     (Is_Cursor_Cell (Snapshot, Row, Col)
      and then Snapshot.Cursor.Shape = Terminal.Core.Cursor_Block);

   function Cell_Column_Span (Cell : Terminal.Core.Cell_Content) return Positive is
     (if Cell.Text.Width = Terminal.Core.Width_Two then 2 else 1);

   function Is_Hovered_Link_Cell
     (R        : Renderer;
      Snapshot : Terminal.Core.Render_Snapshot;
      Row      : Positive;
      Col      : Positive) return Boolean is
     (R.View_State.Hovered_Link.Active
      and then Terminal.Core.Cell_Link_Equals
        (Snapshot, Row, Col, R.View_State.Hovered_Link));
end Terminal.App.Renderer.Visual_Style;

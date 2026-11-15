with Textrender;

private package Terminal.App.Renderer.Drawing_Commands is
   procedure Add_Rectangle
     (R      : in out Renderer;
      X      : Float;
      Y      : Float;
      Width  : Float;
      Height : Float;
      Color  : Terminal.App.Render_Model.Pixel_Color;
      Layer  : Terminal.App.Render_Model.Rectangle_Layer :=
        Terminal.App.Render_Model.Rectangle_Foreground);

   procedure Add_Glyph
     (R         : in out Renderer;
      Placement : Textrender.Glyph_Placement;
      Metric    : Textrender.Glyph_Metric;
      Color     : Terminal.App.Render_Model.Pixel_Color;
      Codepoint : Natural);

   procedure Add_Underline
     (R      : in out Renderer;
      Kind   : Terminal.Core.Underline_Style;
      X      : Float;
      Y      : Float;
      Width  : Float;
      Color  : Terminal.App.Render_Model.Pixel_Color);

   function Add_Colour_Glyph
     (R         : in out Renderer;
      Codepoint : Terminal.Common.Code_Point;
      X         : Float;
      Y         : Float) return Boolean;
end Terminal.App.Renderer.Drawing_Commands;

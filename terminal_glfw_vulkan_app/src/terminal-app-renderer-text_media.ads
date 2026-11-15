with Terminal.Common;
with Terminal.App.Render_Model;
with Terminal.Core;
with Textrender;

private package Terminal.App.Renderer.Text_Media is
   function Ceiling_Positive (Value : Float) return Positive;
   function Measured_Cell_Width
     (Text : in out Textrender.Renderer; Fallback : Positive) return Positive;
   function Is_Emoji_Scalar
     (Codepoint : Terminal.Common.Code_Point) return Boolean;
   function Colour_PNG_Extent
     (Data   : Textrender.Encoded_Image;
      Width  : out Natural;
      Height : out Natural) return Boolean;
   function Is_Drawable (Cell : Terminal.Core.Cell_Content) return Boolean;
   procedure Cell_Properties
     (Cell      : Terminal.Core.Cell_Content;
      Direction : out Terminal.App.Render_Model.Text_Run_Direction;
      Script    : out Terminal.App.Render_Model.Text_Run_Script);
   function Cell_Joins_Run
     (Snapshot  : Terminal.Core.Render_Snapshot;
      Row       : Positive;
      Col       : Positive;
      Base      : Terminal.Core.Cell_Content;
      Direction : in out Terminal.App.Render_Model.Text_Run_Direction;
      Script    : in out Terminal.App.Render_Model.Text_Run_Script)
      return Boolean;
end Terminal.App.Renderer.Text_Media;

with Terminal.Common.Bytes;
with Terminal.Core;
with Terminal.App.Render_Model;

private package Terminal.App.Renderer.Visual_Style is
   function Graphics_Protocol
     (Protocol : Terminal.Core.Graphics_Protocol_Kind)
      return Terminal.App.Render_Model.Image_Protocol;
   function Graphics_Tint
     (Protocol : Terminal.Core.Graphics_Protocol_Kind)
      return Terminal.App.Render_Model.Pixel_Color;
   function XTerm_Indexed_Color
     (R : Renderer; Index : Natural)
      return Terminal.App.Render_Model.Pixel_Color;
   function Kitty_Indexed_Color
     (R : Renderer; Index : Natural)
      return Terminal.App.Render_Model.Pixel_Color;
   function Color_Byte
     (Value : Float) return Terminal.Common.Bytes.Byte;
   function Expand_Kitty_Indexed
     (R              : Renderer;
      Indexed_Format : Natural;
      Pixel_Width    : Natural;
      Pixel_Height   : Natural;
      Source         : Terminal.Common.Bytes.Byte_Array;
      Target         : in out Terminal.Common.Bytes.Byte_Array)
      return Boolean;
   function Foreground
     (R : Renderer; Cell : Terminal.Core.Cell_Content)
      return Terminal.App.Render_Model.Pixel_Color;
   function Background
     (R : Renderer; Cell : Terminal.Core.Cell_Content)
      return Terminal.App.Render_Model.Pixel_Color;
   function Has_Non_Default_Background
     (Cell : Terminal.Core.Cell_Content) return Boolean;
   function Underline_Color
     (R          : Renderer;
      Cell       : Terminal.Core.Cell_Content;
      Foreground : Terminal.App.Render_Model.Pixel_Color)
      return Terminal.App.Render_Model.Pixel_Color;
   function Is_Cursor_Cell
     (Snapshot : Terminal.Core.Render_Snapshot;
      Row      : Positive;
      Col      : Positive) return Boolean;
   function Cursor_Block_Height (R : Renderer) return Positive;
   function Cursor_Block_Y (R : Renderer; Cell_Y : Float) return Float;
   function Cursor_Bar_Width (R : Renderer) return Positive;
   function Cursor_Underline_Height (R : Renderer) return Positive;
   function Is_Block_Cursor
     (Snapshot : Terminal.Core.Render_Snapshot;
      Row      : Positive;
      Col      : Positive) return Boolean;
   function Cell_Column_Span (Cell : Terminal.Core.Cell_Content) return Positive;
   function Is_Hovered_Link_Cell
     (R        : Renderer;
      Snapshot : Terminal.Core.Render_Snapshot;
      Row      : Positive;
      Col      : Positive) return Boolean;
end Terminal.App.Renderer.Visual_Style;

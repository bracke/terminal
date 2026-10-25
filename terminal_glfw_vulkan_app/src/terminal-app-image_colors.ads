with Terminal.App.Render_Model;
with Terminal.App.Theme;
with Terminal.Common.Bytes;

package Terminal.App.Image_Colors is
   function XTerm_Indexed
     (Theme : Terminal.App.Theme.Theme;
      Index : Natural) return Terminal.App.Render_Model.Pixel_Color;

   function Kitty_Indexed
     (Theme : Terminal.App.Theme.Theme;
      Index : Natural) return Terminal.App.Render_Model.Pixel_Color;

   function Color_Byte
     (Value : Float) return Terminal.Common.Bytes.Byte;

   function Expand_Kitty_Indexed
     (Theme          : Terminal.App.Theme.Theme;
      Indexed_Format : Natural;
      Pixel_Width    : Natural;
      Pixel_Height   : Natural;
      Source         : Terminal.App.Render_Model.Image_Data_View;
      Target         : Terminal.App.Render_Model.Image_Data_Access)
      return Boolean;
end Terminal.App.Image_Colors;

separate (Terminal.App.Graphics)
function Header_Text
  (Protocol : Terminal.Core.Graphics_Protocol_Kind;
   Text     : String) return Graphics_Header is
begin
   return
     (case Protocol is
         when Terminal.Core.Sixel_Graphics  => Parse_Sixel_Header (Text),
         when Terminal.Core.Kitty_Graphics  => Parse_Kitty_Header (Text),
         when Terminal.Core.ITerm2_Graphics => Parse_ITerm2_Header (Text),
         when Terminal.Core.No_Graphics     => (others => <>));
end Header_Text;

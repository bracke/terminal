package body Terminal.App.Graphics.Capability_Reporting is
   function Capability
     (Protocol            : Graphics_Protocol;
      Rendering_Available : Boolean) return Protocol_Capability is
   begin
      case Protocol is
         when Kitty | Sixel | ITerm2 =>
            return
              (Recognized => True,
               Decoded    => True,
               Rendered   => Rendering_Available);
      end case;
   end Capability;

   function Color_Emoji
     (Color_Font_Available : Boolean) return Emoji_Capability is
     (Cluster_Preserved    => True,
      Monochrome_Fallback  => True,
      Color_Glyph_Rendered => Color_Font_Available);

   function Name (Protocol : Graphics_Protocol) return String is
   begin
      case Protocol is
         when Sixel =>
            return "sixel";
         when Kitty =>
            return "kitty";
         when ITerm2 =>
            return "iTerm2";
      end case;
   end Name;

   function Name
     (Protocol : Terminal.Core.Graphics_Protocol_Kind) return String is
   begin
      case Protocol is
         when Terminal.Core.No_Graphics =>
            return "";
         when Terminal.Core.Sixel_Graphics =>
            return "sixel";
         when Terminal.Core.Kitty_Graphics =>
            return "kitty";
         when Terminal.Core.ITerm2_Graphics =>
            return "iTerm2";
      end case;
   end Name;

   function Status_Label
     (Protocol            : Graphics_Protocol;
      Rendering_Available : Boolean) return String is
   begin
      case Protocol is
         when Sixel =>
            return (if Rendering_Available
                    then "sixel decode and raster texture rendering available"
                    else "sixel decode support; renderer availability unknown");
         when Kitty =>
            return (if Rendering_Available
                    then "kitty RGB/RGBA/indexed/PNG/JPEG/GIF rendering available"
                    else "kitty RGB/RGBA/indexed/PNG/JPEG/GIF decode support");
         when ITerm2 =>
            return (if Rendering_Available
                    then "iTerm2 PNG/JPEG/GIF/PICT rendering available"
                    else "iTerm2 PNG/JPEG/GIF/PICT decode support");
      end case;
   end Status_Label;
end Terminal.App.Graphics.Capability_Reporting;

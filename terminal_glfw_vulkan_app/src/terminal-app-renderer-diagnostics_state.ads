private package Terminal.App.Renderer.Diagnostics_State is
   procedure Clear_Last_Media (R : in out Renderer);
   function Capture
     (R : Renderer; Include_Image_Preview : Boolean)
      return Renderer_Diagnostics;
   function Equivalent (Left, Right : Renderer_Diagnostics) return Boolean;
   function Color_Emoji_Label
     (Diagnostics : Renderer_Diagnostics) return String;
   function Paragraph_Bidi_Label
     (Diagnostics : Renderer_Diagnostics) return String;
   function Image_Label
     (Diagnostics : Renderer_Diagnostics) return String;
   function Media_Label
     (Diagnostics : Renderer_Diagnostics) return String;
end Terminal.App.Renderer.Diagnostics_State;

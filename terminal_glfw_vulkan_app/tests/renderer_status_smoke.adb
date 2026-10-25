with AUnit.Assertions;

with Terminal.App.Renderer;

procedure Renderer_Status_Smoke is
   use AUnit.Assertions;

   Diagnostics : Terminal.App.Renderer.Renderer_Diagnostics := (others => <>);
begin
   Assert
     (Terminal.App.Renderer.Color_Emoji_Status_Label (Diagnostics) = "",
      "empty color emoji status label");
   Assert
     (Terminal.App.Renderer.Paragraph_Bidi_Status_Label (Diagnostics) = "",
      "empty paragraph BiDi status label");
   Assert
     (Terminal.App.Renderer.Image_Status_Label (Diagnostics) = "",
      "empty image status label");

   Diagnostics.Last_Color_Emoji_Fallback_Count := 1;
   Assert
     (Terminal.App.Renderer.Color_Emoji_Status_Label (Diagnostics) =
        "Color emoji rendered with monochrome fallback",
      "color emoji fallback status label");
   Diagnostics.Last_Color_Glyph_Count := 1;
   Assert
     (Terminal.App.Renderer.Color_Emoji_Status_Label (Diagnostics) =
        "Color emoji glyphs rendered with fallback",
      "mixed color emoji status label");
   Diagnostics.Last_Color_Emoji_Fallback_Count := 0;
   Assert
     (Terminal.App.Renderer.Color_Emoji_Status_Label (Diagnostics) =
        "Color emoji glyphs rendered",
      "color emoji rendered status label");

   Diagnostics.Last_Paragraph_Bidi_Fallback_Count := 1;
   Assert
     (Terminal.App.Renderer.Paragraph_Bidi_Status_Label (Diagnostics) =
        "Paragraph BiDi reordering not applied",
      "paragraph BiDi fallback status label");
end Renderer_Status_Smoke;

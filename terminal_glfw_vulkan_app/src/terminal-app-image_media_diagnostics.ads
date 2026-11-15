with Terminal.App.Image_Media;

private package Terminal.App.Image_Media_Diagnostics is
   procedure Initialize
     (Target     : out Terminal.App.Image_Media.Decode_Diagnostic;
      Present    : Boolean;
      Identifier : String);

   procedure Replace_Identifier
     (Target     : in out Terminal.App.Image_Media.Decode_Diagnostic;
      Identifier : String);
end Terminal.App.Image_Media_Diagnostics;

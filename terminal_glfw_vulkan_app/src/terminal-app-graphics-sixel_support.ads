with Terminal.Common.Bytes;
with Terminal.Common.Sixel;

private package Terminal.App.Graphics.Sixel_Support is
   subtype Sixel_Info is Terminal.Common.Sixel.Analysis;

   function Byte_From_Percent
     (Value : Natural) return Terminal.Common.Bytes.Byte;
   function Sixel_HLS_Color
     (Hue, Lightness, Saturation : Natural) return Sixel_Color;
   procedure Skip_Sixel_Number (Text : String; Index : in out Natural);
   function Read_Sixel_Number
     (Text : String; Index : in out Natural) return Natural;
   function Analyze_Sixel (Text : String) return Sixel_Info renames
     Terminal.Common.Sixel.Analyze;
end Terminal.App.Graphics.Sixel_Support;

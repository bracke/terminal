with Terminal.Common.Bytes;
with Terminal.Core;

private package Terminal.App.Renderer.Theme_Pixels is
   procedure Fill_Background
     (Target : in out Terminal.Common.Bytes.Byte_Array;
      Width  : Positive;
      Height : Positive;
      Color  : Terminal.Core.Graphics_ID);

   procedure Composite_Pixel
     (Target : in out Terminal.Common.Bytes.Byte_Array;
      Index  : Positive;
      SR     : Natural;
      SG     : Natural;
      SB     : Natural;
      SA     : Natural;
      Mode   : Natural);

   procedure Composite_Region
     (Target        : in out Terminal.Common.Bytes.Byte_Array;
      Source        : Terminal.Common.Bytes.Byte_Array;
      Canvas_Width  : Positive;
      Source_X      : Natural;
      Source_Y      : Natural;
      Target_X      : Natural;
      Target_Y      : Natural;
      Region_Width  : Positive;
      Region_Height : Positive;
      Mode          : Natural);
end Terminal.App.Renderer.Theme_Pixels;

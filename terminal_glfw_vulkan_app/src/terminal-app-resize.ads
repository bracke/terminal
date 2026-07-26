package Terminal.App.Resize is
   procedure Pixels_To_Cells
     (Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Cell_Width   : Positive;
      Cell_Height  : Positive;
      Margin       : Natural := 0;
      Rows         : out Positive;
      Cols         : out Positive);

   procedure Startup_Cells
     (Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Cell_Width   : Positive;
      Cell_Height  : Positive;
      Margin       : Natural := 0;
      Default_Rows : Positive := 24;
      Default_Cols : Positive := 80;
      Rows         : out Positive;
      Cols         : out Positive);
end Terminal.App.Resize;

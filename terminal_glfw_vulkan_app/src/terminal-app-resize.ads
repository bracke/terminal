package Terminal.App.Resize is
   Max_Status_Label_Length : constant := 96;

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

   function Grid_Status_Label
     (Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Cell_Width   : Positive;
      Cell_Height  : Positive;
      Margin       : Natural := 0) return String;

   function Startup_Status_Label
     (Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Cell_Width   : Positive;
      Cell_Height  : Positive;
      Margin       : Natural := 0;
      Default_Rows : Positive := 24;
      Default_Cols : Positive := 80) return String;
end Terminal.App.Resize;

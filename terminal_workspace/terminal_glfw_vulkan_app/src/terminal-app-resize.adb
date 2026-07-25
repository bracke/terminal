package body Terminal.App.Resize is
   procedure Pixels_To_Cells
     (Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Cell_Width   : Positive;
      Cell_Height  : Positive;
      Rows         : out Positive;
      Cols         : out Positive)
   is
   begin
      Cols := Positive'Max (1, Pixel_Width / Cell_Width);
      Rows := Positive'Max (1, Pixel_Height / Cell_Height);
   end Pixels_To_Cells;
end Terminal.App.Resize;


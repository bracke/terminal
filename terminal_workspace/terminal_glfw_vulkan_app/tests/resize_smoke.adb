with AUnit.Assertions;

with Terminal.App.Resize;

procedure Resize_Smoke is
   use AUnit.Assertions;

   Rows : Positive;
   Cols : Positive;
begin
   Terminal.App.Resize.Pixels_To_Cells
     (Pixel_Width  => 960,
      Pixel_Height => 600,
      Cell_Width   => 8,
      Cell_Height  => 16,
      Rows         => Rows,
      Cols         => Cols);
   Assert (Rows = 37, "600 px at 16 px/cell");
   Assert (Cols = 120, "960 px at 8 px/cell");

   Terminal.App.Resize.Pixels_To_Cells
     (Pixel_Width  => 1,
      Pixel_Height => 1,
      Cell_Width   => 8,
      Cell_Height  => 16,
      Rows         => Rows,
      Cols         => Cols);
   Assert (Rows = 1, "tiny height clamps to one row");
   Assert (Cols = 1, "tiny width clamps to one col");

   Terminal.App.Resize.Pixels_To_Cells
     (Pixel_Width  => 0,
      Pixel_Height => 0,
      Cell_Width   => 8,
      Cell_Height  => 16,
      Rows         => Rows,
      Cols         => Cols);
   Assert (Rows = 1, "zero height clamps to one row");
   Assert (Cols = 1, "zero width clamps to one col");
end Resize_Smoke;

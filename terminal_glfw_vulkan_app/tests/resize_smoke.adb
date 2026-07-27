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
      Margin       => 0,
      Rows         => Rows,
      Cols         => Cols);
   Assert (Rows = 37, "600 px at 16 px/cell");
   Assert (Cols = 120, "960 px at 8 px/cell");
   Assert
     (Terminal.App.Resize.Grid_Status_Label
        (Pixel_Width  => 960,
         Pixel_Height => 600,
         Cell_Width   => 8,
         Cell_Height  => 16,
         Margin       => 0) =
      "Grid 37x120 from 960x600 px",
      "grid status label");
   Assert
     (Terminal.App.Resize.Grid_Status_Label
        (Pixel_Width  => 960,
         Pixel_Height => 600,
         Cell_Width   => 8,
         Cell_Height  => 16)'Length <=
      Terminal.App.Resize.Max_Status_Label_Length,
      "grid status label should be bounded");

   Terminal.App.Resize.Pixels_To_Cells
     (Pixel_Width  => 1,
      Pixel_Height => 1,
      Cell_Width   => 8,
      Cell_Height  => 16,
      Margin       => 0,
      Rows         => Rows,
      Cols         => Cols);
   Assert (Rows = 1, "tiny height clamps to one row");
   Assert (Cols = 1, "tiny width clamps to one col");
   Assert
     (Terminal.App.Resize.Grid_Status_Label
        (Pixel_Width  => 1,
         Pixel_Height => 1,
         Cell_Width   => 8,
         Cell_Height  => 16) =
      "Grid 1x1 from 1x1 px",
      "tiny grid status label");

   Terminal.App.Resize.Pixels_To_Cells
     (Pixel_Width  => 0,
      Pixel_Height => 0,
      Cell_Width   => 8,
      Cell_Height  => 16,
      Margin       => 0,
      Rows         => Rows,
      Cols         => Cols);
   Assert (Rows = 1, "zero height clamps to one row");
   Assert (Cols = 1, "zero width clamps to one col");

   Terminal.App.Resize.Pixels_To_Cells
     (Pixel_Width  => 960,
      Pixel_Height => 600,
      Cell_Width   => 8,
      Cell_Height  => 16,
      Margin       => 6,
      Rows         => Rows,
      Cols         => Cols);
   Assert (Rows = 36, "vertical margin reduces usable rows");
   Assert (Cols = 118, "horizontal margin reduces usable cols");

   Terminal.App.Resize.Startup_Cells
     (Pixel_Width  => 960,
      Pixel_Height => 600,
      Cell_Width   => 8,
      Cell_Height  => 16,
      Margin       => 6,
      Rows         => Rows,
      Cols         => Cols);
   Assert (Rows = 36, "startup should use framebuffer-derived rows");
   Assert (Cols = 118, "startup should use framebuffer-derived cols");
   Assert
     (Terminal.App.Resize.Startup_Status_Label
        (Pixel_Width  => 960,
         Pixel_Height => 600,
         Cell_Width   => 8,
         Cell_Height  => 16,
         Margin       => 6) =
      "Startup grid 36x118 from framebuffer",
      "startup framebuffer status label");

   Terminal.App.Resize.Startup_Cells
     (Pixel_Width  => 0,
      Pixel_Height => 600,
      Cell_Width   => 8,
      Cell_Height  => 16,
      Margin       => 6,
      Default_Rows => 24,
      Default_Cols => 80,
      Rows         => Rows,
      Cols         => Cols);
   Assert (Rows = 24, "startup zero framebuffer width falls back to rows");
   Assert (Cols = 80, "startup zero framebuffer width falls back to cols");
   Assert
     (Terminal.App.Resize.Startup_Status_Label
        (Pixel_Width  => 0,
         Pixel_Height => 600,
         Cell_Width   => 8,
         Cell_Height  => 16,
         Margin       => 6,
         Default_Rows => 24,
         Default_Cols => 80) =
      "Startup grid 24x80 fallback",
      "startup fallback status label");
   Assert
     (Terminal.App.Resize.Startup_Status_Label
        (Pixel_Width  => 0,
         Pixel_Height => 600,
         Cell_Width   => 8,
         Cell_Height  => 16,
         Margin       => 6,
         Default_Rows => 24,
         Default_Cols => 80)'Length <=
      Terminal.App.Resize.Max_Status_Label_Length,
      "startup status label should be bounded");

   Terminal.App.Resize.Startup_Cells
     (Pixel_Width  => 960,
      Pixel_Height => 0,
      Cell_Width   => 8,
      Cell_Height  => 16,
      Margin       => 6,
      Default_Rows => 30,
      Default_Cols => 100,
      Rows         => Rows,
      Cols         => Cols);
   Assert (Rows = 30, "startup zero framebuffer height falls back to rows");
   Assert (Cols = 100, "startup zero framebuffer height falls back to cols");
end Resize_Smoke;

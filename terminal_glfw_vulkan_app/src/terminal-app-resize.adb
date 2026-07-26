package body Terminal.App.Resize is
   procedure Pixels_To_Cells
     (Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Cell_Width   : Positive;
      Cell_Height  : Positive;
      Margin       : Natural := 0;
      Rows         : out Positive;
      Cols         : out Positive)
   is
      Horizontal_Margin : constant Natural := Margin * 2;
      Vertical_Margin   : constant Natural := Margin * 2;
      Usable_Width      : constant Natural :=
        (if Pixel_Width > Horizontal_Margin
         then Pixel_Width - Horizontal_Margin
         else 0);
      Usable_Height     : constant Natural :=
        (if Pixel_Height > Vertical_Margin
         then Pixel_Height - Vertical_Margin
         else 0);
   begin
      Cols := Positive'Max (1, Usable_Width / Cell_Width);
      Rows := Positive'Max (1, Usable_Height / Cell_Height);
   end Pixels_To_Cells;

   procedure Startup_Cells
     (Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Cell_Width   : Positive;
      Cell_Height  : Positive;
      Margin       : Natural := 0;
      Default_Rows : Positive := 24;
      Default_Cols : Positive := 80;
      Rows         : out Positive;
      Cols         : out Positive)
   is
   begin
      if Pixel_Width = 0 or else Pixel_Height = 0 then
         Rows := Default_Rows;
         Cols := Default_Cols;
      else
         Pixels_To_Cells
           (Pixel_Width  => Pixel_Width,
            Pixel_Height => Pixel_Height,
            Cell_Width   => Cell_Width,
            Cell_Height  => Cell_Height,
            Margin       => Margin,
            Rows         => Rows,
            Cols         => Cols);
      end if;
   end Startup_Cells;
end Terminal.App.Resize;

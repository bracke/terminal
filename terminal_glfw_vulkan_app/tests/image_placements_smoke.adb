with AUnit.Assertions;

with Terminal.App.Graphics;
with Terminal.App.Image_Placements;

procedure Image_Placements_Smoke is
   use AUnit.Assertions;

   Header : Terminal.App.Graphics.Graphics_Header :=
     (Kitty_Columns_Specified => True,
      Kitty_Rows_Specified => True,
      Placeholder_Cols => 2,
      Placeholder_Rows => 2,
      others => <>);
   Geometry : Terminal.App.Image_Placements.Geometry :=
     Terminal.App.Image_Placements.Resolve
       (Cell_Width => 10,
        Cell_Height => 10,
        Pixel_Width => 20,
        Pixel_Height => 30,
        Header => Header);
begin
   Assert
     (Geometry.Valid
      and then Geometry.Columns = 2
      and then Geometry.Rows = 2
      and then Geometry.Draw_Width = 13
      and then Geometry.Draw_Height = 20
      and then Geometry.Draw_Offset_X = 3
      and then Geometry.Draw_Offset_Y = 0,
      "placement geometry preserves aspect ratio in its cell box");

   Header.Kitty_Source_X := 20;
   Geometry := Terminal.App.Image_Placements.Resolve
     (Cell_Width => 10,
      Cell_Height => 10,
      Pixel_Width => 20,
      Pixel_Height => 30,
      Header => Header);
   Assert
     (not Geometry.Valid,
      "placement geometry rejects an out-of-range source crop");
end Image_Placements_Smoke;

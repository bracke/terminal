separate (Vulkan_Submit_Smoke)
procedure Invalid_Frame_Cases is
begin
   Reset_Fixture;
   declare
      Invalid : RM.Frame_Commands :=
        (Width           => 10,
         Height          => 10,
         Rectangles      => Rects'Unchecked_Access,
         Rectangle_Count => Rects'Length + 1,
         others          => <>);
   begin
      VS.Build (Invalid, Batch, Status);
      Assert
        (Status = VS.Invalid_Frame,
         "command count beyond a borrowed view should be rejected");
      Invalid.Rectangles := null;
      Invalid.Rectangle_Count := 0;
      Invalid.Colour_Glyph_Count := 1;
      VS.Build (Invalid, Batch, Status);
      Assert
        (Status = VS.Invalid_Frame,
         "missing colour glyph view should be rejected");
      Invalid.Colour_Glyph_Count := 0;
      Invalid.Images := Images'Unchecked_Access;
      Invalid.Image_Count := 1;
      Images (1).Width := -1.0;
      VS.Build (Invalid, Batch, Status);
      Assert
        (Status = VS.Invalid_Frame,
         "invalid image geometry should be rejected without an exception");
      Images (1).Width := 12.0;
      Invalid.Images := null;
      Invalid.Image_Count := 0;
      Invalid.Rectangles := Rects'Unchecked_Access;
      Invalid.Rectangle_Count := 1;
      Rects (1).Width := -1.0;
      VS.Build (Invalid, Batch, Status);
      Assert
        (Status = VS.Invalid_Frame,
         "invalid rectangle geometry should be rejected");
      Rects (1).Width := 50.0;
      Rects (1).X := Float'Last;
      VS.Build (Invalid, Batch, Status);
      Assert
        (Status = VS.Invalid_Frame,
         "overflowing finite coordinates should be rejected");
      Rects (1).X := 0.0;
      Rects (1).Color.R := 2.0;
      VS.Build (Invalid, Batch, Status);
      Assert
        (Status = VS.Invalid_Frame,
         "out-of-range colors should be rejected");
      Rects (1).Color.R := 1.0;
      Invalid.Rectangles := null;
      Invalid.Rectangle_Count := 0;
      declare
         Tiles : aliased RM.Colour_Glyph_Array :=
           [1 => (X => 0.0, Y => 0.0, Width => 1, Height => 1,
                  U0 => 0.0, V0 => 0.0, U1 => 1.0, V1 => 1.0)];
      begin
         Invalid.Colour_Glyphs := Tiles'Unchecked_Access;
         Invalid.Colour_Glyph_Count := 1;
         Invalid.Colour_Sheet_Width := 1;
         Invalid.Colour_Sheet_Height := 1;
         VS.Build (Invalid, Batch, Status);
         Assert
           (Status = VS.Invalid_Frame,
            "colour glyphs without sheet pixels should be rejected");
         Invalid.Colour_Sheet_Pixels := Atlas_Data'Address;
         Invalid.Colour_Sheet_Bytes := 3;
         VS.Build (Invalid, Batch, Status);
         Assert
           (Status = VS.Invalid_Frame,
            "undersized colour atlas storage should be rejected");
         Invalid.Colour_Sheet_Bytes := 4;
         VS.Build (Invalid, Batch, Status);
         Assert
           (Status = VS.Ok,
            "fully bounded colour atlas storage should be accepted");
         VS.Release (Batch);
         Invalid.Colour_Sheet_Width := VS.Max_Image_Atlas_Dimension + 1;
         Invalid.Colour_Sheet_Height := 1;
         Invalid.Colour_Sheet_Bytes := Natural'Last;
         VS.Build (Invalid, Batch, Status);
         Assert
           (Status = VS.Invalid_Frame,
            "oversized colour atlas dimensions should be rejected");
      end;
      Invalid.Colour_Glyphs := null;
      Invalid.Colour_Glyph_Count := 0;
      Invalid.Colour_Sheet_Width := 0;
      Invalid.Colour_Sheet_Height := 0;
      Invalid.Colour_Sheet_Pixels := System.Null_Address;
      Invalid.Colour_Sheet_Bytes := 0;
      Invalid.Glyphs := Glyphs'Unchecked_Access;
      Invalid.Glyph_Count := 1;
      Invalid.Atlas_Width := 2;
      Invalid.Atlas_Height := 2;
      Invalid.Atlas_Bytes := 4;
      Invalid.Atlas_Pixels := System.Null_Address;
      VS.Build (Invalid, Batch, Status);
      Assert
        (Status = VS.Invalid_Frame,
         "text glyphs without atlas pixels should be rejected");
      Invalid.Atlas_Pixels := Atlas_Data'Address;
      Invalid.Atlas_Bytes := 3;
      VS.Build (Invalid, Batch, Status);
      Assert
        (Status = VS.Invalid_Frame,
         "undersized text atlas storage should be rejected");
      Invalid.Atlas_Width := VS.Max_Image_Atlas_Dimension + 1;
      Invalid.Atlas_Height := 1;
      Invalid.Atlas_Bytes := Natural'Last;
      VS.Build (Invalid, Batch, Status);
      Assert
        (Status = VS.Invalid_Frame,
         "oversized text atlas dimensions should be rejected");
      Invalid.Glyphs := null;
      Invalid.Glyph_Count := 0;
      Invalid.Atlas_Width := 0;
      Invalid.Atlas_Height := 0;
      Invalid.Atlas_Bytes := 0;
      Invalid.Atlas_Pixels := System.Null_Address;
      Invalid.Images := Images'Unchecked_Access;
      Invalid.Image_Count := 1;
      Images (1).U1 := 2.0;
      VS.Build (Invalid, Batch, Status);
      Assert
        (Status = VS.Invalid_Frame,
         "out-of-range texture coordinates should be rejected");
      Images (1).U1 := 1.0;
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("invalid frame validation", E);
   end;

end Invalid_Frame_Cases;

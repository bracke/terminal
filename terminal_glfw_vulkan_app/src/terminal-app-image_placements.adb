package body Terminal.App.Image_Placements is
   function Resolve
     (Cell_Width   : Natural;
      Cell_Height  : Natural;
      Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Header       : Terminal.App.Graphics.Graphics_Header) return Geometry
   is
      use type Long_Long_Integer;
      Result : Geometry;
      Source_Width  : Natural;
      Source_Height : Natural;
      Source_W : Long_Long_Integer;
      Source_H : Long_Long_Integer;
      Cell_W   : constant Long_Long_Integer := Long_Long_Integer (Cell_Width);
      Cell_H   : constant Long_Long_Integer := Long_Long_Integer (Cell_Height);
      Cols     : Long_Long_Integer := 1;
      Rows     : Long_Long_Integer := 1;
      Box_W    : Long_Long_Integer := 1;
      Box_H    : Long_Long_Integer := 1;
      Draw_W   : Long_Long_Integer := 1;
      Draw_H   : Long_Long_Integer := 1;

      function Ceiling_Divide
        (Dividend : Long_Long_Integer;
         Divisor  : Long_Long_Integer) return Long_Long_Integer is
        ((Dividend + Divisor - 1) / Divisor);

      function Fits_Natural (Value : Long_Long_Integer) return Boolean is
        (Value >= 0
         and then Value <= Long_Long_Integer (Natural'Last));

      function Fits_Positive (Value : Long_Long_Integer) return Boolean is
        (Value >= 1
         and then Value <= Long_Long_Integer (Positive'Last));
   begin
      if Pixel_Width = 0
        or else Pixel_Height = 0
        or else Cell_Width = 0
        or else Cell_Height = 0
        or else not Header.Kitty_Columns_Valid
        or else not Header.Kitty_Rows_Valid
        or else not Header.Kitty_Geometry_Controls_Valid
        or else Header.Kitty_Cell_X >= Cell_Width
        or else Header.Kitty_Cell_Y >= Cell_Height
        or else Header.Kitty_Source_X >= Pixel_Width
        or else Header.Kitty_Source_Y >= Pixel_Height
      then
         return Result;
      end if;

      Source_Width := Pixel_Width - Header.Kitty_Source_X;
      Source_Height := Pixel_Height - Header.Kitty_Source_Y;
      if Header.Kitty_Source_Width > 0 then
         Source_Width := Natural'Min
           (Source_Width, Header.Kitty_Source_Width);
      end if;
      if Header.Kitty_Source_Height > 0 then
         Source_Height := Natural'Min
           (Source_Height, Header.Kitty_Source_Height);
      end if;
      if Source_Width = 0 or else Source_Height = 0 then
         return Result;
      end if;

      Source_W := Long_Long_Integer (Source_Width);
      Source_H := Long_Long_Integer (Source_Height);
      if Header.Kitty_Columns_Specified then
         Cols := Long_Long_Integer (Header.Placeholder_Cols);
      end if;
      if Header.Kitty_Rows_Specified then
         Rows := Long_Long_Integer (Header.Placeholder_Rows);
      end if;

      if not Header.Kitty_Columns_Specified
        and then not Header.Kitty_Rows_Specified
      then
         Draw_W := Source_W;
         Draw_H := Source_H;
         Cols := Ceiling_Divide (Draw_W, Cell_W);
         Rows := Ceiling_Divide (Draw_H, Cell_H);
         Box_W := Cols * Cell_W;
         Box_H := Rows * Cell_H;
      elsif Header.Kitty_Columns_Specified
        and then not Header.Kitty_Rows_Specified
      then
         Box_W := Cols * Cell_W;
         Draw_W := Box_W;
         Draw_H := Long_Long_Integer'Max
           (1, (Box_W * Source_H) / Source_W);
         Rows := Ceiling_Divide (Draw_H, Cell_H);
         Box_H := Rows * Cell_H;
      elsif not Header.Kitty_Columns_Specified
        and then Header.Kitty_Rows_Specified
      then
         Box_H := Rows * Cell_H;
         Draw_H := Box_H;
         Draw_W := Long_Long_Integer'Max
           (1, (Box_H * Source_W) / Source_H);
         Cols := Ceiling_Divide (Draw_W, Cell_W);
         Box_W := Cols * Cell_W;
      else
         Box_W := Cols * Cell_W;
         Box_H := Rows * Cell_H;
         if Source_W * Box_H >= Source_H * Box_W then
            Draw_W := Box_W;
            Draw_H := Long_Long_Integer'Max
              (1, (Box_W * Source_H) / Source_W);
         else
            Draw_H := Box_H;
            Draw_W := Long_Long_Integer'Max
              (1, (Box_H * Source_W) / Source_H);
         end if;
      end if;

      if not Fits_Positive (Cols)
        or else not Fits_Positive (Rows)
        or else not Fits_Positive (Draw_W)
        or else not Fits_Positive (Draw_H)
        or else not Fits_Natural (Box_W)
        or else not Fits_Natural (Box_H)
      then
         return Result;
      end if;

      return
        (Valid         => True,
         Columns       => Positive (Cols),
         Rows          => Positive (Rows),
         Draw_Offset_X => Natural ((Box_W - Draw_W) / 2),
         Draw_Offset_Y => Natural ((Box_H - Draw_H) / 2),
         Draw_Width    => Positive (Draw_W),
         Draw_Height   => Positive (Draw_H));
   exception
      when Constraint_Error =>
         return (others => <>);
   end Resolve;
end Terminal.App.Image_Placements;

package body Terminal.App.Resize is
   function Natural_Image (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Natural_Image;

   function Bounded (Text : String) return String is
      Result : String (1 .. Max_Status_Label_Length);
      Last   : Natural := 0;
   begin
      for Ch of Text loop
         exit when Last = Result'Last;
         Last := Last + 1;
         Result (Last) := Ch;
      end loop;
      return Result (1 .. Last);
   end Bounded;

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

   function Grid_Status_Label
     (Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Cell_Width   : Positive;
      Cell_Height  : Positive;
      Margin       : Natural := 0) return String
   is
      Rows : Positive;
      Cols : Positive;
   begin
      Pixels_To_Cells
        (Pixel_Width  => Pixel_Width,
         Pixel_Height => Pixel_Height,
         Cell_Width   => Cell_Width,
         Cell_Height  => Cell_Height,
         Margin       => Margin,
         Rows         => Rows,
         Cols         => Cols);
      return Bounded
        ("Grid "
         & Natural_Image (Rows)
         & "x"
         & Natural_Image (Cols)
         & " from "
         & Natural_Image (Pixel_Width)
         & "x"
         & Natural_Image (Pixel_Height)
         & " px");
   end Grid_Status_Label;

   function Startup_Status_Label
     (Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Cell_Width   : Positive;
      Cell_Height  : Positive;
      Margin       : Natural := 0;
      Default_Rows : Positive := 24;
      Default_Cols : Positive := 80) return String
   is
      Rows : Positive;
      Cols : Positive;
   begin
      Startup_Cells
        (Pixel_Width  => Pixel_Width,
         Pixel_Height => Pixel_Height,
         Cell_Width   => Cell_Width,
         Cell_Height  => Cell_Height,
         Margin       => Margin,
         Default_Rows => Default_Rows,
         Default_Cols => Default_Cols,
         Rows         => Rows,
         Cols         => Cols);

      if Pixel_Width = 0 or else Pixel_Height = 0 then
         return Bounded
           ("Startup grid "
            & Natural_Image (Rows)
            & "x"
            & Natural_Image (Cols)
            & " fallback");
      else
         return Bounded
           ("Startup grid "
            & Natural_Image (Rows)
            & "x"
            & Natural_Image (Cols)
            & " from framebuffer");
      end if;
   end Startup_Status_Label;
end Terminal.App.Resize;

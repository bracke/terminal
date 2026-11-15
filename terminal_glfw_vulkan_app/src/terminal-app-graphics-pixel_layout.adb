package body Terminal.App.Graphics.Pixel_Layout is
   function Raw_Bytes_Per_Pixel (Raw_Format : Natural) return Natural is
     (case Raw_Format is
         when 8      => 1,
         when 16     => 2,
         when 24     => 3,
         when 32     => 4,
         when others => 0);

   function Raw_Row_Stride
     (Raw_Format : Natural; Pixel_Width : Natural) return Natural
   is
      Bytes_Per_Pixel : constant Natural := Raw_Bytes_Per_Pixel (Raw_Format);
   begin
      if Bytes_Per_Pixel = 0
        or else Pixel_Width = 0
        or else Pixel_Width > Natural'Last / Bytes_Per_Pixel
      then
         return 0;
      end if;
      return Pixel_Width * Bytes_Per_Pixel;
   end Raw_Row_Stride;

   function Raw_Decoded_Length
     (Raw_Format, Pixel_Width, Pixel_Height : Natural) return Natural
   is
      Row_Stride : constant Natural := Raw_Row_Stride (Raw_Format, Pixel_Width);
   begin
      if Row_Stride = 0
        or else Pixel_Height = 0
        or else Pixel_Height > Max_Data_Preview_Length / Row_Stride
      then
         return 0;
      end if;
      return Pixel_Height * Row_Stride;
   end Raw_Decoded_Length;

   function RGBA_Decoded_Length
     (Pixel_Width, Pixel_Height : Natural) return Natural is
     (Raw_Decoded_Length (32, Pixel_Width, Pixel_Height));
end Terminal.App.Graphics.Pixel_Layout;

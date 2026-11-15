private package Terminal.App.Graphics.Pixel_Layout is
   function Raw_Bytes_Per_Pixel (Raw_Format : Natural) return Natural;
   function Raw_Row_Stride
     (Raw_Format : Natural; Pixel_Width : Natural) return Natural;
   function Raw_Decoded_Length
     (Raw_Format, Pixel_Width, Pixel_Height : Natural) return Natural;
   function RGBA_Decoded_Length
     (Pixel_Width, Pixel_Height : Natural) return Natural;
end Terminal.App.Graphics.Pixel_Layout;

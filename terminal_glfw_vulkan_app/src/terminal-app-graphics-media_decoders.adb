with Terminal.App.Graphics.Pixel_Layout;
with Terminal.App.Graphics.PNG_Chunks;
with Terminal.App.Graphics.PNG_Inflation;
with Terminal.App.Graphics.PNG_Pixels;
with Terminal.App.Graphics.PNG_Support;
with Terminal.App.Graphics.PNG_Types;
with Terminal.App.Graphics.Preview_Storage;
with Terminal.App.Graphics.Sixel_Support;
with Terminal.App.Image_Media;
with Terminal.App.JPEG_Decoder;
with Terminal.App.Owned_Image_Data;

package body Terminal.App.Graphics.Media_Decoders is
   use type Terminal.App.Image_Media.Decode_Status;
   use type Terminal.App.Render_Model.Image_Data_View;
   use Terminal.App.Graphics.Pixel_Layout;
   use Terminal.App.Graphics.PNG_Chunks;
   use Terminal.App.Graphics.PNG_Types;
   use Terminal.App.Graphics.Sixel_Support;

   subtype Image_Data_Holder is Terminal.App.Owned_Image_Data.Owner;

   procedure Decode_Sixel_Rows
     (Text : String;
      Row_Sink : not null access procedure
        (Y : Natural; Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Palette : in out Sixel_Palette_State; Reset_Palette : Boolean;
      Result : in out Graphics_Data_Preview;
      Maximum_Decoded_Bytes : Positive := Max_Data_Preview_Length;
      Maximum_Pixel_Dimension : Positive := Max_Sixel_Pixel_Dimension)
   is separate;

   procedure Decode_Sixel_Rows
     (Text : String;
      Row_Sink : not null access procedure
        (Y : Natural; Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result : in out Graphics_Data_Preview;
      Maximum_Decoded_Bytes : Positive := Max_Data_Preview_Length;
      Maximum_Pixel_Dimension : Positive := Max_Sixel_Pixel_Dimension)
   is
      Palette : Sixel_Palette_State := Default_Sixel_Palette;
   begin
      Decode_Sixel_Rows
        (Text, Row_Sink, Palette, Reset_Palette => False, Result => Result,
         Maximum_Decoded_Bytes => Maximum_Decoded_Bytes,
         Maximum_Pixel_Dimension => Maximum_Pixel_Dimension);
   end Decode_Sixel_Rows;

   procedure Decode_Sixel_Raster
     (Text : String; Info : Sixel_Info; Result : in out Graphics_Data_Preview)
   is separate;

   procedure Decode_Sixel_Data
     (Text : String;
      Width, Height, Logical_Height, Vertical_Aspect : Natural;
      Transparent : Boolean;
      Result : in out Graphics_Data_Preview) is
   begin
      Decode_Sixel_Raster
        (Text,
         (Width => Width,
          Height => Height,
          Logical_Height => Logical_Height,
          Vertical_Aspect => Vertical_Aspect,
          Transparent => Transparent),
         Result);
   end Decode_Sixel_Data;

   procedure Decode_PNG_RGBA_Source_Rows
     (Length : Natural;
      PNG_Byte : not null access function
        (Index : Positive) return Terminal.Common.Bytes.Byte;
      Row_Sink : not null access procedure
        (Y : Natural; Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result : in out Graphics_Data_Preview)
   is separate;

   procedure Decode_PNG_RGBA_Rows
     (PNG : Terminal.Common.Bytes.Byte_Array; Length : Natural;
      Row_Sink : not null access procedure
        (Y : Natural; Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result : in out Graphics_Data_Preview)
   is
      function Source_Byte
        (Index : Positive) return Terminal.Common.Bytes.Byte is
        (if Index > PNG'Length then 0 else PNG (PNG'First + Index - 1));
   begin
      if Length > PNG'Length then
         Set_Decode_Failure (Result, Decode_Invalid_Data);
      else
         Decode_PNG_RGBA_Source_Rows
           (Length, Source_Byte'Access, Row_Sink, Result);
      end if;
   end Decode_PNG_RGBA_Rows;

   procedure Decode_PNG_RGBA
     (PNG : Terminal.Common.Bytes.Byte_Array; Length : Natural;
      Result : in out Graphics_Data_Preview)
   is separate;

   procedure Decode_PNG_RGBA_Data
     (PNG : Terminal.Common.Bytes.Byte_Array; Length : Natural;
      Result : in out Graphics_Data_Preview)
   is separate;

   procedure Decode_JPEG_RGBA_Data
     (JPEG : Terminal.Common.Bytes.Byte_Array; Length : Natural;
      Result : in out Graphics_Data_Preview;
      Maximum_Decoded_Bytes : Data_Decode_Byte_Limit := Max_Data_Preview_Length;
      Maximum_Pixel_Dimension : Positive := Positive'Last)
   is separate;

   procedure Decode_Image_RGBA_Data
     (Data : Terminal.Common.Bytes.Byte_Array; Length : Natural;
      Result : in out Graphics_Data_Preview)
   is separate;
end Terminal.App.Graphics.Media_Decoders;

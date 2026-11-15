with Terminal.Common.Bytes;

package Terminal.App.Graphics.Media_Decoders is
   procedure Decode_Sixel_Data
     (Text : String;
      Width, Height, Logical_Height, Vertical_Aspect : Natural;
      Transparent : Boolean;
      Result : in out Graphics_Data_Preview);
   procedure Decode_PNG_RGBA_Data
     (PNG : Terminal.Common.Bytes.Byte_Array; Length : Natural;
      Result : in out Graphics_Data_Preview);
   procedure Decode_JPEG_RGBA_Data
     (JPEG : Terminal.Common.Bytes.Byte_Array; Length : Natural;
      Result : in out Graphics_Data_Preview;
      Maximum_Decoded_Bytes : Data_Decode_Byte_Limit := Max_Data_Preview_Length;
      Maximum_Pixel_Dimension : Positive := Positive'Last);
   procedure Decode_Image_RGBA_Data
     (Data : Terminal.Common.Bytes.Byte_Array; Length : Natural;
      Result : in out Graphics_Data_Preview);
   procedure Decode_PNG_RGBA_Source_Rows
     (Length : Natural;
      PNG_Byte : not null access function
        (Index : Positive) return Terminal.Common.Bytes.Byte;
      Row_Sink : not null access procedure
        (Y : Natural; Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result : in out Graphics_Data_Preview);
   procedure Decode_PNG_RGBA_Rows
     (PNG : Terminal.Common.Bytes.Byte_Array; Length : Natural;
      Row_Sink : not null access procedure
        (Y : Natural; Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result : in out Graphics_Data_Preview);
   procedure Decode_Sixel_Rows
     (Text : String;
      Row_Sink : not null access procedure
        (Y : Natural; Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result : in out Graphics_Data_Preview;
      Maximum_Decoded_Bytes : Positive := Max_Data_Preview_Length;
      Maximum_Pixel_Dimension : Positive := Max_Sixel_Pixel_Dimension);
   procedure Decode_Sixel_Rows
     (Text : String;
      Row_Sink : not null access procedure
        (Y : Natural; Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Palette : in out Sixel_Palette_State;
      Reset_Palette : Boolean;
      Result : in out Graphics_Data_Preview;
      Maximum_Decoded_Bytes : Positive := Max_Data_Preview_Length;
      Maximum_Pixel_Dimension : Positive := Max_Sixel_Pixel_Dimension);
end Terminal.App.Graphics.Media_Decoders;

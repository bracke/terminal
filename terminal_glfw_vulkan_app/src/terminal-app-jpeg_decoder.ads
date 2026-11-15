with Terminal.Common.Bytes;
with Terminal.Common.Graphics_Limits;
with Terminal.App.Owned_Image_Data;

private package Terminal.App.JPEG_Decoder is
   type Decode_Status is
     (Decode_Ok,
      Decode_Unsupported,
      Decode_Invalid,
      Decode_Too_Large,
      Decode_Allocation_Failed);

   subtype Decode_Byte_Limit is Positive range
     1 .. Terminal.Common.Graphics_Limits.Max_Image_Bytes;

   procedure Decode
     (JPEG                    : Terminal.Common.Bytes.Byte_Array;
      Length                  : Natural;
      Maximum_Decoded_Bytes   : Decode_Byte_Limit;
      Maximum_Pixel_Dimension : Positive;
      Pixels                  : in out Terminal.App.Owned_Image_Data.Owner;
      Pixel_Width             : out Natural;
      Pixel_Height            : out Natural;
      Status                  : out Decode_Status);
end Terminal.App.JPEG_Decoder;

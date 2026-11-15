separate (Terminal.App.Graphics.Media_Decoders)
procedure Decode_JPEG_RGBA_Data
  (JPEG : Terminal.Common.Bytes.Byte_Array; Length : Natural;
   Result : in out Graphics_Data_Preview;
   Maximum_Decoded_Bytes : Data_Decode_Byte_Limit := Max_Data_Preview_Length;
   Maximum_Pixel_Dimension : Positive := Positive'Last)
is
   Pixel_Owner : Image_Data_Holder;
   Width  : Natural := 0;
   Height : Natural := 0;
   Status : Terminal.App.JPEG_Decoder.Decode_Status;
begin
   if Length > JPEG'Length then
      Set_Decode_Failure (Result, Decode_Invalid_Data);
      return;
   end if;
   Preview_Storage.Reset_Decode_Metadata (Result);
   Terminal.App.JPEG_Decoder.Decode
     (JPEG, Length, Maximum_Decoded_Bytes, Maximum_Pixel_Dimension,
      Pixel_Owner, Width, Height, Status);
   case Status is
      when Terminal.App.JPEG_Decoder.Decode_Ok =>
         Adopt_Bytes (Result, Pixel_Owner);
         Result.Raw_Format := 32;
         Result.Pixel_Width := Width;
         Result.Pixel_Height := Height;
         Result.Decoded_Row_Stride_Bytes := Width * 4;
         Result.Decoded_Length := Width * Height * 4;
         Result.Decode_Complete := True;
         Result.Decode_Status := Decode_Ok;
      when Terminal.App.JPEG_Decoder.Decode_Unsupported =>
         Result.Decode_Status := Decode_Unsupported_Format;
      when Terminal.App.JPEG_Decoder.Decode_Invalid =>
         Result.Decode_Status := Decode_Invalid_Byte;
      when Terminal.App.JPEG_Decoder.Decode_Too_Large =>
         Result.Decode_Status := Decode_Preview_Truncated;
      when Terminal.App.JPEG_Decoder.Decode_Allocation_Failed =>
         Result.Decode_Status := Decode_Allocation_Failed;
   end case;
end Decode_JPEG_RGBA_Data;

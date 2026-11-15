separate (Terminal.App.Graphics.Media_Decoders)
procedure Decode_Image_RGBA_Data
  (Data : Terminal.Common.Bytes.Byte_Array; Length : Natural;
   Result : in out Graphics_Data_Preview)
is
begin
   if Length > Data'Length then
      Set_Decode_Failure (Result, Decode_Invalid_Data);
      return;
   end if;
   Decode_PNG_RGBA_Data (Data, Length, Result);
   if Result.Decode_Status = Decode_Unsupported_Format then
      Decode_JPEG_RGBA_Data (Data, Length, Result);
   end if;
   if Result.Decode_Status = Decode_Unsupported_Format
     and then Terminal.App.Image_Media.Available
   then
      declare
         Media        : Terminal.App.Image_Media.Decoded_Image;
         Media_Status : Terminal.App.Image_Media.Decode_Status;
      begin
         Terminal.App.Image_Media.Decode
           (Data, Length, Max_Data_Preview_Length,
            Max_Sixel_Pixel_Dimension, Media, Media_Status);
         if Media_Status = Terminal.App.Image_Media.Decode_Ok
           and then Media.Has_Bytes
           and then Media.Frame_Bytes > 0
         then
            declare
               Decoded_Owner : Image_Data_Holder;

               procedure Copy_Decoded
                 (Bytes : in out Terminal.Common.Bytes.Byte_Array) is
               begin
                  Media.Copy_Frame (1, Bytes);
               end Copy_Decoded;
            begin
               Terminal.App.Owned_Image_Data.Allocate
                 (Decoded_Owner, Media.Frame_Bytes);
               Decoded_Owner.Modify (Copy_Decoded'Access);
               Release (Result);
               Adopt_Bytes (Result, Decoded_Owner);
            end;
            Result.Header_Recognized := True;
            Result.Has_Data := True;
            Result.Raw_Format := 32;
            Result.Pixel_Width := Media.Pixel_Width;
            Result.Pixel_Height := Media.Pixel_Height;
            Result.Decoded_Length := Media.Frame_Bytes;
            Result.Decoded_Row_Stride_Bytes := Media.Pixel_Width * 4;
            Result.Decode_Complete := True;
            Result.Decode_Status := Decode_Ok;
         else
            Result.Decode_Status :=
              (if Media_Status = Terminal.App.Image_Media.Decode_Ok
               then Decode_Invalid_Data
               else Media_Status);
         end if;
         Terminal.App.Image_Media.Release (Media);
      end;
   end if;
end Decode_Image_RGBA_Data;

separate (Terminal.App.Graphics)
   procedure Decode_Base64_Zlib_Raw_Chunk_Rows
     (Chunk_Count  : Natural;
      Chunk_Text   : not null access function (Index : Positive) return String;
      Raw_Format   : Natural;
      Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Row_Sink     : not null access procedure
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result       : in out Graphics_Data_Preview)
   is
      Row_Stride : constant Natural := Raw_Row_Stride (Raw_Format, Pixel_Width);
      Expected   : constant Natural :=
        Raw_Decoded_Length (Raw_Format, Pixel_Width, Pixel_Height);
      Data       : Terminal.App.Render_Model.Image_Data_Access := null;
      Actual     : Natural := 0;
      Encoded    : Natural := 0;
      Status     : Data_Decode_Status := Decode_Not_Attempted;
   begin
      Release (Result);
      Result.Header_Recognized := True;
      Result.Raw_Format := Raw_Format;
      Result.Pixel_Width := Pixel_Width;
      Result.Pixel_Height := Pixel_Height;
      Result.Decoded_Row_Stride_Bytes := Row_Stride;
      if Row_Stride = 0 or else Expected = 0 then
         Result.Decode_Status := Decode_Unsupported_Format;
         return;
      end if;

      Decode_Base64_Zlib_Chunks
        (Chunk_Count,
         Chunk_Text,
         Expected,
         True,
         Data,
         Actual,
         Encoded,
         Status);
      Result.Encoded_Length := Encoded;
      Result.Has_Data := Encoded > 0;
      Result.Decode_Status := Status;
      if Status /= Decode_Ok or else Data = null then
         return;
      end if;

      for Y in 0 .. Pixel_Height - 1 loop
         declare
            First : constant Positive := Y * Row_Stride + 1;
            Last  : constant Positive := First + Row_Stride - 1;
            Continue : Boolean := True;
         begin
            Row_Sink (Y, Data (First .. Last), Continue);
            if not Continue then
               Result.Decode_Status := Decode_Invalid_Byte;
               Free_Image_Data (Data);
               return;
            end if;
         end;
      end loop;
      Result.Decoded_Length := Actual;
      Result.Decode_Complete := True;
      Free_Image_Data (Data);
   end Decode_Base64_Zlib_Raw_Chunk_Rows;


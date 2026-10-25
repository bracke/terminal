separate (Terminal.App.Graphics)
   procedure Decode_Base64_Zlib_PNG_Chunk_Rows
     (Chunk_Count    : Natural;
      Chunk_Text     : not null access function (Index : Positive) return String;
      Inflated_Length : Natural;
      Encoded_Length : out Natural;
      Row_Sink       : not null access procedure
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result         : in out Graphics_Data_Preview)
   is
      PNG    : Terminal.App.Render_Model.Image_Data_Access := null;
      Actual : Natural := 0;
      Status : Data_Decode_Status := Decode_Not_Attempted;
   begin
      Release (Result);
      Decode_Base64_Zlib_Chunks
        (Chunk_Count,
         Chunk_Text,
         (if Inflated_Length = 0
          then Max_Data_Preview_Length
          else Inflated_Length),
         Inflated_Length /= 0,
         PNG,
         Actual,
         Encoded_Length,
         Status);
      Result.Header_Recognized := True;
      Result.Has_Data := Encoded_Length > 0;
      Result.Encoded_Length := Encoded_Length;
      Result.Decode_Status := Status;
      if Status /= Decode_Ok or else PNG = null then
         return;
      end if;

      Decode_PNG_RGBA_Rows (PNG.all, Actual, Row_Sink, Result);
      Result.Encoded_Length := Encoded_Length;
      Result.Has_Data := Encoded_Length > 0;
      Free_Image_Data (PNG);
   exception
      when Storage_Error =>
         if PNG /= null then
            Free_Image_Data (PNG);
         end if;
         Result.Decode_Status := Decode_Allocation_Failed;
         Result.Decode_Complete := False;
      when others =>
         if PNG /= null then
            Free_Image_Data (PNG);
         end if;
         raise;
   end Decode_Base64_Zlib_PNG_Chunk_Rows;


separate (Terminal.App.Graphics.Transport_Decoders)
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
      PNG_Owner : Image_Data_Holder;
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
         PNG_Owner,
         Actual,
         Encoded_Length,
         Status);
      Result.Header_Recognized := True;
      Result.Has_Data := Encoded_Length > 0;
      Result.Encoded_Length := Encoded_Length;
      Result.Decode_Status := Status;
      if Status /= Decode_Ok
        or else Terminal.App.Owned_Image_Data.Is_Empty (PNG_Owner)
      then
         return;
      end if;

      declare
         procedure Decode (PNG : Terminal.Common.Bytes.Byte_Array) is
         begin
            Terminal.App.Graphics.Media_Decoders.Decode_PNG_RGBA_Rows
              (PNG, Actual, Row_Sink, Result);
         end Decode;
      begin
         PNG_Owner.Read (Decode'Access);
      end;
      Result.Encoded_Length := Encoded_Length;
      Result.Has_Data := Encoded_Length > 0;
   exception
      when Storage_Error =>
         Result.Decode_Status := Decode_Allocation_Failed;
         Result.Decode_Complete := False;
   end Decode_Base64_Zlib_PNG_Chunk_Rows;

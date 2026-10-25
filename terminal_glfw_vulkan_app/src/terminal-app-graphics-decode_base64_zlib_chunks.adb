separate (Terminal.App.Graphics)
   procedure Decode_Base64_Zlib_Chunks
     (Chunk_Count     : Natural;
      Chunk_Text      : not null access function
        (Index : Positive) return String;
      Maximum_Length  : Natural;
      Exact_Length    : Boolean;
      Inflated        : out Terminal.App.Render_Model.Image_Data_Access;
      Inflated_Length : out Natural;
      Encoded_Length  : out Natural;
      Status          : out Data_Decode_Status)
   is
      Base64_Result : Graphics_Data_Preview;
      Decoder       : Terminal.App.Zlib_Inflation.Decoder;

      procedure Accept_Compressed_Byte
        (Value    : Terminal.Common.Bytes.Byte;
         Continue : in out Boolean)
      is
      begin
         Terminal.App.Zlib_Inflation.Push (Decoder, Value, Continue);
      end Accept_Compressed_Byte;
   begin
      Inflated := null;
      Inflated_Length := 0;
      Encoded_Length := 0;
      Status := Decode_Invalid_Byte;
      Terminal.App.Zlib_Inflation.Start
        (Decoder, Maximum_Length, Exact_Length, Status);
      if Status /= Decode_Ok then
         return;
      end if;

      Decode_Base64_Chunk_Bytes
        (Chunk_Count,
         Chunk_Text,
         Accept_Compressed_Byte'Access,
         Base64_Result);
      Encoded_Length := Base64_Result.Encoded_Length;
      if Base64_Result.Decode_Status /= Decode_Ok
        or else not Base64_Result.Decode_Complete
      then
         declare
            Discarded : Terminal.App.Render_Model.Image_Data_Access := null;
            Discarded_Length : Natural;
            Inflate_Status : Data_Decode_Status;
         begin
            Terminal.App.Zlib_Inflation.Finish
              (Decoder, Discarded, Discarded_Length, Inflate_Status);
            Free_Image_Data (Discarded);
            Status :=
              (if Inflate_Status in Decode_Too_Large
                   | Decode_Allocation_Failed
                   | Decode_Preview_Truncated
               then Inflate_Status
               elsif Base64_Result.Decode_Status in
                 Decode_Ok | Decode_Not_Attempted
               then Decode_Invalid_Byte
               else Base64_Result.Decode_Status);
         end;
         Release (Base64_Result);
         return;
      end if;

      Terminal.App.Zlib_Inflation.Finish
        (Decoder, Inflated, Inflated_Length, Status);
      Release (Base64_Result);
   exception
      when others =>
         Release (Base64_Result);
         raise;
   end Decode_Base64_Zlib_Chunks;


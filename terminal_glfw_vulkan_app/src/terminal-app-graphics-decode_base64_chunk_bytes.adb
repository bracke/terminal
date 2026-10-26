separate (Terminal.App.Graphics)
   procedure Decode_Base64_Chunk_Bytes
     (Chunk_Count : Natural;
      Chunk_Text  : not null access function (Index : Positive) return String;
      Byte_Sink   : not null access procedure
        (Value : Terminal.Common.Bytes.Byte;
         Continue : in out Boolean);
      Result      : in out Graphics_Data_Preview)
   is
      Decoder : Terminal.Common.Base64.Decoder_State;
      Bytes : Terminal.Common.Base64.Decoded_Quantum;
      Byte_Count : Natural := 0;
      Base64_Status : Terminal.Common.Base64.Decoder_Status;
      Done   : Boolean := False;

      procedure Append_Byte (Value : Natural) is
         Continue : Boolean := True;
      begin
         if Result.Decoded_Length = Max_Data_Preview_Length then
            Result.Decode_Status := Decode_Preview_Truncated;
            Result.Decode_Complete := False;
            Done := True;
            return;
         end if;

         Byte_Sink (Terminal.Common.Bytes.Byte (Value mod 256), Continue);
         if not Continue then
            Result.Decode_Status := Decode_Invalid_Byte;
            Result.Decode_Complete := False;
            Done := True;
            return;
         end if;

         Result.Decoded_Length := Result.Decoded_Length + 1;
      end Append_Byte;

      procedure Append_Output is
      begin
         if Base64_Status = Terminal.Common.Base64.Invalid_Data then
            if Result.Decode_Status /= Decode_Trailing_Data then
               Result.Decode_Status := Decode_Invalid_Byte;
            end if;
            Result.Decode_Complete := False;
            Done := True;
            return;
         end if;
         for I in 1 .. Byte_Count loop
            Append_Byte (Natural (Bytes (I)));
            exit when Done;
         end loop;
      end Append_Output;
   begin
      Release (Result);
      Result.Header_Recognized := True;
      Terminal.Common.Base64.Reset
        (Decoder, Allow_Unpadded => True, Allow_Whitespace => True);

      for Index in 1 .. Chunk_Count loop
         declare
            Text : constant String := Chunk_Text (Index);
         begin
            Result.Encoded_Length := Result.Encoded_Length + Text'Length;
            if Text'Length > 0 then
               Result.Has_Data := True;
            end if;
         end;
      end loop;

      for Index in 1 .. Chunk_Count loop
         declare
            Text : constant String := Chunk_Text (Index);
         begin
            for Ch of Text loop
               declare
                  Was_Complete : constant Boolean :=
                    Terminal.Common.Base64.Is_Complete (Decoder);
               begin
                  Terminal.Common.Base64.Push
                    (Decoder, Ch, Bytes, Byte_Count, Base64_Status);
                  if Base64_Status = Terminal.Common.Base64.Invalid_Data
                    and then Was_Complete
                  then
                     Result.Decode_Status := Decode_Trailing_Data;
                  end if;
                  Append_Output;
                  if Done then
                     return;
                  end if;
               end;
            end loop;
         end;
      end loop;

      Terminal.Common.Base64.Finish
        (Decoder, Bytes, Byte_Count, Base64_Status);
      Append_Output;
      if Done then
         return;
      end if;

      Result.Decode_Complete := Result.Has_Data;
      Result.Decode_Status :=
        (if Result.Decode_Complete then Decode_Ok else Decode_Not_Attempted);
   end Decode_Base64_Chunk_Bytes;


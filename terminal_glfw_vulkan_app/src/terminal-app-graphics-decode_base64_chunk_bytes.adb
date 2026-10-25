separate (Terminal.App.Graphics)
   procedure Decode_Base64_Chunk_Bytes
     (Chunk_Count : Natural;
      Chunk_Text  : not null access function (Index : Positive) return String;
      Byte_Sink   : not null access procedure
        (Value : Terminal.Common.Bytes.Byte;
         Continue : in out Boolean);
      Result      : in out Graphics_Data_Preview)
   is
      Values : array (Positive range 1 .. 4) of Natural := (others => 0);
      Count  : Natural := 0;
      Padding : Natural := 0;
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

      procedure Flush_Group is
      begin
         if Count = 0 then
            return;
         elsif Count = 1 or else Padding > 2 then
            Result.Decode_Status := Decode_Invalid_Byte;
            Result.Decode_Complete := False;
            Done := True;
            return;
         end if;

         Append_Byte ((Values (1) * 4) + (Values (2) / 16));
         if Done then
            return;
         end if;

         if Count >= 3 and then Padding < 2 then
            Append_Byte (((Values (2) mod 16) * 16) + (Values (3) / 4));
            if Done then
               return;
            end if;
         end if;

         if Count = 4 and then Padding = 0 then
            Append_Byte (((Values (3) mod 4) * 64) + Values (4));
         end if;
      end Flush_Group;
   begin
      Release (Result);
      Result.Header_Recognized := True;

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
                  V : constant Integer := Base64_Value (Ch);
               begin
                  if Ch = ASCII.CR or else Ch = ASCII.LF or else Ch = ' ' then
                     null;
                  elsif Done then
                     Result.Decode_Status := Decode_Trailing_Data;
                     Result.Decode_Complete := False;
                     return;
                  elsif Ch = '=' then
                     Count := Count + 1;
                     if Count > 4 then
                        Result.Decode_Status := Decode_Trailing_Data;
                        Result.Decode_Complete := False;
                        return;
                     end if;
                     Padding := Padding + 1;
                     Values (Count) := 0;
                     if Count = 4 then
                        Flush_Group;
                        if Done then
                           return;
                        end if;
                        Done := True;
                     end if;
                  elsif V < 0 or else Padding > 0 then
                     Result.Decode_Status := Decode_Invalid_Byte;
                     Result.Decode_Complete := False;
                     return;
                  else
                     Count := Count + 1;
                     if Count > 4 then
                        Result.Decode_Status := Decode_Trailing_Data;
                        Result.Decode_Complete := False;
                        return;
                     end if;
                     Values (Count) := Natural (V);
                     if Count = 4 then
                        Flush_Group;
                        if Done then
                           return;
                        end if;
                        Values := (others => 0);
                        Count := 0;
                     end if;
                  end if;
               end;
            end loop;
         end;
      end loop;

      if Count > 0 and then not Done then
         Flush_Group;
         if Done
           and then Result.Decode_Status /= Decode_Preview_Truncated
         then
            return;
         end if;
      end if;

      Result.Decode_Complete := Result.Has_Data;
      Result.Decode_Status :=
        (if Result.Decode_Complete then Decode_Ok else Decode_Not_Attempted);
   end Decode_Base64_Chunk_Bytes;


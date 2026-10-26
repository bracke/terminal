separate (Terminal.App.Graphics)
   procedure Decode_Base64_Raw_Chunk_Rows
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
      Bytes_Per_Pixel : constant Natural :=
        Raw_Bytes_Per_Pixel (Raw_Format);
      Row_Stride : constant Natural := Raw_Row_Stride (Raw_Format, Pixel_Width);
      Expected_Decoded_Length : constant Natural :=
        Raw_Decoded_Length (Raw_Format, Pixel_Width, Pixel_Height);
      Decoder : Terminal.Common.Base64.Decoder_State;
      Bytes : Terminal.Common.Base64.Decoded_Quantum;
      Byte_Count : Natural := 0;
      Base64_Status : Terminal.Common.Base64.Decoder_Status;
      Done   : Boolean := False;
   begin
      Release (Result);
      Result.Header_Recognized := True;
      Result.Raw_Format := Raw_Format;
      Result.Pixel_Width := Pixel_Width;
      Result.Pixel_Height := Pixel_Height;
      Result.Decoded_Row_Stride_Bytes := Row_Stride;
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

      if Bytes_Per_Pixel = 0
        or else Pixel_Width = 0
        or else Pixel_Height = 0
        or else Row_Stride = 0
      then
         Result.Decode_Status := Decode_Unsupported_Format;
         Result.Decode_Complete := False;
         return;
      elsif Expected_Decoded_Length > Max_Data_Preview_Length then
         Result.Decode_Status := Decode_Preview_Truncated;
         Result.Decode_Complete := False;
         return;
      elsif Expected_Decoded_Length = 0 then
         Result.Decode_Status := Decode_Preview_Truncated;
         Result.Decode_Complete := False;
         return;
      end if;

      declare
         Row : Image_Data_Holder;
         Row_Length : Natural := 0;
         Y : Natural := 0;

         procedure Append_Byte (Value : Natural) is
            Continue : Boolean := True;
         begin
            if Result.Decoded_Length >= Expected_Decoded_Length
              or else Y >= Pixel_Height
            then
               Result.Decode_Status := Decode_Trailing_Data;
               Result.Decode_Complete := False;
               Done := True;
               return;
            end if;

            Row_Length := Row_Length + 1;
            Row.Data (Row_Length) :=
              Terminal.Common.Bytes.Byte (Value mod 256);
            Result.Decoded_Length := Result.Decoded_Length + 1;

            if Row_Length = Row_Stride then
               Row_Sink (Y, Row.Data.all, Continue);
               if not Continue then
                  Result.Decode_Status := Decode_Invalid_Byte;
                  Result.Decode_Complete := False;
                  Done := True;
                  return;
               end if;
               Row_Length := 0;
               Y := Y + 1;
            end if;
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
         Row.Data := new Terminal.Common.Bytes.Byte_Array (1 .. Row_Stride);
         Row.Data.all := (others => 0);
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

         if Result.Decoded_Length /= Expected_Decoded_Length
           or else Row_Length /= 0
           or else Y /= Pixel_Height
         then
            Result.Decode_Status := Decode_Invalid_Byte;
            Result.Decode_Complete := False;
            return;
         end if;
      exception
         when Storage_Error =>
            Result.Decode_Status := Decode_Allocation_Failed;
            Result.Decode_Complete := False;
            return;
      end;

      Result.Decode_Complete := True;
      Result.Decode_Status := Decode_Ok;
   end Decode_Base64_Raw_Chunk_Rows;


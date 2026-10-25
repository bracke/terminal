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
      Values : array (Positive range 1 .. 4) of Natural := (others => 0);
      Count  : Natural := 0;
      Padding : Natural := 0;
      Done   : Boolean := False;
   begin
      Release (Result);
      Result.Header_Recognized := True;
      Result.Raw_Format := Raw_Format;
      Result.Pixel_Width := Pixel_Width;
      Result.Pixel_Height := Pixel_Height;
      Result.Decoded_Row_Stride_Bytes := Row_Stride;

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
         Row.Data := new Terminal.Common.Bytes.Byte_Array (1 .. Row_Stride);
         Row.Data.all := (others => 0);
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
                           if Done
                             and then Result.Decode_Status /= Decode_Trailing_Data
                           then
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
              and then Result.Decode_Status /= Decode_Trailing_Data
            then
               return;
            end if;
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


separate (Terminal.App.Graphics)
   procedure Decode_Base64_PNG_Chunk_Rows
     (Chunk_Count    : Natural;
      Chunk_Text     : not null access function (Index : Positive) return String;
      Encoded_Length : out Natural;
      PNG_Length     : out Natural;
      Row_Sink       : not null access procedure
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result         : in out Graphics_Data_Preview)
   is
      Cursor_Chunk : Positive := 1;
      Cursor_Offset : Natural := 0;
      Cursor_Values : array (Positive range 1 .. 4) of Natural := (others => 0);
      Cursor_Count : Natural := 0;
      Cursor_Padding : Natural := 0;
      Cursor_Done : Boolean := False;
      Cursor_Invalid : Boolean := False;
      Decoded_Position : Natural := 0;
      Window_First : Natural := 0;
      Window_Last : Natural := 0;
      Window_Bytes : Terminal.Common.Bytes.Byte_Array (1 .. 3) := (others => 0);

      function Base64_Group_Decoded_Length
        (Count   : Natural;
         Padding : Natural) return Natural
      is
      begin
         if Count = 0 then
            return 0;
         elsif Count = 1 or else Padding > 2 then
            return 0;
         elsif Count = 2 then
            return 1;
         elsif Count = 3 then
            return (if Padding = 0 then 2 else 1);
         else
            return 3 - Padding;
         end if;
      end Base64_Group_Decoded_Length;

      function Base64_Group_Byte
        (Values : Terminal.Common.Bytes.Byte_Array;
         Index  : Positive) return Terminal.Common.Bytes.Byte
      is
         V1 : constant Natural := Natural (Values (1));
         V2 : constant Natural := Natural (Values (2));
         V3 : constant Natural := Natural (Values (3));
         V4 : constant Natural := Natural (Values (4));
      begin
         case Index is
            when 1 =>
               return Terminal.Common.Bytes.Byte ((V1 * 4) + (V2 / 16));
            when 2 =>
               return Terminal.Common.Bytes.Byte
                 (((V2 mod 16) * 16) + (V3 / 4));
            when others =>
               return Terminal.Common.Bytes.Byte (((V3 mod 4) * 64) + V4);
         end case;
      end Base64_Group_Byte;

      procedure Measure_Base64_PNG is
         Count : Natural := 0;
         Padding : Natural := 0;
         Done : Boolean := False;

         procedure Append_Byte is
         begin
            if PNG_Length = Max_Data_Preview_Length then
               Result.Decode_Status := Decode_Preview_Truncated;
               Result.Decode_Complete := False;
               Done := True;
               return;
            end if;
            PNG_Length := PNG_Length + 1;
         end Append_Byte;

         procedure Flush_Group is
            Group_Length : constant Natural :=
              Base64_Group_Decoded_Length (Count, Padding);
         begin
            if Count = 0 then
               return;
            elsif Group_Length = 0 then
               Result.Decode_Status := Decode_Invalid_Byte;
               Result.Decode_Complete := False;
               Done := True;
               return;
            end if;

            for I in 1 .. Group_Length loop
               Append_Byte;
               if Done then
                  return;
               end if;
            end loop;
         end Flush_Group;
      begin
         Result.Header_Recognized := True;

         for Index in 1 .. Chunk_Count loop
            declare
               Text : constant String := Chunk_Text (Index);
            begin
               Encoded_Length := Encoded_Length + Text'Length;
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
                        if Count = 4 then
                           Flush_Group;
                           if Done then
                              return;
                           end if;
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
      end Measure_Base64_PNG;

      procedure Reset_Base64_Cursor is
      begin
         Cursor_Chunk := 1;
         Cursor_Offset := 0;
         Cursor_Values := (others => 0);
         Cursor_Count := 0;
         Cursor_Padding := 0;
         Cursor_Done := False;
         Cursor_Invalid := False;
         Decoded_Position := 0;
         Window_First := 0;
         Window_Last := 0;
         Window_Bytes := (others => 0);
      end Reset_Base64_Cursor;

      procedure Append_Window_Byte
        (Value : Terminal.Common.Bytes.Byte;
         Count : in out Natural)
      is
      begin
         Count := Count + 1;
         if Count <= Window_Bytes'Length then
            Window_Bytes (Count) := Value;
         else
            Cursor_Invalid := True;
         end if;
      end Append_Window_Byte;

      procedure Flush_Cursor_Group is
         Group_Count : constant Natural :=
           Base64_Group_Decoded_Length (Cursor_Count, Cursor_Padding);
         Emitted_Count : Natural := 0;
      begin
         if Cursor_Count = 0 then
            return;
         elsif Group_Count = 0 then
            Cursor_Invalid := True;
            return;
         end if;

         Window_First := Decoded_Position + 1;
         Window_Last := 0;
         Window_Bytes := (others => 0);

         for I in 1 .. Group_Count loop
            Append_Window_Byte
              (Base64_Group_Byte
                 ((1 => Terminal.Common.Bytes.Byte (Cursor_Values (1)),
                   2 => Terminal.Common.Bytes.Byte (Cursor_Values (2)),
                   3 => Terminal.Common.Bytes.Byte (Cursor_Values (3)),
                   4 => Terminal.Common.Bytes.Byte (Cursor_Values (4))),
                  I),
               Emitted_Count);
         end loop;

         if Cursor_Invalid then
            return;
         end if;

         Decoded_Position := Decoded_Position + Emitted_Count;
         Window_Last := Decoded_Position;
      end Flush_Cursor_Group;

      function Base64_PNG_Byte
        (Target : Positive) return Terminal.Common.Bytes.Byte
      is
      begin
         if Target > PNG_Length then
            return 0;
         end if;

         if Target >= Window_First and then Target <= Window_Last then
            return Window_Bytes (Target - Window_First + 1);
         elsif Target <= Decoded_Position then
            Reset_Base64_Cursor;
         end if;

         while Decoded_Position < Target
           and then not Cursor_Done
           and then not Cursor_Invalid
           and then Cursor_Chunk <= Chunk_Count
         loop
            declare
               Text : constant String := Chunk_Text (Cursor_Chunk);
            begin
               if Cursor_Offset = 0 then
                  Cursor_Offset := Text'First;
               end if;

               while Cursor_Offset <= Text'Last
                 and then Decoded_Position < Target
                 and then not Cursor_Done
                 and then not Cursor_Invalid
               loop
                  declare
                     Ch : constant Character := Text (Cursor_Offset);
                     V : constant Integer := Base64_Value (Ch);
                  begin
                     Cursor_Offset := Cursor_Offset + 1;
                     if Ch = ASCII.CR or else Ch = ASCII.LF or else Ch = ' ' then
                        null;
                     elsif Ch = '=' then
                        Cursor_Count := Cursor_Count + 1;
                        if Cursor_Count > 4 then
                           return 0;
                        end if;
                        Cursor_Padding := Cursor_Padding + 1;
                        Cursor_Values (Cursor_Count) := 0;
                        if Cursor_Count = 4 then
                           Flush_Cursor_Group;
                           Cursor_Done := True;
                        end if;
                     elsif V < 0 or else Cursor_Padding > 0 then
                        return 0;
                     else
                        Cursor_Count := Cursor_Count + 1;
                        if Cursor_Count > 4 then
                           return 0;
                        end if;
                        Cursor_Values (Cursor_Count) := Natural (V);
                        if Cursor_Count = 4 then
                           Flush_Cursor_Group;
                           Cursor_Values := (others => 0);
                           Cursor_Count := 0;
                        end if;
                     end if;
                  end;
               end loop;

               if Cursor_Offset > Text'Last then
                  Cursor_Chunk := Cursor_Chunk + 1;
                  Cursor_Offset := 0;
               end if;
            end;
         end loop;

         if Decoded_Position < Target
           and then not Cursor_Done
           and then not Cursor_Invalid
           and then Cursor_Count > 0
         then
            Flush_Cursor_Group;
            Cursor_Done := True;
         end if;

         if Target >= Window_First and then Target <= Window_Last then
            return Window_Bytes (Target - Window_First + 1);
         else
            return 0;
         end if;
      end Base64_PNG_Byte;
   begin
      Encoded_Length := 0;
      PNG_Length := 0;
      Release (Result);

      Measure_Base64_PNG;
      if not Result.Decode_Complete or else PNG_Length = 0 then
         Result.Encoded_Length := Encoded_Length;
         Result.Decode_Complete := False;
         return;
      end if;

      Decode_PNG_RGBA_Source_Rows
        (PNG_Length, Base64_PNG_Byte'Access, Row_Sink, Result);
   end Decode_Base64_PNG_Chunk_Rows;


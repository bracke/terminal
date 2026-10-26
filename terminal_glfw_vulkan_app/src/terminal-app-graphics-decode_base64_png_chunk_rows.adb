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
      Cursor_Decoder : Terminal.Common.Base64.Decoder_State;
      Cursor_Bytes : Terminal.Common.Base64.Decoded_Quantum;
      Cursor_Byte_Count : Natural := 0;
      Cursor_Status : Terminal.Common.Base64.Decoder_Status;
      Cursor_Done : Boolean := False;
      Cursor_Invalid : Boolean := False;
      Decoded_Position : Natural := 0;
      Window_First : Natural := 0;
      Window_Last : Natural := 0;
      Window_Bytes : Terminal.Common.Bytes.Byte_Array (1 .. 3) := (others => 0);

      procedure Measure_Base64_PNG is
         Decoder : Terminal.Common.Base64.Decoder_State;
         Bytes : Terminal.Common.Base64.Decoded_Quantum;
         Byte_Count : Natural := 0;
         Base64_Status : Terminal.Common.Base64.Decoder_Status;
         Done : Boolean := False;

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
            if Byte_Count > Max_Data_Preview_Length - PNG_Length then
               Result.Decode_Status := Decode_Preview_Truncated;
               Result.Decode_Complete := False;
               Done := True;
               return;
            end if;
            PNG_Length := PNG_Length + Byte_Count;
         end Append_Output;
      begin
         Result.Header_Recognized := True;
         Terminal.Common.Base64.Reset
           (Decoder, Allow_Unpadded => True, Allow_Whitespace => True);

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
      end Measure_Base64_PNG;

      procedure Reset_Base64_Cursor is
      begin
         Cursor_Chunk := 1;
         Cursor_Offset := 0;
         Terminal.Common.Base64.Reset
           (Cursor_Decoder,
            Allow_Unpadded => True,
            Allow_Whitespace => True);
         Cursor_Bytes := (others => 0);
         Cursor_Byte_Count := 0;
         Cursor_Done := False;
         Cursor_Invalid := False;
         Decoded_Position := 0;
         Window_First := 0;
         Window_Last := 0;
         Window_Bytes := (others => 0);
      end Reset_Base64_Cursor;

      procedure Capture_Cursor_Output is
      begin
         if Cursor_Status = Terminal.Common.Base64.Invalid_Data then
            Cursor_Invalid := True;
            return;
         end if;
         if Cursor_Byte_Count = 0 then
            return;
         end if;
         Window_First := Decoded_Position + 1;
         Window_Bytes := (others => 0);
         for I in 1 .. Cursor_Byte_Count loop
            Window_Bytes (I) := Cursor_Bytes (I);
         end loop;
         Decoded_Position := Decoded_Position + Cursor_Byte_Count;
         Window_Last := Decoded_Position;
      end Capture_Cursor_Output;

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
                  begin
                     Cursor_Offset := Cursor_Offset + 1;
                     Terminal.Common.Base64.Push
                       (Cursor_Decoder,
                        Ch,
                        Cursor_Bytes,
                        Cursor_Byte_Count,
                        Cursor_Status);
                     Capture_Cursor_Output;
                     Cursor_Done :=
                       Terminal.Common.Base64.Is_Complete (Cursor_Decoder);
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
         then
            Terminal.Common.Base64.Finish
              (Cursor_Decoder,
               Cursor_Bytes,
               Cursor_Byte_Count,
               Cursor_Status);
            Capture_Cursor_Output;
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

      Reset_Base64_Cursor;
      Decode_PNG_RGBA_Source_Rows
        (PNG_Length, Base64_PNG_Byte'Access, Row_Sink, Result);
   end Decode_Base64_PNG_Chunk_Rows;


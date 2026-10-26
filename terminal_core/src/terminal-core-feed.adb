separate (Terminal.Core)
procedure Feed
  (T      : in out Terminal;
   Data   : Core_Byte_Array;
   Status : out Feed_Status)
is
   Ch : Standard.Character;
   Overflowed : Boolean := False;
   Recovered  : Boolean := False;
begin
   if not T.Initialized then
      Status := Invalid_State;
      return;
   end if;

   T.Graphics_Queue_Overflowed := False;

   if T.Graphics_Input_Blocked then
      Status :=
        (if Append_Deferred_Input (T, Data) then Ok else Parser_Overflow);
      return;
   end if;

   for Data_Index in Data'Range loop
      declare
         B : constant Common.Bytes.Byte := Data (Data_Index);
      begin
      if T.Kitty_Chunk_Active then
         if T.State = Ground
           and then Natural (B) in 16#18# | 16#1A#
         then
            Advance_Graphics_Transaction (T);
            Enqueue_Graphics_Event
              (T,
               Kitty_Graphics,
               T.Cursor_Row,
               T.Cursor_Col,
               "",
               Cancelled => True);
            Clear_Kitty_Chunk (T);
         elsif T.State = Ground
           and then Natural (B) not in 16#1B# | 16#90# | 16#9F#
         then
            Reject_Kitty_Chunk_Interleave (T);
         elsif T.State = Escape
           and then Standard.Character'Val (Natural (B)) not in '_' | 'P'
         then
            Reject_Kitty_Chunk_Interleave (T);
         end if;
      end if;

      if Natural (B) = 16#9C#
        and then (In_String_Control (T.State) or else T.UTF8_Need = 0)
      then
         if T.State = OSC or else T.State = OSC_Escape then
            Finish_OSC (T);
            goto Continue;
         elsif T.State = OSC_Overflow
           or else T.State = OSC_Overflow_Escape
         then
            T.State := Ground;
            goto Continue;
         elsif T.State = Ignored_String
           or else T.State = Ignored_String_Escape
         then
            Finish_Ignored_String (T);
            goto Continue;
         elsif T.State = Ignored_String_Overflow
           or else T.State = Ignored_String_Overflow_Escape
         then
            T.Ignored_String_Is_DCS := False;
            T.Ignored_String_Is_APC := False;
            Clear_Graphics_Transfer (T);
            T.State := Ground;
            goto Continue;
         elsif not In_String_Control (T.State) then
            Recover_Incomplete_UTF8 (T);
            goto Continue;
         end if;
      elsif not In_String_Control (T.State) and then T.UTF8_Need = 0 then
         if Natural (B) = 16#9B# then
            Recover_Incomplete_UTF8 (T);
            Clear_CSI (T);
            T.State := CSI;
            goto Continue;
         elsif Natural (B) = 16#90# then
            Recover_Incomplete_UTF8 (T);
            Start_Ignored_String (T, Is_DCS => True);
            goto Continue;
         elsif Natural (B) = 16#98# then
            Recover_Incomplete_UTF8 (T);
            Start_Ignored_String (T, Is_DCS => False);
            goto Continue;
         elsif Natural (B) = 16#9E# then
            Recover_Incomplete_UTF8 (T);
            Start_Ignored_String (T, Is_DCS => False);
            goto Continue;
         elsif Natural (B) = 16#9F# then
            Recover_Incomplete_UTF8 (T);
            Start_Ignored_String (T, Is_DCS => False, Is_APC => True);
            goto Continue;
         elsif Natural (B) = 16#84# then
            Recover_Incomplete_UTF8 (T);
            Index_Control (T);
            goto Continue;
         elsif Natural (B) = 16#85# then
            Recover_Incomplete_UTF8 (T);
            Next_Line_Control (T);
            goto Continue;
         elsif Natural (B) = 16#88# then
            Recover_Incomplete_UTF8 (T);
            Horizontal_Tab_Set (T);
            goto Continue;
         elsif Natural (B) = 16#8C# then
            Recover_Incomplete_UTF8 (T);
            Reset_Terminal (T);
            goto Continue;
         elsif Natural (B) = 16#8D# then
            Recover_Incomplete_UTF8 (T);
            Reverse_Index_Control (T);
            goto Continue;
         elsif Natural (B) = 16#8E# then
            Recover_Incomplete_UTF8 (T);
            T.Single_Shift_Charset := G2;
            T.State := Single_Shift;
            goto Continue;
         elsif Natural (B) = 16#8F# then
            Recover_Incomplete_UTF8 (T);
            T.Single_Shift_Charset := G3;
            T.State := Single_Shift;
            goto Continue;
         elsif Natural (B) = 16#9D# then
            Recover_Incomplete_UTF8 (T);
            T.OSC_Count := 0;
            T.State := OSC;
            goto Continue;
         elsif Natural (B) = 16#7F# then
            Recover_Incomplete_UTF8 (T);
            goto Continue;
         end if;
      elsif Natural (B) = 16#7F# and then not In_String_Control (T.State) then
         Recover_Incomplete_UTF8 (T);
         goto Continue;
      end if;

      if Natural (B) < 32 then
         if T.State = OSC and then Natural (B) = 27 then
            T.State := OSC_Escape;
            goto Continue;
         elsif T.State = OSC_Overflow and then Natural (B) = 27 then
            T.State := OSC_Overflow_Escape;
            goto Continue;
         elsif T.State = Ignored_String and then Natural (B) = 27 then
            T.State := Ignored_String_Escape;
            goto Continue;
         elsif T.State = Ignored_String_Overflow and then Natural (B) = 27 then
            T.State := Ignored_String_Overflow_Escape;
            goto Continue;
         elsif T.State = OSC and then Natural (B) = 7 then
            Finish_OSC (T);
            goto Continue;
         elsif T.State = OSC_Overflow and then Natural (B) = 7 then
            T.State := Ground;
            goto Continue;
         elsif T.State = Ignored_String and then Natural (B) = 7 then
            Finish_Ignored_String (T);
            goto Continue;
         elsif T.State = Ignored_String_Overflow and then Natural (B) = 7 then
            T.Ignored_String_Is_DCS := False;
            T.Ignored_String_Is_APC := False;
            Clear_Graphics_Transfer (T);
            T.State := Ground;
            goto Continue;
         elsif (Natural (B) = 16#18# or else Natural (B) = 16#1A#)
           and then T.State /= Ground
         then
            if T.Kitty_Chunk_Active
              and then T.Ignored_String_Is_APC
            then
               --  CAN/SUB aborts the complete in-flight chunk transaction,
               --  not merely the APC fragment currently being parsed.
               --  Deliver an ordered marker so the app can release the
               --  encoded segments it owns without manufacturing a Kitty
               --  response or mutating any image placement.
               Advance_Graphics_Transaction (T);
               Enqueue_Graphics_Event
                 (T,
                  Kitty_Graphics,
                  T.Cursor_Row,
                  T.Cursor_Col,
                  "",
                  Cancelled => True);
               Clear_Kitty_Chunk (T);
            end if;
            Recover_Incomplete_UTF8 (T);
            Clear_CSI (T);
            Clear_Graphics_Transfer (T);
            T.Ignored_String_Is_DCS := False;
            T.Ignored_String_Is_APC := False;
            T.State := Ground;
            goto Continue;
         elsif T.State = Single_Shift then
            T.State := Ground;
            Recover_Incomplete_UTF8 (T);
            Execute_C0 (T, B);
            goto Continue;
         elsif not In_String_Control (T.State) then
            Recover_Incomplete_UTF8 (T);
            Execute_C0 (T, B);
            goto Continue;
         end if;
      end if;

      Ch := Standard.Character'Val (Natural (B));
      case T.State is
         when Ground =>
            Decode_Printable (T, B);
         when Escape =>
            case Ch is
               when 'c' =>
                  Reset_Terminal (T);
                  T.State := Ground;
               when '7' =>
                  Save_Cursor_State (T);
                  T.State := Ground;
               when '8' =>
                  Restore_Cursor_State (T);
                  T.State := Ground;
               when 'D' =>
                  Index_Control (T);
                  T.State := Ground;
               when 'E' =>
                  Next_Line_Control (T);
                  T.State := Ground;
               when 'H' =>
                  Horizontal_Tab_Set (T);
                  T.State := Ground;
               when 'M' =>
                  Reverse_Index_Control (T);
                  T.State := Ground;
               when 'N' =>
                  T.Single_Shift_Charset := G2;
                  T.State := Single_Shift;
               when 'O' =>
                  T.Single_Shift_Charset := G3;
                  T.State := Single_Shift;
               when 'Z' =>
                  Queue_Device_Attributes (T);
                  T.State := Ground;
               when '[' =>
                  Clear_CSI (T);
                  T.State := CSI;
               when ']' =>
                  T.OSC_Count := 0;
                  T.State := OSC;
               when 'P' =>
                  Start_Ignored_String (T, Is_DCS => True);
               when 'X' =>
                  Start_Ignored_String (T, Is_DCS => False);
               when '^' =>
                  Start_Ignored_String (T, Is_DCS => False);
               when '_' =>
                  Start_Ignored_String
                    (T, Is_DCS => False, Is_APC => True);
               when '(' =>
                  T.Charset_Target := G0;
                  T.State := Charset;
               when ')' | '-' =>
                  T.Charset_Target := G1;
                  T.State := Charset;
               when '*' | '.' =>
                  T.Charset_Target := G2;
                  T.State := Charset;
               when '+' | '/' =>
                  T.Charset_Target := G3;
                  T.State := Charset;
               when '%' =>
                  T.State := Coding_System;
               when '#' =>
                  T.State := Screen_Alignment;
               when '=' =>
                  T.Current_Modes.Application_Keypad := True;
                  T.State := Ground;
               when '>' =>
                  T.Current_Modes.Application_Keypad := False;
                  T.State := Ground;
               when others =>
                  T.Diag.Ignored_Escape := T.Diag.Ignored_Escape + 1;
                  Recovered := True;
                  T.State := Ground;
            end case;
         when CSI =>
            if Ch in '<' .. '?'
              and then T.CSI_Count = 0
              and then T.CSI_Private = ASCII.NUL
            then
               T.CSI_Private := Ch;
            elsif Ch in '0' .. '9' then
               if T.CSI_Count = 0 then
                  T.CSI_Count := 1;
               end if;
               T.CSI_Set (T.CSI_Count) := True;
               T.CSI_Params (T.CSI_Count) :=
                 Append_Decimal_Digit
                   (T.CSI_Params (T.CSI_Count),
                    Standard.Character'Pos (Ch)
                      - Standard.Character'Pos ('0'),
                    Natural'Last / 2);
            elsif Ch = ';' or else Ch = ':' then
               if T.CSI_Count < Parser.Max_CSI_Params then
                  T.CSI_Count := T.CSI_Count + 1;
                  T.CSI_Separators (T.CSI_Count) := Ch;
               else
                  T.Diag.Parser_Overflow := T.Diag.Parser_Overflow + 1;
                  Overflowed := True;
               end if;
            elsif Ch in ' ' .. '/' then
               if T.CSI_Intermediate_Count < Parser.Max_CSI_Intermediate then
                  T.CSI_Intermediate_Count := T.CSI_Intermediate_Count + 1;
                  T.CSI_Intermediates (T.CSI_Intermediate_Count) := Ch;
               else
                  T.Diag.Parser_Overflow := T.Diag.Parser_Overflow + 1;
                  Overflowed := True;
               end if;
            elsif Ch in '@' .. '~' then
               Execute_CSI (T, Ch);
               Clear_CSI (T);
               T.State := Ground;
            else
               T.Diag.Ignored_Escape := T.Diag.Ignored_Escape + 1;
               Recovered := True;
               Clear_CSI (T);
               T.State := Ground;
            end if;
         when OSC =>
            Append_OSC_Byte (T, Ch, Overflowed);
         when OSC_Escape =>
            if Ch = '\' then
               Finish_OSC (T);
            else
               Append_OSC_Byte (T, ASCII.ESC, Overflowed);
               if T.State = OSC_Overflow then
                  goto Continue;
               end if;
               Append_OSC_Byte (T, Ch, Overflowed);
               if T.State /= OSC_Overflow then
                  T.State := OSC;
               end if;
            end if;
         when OSC_Overflow =>
            null;
         when OSC_Overflow_Escape =>
            if Ch = '\' then
               T.State := Ground;
            else
               T.State := OSC_Overflow;
            end if;
         when Ignored_String =>
            Append_Ignored_String_Byte (T, Ch, Overflowed);
         when Ignored_String_Escape =>
            if Ch = '\' then
               Finish_Ignored_String (T);
            else
               Append_Ignored_String_Byte (T, ASCII.ESC, Overflowed);
               if T.State /= Ignored_String_Overflow then
                  Append_Ignored_String_Byte (T, Ch, Overflowed);
                  if T.State /= Ignored_String_Overflow then
                     T.State := Ignored_String;
                  end if;
               end if;
            end if;
         when Ignored_String_Overflow =>
            null;
         when Ignored_String_Overflow_Escape =>
            if Ch = '\' then
               T.Ignored_String_Is_DCS := False;
               T.Ignored_String_Is_APC := False;
               Clear_Graphics_Transfer (T);
               T.State := Ground;
            else
               T.State := Ignored_String_Overflow;
            end if;
         when Charset =>
            if Ch = '0' or else Ch = 'B' or else Ch = '@' then
               declare
                  New_Charset : constant Charset_Kind :=
                    (if Ch = '0' then DEC_Special_Graphics else ASCII_Charset);
               begin
                  case T.Charset_Target is
                     when G0 =>
                        T.G0_Charset := New_Charset;
                     when G1 =>
                        T.G1_Charset := New_Charset;
                     when G2 =>
                        T.G2_Charset := New_Charset;
                     when G3 =>
                        T.G3_Charset := New_Charset;
                  end case;
               end;
            else
               T.Diag.Ignored_Escape := T.Diag.Ignored_Escape + 1;
               Recovered := True;
            end if;
            T.State := Ground;
         when Coding_System =>
            if Ch /= 'G' and then Ch /= '@' then
               T.Diag.Ignored_Escape := T.Diag.Ignored_Escape + 1;
               Recovered := True;
            end if;
            T.State := Ground;
         when Single_Shift =>
            if Natural (B) < 16#80# then
               declare
                  Saved_Active : constant Charset_Slot := T.Active_Charset;
               begin
                  T.Active_Charset := T.Single_Shift_Charset;
                  Decode_Printable (T, B);
                  T.Active_Charset := Saved_Active;
               end;
            else
               Decode_Printable (T, B);
            end if;
            T.State := Ground;
         when Screen_Alignment =>
            if Ch = '8' then
               Screen_Alignment_Test (T);
            else
               T.Diag.Ignored_Escape := T.Diag.Ignored_Escape + 1;
               Recovered := True;
            end if;
            T.State := Ground;
      end case;

      <<Continue>>
      null;
      if T.Graphics_Input_Blocked then
         if Data_Index < Data'Last
           and then not Append_Deferred_Input
             (T, Data (Data_Index + 1 .. Data'Last))
         then
            Overflowed := True;
         end if;
         exit;
      end if;
      end;
   end loop;

   if Overflowed or else T.Graphics_Queue_Overflowed then
      Status := Parser_Overflow;
   elsif Recovered then
      Status := Parser_Recovered;
   else
      Status := Ok;
   end if;
end Feed;

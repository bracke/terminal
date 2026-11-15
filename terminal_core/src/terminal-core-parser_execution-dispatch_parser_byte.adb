separate (Terminal.Core.Parser_Execution)
procedure Dispatch_Parser_Byte
  (T                  : in out Terminal;
   B                  : Common.Bytes.Byte;
   Overflowed         : in out Boolean;
   Recovered          : in out Boolean;
   Passthrough        : in out Core_Byte_Array_Access;
   Passthrough_Length : in out Natural;
   Passthrough_Budget : in out Natural)
is
   Ch : constant Standard.Character :=
     Standard.Character'Val (Natural (B));
begin
   case T.Parser.State is
      when Ground =>
         Decode_Printable (T, B);
      when Escape =>
         case Ch is
            when 'c' =>
               Reset_Terminal (T);
               T.Parser.State := Ground;
            when '7' =>
               Save_Cursor_State (T);
               T.Parser.State := Ground;
            when '8' =>
               Restore_Cursor_State (T);
               T.Parser.State := Ground;
            when 'D' =>
               Index_Control (T);
               T.Parser.State := Ground;
            when 'E' =>
               Next_Line_Control (T);
               T.Parser.State := Ground;
            when 'H' =>
               Horizontal_Tab_Set (T);
               T.Parser.State := Ground;
            when 'M' =>
               Reverse_Index_Control (T);
               T.Parser.State := Ground;
            when 'N' =>
               T.Single_Shift_Charset := G2;
               T.Parser.State := Single_Shift;
            when 'O' =>
               T.Single_Shift_Charset := G3;
               T.Parser.State := Single_Shift;
            when 'Z' =>
               Queue_Device_Attributes (T);
               T.Parser.State := Ground;
            when '[' =>
               Clear_CSI (T);
               T.Parser.State := CSI;
            when ']' =>
               T.Parser.OSC_Count := 0;
               T.Parser.State := OSC;
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
               T.Parser.State := Charset;
            when ')' | '-' =>
               T.Charset_Target := G1;
               T.Parser.State := Charset;
            when '*' | '.' =>
               T.Charset_Target := G2;
               T.Parser.State := Charset;
            when '+' | '/' =>
               T.Charset_Target := G3;
               T.Parser.State := Charset;
            when '%' =>
               T.Parser.State := Coding_System;
            when '#' =>
               T.Parser.State := Screen_Alignment;
            when '=' =>
               T.Current_Modes.Application_Keypad := True;
               T.Parser.State := Ground;
            when '>' =>
               T.Current_Modes.Application_Keypad := False;
               T.Parser.State := Ground;
            when others =>
               Increment_Saturating (T.Diag.Ignored_Escape);
               Recovered := True;
               T.Parser.State := Ground;
         end case;
      when CSI =>
         if Ch in '<' .. '?'
           and then T.Parser.CSI_Count = 0
           and then T.Parser.CSI_Private = ASCII.NUL
         then
            T.Parser.CSI_Private := Ch;
         elsif Ch in '0' .. '9' then
            if T.Parser.CSI_Count = 0 then
               T.Parser.CSI_Count := 1;
            end if;
            T.Parser.CSI_Set (T.Parser.CSI_Count) := True;
            declare
               Digit : constant Natural :=
                 Standard.Character'Pos (Ch)
                 - Standard.Character'Pos ('0');
               Value : Natural renames
                 T.Parser.CSI_Params (T.Parser.CSI_Count);
            begin
               if Value > (Parser.Max_CSI_Parameter - Digit) / 10 then
                  Value := Parser.Max_CSI_Parameter;
                  Increment_Saturating (T.Diag.Parser_Overflow);
                  T.Parser.CSI_Invalid := True;
                  Overflowed := True;
               else
                  Value := Value * 10 + Digit;
               end if;
            end;
         elsif Ch = ';' or else Ch = ':' then
            if T.Parser.CSI_Count < Parser.Max_CSI_Params then
               T.Parser.CSI_Count := T.Parser.CSI_Count + 1;
               T.Parser.CSI_Separators (T.Parser.CSI_Count) := Ch;
            else
               Increment_Saturating (T.Diag.Parser_Overflow);
               T.Parser.CSI_Invalid := True;
               Overflowed := True;
            end if;
         elsif Ch in ' ' .. '/' then
            if T.Parser.CSI_Intermediate_Count < Parser.Max_CSI_Intermediate then
               T.Parser.CSI_Intermediate_Count := T.Parser.CSI_Intermediate_Count + 1;
               T.Parser.CSI_Intermediates (T.Parser.CSI_Intermediate_Count) := Ch;
            else
               Increment_Saturating (T.Diag.Parser_Overflow);
               T.Parser.CSI_Invalid := True;
               Overflowed := True;
            end if;
         elsif Ch in '@' .. '~' then
            if T.Parser.CSI_Invalid then
               --  Never execute a command assembled from saturated or
               --  truncated fields.  In particular, REP would otherwise
               --  amplify a few input bytes into tens of thousands of cell
               --  updates.  Mark recovery in the call that sees the final
               --  byte even when the overflow was reported by an earlier
               --  Feed call.
               Recovered := True;
            else
               Execute_CSI (T, Ch);
            end if;
            Clear_CSI (T);
            T.Parser.State := Ground;
         else
            Increment_Saturating (T.Diag.Ignored_Escape);
            Recovered := True;
            Clear_CSI (T);
            T.Parser.State := Ground;
         end if;
      when OSC =>
         Append_OSC_Byte (T, Ch, Overflowed);
      when OSC_Escape =>
         if Ch = '\' then
            Finish_OSC (T);
         else
            Append_OSC_Byte (T, ASCII.ESC, Overflowed);
            if T.Parser.State = OSC_Overflow then
               return;
            end if;
            Append_OSC_Byte (T, Ch, Overflowed);
            if T.Parser.State /= OSC_Overflow then
               T.Parser.State := OSC;
            end if;
         end if;
      when OSC_Overflow =>
         null;
      when OSC_Overflow_Escape =>
         if Ch = '\' then
            T.Parser.State := Ground;
         else
            T.Parser.State := OSC_Overflow;
         end if;
      when Ignored_String =>
         Append_Ignored_String_Byte (T, Ch, Overflowed);
      when Ignored_String_Escape =>
         if Ch = '\' then
            Finish_Ignored_String
              (T, Overflowed, Recovered, Passthrough,
               Passthrough_Length, Passthrough_Budget);
         else
            Append_Ignored_String_Byte (T, ASCII.ESC, Overflowed);
            if T.Parser.State /= Ignored_String_Overflow then
               Append_Ignored_String_Byte (T, Ch, Overflowed);
               if T.Parser.State /= Ignored_String_Overflow then
                  T.Parser.State := Ignored_String;
               end if;
            end if;
         end if;
      when Ignored_String_Overflow =>
         null;
      when Ignored_String_Overflow_Escape =>
         if Ch = '\' then
            T.Parser.Ignored_String_Is_DCS := False;
            T.Parser.Ignored_String_Is_APC := False;
            Graphics_Runtime.Clear_Graphics_Transfer (T.Graphics);
            T.Parser.State := Ground;
         else
            T.Parser.State := Ignored_String_Overflow;
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
            Increment_Saturating (T.Diag.Ignored_Escape);
            Recovered := True;
         end if;
         T.Parser.State := Ground;
      when Coding_System =>
         if Ch /= 'G' and then Ch /= '@' then
            Increment_Saturating (T.Diag.Ignored_Escape);
            Recovered := True;
         end if;
         T.Parser.State := Ground;
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
         T.Parser.State := Ground;
      when Screen_Alignment =>
         if Ch = '8' then
            Screen_Alignment_Test (T);
         else
            Increment_Saturating (T.Diag.Ignored_Escape);
            Recovered := True;
         end if;
         T.Parser.State := Ground;
   end case;
end Dispatch_Parser_Byte;

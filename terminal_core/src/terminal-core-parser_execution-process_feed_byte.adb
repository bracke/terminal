separate (Terminal.Core.Parser_Execution)
procedure Process_Feed_Byte
  (T                  : in out Terminal;
   B                  : Common.Bytes.Byte;
   Overflowed         : in out Boolean;
   Recovered          : in out Boolean;
   Passthrough        : in out Core_Byte_Array_Access;
   Passthrough_Length : in out Natural;
   Passthrough_Budget : in out Natural)
is
begin
   if T.Graphics.Kitty_Chunk_Active then
      if T.Parser.State = Ground
        and then Natural (B) in 16#18# | 16#1A#
      then
         Graphics_Runtime.Advance_Graphics_Transaction (T.Graphics);
         Enqueue_Graphics_Event
           (T,
            Kitty_Graphics,
            T.Cursor_Row,
            T.Cursor_Col,
            "",
            Cancelled => True);
         Graphics_Runtime.Clear_Kitty_Chunk (T.Graphics);
      elsif T.Parser.State = Ground
        and then Natural (B) not in 16#1B# | 16#90# | 16#9F#
      then
         Reject_Kitty_Chunk_Interleave (T);
      elsif T.Parser.State = Escape
        and then Standard.Character'Val (Natural (B)) not in '_' | 'P'
      then
         Reject_Kitty_Chunk_Interleave (T);
      end if;
   end if;

   if Natural (B) = 16#9C#
     and then (In_String_Control (T.Parser.State) or else T.Parser.UTF8_Need = 0)
   then
      if T.Parser.State = OSC or else T.Parser.State = OSC_Escape then
         Finish_OSC (T);
         goto Continue;
      elsif T.Parser.State = OSC_Overflow
        or else T.Parser.State = OSC_Overflow_Escape
      then
         T.Parser.State := Ground;
         goto Continue;
      elsif T.Parser.State = Ignored_String
        or else T.Parser.State = Ignored_String_Escape
      then
         Finish_Ignored_String
           (T, Overflowed, Recovered, Passthrough,
            Passthrough_Length, Passthrough_Budget);
         goto Continue;
      elsif T.Parser.State = Ignored_String_Overflow
        or else T.Parser.State = Ignored_String_Overflow_Escape
      then
         T.Parser.Ignored_String_Is_DCS := False;
         T.Parser.Ignored_String_Is_APC := False;
         Graphics_Runtime.Clear_Graphics_Transfer (T.Graphics);
         T.Parser.State := Ground;
         goto Continue;
      elsif not In_String_Control (T.Parser.State) then
         Recover_Incomplete_UTF8 (T);
         goto Continue;
      end if;
   elsif not In_String_Control (T.Parser.State) and then T.Parser.UTF8_Need = 0 then
      if Natural (B) = 16#9B# then
         Recover_Incomplete_UTF8 (T);
         Clear_CSI (T);
         T.Parser.State := CSI;
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
         T.Parser.State := Single_Shift;
         goto Continue;
      elsif Natural (B) = 16#8F# then
         Recover_Incomplete_UTF8 (T);
         T.Single_Shift_Charset := G3;
         T.Parser.State := Single_Shift;
         goto Continue;
      elsif Natural (B) = 16#9D# then
         Recover_Incomplete_UTF8 (T);
         T.Parser.OSC_Count := 0;
         T.Parser.State := OSC;
         goto Continue;
      elsif Natural (B) = 16#7F# then
         Recover_Incomplete_UTF8 (T);
         goto Continue;
      end if;
   elsif Natural (B) = 16#7F# and then not In_String_Control (T.Parser.State) then
      Recover_Incomplete_UTF8 (T);
      goto Continue;
   end if;

   if Natural (B) < 32 then
      if T.Parser.State = OSC and then Natural (B) = 27 then
         T.Parser.State := OSC_Escape;
         goto Continue;
      elsif T.Parser.State = OSC_Overflow and then Natural (B) = 27 then
         T.Parser.State := OSC_Overflow_Escape;
         goto Continue;
      elsif T.Parser.State = Ignored_String and then Natural (B) = 27 then
         T.Parser.State := Ignored_String_Escape;
         goto Continue;
      elsif T.Parser.State = Ignored_String_Overflow and then Natural (B) = 27 then
         T.Parser.State := Ignored_String_Overflow_Escape;
         goto Continue;
      elsif T.Parser.State = OSC and then Natural (B) = 7 then
         Finish_OSC (T);
         goto Continue;
      elsif T.Parser.State = OSC_Overflow and then Natural (B) = 7 then
         T.Parser.State := Ground;
         goto Continue;
      elsif T.Parser.State = Ignored_String and then Natural (B) = 7 then
         Finish_Ignored_String
           (T, Overflowed, Recovered, Passthrough,
            Passthrough_Length, Passthrough_Budget);
         goto Continue;
      elsif T.Parser.State = Ignored_String_Overflow and then Natural (B) = 7 then
         T.Parser.Ignored_String_Is_DCS := False;
         T.Parser.Ignored_String_Is_APC := False;
         Graphics_Runtime.Clear_Graphics_Transfer (T.Graphics);
         T.Parser.State := Ground;
         goto Continue;
      elsif (Natural (B) = 16#18# or else Natural (B) = 16#1A#)
        and then T.Parser.State /= Ground
      then
         if T.Graphics.Kitty_Chunk_Active
           and then T.Parser.Ignored_String_Is_APC
         then
            --  CAN/SUB aborts the complete in-flight chunk transaction,
            --  not merely the APC fragment currently being parsed.
            --  Deliver an ordered marker so the app can release the
            --  encoded segments it owns without manufacturing a Kitty
            --  response or mutating any image placement.
            Graphics_Runtime.Advance_Graphics_Transaction (T.Graphics);
            Enqueue_Graphics_Event
              (T,
               Kitty_Graphics,
               T.Cursor_Row,
               T.Cursor_Col,
               "",
               Cancelled => True);
            Graphics_Runtime.Clear_Kitty_Chunk (T.Graphics);
         end if;
         Recover_Incomplete_UTF8 (T);
         Clear_CSI (T);
         Graphics_Runtime.Clear_Graphics_Transfer (T.Graphics);
         T.Parser.Ignored_String_Is_DCS := False;
         T.Parser.Ignored_String_Is_APC := False;
         T.Parser.State := Ground;
         goto Continue;
      elsif T.Parser.State = Single_Shift then
         T.Parser.State := Ground;
         Recover_Incomplete_UTF8 (T);
         Execute_C0 (T, B);
         goto Continue;
      elsif not In_String_Control (T.Parser.State) then
         Recover_Incomplete_UTF8 (T);
         Execute_C0 (T, B);
         goto Continue;
      end if;
   end if;

   Dispatch_Parser_Byte
     (T, B, Overflowed, Recovered, Passthrough,
      Passthrough_Length, Passthrough_Budget);

   <<Continue>>
   null;

end Process_Feed_Byte;

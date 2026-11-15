with AUnit.Assertions;
with Terminal.Common.UTF8;

procedure Common_UTF8_Smoke is
   use AUnit.Assertions;
   use type Terminal.Common.UTF8.UTF16_Unit;
   Result : Terminal.Common.UTF8.UTF16_Array (3 .. 10);
   Length : Natural;
   Valid  : Boolean;

   procedure Decode (Value : String) is
   begin
      Terminal.Common.UTF8.Decode_UTF16 (Value, Result, Length, Valid);
   end Decode;
begin
   Decode
     ("A"
      & Character'Val (16#C2#) & Character'Val (16#A2#)
      & Character'Val (16#E2#) & Character'Val (16#82#)
      & Character'Val (16#AC#)
      & Character'Val (16#F0#) & Character'Val (16#9F#)
      & Character'Val (16#98#) & Character'Val (16#80#));
   Assert
     (Valid
      and then Length = 5
      and then Result (3) = 16#0041#
      and then Result (4) = 16#00A2#
      and then Result (5) = 16#20AC#
      and then Result (6) = 16#D83D#
      and then Result (7) = 16#DE00#
      and then Result (8) = 0,
      "UTF-8 decoder should emit BMP and surrogate-pair UTF-16");

   Decode (Character'Val (16#C0#) & Character'Val (16#80#));
   Assert (not Valid, "UTF-8 decoder should reject overlong sequences");
   Decode
     (Character'Val (16#ED#) & Character'Val (16#A0#)
      & Character'Val (16#80#));
   Assert (not Valid, "UTF-8 decoder should reject surrogate scalars");
   Decode (Character'Val (16#F0#) & Character'Val (16#9F#));
   Assert (not Valid, "UTF-8 decoder should reject truncated sequences");

   declare
      Short : Terminal.Common.UTF8.UTF16_Array (1 .. 1);
   begin
      Terminal.Common.UTF8.Decode_UTF16 ("A", Short, Length, Valid);
      Assert (not Valid, "UTF-8 decoder should reserve a UTF-16 terminator");
   end;
end Common_UTF8_Smoke;

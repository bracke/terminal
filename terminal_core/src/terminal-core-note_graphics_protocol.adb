separate (Terminal.Core)
procedure Note_Graphics_Protocol
  (T        : in out Terminal;
   Protocol : Graphics_Protocol;
   Payload_Length : Natural;
   Preview        : String := "";
   At_Row         : Natural := 0;
   At_Col         : Natural := 0;
   Kitty_Validation_Error : Boolean := False)
is
   Event_Protocol : Graphics_Protocol_Kind := No_Graphics;
begin
   Increment_Saturating (T.Diag.Graphics_Commands_Received);
   T.Diag.Last_Graphics_Payload_Length := Payload_Length;

   case Protocol is
      when Graphics_Sixel =>
         Increment_Saturating (T.Diag.Sixel_Commands_Received);
         T.Diag.Last_Graphics_Protocol := Sixel_Graphics;
         Event_Protocol := Sixel_Graphics;
      when Graphics_Kitty =>
         Increment_Saturating (T.Diag.Kitty_Commands_Received);
         T.Diag.Last_Graphics_Protocol := Kitty_Graphics;
         Event_Protocol := Kitty_Graphics;
      when Graphics_ITerm2 =>
         Increment_Saturating (T.Diag.ITerm2_Commands_Received);
         T.Diag.Last_Graphics_Protocol := ITerm2_Graphics;
         Event_Protocol := ITerm2_Graphics;
   end case;

   Enqueue_Graphics_Event
     (T,
      Event_Protocol,
      (if At_Row = 0 then T.Cursor_Row
       else Positive'Min (T.Rows, Positive (At_Row))),
      (if At_Col = 0 then T.Cursor_Col
       else Positive'Min (T.Cols, Positive (At_Col))),
      Preview,
      Cancelled => Kitty_Validation_Error);
end Note_Graphics_Protocol;

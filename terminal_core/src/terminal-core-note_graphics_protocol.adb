separate (Terminal.Core)
procedure Note_Graphics_Protocol
  (T        : in out Terminal;
   Protocol : Graphics_Protocol;
   Payload_Length : Natural;
   Preview        : String := "";
   Enqueue        : Boolean := True;
   At_Row         : Natural := 0;
   At_Col         : Natural := 0;
   Kitty_Validation_Error : Boolean := False)
is
   Preview_Length : constant Graphics_Preview_Length_Range :=
     Graphics_Preview_Length_Range'Min
       (Preview'Length, Max_Graphics_Preview_Length);
   Previous_Graphics : constant Graphics_Event := T.Last_Graphics;
begin
   T.Diag.Graphics_Protocol_Ignored :=
     T.Diag.Graphics_Protocol_Ignored + 1;
   T.Diag.Last_Graphics_Payload_Length := Payload_Length;
   T.Last_Graphics.Pending := True;
   T.Last_Graphics.Cancelled := Kitty_Validation_Error;
   T.Last_Graphics.Stream_ID := T.Graphics_Stream;
   T.Last_Graphics.Sequence := 0;
   T.Last_Graphics.Transaction_Generation := T.Graphics_Transaction;
   T.Last_Graphics.Alternate_Screen := T.Active = Alternate;
   T.Last_Graphics.Screen_Generation :=
     (if T.Active = Alternate
      then T.Alternate_Graphics_Generation
      else T.Primary_Graphics_Generation);
   T.Last_Graphics.Scroll_Sequence :=
     (if T.Active = Alternate
      then T.Alternate_Graphics_Scroll_Sequence
      else T.Primary_Graphics_Scroll_Sequence);
   T.Last_Graphics.Sixel_Private_Colors :=
     T.Current_Modes.Sixel_Private_Colors;
   T.Last_Graphics.Row :=
     (if At_Row = 0 then T.Cursor_Row
      else Positive'Min (T.Rows, Positive (At_Row)));
   T.Last_Graphics.Col :=
     (if At_Col = 0 then T.Cursor_Col
      else Positive'Min (T.Cols, Positive (At_Col)));
   T.Last_Graphics.Payload_Length := Payload_Length;
   T.Last_Graphics.Preview_Length := Preview_Length;
   T.Last_Graphics.Preview := (others => ASCII.NUL);
   for I in 1 .. Preview_Length loop
      T.Last_Graphics.Preview (I) := Preview (Preview'First + I - 1);
   end loop;

   case Protocol is
      when Graphics_Sixel =>
         T.Diag.Sixel_Ignored := T.Diag.Sixel_Ignored + 1;
         T.Diag.Last_Graphics_Protocol := Sixel_Graphics;
         T.Last_Graphics.Protocol := Sixel_Graphics;
      when Graphics_Kitty =>
         T.Diag.Kitty_Graphics_Ignored :=
           T.Diag.Kitty_Graphics_Ignored + 1;
         T.Diag.Last_Graphics_Protocol := Kitty_Graphics;
         T.Last_Graphics.Protocol := Kitty_Graphics;
      when Graphics_ITerm2 =>
         T.Diag.ITerm2_Image_Ignored :=
           T.Diag.ITerm2_Image_Ignored + 1;
         T.Diag.Last_Graphics_Protocol := ITerm2_Graphics;
         T.Last_Graphics.Protocol := ITerm2_Graphics;
   end case;

   if Enqueue then
      Enqueue_Graphics_Event
        (T,
         T.Last_Graphics.Protocol,
         T.Last_Graphics.Row,
         T.Last_Graphics.Col,
         Preview,
         Cancelled => Kitty_Validation_Error);
      --  The compatibility snapshot must never publish a command rejected
      --  by the bounded queue.  Successful queue entries always receive a
      --  nonzero sequence number from Enqueue_Graphics_Event.
      if T.Last_Graphics.Sequence = 0 then
         T.Last_Graphics := Previous_Graphics;
      end if;
   end if;
end Note_Graphics_Protocol;

with Terminal.Core.Graphics_Runtime;

separate (Terminal.Core)
procedure Enqueue_Graphics_Event
  (T              : in out Terminal;
   Protocol       : Graphics_Protocol_Kind;
   Row            : Positive;
   Col            : Positive;
   Payload        : String;
   Cancelled      : Boolean := False)
is
   use type Graphics_Runtime.Enqueue_Result;
   Context : constant Graphics_Runtime.Event_Context :=
     (Stream_ID            => T.Graphics.Stream,
      Transaction          => T.Graphics.Transaction,
      Alternate_Screen     => T.Active = Alternate,
      Screen_Generation    =>
        (if T.Active = Alternate
         then T.Graphics.Alternate_Generation
         else T.Graphics.Primary_Generation),
      Scroll_Sequence      =>
        (if T.Active = Alternate
         then T.Graphics.Alternate_Scroll_Sequence
         else T.Graphics.Primary_Scroll_Sequence),
      Sixel_Private_Colors => T.Current_Modes.Sixel_Private_Colors,
      Row                  => Row,
      Col                  => Col);
   Result : Graphics_Runtime.Enqueue_Result;
begin
   Graphics_Runtime.Enqueue_Event
     (T.Graphics, Protocol, Context, Payload, Cancelled, Result);
   if Result /= Graphics_Runtime.Event_Enqueued then
      Common.Counters.Increment_Saturating (T.Diag.Queue_Overflow);
   end if;
end Enqueue_Graphics_Event;

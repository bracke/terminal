separate (Terminal.Core)
procedure Enqueue_Graphics_Event
  (T              : in out Terminal;
   Protocol       : Ignored_Graphics_Protocol;
   Row            : Positive;
   Col            : Positive;
   Payload        : String;
   Cancelled      : Boolean := False)
is
   Stored : String_Access := null;
   Node   : Graphics_Event_Node_Access := null;
   Blocks_Input : Boolean := False;
   Old_Chunk_Active : constant Boolean := T.Kitty_Chunk_Active;
   Old_Chunk_Blocks : constant Boolean := T.Kitty_Chunk_Blocks_Input;
begin
   if T.Graphics_Event_Count >= T.Graphics_Limits.Pending_Events
     or else Payload'Length > T.Graphics_Limits.Pending_Bytes
     or else T.Graphics_Byte_Count >
       T.Graphics_Limits.Pending_Bytes - Payload'Length
   then
      T.Diag.Queue_Overflow := T.Diag.Queue_Overflow + 1;
      T.Graphics_Queue_Overflowed := True;
      return;
   end if;

   Blocks_Input :=
     not Cancelled
     and then
       (case Protocol is
           when Kitty_Graphics => Kitty_Command_Blocks_Input (T, Payload),
           when ITerm2_Graphics => ITerm2_Command_Blocks_Input (Payload),
           when Sixel_Graphics => False,
           when No_Graphics => False);
   Stored := new String'(Payload);
   Node := new Graphics_Event_Node'
     (Protocol       => Protocol,
      Cancelled      => Cancelled,
      Stream_ID      => T.Graphics_Stream,
      Sequence       => T.Next_Graphics_Sequence,
      Transaction_Generation => T.Graphics_Transaction,
      Blocks_Input   => Blocks_Input,
      Alternate_Screen => T.Active = Alternate,
      Screen_Generation =>
        (if T.Active = Alternate
         then T.Alternate_Graphics_Generation
         else T.Primary_Graphics_Generation),
      Scroll_Sequence =>
        (if T.Active = Alternate
         then T.Alternate_Graphics_Scroll_Sequence
         else T.Primary_Graphics_Scroll_Sequence),
      Sixel_Private_Colors => T.Current_Modes.Sixel_Private_Colors,
      Row            => Row,
      Col            => Col,
      Payload_Length => Payload'Length,
      Payload        => Stored,
      Read_Offset    => 0,
      Next           => null);

   if T.Graphics_Tail = null then
      T.Graphics_Head := Node;
   else
      T.Graphics_Tail.Next := Node;
   end if;
   T.Graphics_Tail := Node;
   T.Graphics_Event_Count := T.Graphics_Event_Count + 1;
   T.Graphics_Byte_Count := T.Graphics_Byte_Count + Payload'Length;
   T.Graphics_Queue_Backpressure :=
     T.Graphics_Event_Count >= T.Graphics_Limits.Pending_Events
     or else
       (T.Graphics_Event_Count > 0
        and then
          T.Graphics_Limits.Pending_Bytes - T.Graphics_Byte_Count <
            Natural'Min
              (T.Graphics_Limits.Transaction_Length,
               T.Graphics_Limits.Pending_Bytes));
   T.Graphics_Input_Blocked :=
     T.Graphics_Input_Blocked
     or else Blocks_Input
     or else T.Graphics_Queue_Backpressure;
   T.Last_Graphics.Stream_ID := T.Graphics_Stream;
   T.Last_Graphics.Sequence := Node.Sequence;
   T.Last_Graphics.Transaction_Generation := T.Graphics_Transaction;
   T.Last_Graphics.Alternate_Screen := Node.Alternate_Screen;
   T.Last_Graphics.Screen_Generation := Node.Screen_Generation;
   T.Last_Graphics.Scroll_Sequence := Node.Scroll_Sequence;
   T.Last_Graphics.Sixel_Private_Colors := Node.Sixel_Private_Colors;
   T.Next_Graphics_Sequence := T.Next_Graphics_Sequence + 1;
   if T.Next_Graphics_Sequence = 0 then
      T.Next_Graphics_Sequence := 1;
   end if;
exception
   when Storage_Error =>
      if Node /= null then
         Free_Graphics_Node (Node);
      end if;
      if Stored /= null then
         Free_String (Stored);
      end if;
      T.Kitty_Chunk_Active := Old_Chunk_Active;
      T.Kitty_Chunk_Blocks_Input := Old_Chunk_Blocks;
      T.Diag.Queue_Overflow := T.Diag.Queue_Overflow + 1;
      T.Graphics_Queue_Overflowed := True;
end Enqueue_Graphics_Event;

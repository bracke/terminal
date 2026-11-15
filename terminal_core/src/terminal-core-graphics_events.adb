with Terminal.Core.Graphics_Runtime;

package body Terminal.Core.Graphics_Events is
   use type Graphics_Event_Node_Access;
   use type Graphics_Event_Sequence;
   use type Graphics_Stream_ID;
   use type Graphics_Protocol_Kind;
   use type String_Access;

   function Rank (Status : Feed_Status) return Natural is
     (case Status is
         when Ok               => 0,
         when Parser_Recovered => 1,
         when Parser_Overflow  => 2,
         when Invalid_State    => 3);

   procedure Remember_Deferred_Status
     (T      : in out Terminal;
      Status : Feed_Status) is
   begin
      if Rank (Status) > Rank (T.Graphics.Deferred_Feed_Status) then
         T.Graphics.Deferred_Feed_Status := Status;
      end if;
   end Remember_Deferred_Status;

   procedure Resume_Deferred_Input (T : in out Terminal) is
      Saved  : Core_Byte_Array_Access := null;
      Length : Natural := 0;
      Status : Feed_Status;
   begin
      Graphics_Runtime.Take_Deferred_Input (T.Graphics, Saved, Length);
      if Saved = null or else Length = 0 then
         Graphics_Runtime.Release_Byte_Array (Saved);
         return;
      end if;
      Feed (T, Saved (1 .. Length), Status);
      Remember_Deferred_Status (T, Status);
      Graphics_Runtime.Release_Byte_Array (Saved);
   exception
      when others =>
         Graphics_Runtime.Release_Byte_Array (Saved);
         raise;
   end Resume_Deferred_Input;

   function Take_Deferred_Feed_Status
     (T : in out Terminal) return Feed_Status
   is
      Status : constant Feed_Status := T.Graphics.Deferred_Feed_Status;
   begin
      T.Graphics.Deferred_Feed_Status := Ok;
      return Status;
   end Take_Deferred_Feed_Status;

   procedure Peek
     (T     : Terminal;
      Event : out Graphics_Event)
   is
      Node          : constant Graphics_Event_Node_Access := T.Graphics.Head;
      Preview_Count : Natural;
   begin
      Event := (others => <>);
      if Node = null then
         return;
      end if;

      Event.Pending := True;
      Event.Cancelled := Node.Cancelled;
      Event.Protocol := Node.Protocol;
      Event.Stream_ID := Node.Stream_ID;
      Event.Sequence := Node.Sequence;
      Event.Transaction_Generation := Node.Transaction_Generation;
      Event.Alternate_Screen := Node.Alternate_Screen;
      Event.Screen_Generation := Node.Screen_Generation;
      Event.Scroll_Sequence := Node.Scroll_Sequence;
      Event.Sixel_Private_Colors := Node.Sixel_Private_Colors;
      Event.Row := Node.Row;
      Event.Col := Node.Col;
      Event.Payload_Length := Node.Payload_Length;
      Preview_Count :=
        Natural'Min (Node.Payload_Length, Max_Graphics_Preview_Length);
      Event.Preview_Length := Preview_Count;
      if Preview_Count > 0 and then Node.Payload /= null then
         Event.Preview (1 .. Preview_Count) :=
           Node.Payload (1 .. Preview_Count);
      end if;
   end Peek;

   function Payload
     (T     : Terminal;
      Event : Graphics_Event) return String
   is
      Node : constant Graphics_Event_Node_Access := T.Graphics.Head;
   begin
      if Node = null
        or else not Event.Pending
        or else Event.Protocol /= Node.Protocol
        or else Event.Stream_ID /= Node.Stream_ID
        or else Event.Sequence /= Node.Sequence
        or else Node.Payload = null
      then
         return "";
      end if;
      return Node.Payload.all;
   end Payload;

   procedure Visit_Payload
     (T       : Terminal;
      Event   : Graphics_Event;
      Process : not null access procedure (Payload : String);
      Visited : out Boolean)
   is
      Node : constant Graphics_Event_Node_Access := T.Graphics.Head;
   begin
      Visited := False;
      if Node = null
        or else not Event.Pending
        or else Event.Protocol /= Node.Protocol
        or else Event.Stream_ID /= Node.Stream_ID
        or else Event.Sequence /= Node.Sequence
        or else Node.Payload = null
      then
         return;
      end if;
      Process (Node.Payload.all);
      Visited := True;
   end Visit_Payload;

   procedure Resume_If_Unblocked
     (T           : in out Terminal;
      Was_Blocked : Boolean) is
   begin
      if Was_Blocked and then not T.Graphics.Input_Blocked then
         Graphics_Events.Resume_Deferred_Input (T);
      end if;
   end Resume_If_Unblocked;

   procedure Discard (T : in out Terminal) is
      Was_Blocked : constant Boolean := T.Graphics.Input_Blocked;
   begin
      Graphics_Runtime.Drop_Graphics_Head (T.Graphics);
      Resume_If_Unblocked (T, Was_Blocked);
   end Discard;

   procedure Read
     (T            : in out Terminal;
      Event        : out Graphics_Event;
      Buffer       : out Core_Byte_Array;
      Last         : out Natural;
      End_Of_Event : out Boolean)
   is
      Node      : constant Graphics_Event_Node_Access := T.Graphics.Head;
      Remaining : Natural;
      Count     : Natural;
   begin
      Peek (T, Event);
      Last := 0;
      End_Of_Event := True;
      if Node = null then
         return;
      end if;

      Remaining := Node.Payload_Length - Node.Read_Offset;
      Count := Natural'Min (Buffer'Length, Remaining);
      if Count > 0 and then Node.Payload /= null then
         for I in 1 .. Count loop
            Buffer (Buffer'First + I - 1) :=
              Common.Bytes.Byte
                (Standard.Character'Pos
                   (Node.Payload (Node.Read_Offset + I)));
         end loop;
         Node.Read_Offset := Node.Read_Offset + Count;
         Last := Count;
      end if;

      --  Reading and acknowledging are intentionally separate.  The backend
      --  can determine a Kitty result only after it has consumed the final
      --  payload bytes; Complete_Graphics_Event or Discard_Graphics_Event owns
      --  removal and deferred-input resumption.
      End_Of_Event := Node.Read_Offset = Node.Payload_Length;
   end Read;
end Terminal.Core.Graphics_Events;

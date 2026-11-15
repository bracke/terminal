with Ada.Unchecked_Deallocation;
package body Terminal.Core.Graphics_Runtime is
   procedure Free_String is new Ada.Unchecked_Deallocation
     (String, String_Access);
   procedure Free_Graphics_Node is new Ada.Unchecked_Deallocation
     (Graphics_Event_Node, Graphics_Event_Node_Access);
   procedure Free_Deferred_Input is new Ada.Unchecked_Deallocation
     (Core_Byte_Array, Core_Byte_Array_Access);

   function Expanded_Capacity
     (Current  : Natural;
      Required : Natural;
      Limit    : Positive) return Natural
   is
      Result : Natural := Natural'Min (4_096, Limit);
   begin
      if Required > Limit then
         return 0;
      end if;
      Result := Natural'Max (Result, Current);
      while Result < Required loop
         Result := (if Result > Limit / 2 then Limit else Result * 2);
      end loop;
      return Result;
   end Expanded_Capacity;

   generic
      type Element is private;
      type Buffer_Array is array (Positive range <>) of Element;
      type Buffer_Access is access all Buffer_Array;
      with procedure Free_Buffer (Buffer : in out Buffer_Access);
   function Append_Bounded_Generic
     (Buffer   : in out Buffer_Access;
      Length   : in out Natural;
      Capacity : in out Natural;
      Data     : Buffer_Array;
      Limit    : Positive) return Boolean;

   function Append_Bounded_Generic
     (Buffer   : in out Buffer_Access;
      Length   : in out Natural;
      Capacity : in out Natural;
      Data     : Buffer_Array;
      Limit    : Positive) return Boolean
   is
      Required : Natural;
      New_Capacity : Natural;
      Replacement : Buffer_Access := null;
   begin
      if Data'Length = 0 then
         return True;
      elsif Data'Length > Limit or else Length > Limit - Data'Length then
         return False;
      end if;
      Required := Length + Data'Length;
      if Required > Capacity then
         New_Capacity := Expanded_Capacity (Capacity, Required, Limit);
         Replacement := new Buffer_Array (1 .. New_Capacity);
         if Length > 0 then
            Replacement (1 .. Length) := Buffer (1 .. Length);
         end if;
         Free_Buffer (Buffer);
         Buffer := Replacement;
         Capacity := New_Capacity;
         Replacement := null;
      end if;
      Buffer (Length + 1 .. Required) := Data;
      Length := Required;
      return True;
   exception
      when Storage_Error =>
         Free_Buffer (Replacement);
         return False;
   end Append_Bounded_Generic;

   function Append_String_Bounded is new Append_Bounded_Generic
     (Element       => Standard.Character,
      Buffer_Array  => String,
      Buffer_Access => String_Access,
      Free_Buffer   => Free_String);
   function Append_Bytes_Bounded is new Append_Bounded_Generic
     (Element       => Common.Bytes.Byte,
      Buffer_Array  => Core_Byte_Array,
      Buffer_Access => Core_Byte_Array_Access,
      Free_Buffer   => Free_Deferred_Input);

   generic
      type Element is private;
      type Buffer_Array is array (Positive range <>) of Element;
      type Buffer_Access is access all Buffer_Array;
      with procedure Free_Buffer (Buffer : in out Buffer_Access);
   procedure Reconcile_Buffer
     (Buffer    : in out Buffer_Access;
      Length    : in out Natural;
      Capacity  : in out Natural;
      Limit     : Positive;
      Discarded : out Boolean);

   procedure Reconcile_Buffer
     (Buffer    : in out Buffer_Access;
      Length    : in out Natural;
      Capacity  : in out Natural;
      Limit     : Positive;
      Discarded : out Boolean)
   is
      Replacement : Buffer_Access := null;
   begin
      Discarded := False;
      if Length > Limit then
         Free_Buffer (Buffer);
         Length := 0;
         Capacity := 0;
         Discarded := True;
      elsif Length = 0 then
         Free_Buffer (Buffer);
         Capacity := 0;
      elsif Capacity > Limit then
         Replacement := new Buffer_Array (1 .. Length);
         Replacement.all := Buffer (1 .. Length);
         Free_Buffer (Buffer);
         Buffer := Replacement;
         Capacity := Length;
         Replacement := null;
      end if;
   exception
      when Storage_Error =>
         Free_Buffer (Replacement);
         Free_Buffer (Buffer);
         Length := 0;
         Capacity := 0;
         Discarded := True;
   end Reconcile_Buffer;

   procedure Reconcile_String is new Reconcile_Buffer
     (Element       => Standard.Character,
      Buffer_Array  => String,
      Buffer_Access => String_Access,
      Free_Buffer   => Free_String);
   procedure Reconcile_Bytes is new Reconcile_Buffer
     (Element       => Common.Bytes.Byte,
      Buffer_Array  => Core_Byte_Array,
      Buffer_Access => Core_Byte_Array_Access,
      Free_Buffer   => Free_Deferred_Input);

   procedure Clear_Deferred_Input (State : in out Graphics_Runtime_State) is
   begin
      Free_Deferred_Input (State.Deferred_Input);
      State.Deferred_Input_Length := 0;
      State.Deferred_Input_Capacity := 0;
   end Clear_Deferred_Input;

   function Append_Deferred_Input
     (State : in out Graphics_Runtime_State;
      Data  : Core_Byte_Array) return Boolean
   is (Append_Bytes_Bounded
         (State.Deferred_Input,
          State.Deferred_Input_Length,
          State.Deferred_Input_Capacity,
          Data,
          State.Limits.Deferred_Input_Bytes));

   procedure Take_Deferred_Input
     (State  : in out Graphics_Runtime_State;
      Data   : out Core_Byte_Array_Access;
      Length : out Natural) is
   begin
      Data := State.Deferred_Input;
      Length := State.Deferred_Input_Length;
      State.Deferred_Input := null;
      State.Deferred_Input_Length := 0;
      State.Deferred_Input_Capacity := 0;
   end Take_Deferred_Input;

   procedure Release_Byte_Array (Data : in out Core_Byte_Array_Access) is
   begin
      Free_Deferred_Input (Data);
   end Release_Byte_Array;

   procedure Clear_Graphics_Transfer (State : in out Graphics_Runtime_State) is
   begin
      Free_String (State.Transfer);
      State.Transfer_Length := 0;
      State.Transfer_Capacity := 0;
   end Clear_Graphics_Transfer;

   function Append_Transfer_Character
     (State : in out Graphics_Runtime_State;
      Ch    : Standard.Character) return Boolean
   is
      Text : constant String := (1 => Ch);
   begin
      return Append_String_Bounded
        (State.Transfer,
         State.Transfer_Length,
         State.Transfer_Capacity,
         Text,
         State.Limits.Transaction_Length);
   end Append_Transfer_Character;

   procedure Clear_Kitty_Chunk (State : in out Graphics_Runtime_State) is
   begin
      Free_String (State.Kitty_Chunk_Data);
      State.Kitty_Chunk_Length := 0;
      State.Kitty_Chunk_Capacity := 0;
      State.Kitty_Chunk_Active := False;
      State.Kitty_Chunk_Blocks_Input := False;
      State.Kitty_Chunk_Action := 't';
   end Clear_Kitty_Chunk;

   function Append_Kitty_Chunk_Data
     (State : in out Graphics_Runtime_State;
      Text  : String) return Boolean
   is (Append_String_Bounded
         (State.Kitty_Chunk_Data,
          State.Kitty_Chunk_Length,
          State.Kitty_Chunk_Capacity,
          Text,
          State.Limits.Transaction_Length));

   function Apply_Kitty_Chunk_Quiet
     (State : in out Graphics_Runtime_State;
      Quiet : Natural) return Boolean
   is
      Header_Last : Natural := 0;
      Field_First : Natural := 0;
      Old_Length  : Natural;
   begin
      if Quiet > 2
        or else State.Kitty_Chunk_Data = null
        or else State.Kitty_Chunk_Length = 0
      then
         return False;
      end if;
      for I in 1 .. State.Kitty_Chunk_Length loop
         if State.Kitty_Chunk_Data (I) = ';' then
            Header_Last := I - 1;
            exit;
         end if;
      end loop;
      if Header_Last = 0 then
         return False;
      end if;
      Field_First := 2;
      for I in 2 .. Header_Last + 1 loop
         if I = Header_Last + 1 or else State.Kitty_Chunk_Data (I) = ',' then
            if I = Field_First + 3
              and then State.Kitty_Chunk_Data
                (Field_First .. Field_First + 1) = "q="
            then
               State.Kitty_Chunk_Data (Field_First + 2) :=
                 Standard.Character'Val
                   (Standard.Character'Pos ('0') + Quiet);
               return True;
            end if;
            Field_First := I + 1;
         end if;
      end loop;
      Old_Length := State.Kitty_Chunk_Length;
      if not Append_Kitty_Chunk_Data (State, "    ") then
         return False;
      end if;
      for I in reverse Header_Last + 1 .. Old_Length loop
         State.Kitty_Chunk_Data (I + 4) := State.Kitty_Chunk_Data (I);
      end loop;
      State.Kitty_Chunk_Data (Header_Last + 1 .. Header_Last + 4) :=
        ",q=" & Standard.Character'Val
          (Standard.Character'Pos ('0') + Quiet);
      return True;
   end Apply_Kitty_Chunk_Quiet;

   procedure Advance_Graphics_Transaction
     (State : in out Graphics_Runtime_State) is
   begin
      State.Transaction := State.Transaction + 1;
      if State.Transaction = 0 then
         State.Transaction := 1;
      end if;
   end Advance_Graphics_Transaction;

   procedure Clear_ITerm2_Multipart (State : in out Graphics_Runtime_State) is
   begin
      Free_String (State.ITerm2_Multipart);
      State.ITerm2_Multipart_Length := 0;
      State.ITerm2_Multipart_Capacity := 0;
      State.ITerm2_Multipart_Active := False;
   end Clear_ITerm2_Multipart;

   function Append_ITerm2_Multipart
     (State : in out Graphics_Runtime_State; Text : String) return Boolean
   is
      Appended : Boolean;
   begin
      Appended := Append_String_Bounded
        (State.ITerm2_Multipart,
         State.ITerm2_Multipart_Length,
         State.ITerm2_Multipart_Capacity,
         Text,
         State.Limits.Transaction_Length);
      if not Appended then
         Clear_ITerm2_Multipart (State);
      end if;
      return Appended;
   end Append_ITerm2_Multipart;

   procedure Refresh_Last_Event (State : in out Graphics_Runtime_State) is
      Node : constant Graphics_Event_Node_Access := State.Tail;
      Preview_Length : Graphics_Preview_Length_Range := 0;
   begin
      if Node = null then
         State.Last_Event := (Stream_ID => State.Stream, others => <>);
         return;
      end if;

      Preview_Length :=
        Graphics_Preview_Length_Range'Min
          (Node.Payload_Length, Max_Graphics_Preview_Length);
      State.Last_Event :=
        (Pending                => True,
         Cancelled              => Node.Cancelled,
         Protocol               => Node.Protocol,
         Stream_ID              => Node.Stream_ID,
         Sequence               => Node.Sequence,
         Transaction_Generation => Node.Transaction_Generation,
         Alternate_Screen       => Node.Alternate_Screen,
         Screen_Generation      => Node.Screen_Generation,
         Scroll_Sequence        => Node.Scroll_Sequence,
         Sixel_Private_Colors   => Node.Sixel_Private_Colors,
         Row                    => Node.Row,
         Col                    => Node.Col,
         Payload_Length         => Node.Payload_Length,
         Preview_Length         => Preview_Length,
         Preview                => (others => ASCII.NUL));
      if Preview_Length > 0 then
         State.Last_Event.Preview (1 .. Preview_Length) :=
           Node.Payload (1 .. Preview_Length);
      end if;
   end Refresh_Last_Event;

   procedure Enqueue_Event
     (State     : in out Graphics_Runtime_State;
      Protocol  : Graphics_Protocol_Kind;
      Context   : Event_Context;
      Payload   : String;
      Cancelled : Boolean;
      Result    : out Enqueue_Result)
   is
      Stored : String_Access := null;
      Node   : Graphics_Event_Node_Access := null;
      Blocks_Input : Boolean := False;

      procedure Release_Unlinked_Node is
      begin
         if Node /= null then
            Free_String (Node.Payload);
            Free_Graphics_Node (Node);
         end if;
         Free_String (Stored);
      end Release_Unlinked_Node;
   begin
      Result := Event_Queue_Limit;
      if State.Event_Count >= State.Limits.Pending_Events
        or else Payload'Length > State.Limits.Pending_Bytes
        or else State.Byte_Count >
          State.Limits.Pending_Bytes - Payload'Length
      then
         State.Queue_Overflowed := True;
         return;
      end if;

      Blocks_Input :=
        not Cancelled
        and then
          (case Protocol is
              when Kitty_Graphics =>
                Kitty_Command_Blocks_Input (State, Payload),
              when ITerm2_Graphics =>
                ITerm2_Command_Blocks_Input (Payload),
              when Sixel_Graphics | No_Graphics => False);
      Stored := new String (1 .. Payload'Length);
      Stored.all := Payload;
      Node := new Graphics_Event_Node'
        (Protocol       => Protocol,
         Cancelled      => Cancelled,
         Stream_ID      => Context.Stream_ID,
         Sequence       => State.Next_Sequence,
         Transaction_Generation => Context.Transaction,
         Blocks_Input   => Blocks_Input,
         Alternate_Screen => Context.Alternate_Screen,
         Screen_Generation => Context.Screen_Generation,
         Scroll_Sequence => Context.Scroll_Sequence,
         Sixel_Private_Colors => Context.Sixel_Private_Colors,
         Row            => Context.Row,
         Col            => Context.Col,
         Payload_Length => Payload'Length,
         Payload        => Stored,
         Read_Offset    => 0,
         Next           => null);
      Stored := null;

      if State.Tail = null then
         State.Head := Node;
      else
         State.Tail.Next := Node;
      end if;
      State.Tail := Node;
      State.Event_Count := State.Event_Count + 1;
      if Blocks_Input then
         State.Blocking_Event_Count := State.Blocking_Event_Count + 1;
      end if;
      State.Byte_Count := State.Byte_Count + Payload'Length;
      State.Queue_Backpressure :=
        State.Event_Count >= State.Limits.Pending_Events
        or else
          (State.Event_Count > 0
           and then
             State.Limits.Pending_Bytes - State.Byte_Count <
               Natural'Min
                 (State.Limits.Transaction_Length,
                  State.Limits.Pending_Bytes));
      State.Input_Blocked :=
        State.Input_Blocked
        or else Blocks_Input
        or else State.Queue_Backpressure;
      Refresh_Last_Event (State);
      State.Next_Sequence := State.Next_Sequence + 1;
      if State.Next_Sequence = 0 then
         State.Next_Sequence := 1;
      end if;
      Node := null;
      Result := Event_Enqueued;
   exception
      when Storage_Error =>
         Release_Unlinked_Node;
         State.Queue_Overflowed := True;
         Result := Event_Allocation_Failure;
   end Enqueue_Event;

   procedure Apply_Limits
     (State  : in out Graphics_Runtime_State;
      Limits : Graphics_Resource_Limits;
      Result : out Limit_Reconcile_Result)
   is
      Keep_Tail : Graphics_Event_Node_Access := null;
      Current   : Graphics_Event_Node_Access := State.Head;
      Kept_Events : Natural := 0;
      Kept_Blocking_Events : Natural := 0;
      Kept_Bytes  : Natural := 0;
      Discarded : Boolean;
   begin
      Result := (others => <>);
      Reconcile_String
        (State.Transfer, State.Transfer_Length, State.Transfer_Capacity,
         Limits.Transaction_Length, Result.Transfer_Discarded);
      Reconcile_Bytes
        (State.Deferred_Input, State.Deferred_Input_Length,
         State.Deferred_Input_Capacity, Limits.Deferred_Input_Bytes,
         Result.Deferred_Discarded);
      Reconcile_String
        (State.Kitty_Chunk_Data, State.Kitty_Chunk_Length,
         State.Kitty_Chunk_Capacity, Limits.Transaction_Length, Discarded);
      if Discarded then
         Result.Kitty_Discarded := True;
         State.Kitty_Chunk_Active := False;
         State.Kitty_Chunk_Blocks_Input := False;
         State.Kitty_Chunk_Action := 't';
      end if;
      Reconcile_String
        (State.ITerm2_Multipart, State.ITerm2_Multipart_Length,
         State.ITerm2_Multipart_Capacity, Limits.Transaction_Length,
         Discarded);
      if Discarded then
         Result.Multipart_Discarded := True;
         State.ITerm2_Multipart_Active := False;
      end if;

      while Current /= null
        and then Kept_Events < Limits.Pending_Events
        and then Current.Payload_Length <= Limits.Pending_Bytes - Kept_Bytes
      loop
         Kept_Events := Kept_Events + 1;
         if Current.Blocks_Input then
            Kept_Blocking_Events := Kept_Blocking_Events + 1;
         end if;
         Kept_Bytes := Kept_Bytes + Current.Payload_Length;
         Keep_Tail := Current;
         Current := Current.Next;
      end loop;
      if Keep_Tail = null then
         State.Head := null;
      else
         Keep_Tail.Next := null;
      end if;
      State.Tail := Keep_Tail;
      while Current /= null loop
         declare
            Next : constant Graphics_Event_Node_Access := Current.Next;
         begin
            Free_String (Current.Payload);
            Free_Graphics_Node (Current);
            Result.Dropped_Events := Result.Dropped_Events + 1;
            Current := Next;
         end;
      end loop;
      State.Event_Count := Kept_Events;
      State.Blocking_Event_Count := Kept_Blocking_Events;
      State.Byte_Count := Kept_Bytes;
      State.Limits := Limits;
      if Result.Dropped_Events > 0 then
         State.Queue_Overflowed := True;
      end if;
      Refresh_Last_Event (State);
      Refresh_Graphics_Input_Block (State);
   end Apply_Limits;

   procedure Clear_Graphics_Events (State : in out Graphics_Runtime_State) is
      Current : Graphics_Event_Node_Access := State.Head;
      Next    : Graphics_Event_Node_Access;
   begin
      while Current /= null loop
         Next := Current.Next;
         Free_String (Current.Payload);
         Free_Graphics_Node (Current);
         Current := Next;
      end loop;
      State.Head := null;
      State.Tail := null;
      State.Event_Count := 0;
      State.Blocking_Event_Count := 0;
      State.Byte_Count := 0;
      State.Input_Blocked := False;
      State.Queue_Backpressure := False;
      State.Queue_Overflowed := False;
      Refresh_Last_Event (State);
      Clear_Kitty_Chunk (State);
   end Clear_Graphics_Events;

   function Kitty_Field_Value
     (Payload : String; Key : Standard.Character) return String
   is
      Header_Last : Natural := Payload'Last;
      Field_First : Natural := Payload'First;
      I : Natural;
   begin
      for Pos in Payload'Range loop
         if Payload (Pos) = ';' then
            Header_Last := Pos - 1;
            exit;
         end if;
      end loop;
      if Header_Last < Payload'First then
         return "";
      end if;
      I := Payload'First;
      if Payload (I) = 'G' then
         I := I + 1;
      end if;
      Field_First := I;
      while I <= Header_Last + 1 loop
         if I = Header_Last + 1 or else Payload (I) = ',' then
            if I >= Field_First + 2
              and then Payload (Field_First) = Key
              and then Payload (Field_First + 1) = '='
            then
               return Payload (Field_First + 2 .. I - 1);
            end if;
            Field_First := I + 1;
         end if;
         I := I + 1;
      end loop;
      return "";
   end Kitty_Field_Value;

   function Kitty_Command_Blocks_Input
     (State : Graphics_Runtime_State; Payload : String) return Boolean
   is
      Action_Text : constant String := Kitty_Field_Value (Payload, 'a');
      More_Text   : constant String := Kitty_Field_Value (Payload, 'm');
      Quiet_Text  : constant String := Kitty_Field_Value (Payload, 'q');
      Cursor_Text : constant String := Kitty_Field_Value (Payload, 'C');
      Virtual_Text : constant String := Kitty_Field_Value (Payload, 'U');
      Parent_Text : constant String := Kitty_Field_Value (Payload, 'P');
      Action : constant Standard.Character :=
        (if Action_Text'Length = 0 then 't' else Action_Text (Action_Text'First));
      Placement_Would_Move : constant Boolean :=
        Action in 'T' | 'p'
        and then Cursor_Text /= "1"
        and then Virtual_Text /= "1"
        and then (Parent_Text'Length = 0 or else Parent_Text = "0");
      Could_Respond : constant Boolean := Quiet_Text /= "2";
   begin
      if More_Text = "1" then
         return False;
      elsif More_Text = "0" then
         return
           (if State.Kitty_Chunk_Active
            then State.Kitty_Chunk_Blocks_Input
            else Could_Respond or else Placement_Would_Move);
      end if;
      return Could_Respond or else Placement_Would_Move;
   end Kitty_Command_Blocks_Input;

   function ITerm2_Command_Blocks_Input (Payload : String) return Boolean is
      function Has_Field (Field : String) return Boolean is
         First : Natural := Payload'First + 5;
         Last  : Natural;
      begin
         if Payload'Length < 5
           or else Payload (Payload'First .. Payload'First + 4) /= "File="
         then
            return False;
         end if;
         while First <= Payload'Last loop
            Last := First;
            while Last <= Payload'Last
              and then Payload (Last) not in ';' | ':'
            loop
               Last := Last + 1;
            end loop;
            if Last - First = Field'Length
              and then Payload (First .. Last - 1) = Field
            then
               return True;
            end if;
            exit when Last > Payload'Last or else Payload (Last) = ':';
            First := Last + 1;
         end loop;
         return False;
      end Has_Field;
   begin
      return Has_Field ("inline=1")
        and then not Has_Field ("doNotMoveCursor=1");
   end ITerm2_Command_Blocks_Input;

   procedure Drop_Graphics_Head (State : in out Graphics_Runtime_State) is
      Node : Graphics_Event_Node_Access := State.Head;
   begin
      if Node = null then
         return;
      end if;
      State.Head := Node.Next;
      if State.Head = null then
         State.Tail := null;
      end if;
      State.Event_Count := State.Event_Count - 1;
      if Node.Blocks_Input then
         State.Blocking_Event_Count := State.Blocking_Event_Count - 1;
      end if;
      State.Byte_Count := State.Byte_Count - Node.Payload_Length;
      Free_String (Node.Payload);
      Free_Graphics_Node (Node);
      if State.Head = null then
         Refresh_Last_Event (State);
      end if;
      Refresh_Graphics_Input_Block (State);
   end Drop_Graphics_Head;

   procedure Refresh_Graphics_Input_Block
     (State : in out Graphics_Runtime_State) is
   begin
      State.Queue_Backpressure :=
        State.Event_Count >= State.Limits.Pending_Events
        or else
          (State.Event_Count > 0
           and then
             (State.Byte_Count >= State.Limits.Pending_Bytes
              or else State.Limits.Pending_Bytes - State.Byte_Count <
                Natural'Min
                  (State.Limits.Transaction_Length,
                   State.Limits.Pending_Bytes)));
      State.Input_Blocked :=
        State.Queue_Backpressure or else State.Blocking_Event_Count > 0;
   end Refresh_Graphics_Input_Block;
end Terminal.Core.Graphics_Runtime;

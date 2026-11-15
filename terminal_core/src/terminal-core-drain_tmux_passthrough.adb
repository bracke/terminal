separate (Terminal.Core)
procedure Drain_Tmux_Passthrough
  (T                  : in out Terminal;
   Passthrough        : in out Core_Byte_Array_Access;
   Passthrough_Length : in out Natural;
   Passthrough_Budget : in out Natural;
   Overflowed         : in out Boolean;
   Recovered          : in out Boolean)
is
   type Work_Item is record
      Buffer : Core_Byte_Array_Access := null;
      Next   : Natural := 1;
      Last   : Natural := 0;
   end record;
   type Work_Stack is
     array (Positive range 1 .. Max_Tmux_Passthrough_Depth) of Work_Item;
   Stack      : Work_Stack;
   Stack_Last : Natural := 0;

   procedure Release_Decoded (Buffer : in out Core_Byte_Array_Access) is
      Length : constant Natural :=
        (if Buffer = null then 0 else Buffer'Length);
   begin
      --  Decoded buffers are charged before allocation.  Refund their
      --  exact size only when ownership is released; suspended outer
      --  buffers therefore continue to count while an inner wrapper runs.
      Passthrough_Budget := Passthrough_Budget + Length;
      Storage.Release (Buffer);
   end Release_Decoded;

   procedure Defer
     (Buffer : Core_Byte_Array_Access;
      First  : Natural;
      Last   : Natural) is
   begin
      if Buffer /= null
        and then First <= Last
        and then not Append_Deferred_Input
          (T, Buffer.all (First .. Last))
      then
         Overflowed := True;
      end if;
   end Defer;

   procedure Release_Stack is
   begin
      while Stack_Last > 0 loop
         Release_Decoded (Stack (Stack_Last).Buffer);
         Stack_Last := Stack_Last - 1;
      end loop;
   end Release_Stack;

   Current       : Core_Byte_Array_Access := Passthrough;
   Current_Index : Natural := 1;
   Current_Last  : Natural := Passthrough_Length;
   Initial_Depth : constant Natural :=
     T.Parser.Tmux_Passthrough_Depth;
begin
   Passthrough := null;
   Passthrough_Length := 0;
   if Current = null then
      return;
   end if;

   T.Parser.Tmux_Passthrough_Depth := Initial_Depth + 1;
   loop
      while Current_Index <= Current_Last loop
         Process_Feed_Byte
           (T, Current (Current_Index), Overflowed, Recovered,
            Passthrough, Passthrough_Length, Passthrough_Budget);
         Current_Index := Current_Index + 1;

         if T.Graphics.Input_Blocked then
            Defer (Current, Current_Index, Current_Last);
            Release_Decoded (Current);
            while Stack_Last > 0 loop
               Defer
                 (Stack (Stack_Last).Buffer,
                  Stack (Stack_Last).Next,
                  Stack (Stack_Last).Last);
               Release_Decoded (Stack (Stack_Last).Buffer);
               Stack_Last := Stack_Last - 1;
            end loop;
            T.Parser.Tmux_Passthrough_Depth := Initial_Depth;
            return;
         elsif Passthrough /= null then
            if Current_Index <= Current_Last then
               Stack_Last := Stack_Last + 1;
               Stack (Stack_Last) :=
                 (Buffer => Current,
                  Next   => Current_Index,
                  Last   => Current_Last);
            else
               Release_Decoded (Current);
            end if;
            Current := Passthrough;
            Current_Index := 1;
            Current_Last := Passthrough_Length;
            Passthrough := null;
            Passthrough_Length := 0;
            T.Parser.Tmux_Passthrough_Depth :=
              T.Parser.Tmux_Passthrough_Depth + 1;
         end if;
      end loop;

      Release_Decoded (Current);
      exit when Stack_Last = 0;
      Current := Stack (Stack_Last).Buffer;
      Current_Index := Stack (Stack_Last).Next;
      Current_Last := Stack (Stack_Last).Last;
      Stack (Stack_Last) := (others => <>);
      Stack_Last := Stack_Last - 1;
      T.Parser.Tmux_Passthrough_Depth :=
        T.Parser.Tmux_Passthrough_Depth - 1;
   end loop;
   T.Parser.Tmux_Passthrough_Depth := Initial_Depth;
exception
   when others =>
      Release_Decoded (Current);
      Release_Decoded (Passthrough);
      Passthrough_Length := 0;
      Release_Stack;
      T.Parser.Tmux_Passthrough_Depth := Initial_Depth;
      raise;

end Drain_Tmux_Passthrough;

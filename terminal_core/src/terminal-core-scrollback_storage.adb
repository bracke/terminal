with Ada.Unchecked_Deallocation;
with Terminal.Common.Counters;

package body Terminal.Core.Scrollback_Storage is
   procedure Free is new Ada.Unchecked_Deallocation
     (Stored_Cell_Array, Stored_Cell_Array_Access);

   procedure Clear
     (State         : in out Scrollback_Runtime_State;
      Current_Style : Style)
   is
      Blank : constant Stored_Cell :=
        (Kind  => Empty,
         Text  => (Code_Point => 0, Width => Width_One, others => <>),
         Style => Current_Style,
         Link  => null,
         Image => <>,
         Clipped_Wide => False,
         Wraps_To_Next => False);
   begin
      --  Capacity is deliberately retained.  Clear the entire allocation,
      --  rather than only the logical rows, so erased hyperlink references
      --  cannot survive in ring-buffer slots and dangle after pool sweeping.
      if State.Cells /= null then
         State.Cells.all := (others => Blank);
      end if;
      State.Rows := 0;
      State.Head := 0;
   end Clear;

   function Index
     (State : Scrollback_Runtime_State;
      Cols  : Positive;
      Row   : Positive;
      Col   : Positive) return Positive
   is
      Offset : Natural;
      Slot   : Natural;
   begin
      if State.Capacity_Rows = 0
        or else Row > State.Capacity_Rows
        or else Col > Cols
        or else State.Capacity_Rows > Natural'Last / Cols
      then
         raise Constraint_Error with "invalid scrollback coordinates";
      end if;
      Offset := (Row - 1) mod State.Capacity_Rows;
      Slot :=
        (if Offset = 0 then State.Head
         elsif State.Head >= State.Capacity_Rows - Offset
         then State.Head - (State.Capacity_Rows - Offset)
         else State.Head + Offset);
      return Slot * Cols + Col;
   end Index;

   procedure Ensure_Capacity
     (State         : in out Scrollback_Runtime_State;
      Cols          : Positive;
      Current_Style : Style;
      Required      : Positive;
      Success       : out Boolean)
   is
      Initial_Rows : constant Positive := 64;
      New_Capacity : Natural := State.Capacity_Rows;
      Replacement  : Stored_Cell_Array_Access := null;
      Blank : constant Stored_Cell :=
        (Kind  => Empty,
         Text  => (Code_Point => 0, Width => Width_One, others => <>),
         Style => Current_Style,
         Link  => null,
         Image => <>,
         Clipped_Wide => False,
         Wraps_To_Next => False);
   begin
      Success := True;
      if Required > State.Limit then
         Success := False;
         return;
      elsif Required <= State.Capacity_Rows then
         return;
      end if;
      if New_Capacity = 0 then
         New_Capacity := Natural'Min (State.Limit, Initial_Rows);
      end if;
      while New_Capacity < Required loop
         New_Capacity :=
           Natural'Min
             (State.Limit,
              (if New_Capacity > Natural'Last / 2
               then State.Limit
               else New_Capacity * 2));
      end loop;
      if New_Capacity = 0 or else New_Capacity > Natural'Last / Cols then
         Success := False;
         return;
      end if;
      Replacement := new Stored_Cell_Array (1 .. New_Capacity * Cols);
      Replacement.all := (others => Blank);
      if State.Cells /= null then
         for R in 1 .. State.Rows loop
            for C in 1 .. Cols loop
               Replacement ((R - 1) * Cols + C) :=
                 State.Cells (Index (State, Cols, R, C));
            end loop;
         end loop;
         Free (State.Cells);
      end if;
      State.Cells := Replacement;
      State.Capacity_Rows := New_Capacity;
      State.Head := 0;
   exception
      when Storage_Error =>
         if Replacement /= null then
            Free (Replacement);
         end if;
         Success := False;
   end Ensure_Capacity;

   procedure Append_Row
     (State          : in out Scrollback_Runtime_State;
      Cols           : Positive;
      Current_Style  : Style;
      Queue_Overflow : in out Natural;
      Cells          : Stored_Cell_Array_Access;
      Source         : Positive)
   is
      Capacity_Available : Boolean;
      Source_First : Natural;
   begin
      if State.Limit = 0 or else Cells = null then
         return;
      end if;
      if Source - 1 > Natural'Last / Cols then
         Common.Counters.Increment_Saturating (Queue_Overflow);
         return;
      end if;
      Source_First := (Source - 1) * Cols + 1;
      if Source_First not in Cells'Range
        or else Cols - 1 > Cells'Last - Source_First
      then
         Common.Counters.Increment_Saturating (Queue_Overflow);
         return;
      end if;
      if State.Rows < State.Limit then
         Ensure_Capacity
           (State, Cols, Current_Style, State.Rows + 1, Capacity_Available);
         if not Capacity_Available then
            Common.Counters.Increment_Saturating (Queue_Overflow);
            return;
         end if;
      end if;
      if State.Rows = State.Limit then
         State.Head := (State.Head + 1) mod State.Capacity_Rows;
      else
         State.Rows := State.Rows + 1;
      end if;
      for C in 1 .. Cols loop
         State.Cells (Index (State, Cols, State.Rows, C)) :=
           Cells (Source_First + C - 1);
      end loop;
   end Append_Row;
end Terminal.Core.Scrollback_Storage;

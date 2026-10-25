separate (Terminal.Core)
procedure Resize
  (T      : in out Terminal;
   Rows   : Positive;
   Cols   : Positive;
   Status : out Resize_Status)
is
   Old_Primary  : Cell_Array_Access := T.Primary_Cells;
   Old_Alt      : Cell_Array_Access := T.Alt_Cells;
   Old_Scrollback : Cell_Array_Access := T.Scrollback;
   Old_Dirty    : Dirty_Row_Array_Access := T.Dirty;
   Old_Tabs     : Tab_Stop_Array_Access := T.Tab_Stops;
   New_Primary  : Cell_Array_Access := null;
   New_Alt      : Cell_Array_Access := null;
   New_Scrollback : Cell_Array_Access := null;
   New_Dirty    : Dirty_Row_Array_Access := null;
   New_Tabs     : Tab_Stop_Array_Access := null;
   Old_Rows    : constant Positive := T.Rows;
   Old_Cols    : constant Positive := T.Cols;
   Old_Scrollback_Rows : constant Natural := T.Scrollback_Rows;
   Old_Scrollback_Head : constant Natural := T.Scrollback_Head;
   New_Count   : Positive;
begin
   if not T.Initialized then
      Status := Allocation_Failed;
      return;
   end if;

   --  A resize request is also issued to synchronize the PTY and terminal
   --  grid.  Treat an unchanged grid as a true no-op: rebuilding the cell
   --  and scrollback storage here is both expensive and destructive.
   if Rows = T.Rows and then Cols = T.Cols then
      Status := Ok;
      return;
   end if;

   if Rows > Positive'Last / Cols
     or else
       (T.Scrollback_Limit > 0
        and then T.Scrollback_Limit > Natural'Last / Cols)
   then
      Status := Allocation_Failed;
      return;
   end if;
   New_Count := Rows * Cols;

   --  Allocate the complete replacement before changing terminal state.
   --  A failed resize must leave every old buffer and all history usable.
   New_Primary := new Cell_Array (1 .. New_Count);
   New_Alt := new Cell_Array (1 .. New_Count);
   if T.Scrollback_Limit > 0 then
      New_Scrollback := new Cell_Array (1 .. T.Scrollback_Limit * Cols);
      for I in New_Scrollback'Range loop
         New_Scrollback (I) := Blank_Cell (T.Current_Style);
      end loop;
   end if;
   New_Dirty := new Dirty_Row_Array (1 .. Rows);
   New_Tabs := new Tab_Stop_Array (1 .. Cols);

   --  Populate the replacement while it is still detached from T.  This
   --  keeps even a bounds or assignment failure transactional, rather than
   --  exposing a partially initialized live screen.
   for I in New_Primary'Range loop
      New_Primary (I) := Blank_Cell (T.Current_Style);
      New_Alt (I) := Blank_Cell (T.Current_Style);
   end loop;
   New_Dirty.all := (others => True);
   for C in New_Tabs'Range loop
      New_Tabs (C) := C > 1 and then (C - 1) mod 8 = 0;
   end loop;
   for R in 1 .. Positive'Min (Old_Rows, Rows) loop
      for C in 1 .. Positive'Min (Old_Cols, Cols) loop
         New_Primary ((R - 1) * Cols + C) :=
           Old_Primary ((R - 1) * Old_Cols + C);
         New_Alt ((R - 1) * Cols + C) :=
           Old_Alt ((R - 1) * Old_Cols + C);
      end loop;
   end loop;
   if Old_Tabs /= null then
      for C in 1 .. Positive'Min (Old_Cols, Cols) loop
         New_Tabs (C) := Old_Tabs (C);
      end loop;
   end if;
   if Old_Scrollback /= null and then New_Scrollback /= null then
      for R in 1 .. Old_Scrollback_Rows loop
         declare
            Old_Physical_Row : constant Natural :=
              (Old_Scrollback_Head + R - 1) mod T.Scrollback_Limit;
         begin
            for C in 1 .. Positive'Min (Old_Cols, Cols) loop
               New_Scrollback ((R - 1) * Cols + C) :=
                 Old_Scrollback (Old_Physical_Row * Old_Cols + C);
            end loop;
         end;
      end loop;
   end if;

   T.Primary_Cells := New_Primary;
   T.Alt_Cells := New_Alt;
   T.Scrollback := New_Scrollback;
   T.Dirty := New_Dirty;
   T.Tab_Stops := New_Tabs;
   New_Primary := null;
   New_Alt := null;
   New_Scrollback := null;
   New_Dirty := null;
   New_Tabs := null;

   T.Rows := Rows;
   T.Cols := Cols;
   T.Scrollback_Rows := Old_Scrollback_Rows;
   T.Scrollback_Head := 0;

   if Old_Primary /= null then
      Free_Cells (Old_Primary);
   end if;
   if Old_Alt /= null then
      Free_Cells (Old_Alt);
   end if;
   if Old_Scrollback /= null then
      Free_Cells (Old_Scrollback);
   end if;
   if Old_Dirty /= null then
      Free_Dirty (Old_Dirty);
   end if;
   if Old_Tabs /= null then
      Free_Tab_Stops (Old_Tabs);
   end if;

   T.Cursor_Row := Positive'Min (Rows, T.Cursor_Row);
   T.Cursor_Col := Positive'Min (Cols, T.Cursor_Col);
   T.Top_Margin := 1;
   T.Bottom_Margin := Rows;
   Mark_All_Dirty (T);
   Status := Ok;

   if T.Current_Modes.In_Band_Resize then
      Queue_Resize_Report (T);
   end if;
exception
   when Storage_Error | Constraint_Error =>
      if New_Primary /= null then
         Free_Cells (New_Primary);
      end if;
      if New_Alt /= null then
         Free_Cells (New_Alt);
      end if;
      if New_Scrollback /= null then
         Free_Cells (New_Scrollback);
      end if;
      if New_Dirty /= null then
         Free_Dirty (New_Dirty);
      end if;
      if New_Tabs /= null then
         Free_Tab_Stops (New_Tabs);
      end if;
      Status := Allocation_Failed;
end Resize;

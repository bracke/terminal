separate (Terminal.Core)
procedure Snapshot
  (T : Terminal;
   S : in out Render_Snapshot)
is
   Count : constant Natural := T.Rows * T.Cols;
   Src   : constant Cell_Array_Access := Active_Cells (T);
   Scroll_Head : constant Natural :=
     (if T.Active = Alternate
      then T.Alternate_Graphics_Scroll_Head
      else T.Primary_Graphics_Scroll_Head);
   Scroll_Count : constant Natural :=
     (if T.Active = Alternate
      then T.Alternate_Graphics_Scroll_Count
      else T.Primary_Graphics_Scroll_Count);
   New_Cells : Cell_Array_Access := null;
   New_Dirty : Dirty_Row_Array_Access := null;
   New_Scroll_Events : Graphics_Scroll_Event_Array_Access := null;
   Cells_Target : Cell_Array_Access := S.Cells;
   Dirty_Target : Dirty_Row_Array_Access := S.Dirty;
   Scroll_Target : Graphics_Scroll_Event_Array_Access :=
     S.Graphics_Scroll_Events;
   Image_Cell_Count : Natural := 0;
   Scroll_Oldest : Graphics_Scroll_Sequence := 0;

   procedure Release_Replacements is
   begin
      if New_Cells /= null then
         Free_Cells (New_Cells);
      end if;
      if New_Dirty /= null then
         Free_Dirty (New_Dirty);
      end if;
      if New_Scroll_Events /= null then
         Free_Graphics_Scroll_Events (New_Scroll_Events);
      end if;
   end Release_Replacements;
begin
   --  Allocate every required replacement before changing the reusable
   --  snapshot.  A failed allocation therefore leaves the caller's previous
   --  snapshot valid and internally consistent.
   begin
      if S.Graphics_Scroll_Events = null
        or else S.Graphics_Scroll_Events'Length < Scroll_Count
      then
         if Scroll_Count > 0 then
            New_Scroll_Events :=
              new Graphics_Scroll_Event_Array (1 .. Scroll_Count);
            Scroll_Target := New_Scroll_Events;
         end if;
      end if;
      if S.Cells = null or else S.Cells'Length /= Count then
         New_Cells := new Cell_Array (1 .. Count);
         Cells_Target := New_Cells;
      end if;
      if S.Dirty = null or else S.Dirty'Length /= T.Rows then
         New_Dirty := new Dirty_Row_Array (1 .. T.Rows);
         Dirty_Target := New_Dirty;
      end if;
   exception
      when others =>
         Release_Replacements;
         raise;
   end;

   if Scroll_Count > 0 then
      for I in 1 .. Scroll_Count loop
         declare
            Slot : constant Positive :=
              ((Scroll_Head + I - 1) mod Max_Graphics_Scroll_Events) + 1;
         begin
            Scroll_Target (I) :=
              (if T.Active = Alternate
               then T.Alternate_Graphics_Scroll_Events (Slot)
               else T.Primary_Graphics_Scroll_Events (Slot));
         end;
      end loop;
      Scroll_Oldest := Scroll_Target (1).Sequence;
   end if;
   for I in 1 .. Count loop
      Cells_Target (I) := Src (I);
      if Src (I).Image.Is_Placeholder then
         Image_Cell_Count := Image_Cell_Count + 1;
      end if;
   end loop;
   for R in 1 .. T.Rows loop
      Dirty_Target (R) := T.Dirty (R);
   end loop;

   if New_Scroll_Events /= null then
      if S.Graphics_Scroll_Events /= null then
         Free_Graphics_Scroll_Events (S.Graphics_Scroll_Events);
      end if;
      S.Graphics_Scroll_Events := New_Scroll_Events;
      New_Scroll_Events := null;
   end if;
   if New_Cells /= null then
      if S.Cells /= null then
         Free_Cells (S.Cells);
      end if;
      S.Cells := New_Cells;
      New_Cells := null;
   end if;
   if New_Dirty /= null then
      if S.Dirty /= null then
         Free_Dirty (S.Dirty);
      end if;
      S.Dirty := New_Dirty;
      New_Dirty := null;
   end if;

   S.Rows := T.Rows;
   S.Cols := T.Cols;
   S.Graphics_Stream := T.Graphics_Stream;
   S.Graphics_Transaction := T.Graphics_Transaction;
   S.Alternate_Screen := T.Active = Alternate;
   S.Screen_Generation :=
     (if T.Active = Alternate
      then T.Alternate_Graphics_Generation
      else T.Primary_Graphics_Generation);
   S.Scrollback_Offset := 0;
   S.Scrollback_Rows :=
     (if T.Active = Primary then T.Scrollback_Rows else 0);
   S.Graphics_Scroll_Current :=
     (if T.Active = Alternate
      then T.Alternate_Graphics_Scroll_Sequence
      else T.Primary_Graphics_Scroll_Sequence);
   S.Graphics_Scroll_Count := Scroll_Count;
   S.Graphics_Scroll_Oldest := Scroll_Oldest;
   S.Image_Cell_Count := Image_Cell_Count;
   S.Cursor :=
     (Row     => T.Cursor_Row,
      Col     => T.Cursor_Col,
      Visible => T.Current_Modes.Cursor_Visible,
      Shape   => T.Current_Cursor_Shape,
      Blinking => T.Current_Cursor_Blinking);
   S.Graphics := T.Last_Graphics;
exception
   when others =>
      Release_Replacements;
      raise;
end Snapshot;

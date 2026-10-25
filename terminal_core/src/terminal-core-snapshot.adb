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
begin
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
   S.Graphics_Scroll_Oldest := 0;
   if Scroll_Count > 0 then
      if S.Graphics_Scroll_Events = null
        or else S.Graphics_Scroll_Events'Length < Scroll_Count
      then
         declare
            Replacement : constant Graphics_Scroll_Event_Array_Access :=
              new Graphics_Scroll_Event_Array (1 .. Scroll_Count);
         begin
            if S.Graphics_Scroll_Events /= null then
               Free_Graphics_Scroll_Events (S.Graphics_Scroll_Events);
            end if;
            S.Graphics_Scroll_Events := Replacement;
         end;
      end if;
      for I in 1 .. Scroll_Count loop
         declare
            Slot : constant Positive :=
              ((Scroll_Head + I - 1) mod Max_Graphics_Scroll_Events) + 1;
         begin
            S.Graphics_Scroll_Events (I) :=
              (if T.Active = Alternate
               then T.Alternate_Graphics_Scroll_Events (Slot)
               else T.Primary_Graphics_Scroll_Events (Slot));
         end;
      end loop;
      S.Graphics_Scroll_Oldest := S.Graphics_Scroll_Events (1).Sequence;
   end if;
   if S.Cells = null or else S.Cells'Length /= Count then
      declare
         Replacement : constant Cell_Array_Access :=
           new Cell_Array (1 .. Count);
      begin
         if S.Cells /= null then
            Free_Cells (S.Cells);
         end if;
         S.Cells := Replacement;
      end;
   end if;
   if S.Dirty = null or else S.Dirty'Length /= T.Rows then
      declare
         Replacement : constant Dirty_Row_Array_Access :=
           new Dirty_Row_Array (1 .. T.Rows);
      begin
         if S.Dirty /= null then
            Free_Dirty (S.Dirty);
         end if;
         S.Dirty := Replacement;
      end;
   end if;
   S.Image_Cell_Count := 0;
   for I in 1 .. Count loop
      S.Cells (I) := Src (I);
      if Src (I).Image.Is_Placeholder then
         S.Image_Cell_Count := S.Image_Cell_Count + 1;
      end if;
   end loop;
   for R in 1 .. T.Rows loop
      S.Dirty (R) := T.Dirty (R);
   end loop;
   S.Cursor :=
     (Row     => T.Cursor_Row,
      Col     => T.Cursor_Col,
      Visible => T.Current_Modes.Cursor_Visible,
      Shape   => T.Current_Cursor_Shape,
      Blinking => T.Current_Cursor_Blinking);
   S.Graphics := T.Last_Graphics;
end Snapshot;

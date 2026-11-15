separate (Terminal.Core)
procedure Build_Snapshot
  (T : Terminal'Class;
   S : in out Render_Snapshot;
   Intern : not null access function
     (State : in out Hyperlink_Runtime_State;
      Value : Hyperlink) return Stored_Hyperlink_Access)
is
   Count : constant Natural := T.Rows * T.Cols;
   Src   : constant Stored_Cell_Array_Access := Active_Cells (T);
   Scroll_Head : constant Natural :=
     (if T.Active = Alternate
      then T.Graphics.Alternate_Scroll_Head
      else T.Graphics.Primary_Scroll_Head);
   Scroll_Count : constant Natural :=
     (if T.Active = Alternate
      then T.Graphics.Alternate_Scroll_Count
      else T.Graphics.Primary_Scroll_Count);
   New_Cells : Snapshot_Cell_Array_Access := null;
   New_Dirty : Dirty_Row_Array_Access := null;
   New_Scroll_Events : Graphics_Scroll_Event_Array_Access := null;
   Cells_Target : Snapshot_Cell_Array_Access := S.Storage.Cells_Data;
   Dirty_Target : Dirty_Row_Array_Access := S.Storage.Dirty_Data;
   Scroll_Target : Graphics_Scroll_Event_Array_Access :=
     S.Storage.Scroll_Events;
   Image_Cell_Count : Natural := 0;
   Blinking_Cell_Count : Natural := 0;
   Dirty_Row_Count : Natural := 0;
   Wide_Violation_Count : Natural := 0;
   Scroll_Oldest : Graphics_Scroll_Sequence := 0;
   Copy_All : Boolean := False;
   New_Prepared_Links : Snapshot_Link_Array_Access := null;
   Prepared_Links : Snapshot_Link_Array_Access := S.Storage.Prepared_Links;
   Prepared_Link_Count : Natural := 0;
   Prepared_Link_Limit : Natural := 0;

   function Compact_Cell
     (Value         : Stored_Cell;
      Prepared_Link : Stored_Hyperlink_Access := null;
      Link_Prepared : Boolean := False) return Snapshot_Cell
   is
      Link : Stored_Hyperlink_Access := null;
   begin
      if Value.Link /= null then
         Link :=
           (if Link_Prepared
            then Prepared_Link
            else Intern.all (S.Storage.Hyperlinks, Value.Link.Value));
      end if;
      return
        (Kind  => Value.Kind,
         Text  =>
           (if Value.Clipped_Wide
            then (Value.Text with delta Width => Width_One)
            else Value.Text),
         Style => Value.Style,
         Link  => Link,
         Image => Value.Image);
   end Compact_Cell;

   procedure Release_Replacements is
   begin
      if Prepared_Links /= null then
         for I in 1 .. Natural'Min
           (Prepared_Link_Limit, Prepared_Links'Length)
         loop
            Hyperlink_Store.Release_Snapshot
              (S.Storage.Hyperlinks, Prepared_Links (I));
         end loop;
      end if;
      if New_Cells /= null then
         Snapshot_Cell_Storage.Abandon_Batch (S, New_Cells);
      end if;
      if New_Dirty /= null then
         Storage.Release (New_Dirty);
      end if;
      if New_Scroll_Events /= null then
         Storage.Release (New_Scroll_Events);
      end if;
      if New_Prepared_Links /= null then
         Storage.Release (New_Prepared_Links);
      end if;
   end Release_Replacements;
begin
   --  Application-side presentation effects and scrollback composition may
   --  have changed the reusable snapshot without changing the terminal.  A
   --  scrollback view replaces arbitrary live rows, so restore it in full.
   --  For ordinary presentation effects, the snapshot dirty mask records the
   --  rows that must be restored from the terminal before applying the next
   --  frame's effects.
   Copy_All := S.Rows /= T.Rows
     or else S.Cols /= T.Cols
     or else S.Scrollback_Offset /= 0;
   --  Allocate every required replacement before changing the reusable
   --  snapshot.  A failed allocation therefore leaves the caller's previous
   --  snapshot valid and internally consistent.
   begin
      if S.Storage.Scroll_Events = null
        or else S.Storage.Scroll_Events'Length < Scroll_Count
      then
         if Scroll_Count > 0 then
            New_Scroll_Events :=
              new Graphics_Scroll_Event_Array (1 .. Scroll_Count);
            Scroll_Target := New_Scroll_Events;
         end if;
      end if;
      if Copy_All
        or else S.Storage.Cells_Data = null
        or else S.Storage.Cells_Data'Length /= Count
      then
         Snapshot_Cell_Storage.Acquire_Batch
           (S, Positive (Count), New_Cells);
         Cells_Target := New_Cells;
         Copy_All := True;
      end if;
      if S.Storage.Dirty_Data = null
        or else S.Storage.Dirty_Data'Length /= T.Rows
      then
         New_Dirty := new Dirty_Row_Array (1 .. T.Rows);
         Dirty_Target := New_Dirty;
      end if;
   exception
      when others =>
         Release_Replacements;
         raise;
   end;

   if Copy_All then
      for I in 1 .. Count loop
         Cells_Target (I) := Compact_Cell (Src (I));
         if Src (I).Image.Is_Placeholder then
            Image_Cell_Count := Image_Cell_Count + 1;
         end if;
         if Src (I).Style.Blink then
            Blinking_Cell_Count := Blinking_Cell_Count + 1;
         end if;
      end loop;
      for I in 1 .. Count loop
         declare
            Col : constant Positive := ((I - 1) mod T.Cols) + 1;
            Value : Snapshot_Cell renames Cells_Target (I);
         begin
            if (Value.Kind = Wide_Continuation
                and then
                  (Col = 1
                   or else Cells_Target (I - 1).Kind /= Character
                   or else Cells_Target (I - 1).Text.Width /= Width_Two))
              or else
                (Value.Kind = Character
                 and then Value.Text.Width = Width_Two
                 and then
                   (Col = T.Cols
                    or else
                      Cells_Target (I + 1).Kind /= Wide_Continuation))
            then
               Wide_Violation_Count := Wide_Violation_Count + 1;
            end if;
         end;
      end loop;
   else
      --  Intern every hyperlink needed by dirty rows before changing the live
      --  reusable snapshot and retain the resulting pointers.  Allocation
      --  failure cannot leave a partially refreshed row set, and the update
      --  pass does not repeat ordered-set lookups.
      for R in 1 .. T.Rows loop
         if T.Dirty (R) or else S.Storage.Dirty_Data (R) then
            Prepared_Link_Count := Prepared_Link_Count + T.Cols;
         end if;
      end loop;
      Prepared_Link_Limit := Prepared_Link_Count;
      if Prepared_Link_Count > 0
        and then
          (Prepared_Links = null
           or else Prepared_Links'Length < Prepared_Link_Count)
      then
         New_Prepared_Links :=
           new Snapshot_Link_Array (1 .. Prepared_Link_Count);
         Prepared_Links := New_Prepared_Links;
      end if;
      Prepared_Link_Count := 0;
      for R in 1 .. T.Rows loop
         if T.Dirty (R) or else S.Storage.Dirty_Data (R) then
            for C in 1 .. T.Cols loop
               declare
                  I : constant Positive := (R - 1) * T.Cols + C;
               begin
                  Prepared_Link_Count := Prepared_Link_Count + 1;
                  if Src (I).Link /= null then
                     Prepared_Links (Prepared_Link_Count) :=
                       Intern.all
                         (S.Storage.Hyperlinks, Src (I).Link.Value);
                  else
                     Prepared_Links (Prepared_Link_Count) := null;
                  end if;
               end;
            end loop;
         end if;
      end loop;
      Prepared_Link_Count := 0;
      for R in 1 .. T.Rows loop
         if T.Dirty (R) or else S.Storage.Dirty_Data (R) then
            for C in 1 .. T.Cols loop
               declare
                  I : constant Positive := (R - 1) * T.Cols + C;
               begin
                  Prepared_Link_Count := Prepared_Link_Count + 1;
                  Snapshot_Access.Set_Compact_Cell
                    (S,
                     I,
                     Compact_Cell
                       (Src (I),
                        Prepared_Links (Prepared_Link_Count),
                        Link_Prepared => True));
                  Prepared_Links (Prepared_Link_Count) := null;
               end;
            end loop;
         end if;
      end loop;
      Image_Cell_Count := S.Storage.Image_Cells;
      Blinking_Cell_Count := S.Storage.Blinking_Cells;
      Wide_Violation_Count := S.Storage.Wide_Violations;
   end if;

   --  No allocation can occur after this point.  Reused scroll-event storage
   --  is therefore not changed until every fallible cell preparation has
   --  completed.
   if Scroll_Count > 0 then
      for I in 1 .. Scroll_Count loop
         declare
            Slot : constant Positive :=
              ((Scroll_Head + I - 1) mod Max_Graphics_Scroll_Events) + 1;
         begin
            Scroll_Target (I) :=
              (if T.Active = Alternate
               then T.Graphics.Alternate_Scroll_Events (Slot)
               else T.Graphics.Primary_Scroll_Events (Slot));
         end;
      end loop;
      Scroll_Oldest := Scroll_Target (1).Sequence;
   end if;
   for R in 1 .. T.Rows loop
      Dirty_Target (R) := T.Dirty (R);
      if T.Dirty (R) then
         Dirty_Row_Count := Dirty_Row_Count + 1;
      end if;
   end loop;

   if New_Scroll_Events /= null then
      if S.Storage.Scroll_Events /= null then
         Storage.Release (S.Storage.Scroll_Events);
      end if;
      S.Storage.Scroll_Events := New_Scroll_Events;
      New_Scroll_Events := null;
   end if;
   if New_Cells /= null then
      Snapshot_Cell_Storage.Commit_Batch (S, New_Cells);
      if S.Storage.Prepared_Links /= null then
         Storage.Release (S.Storage.Prepared_Links);
         Prepared_Links := null;
      end if;
   end if;
   if New_Dirty /= null then
      if S.Storage.Dirty_Data /= null then
         Storage.Release (S.Storage.Dirty_Data);
      end if;
      S.Storage.Dirty_Data := New_Dirty;
      New_Dirty := null;
   end if;
   if New_Prepared_Links /= null then
      if S.Storage.Prepared_Links /= null then
         Storage.Release (S.Storage.Prepared_Links);
      end if;
      S.Storage.Prepared_Links := New_Prepared_Links;
      New_Prepared_Links := null;
   end if;

   S.Rows := T.Rows;
   S.Cols := T.Cols;
   S.Graphics_Stream := T.Graphics.Stream;
   S.Graphics_Transaction := T.Graphics.Transaction;
   S.Alternate_Screen := T.Active = Alternate;
   S.Screen_Generation :=
     (if T.Active = Alternate
      then T.Graphics.Alternate_Generation
      else T.Graphics.Primary_Generation);
   S.Scrollback_Offset := 0;
   S.Scrollback_Rows :=
     (if T.Active = Primary then T.Scrollback_State.Rows else 0);
   S.Graphics_Scroll_Current :=
     (if T.Active = Alternate
      then T.Graphics.Alternate_Scroll_Sequence
      else T.Graphics.Primary_Scroll_Sequence);
   S.Graphics_Scroll_Count := Scroll_Count;
   S.Graphics_Scroll_Oldest := Scroll_Oldest;
   S.Storage.Image_Cells := Image_Cell_Count;
   S.Storage.Blinking_Cells := Blinking_Cell_Count;
   S.Storage.Dirty_Rows := Dirty_Row_Count;
   S.Storage.Wide_Violations := Wide_Violation_Count;
   S.Cursor :=
     (Row     => T.Cursor_Row,
      Col     => T.Cursor_Col,
      Visible => T.Current_Modes.Cursor_Visible,
      Shape   => T.Current_Cursor_Shape,
      Blinking => T.Current_Cursor_Blinking);
   S.Graphics := T.Graphics.Last_Event;
   if not S.Graphics.Pending then
      S.Graphics.Stream_ID := S.Graphics_Stream;
      S.Graphics.Transaction_Generation := S.Graphics_Transaction;
      S.Graphics.Alternate_Screen := S.Alternate_Screen;
      S.Graphics.Screen_Generation := S.Screen_Generation;
   end if;
exception
   when others =>
      Release_Replacements;
      raise;
end Build_Snapshot;

separate (Terminal.Core)
procedure Resize
  (T      : in out Terminal;
   Rows   : Positive;
   Cols   : Positive;
   Status : out Resize_Status)
is
   Old_Primary  : Stored_Cell_Array_Access := T.Primary_Cells;
   Old_Alt      : Stored_Cell_Array_Access := T.Alt_Cells;
   Old_Scrollback : Stored_Cell_Array_Access := T.Scrollback_State.Cells;
   Old_Dirty    : Dirty_Row_Array_Access := T.Dirty;
   Old_Tabs     : Tab_Stop_Array_Access := T.Tab_Stops;
   New_Primary  : Stored_Cell_Array_Access := null;
   New_Alt      : Stored_Cell_Array_Access := null;
   New_Scrollback : Stored_Cell_Array_Access := null;
   New_Dirty    : Dirty_Row_Array_Access := null;
   New_Tabs     : Tab_Stop_Array_Access := null;
   Old_Rows    : constant Positive := T.Rows;
   Old_Cols    : constant Positive := T.Cols;
   Old_Scrollback_Rows : constant Natural := T.Scrollback_State.Rows;
   Old_Scrollback_Head : constant Natural := T.Scrollback_State.Head;
   Old_Scrollback_Capacity : constant Natural :=
     T.Scrollback_State.Capacity_Rows;
   Source_Row_Count : constant Positive := Old_Scrollback_Rows + Old_Rows;
   Cursor_Source_Row : constant Positive :=
     Old_Scrollback_Rows + T.Cursor_Row;
   New_Count   : Positive;
   Reflowed_Row_Count : Natural := 0;
   New_Scrollback_Rows : Natural := 0;
   Dropped_Reflowed_Rows : Natural := 0;
   Viewport_First_Row : Positive := 1;
   Primary_Prefix_Rows : Natural := 0;
   New_Cursor_Global_Row : Natural := 0;
   New_Cursor_Col : Positive := 1;

   function Source_Cell
     (Row : Positive;
      Col : Positive) return Stored_Cell
   is
      Physical_Row : Natural;
   begin
      if Row <= Old_Scrollback_Rows then
         Physical_Row :=
           (Old_Scrollback_Head + Row - 1) mod Old_Scrollback_Capacity;
         return Old_Scrollback (Physical_Row * Old_Cols + Col);
      else
         return Old_Primary
           ((Row - Old_Scrollback_Rows - 1) * Old_Cols + Col);
      end if;
   end Source_Cell;

   function Row_Wraps (Row : Positive) return Boolean is
     (Source_Cell (Row, Old_Cols).Wraps_To_Next);

   function Used_Columns (Row : Positive) return Natural is
      Result : Natural := 0;
   begin
      if Row_Wraps (Row) then
         Result := Old_Cols;
      else
         for Col in reverse 1 .. Old_Cols loop
            if Source_Cell (Row, Col).Kind /= Empty then
               Result := Col;
               exit;
            end if;
         end loop;
      end if;
      if Row = Cursor_Source_Row then
         Result := Natural'Max (Result, T.Cursor_Col);
      end if;
      return Result;
   end Used_Columns;

   function Reflow_Width (Cell : Stored_Cell) return Positive is
     (if Cell.Kind = Character
        and then Cell.Text.Width = Width_Two
        and then Cols > 1
      then 2
      else 1);

   procedure Count_Reflowed_Rows is
      Width_In_Row : Natural := 0;
      Rows_In_Line : Positive := 1;
   begin
      Reflowed_Row_Count := 0;
      New_Cursor_Global_Row := 0;
      for Source_Row in 1 .. Source_Row_Count loop
         declare
            Last : constant Natural := Used_Columns (Source_Row);
         begin
            if Last > 0 then
               for Source_Col in 1 .. Last loop
                  declare
                     Cell : constant Stored_Cell :=
                       Source_Cell (Source_Row, Source_Col);
                  begin
                     if Cell.Kind /= Wide_Continuation then
                        declare
                           Width : constant Positive := Reflow_Width (Cell);
                        begin
                           if Width_In_Row > 0
                             and then Width_In_Row + Width > Cols
                           then
                              Rows_In_Line := Rows_In_Line + 1;
                              Width_In_Row := 0;
                           end if;
                           if Source_Row = Cursor_Source_Row
                             and then T.Cursor_Col >= Source_Col
                             and then T.Cursor_Col < Source_Col
                               + (if Cell.Kind = Character
                                    and then Cell.Text.Width = Width_Two
                                  then 2 else 1)
                           then
                              New_Cursor_Global_Row :=
                                Reflowed_Row_Count + Rows_In_Line;
                              New_Cursor_Col :=
                                Positive'Min
                                  (Cols,
                                   Width_In_Row + 1
                                     + Natural'Min
                                       (T.Cursor_Col - Source_Col,
                                        Width - 1));
                           end if;
                           Width_In_Row := Width_In_Row + Width;
                        end;
                     end if;
                  end;
               end loop;
            end if;
            if not Row_Wraps (Source_Row) then
               Reflowed_Row_Count := Reflowed_Row_Count + Rows_In_Line;
               Width_In_Row := 0;
               Rows_In_Line := 1;
            end if;
         end;
      end loop;
      if Row_Wraps (Source_Row_Count) then
         Reflowed_Row_Count := Reflowed_Row_Count + Rows_In_Line;
      end if;
   end Count_Reflowed_Rows;

   procedure Release_Replacements is
   begin
      if New_Primary /= null then Storage.Release (New_Primary); end if;
      if New_Alt /= null then Storage.Release (New_Alt); end if;
      if New_Scrollback /= null then Storage.Release (New_Scrollback); end if;
      if New_Dirty /= null then Storage.Release (New_Dirty); end if;
      if New_Tabs /= null then Storage.Release (New_Tabs); end if;
   end Release_Replacements;

   procedure Reflow_Primary is
      Output_Row : Natural := 0;
      Output_Col : Positive := 1;

      function Stored_Row (Global_Row : Positive) return Natural is
        (if Global_Row <= Dropped_Reflowed_Rows
         then 0
         else Global_Row - Dropped_Reflowed_Rows);

      procedure Set_Target_Cell
        (Global_Row : Positive;
         Col        : Positive;
         Cell       : Stored_Cell)
      is
         Kept : constant Natural := Stored_Row (Global_Row);
         Primary_Row : Natural;
      begin
         if Kept = 0 then
            return;
         elsif Kept <= New_Scrollback_Rows then
            New_Scrollback ((Kept - 1) * Cols + Col) := Cell;
         else
            Primary_Row :=
              Primary_Prefix_Rows + Kept - New_Scrollback_Rows;
            if Primary_Row in 1 .. Rows then
               New_Primary ((Primary_Row - 1) * Cols + Col) := Cell;
            end if;
         end if;
      end Set_Target_Cell;

      procedure Mark_Output_Wrapped is
         Kept : constant Natural := Stored_Row (Output_Row);
         Primary_Row : Natural;
      begin
         if Kept = 0 then
            return;
         elsif Kept <= New_Scrollback_Rows then
            New_Scrollback (Kept * Cols).Wraps_To_Next := True;
         else
            Primary_Row :=
              Primary_Prefix_Rows + Kept - New_Scrollback_Rows;
            if Primary_Row in 1 .. Rows then
               New_Primary (Primary_Row * Cols).Wraps_To_Next := True;
            end if;
         end if;
      end Mark_Output_Wrapped;

      procedure Start_Output_Row is
      begin
         Output_Row := Output_Row + 1;
         Output_Col := 1;
      end Start_Output_Row;

      procedure Place
        (Cell       : Stored_Cell;
         Source_Row : Positive;
         Source_Col : Positive)
      is
         Width : constant Positive := Reflow_Width (Cell);
         Head : Stored_Cell := Cell;
         Destination_Col : Positive;
      begin
         if Output_Col > Cols
           or else Width - 1 > Cols - Output_Col
         then
            Mark_Output_Wrapped;
            Start_Output_Row;
         end if;
         Destination_Col := Output_Col;
         Head.Wraps_To_Next := False;
         Head.Clipped_Wide :=
           Head.Kind = Character
           and then Head.Text.Width = Width_Two
           and then Cols = 1;
         Set_Target_Cell (Output_Row, Destination_Col, Head);
         if Width = 2 then
            Set_Target_Cell
              (Output_Row,
               Destination_Col + 1,
               (Kind  => Wide_Continuation,
                Text  => (Code_Point => 0, Width => Width_Zero, others => <>),
                Style => Head.Style,
                Link  => Head.Link,
                Image => <>,
                Clipped_Wide => False,
                Wraps_To_Next => False));
         end if;
         if Source_Row = Cursor_Source_Row
           and then T.Cursor_Col >= Source_Col
           and then T.Cursor_Col < Source_Col
             + (if Cell.Kind = Character and then Cell.Text.Width = Width_Two
                then 2 else 1)
         then
            New_Cursor_Global_Row := Output_Row;
            New_Cursor_Col :=
              Positive'Min
                (Cols,
                 Destination_Col
                   + Natural'Min (T.Cursor_Col - Source_Col, Width - 1));
         end if;
         Output_Col := Destination_Col + Width;
      end Place;
   begin
      for Source_Row in 1 .. Source_Row_Count loop
         if Source_Row = 1 or else not Row_Wraps (Source_Row - 1) then
            Start_Output_Row;
         end if;
         declare
            Last : constant Natural := Used_Columns (Source_Row);
         begin
            if Last > 0 then
               for Source_Col in 1 .. Last loop
                  declare
                     Cell : constant Stored_Cell :=
                       Source_Cell (Source_Row, Source_Col);
                  begin
                     if Cell.Kind /= Wide_Continuation then
                        Place (Cell, Source_Row, Source_Col);
                     end if;
                  end;
               end loop;
            end if;
         end;
      end loop;
   end Reflow_Primary;

begin
   if not T.Initialized then
      Status := Allocation_Failed;
      return;
   end if;
   if Rows = T.Rows and then Cols = T.Cols then
      Status := Ok;
      return;
   end if;
   if Rows > Positive'Last / Cols
     or else
       (T.Scrollback_State.Limit > 0
        and then T.Scrollback_State.Limit > Natural'Last / Cols)
   then
      Status := Invalid_Size;
      return;
   end if;
   New_Count := Rows * Cols;
   Count_Reflowed_Rows;
   New_Scrollback_Rows :=
     0;
   Viewport_First_Row :=
     Positive'Min
       ((if Reflowed_Row_Count > Rows
         then Reflowed_Row_Count - Rows + 1
         else 1),
        (if New_Cursor_Global_Row = 0
         then 1 else New_Cursor_Global_Row));
   New_Scrollback_Rows :=
     Natural'Min (T.Scrollback_State.Limit, Viewport_First_Row - 1);
   Dropped_Reflowed_Rows :=
     Viewport_First_Row - 1 - New_Scrollback_Rows;
   --  Growing the viewport exposes blank rows below existing content.  Keep
   --  the first logical row anchored at the top, matching ordinary terminal
   --  resize behavior and preserving stable visible coordinates.
   Primary_Prefix_Rows := 0;

   begin
      New_Primary := new Stored_Cell_Array (1 .. New_Count);
      New_Alt := new Stored_Cell_Array (1 .. New_Count);
      if New_Scrollback_Rows > 0 then
         New_Scrollback :=
           new Stored_Cell_Array (1 .. New_Scrollback_Rows * Cols);
      end if;
      New_Dirty := new Dirty_Row_Array (1 .. Rows);
      New_Tabs := new Tab_Stop_Array (1 .. Cols);

      New_Primary.all := (others => Blank_Cell (T.Current_Style));
      New_Alt.all := (others => Blank_Cell (T.Current_Style));
      if New_Scrollback /= null then
         New_Scrollback.all := (others => Blank_Cell (T.Current_Style));
      end if;
      New_Dirty.all := (others => True);
      for C in New_Tabs'Range loop
         New_Tabs (C) := C > 1 and then (C - 1) mod 8 = 0;
      end loop;

      Reflow_Primary;

      for R in 1 .. Positive'Min (Old_Rows, Rows) loop
         for C in 1 .. Positive'Min (Old_Cols, Cols) loop
            New_Alt ((R - 1) * Cols + C) :=
              Old_Alt ((R - 1) * Old_Cols + C);
            New_Alt ((R - 1) * Cols + C).Wraps_To_Next := False;
         end loop;
         Screen_Rows.Normalize_Wide_Row
           (New_Alt, R, Cols, T.Current_Style);
      end loop;
      if Old_Tabs /= null then
         for C in 1 .. Positive'Min (Old_Cols, Cols) loop
            New_Tabs (C) := Old_Tabs (C);
         end loop;
      end if;
   exception
      when Storage_Error =>
         Release_Replacements;
         Status := Allocation_Failed;
         return;
      when others =>
         Release_Replacements;
         raise;
   end;

   T.Primary_Cells := New_Primary;
   T.Alt_Cells := New_Alt;
   T.Scrollback_State.Cells := New_Scrollback;
   T.Scrollback_State.Capacity_Rows := New_Scrollback_Rows;
   T.Scrollback_State.Rows := New_Scrollback_Rows;
   T.Scrollback_State.Head := 0;
   T.Dirty := New_Dirty;
   T.Tab_Stops := New_Tabs;
   New_Primary := null;
   New_Alt := null;
   New_Scrollback := null;
   New_Dirty := null;
   New_Tabs := null;

   T.Rows := Rows;
   T.Cols := Cols;
   --  Reflow can move the cursor away from the old right margin, so an old
   --  deferred autowrap must not affect the next printable character.
   T.Pending_Wrap := False;
   T.Last_Printable_Clipped_Wide :=
     T.Has_Last_Printable
     and then T.Last_Printable_Text.Width = Width_Two
     and then Cols = 1;

   if Old_Primary /= null then Storage.Release (Old_Primary); end if;
   if Old_Alt /= null then Storage.Release (Old_Alt); end if;
   if Old_Scrollback /= null then Storage.Release (Old_Scrollback); end if;
   if Old_Dirty /= null then Storage.Release (Old_Dirty); end if;
   if Old_Tabs /= null then Storage.Release (Old_Tabs); end if;

   if T.Active = Primary
     and then New_Cursor_Global_Row > Dropped_Reflowed_Rows
   then
      declare
         Kept : constant Natural :=
           New_Cursor_Global_Row - Dropped_Reflowed_Rows;
      begin
         if Kept > New_Scrollback_Rows then
            T.Cursor_Row :=
              Positive'Max
                (1,
                 Positive'Min
                   (Rows,
                    Primary_Prefix_Rows + Kept - New_Scrollback_Rows));
         else
            --  A very short resized viewport can exclude the old cursor row.
            --  Keep the cursor valid at the nearest visible edge.
            T.Cursor_Row := 1;
         end if;
         T.Cursor_Col := New_Cursor_Col;
      end;
   else
      T.Cursor_Row := Positive'Min (Rows, T.Cursor_Row);
      T.Cursor_Col := Positive'Min (Cols, T.Cursor_Col);
   end if;
   T.Top_Margin := 1;
   T.Bottom_Margin := Rows;
   Mark_All_Dirty (T);
   Status := Ok;

   if T.Current_Modes.In_Band_Resize then
      Queue_Resize_Report (T);
   end if;
end Resize;

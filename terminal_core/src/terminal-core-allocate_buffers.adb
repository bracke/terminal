separate (Terminal.Core)
procedure Allocate_Buffers
  (T      : in out Terminal;
   Rows   : Positive;
   Cols   : Positive;
   Status : out Boolean)
is
   Count : constant Positive := Rows * Cols;
   New_Primary : Stored_Cell_Array_Access := null;
   New_Alt : Stored_Cell_Array_Access := null;
   New_Dirty : Dirty_Row_Array_Access := null;
   New_Tab_Stops : Tab_Stop_Array_Access := null;
   New_Primary_Scroll : Graphics_Scroll_Event_Array_Access := null;
   New_Alternate_Scroll : Graphics_Scroll_Event_Array_Access := null;

   procedure Release_Replacements is
   begin
      if New_Primary /= null then Storage.Release (New_Primary); end if;
      if New_Alt /= null then Storage.Release (New_Alt); end if;
      if New_Dirty /= null then Storage.Release (New_Dirty); end if;
      if New_Tab_Stops /= null then Storage.Release (New_Tab_Stops); end if;
      if New_Primary_Scroll /= null then
         Storage.Release (New_Primary_Scroll);
      end if;
      if New_Alternate_Scroll /= null then
         Storage.Release (New_Alternate_Scroll);
      end if;
   end Release_Replacements;
begin
   New_Primary := new Stored_Cell_Array (1 .. Count);
   New_Alt := new Stored_Cell_Array (1 .. Count);
   New_Dirty := new Dirty_Row_Array (1 .. Rows);
   New_Tab_Stops := new Tab_Stop_Array (1 .. Cols);
   New_Primary_Scroll :=
     new Graphics_Scroll_Event_Array (1 .. Max_Graphics_Scroll_Events);
   New_Alternate_Scroll :=
     new Graphics_Scroll_Event_Array (1 .. Max_Graphics_Scroll_Events);

   for I in New_Primary'Range loop
      New_Primary (I) := Blank_Cell (T.Current_Style);
      New_Alt (I) := Blank_Cell (T.Current_Style);
   end loop;
   New_Dirty.all := (others => True);
   for C in New_Tab_Stops'Range loop
      New_Tab_Stops (C) := C > 1 and then (C - 1) mod 8 = 0;
   end loop;
   New_Primary_Scroll.all := (others => <>);
   New_Alternate_Scroll.all := (others => <>);

   if T.Primary_Cells /= null then Storage.Release (T.Primary_Cells); end if;
   if T.Alt_Cells /= null then Storage.Release (T.Alt_Cells); end if;
   if T.Scrollback_State.Cells /= null then
      Storage.Release (T.Scrollback_State.Cells);
   end if;
   T.Scrollback_State.Capacity_Rows := 0;
   if T.Dirty /= null then Storage.Release (T.Dirty); end if;
   if T.Tab_Stops /= null then Storage.Release (T.Tab_Stops); end if;
   if T.Graphics.Primary_Scroll_Events /= null then
      Storage.Release (T.Graphics.Primary_Scroll_Events);
   end if;
   if T.Graphics.Alternate_Scroll_Events /= null then
      Storage.Release (T.Graphics.Alternate_Scroll_Events);
   end if;
   T.Primary_Cells := New_Primary;
   T.Alt_Cells := New_Alt;
   T.Scrollback_State.Cells := null;
   T.Scrollback_State.Capacity_Rows := 0;
   T.Dirty := New_Dirty;
   T.Tab_Stops := New_Tab_Stops;
   T.Graphics.Primary_Scroll_Events := New_Primary_Scroll;
   T.Graphics.Alternate_Scroll_Events := New_Alternate_Scroll;
   New_Primary := null;
   New_Alt := null;
   New_Dirty := null;
   New_Tab_Stops := null;
   New_Primary_Scroll := null;
   New_Alternate_Scroll := null;
   T.Rows := Rows;
   T.Cols := Cols;
   T.Bottom_Margin := Rows;
   T.Scrollback_State.Rows := 0;
   Status := True;
exception
   when Storage_Error =>
      Release_Replacements;
      Status := False;
   when others =>
      Release_Replacements;
      raise;
end Allocate_Buffers;

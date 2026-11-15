separate (Terminal.Core)
procedure Repeat_Last_Printable
  (T     : in out Terminal;
   Count : Positive)
is
   Cells : constant Stored_Cell_Array_Access := Active_Cells (T);
   Width : constant Cell_Width :=
     (if T.Last_Printable_Clipped_Wide
      then Width_One
      else T.Last_Printable_Text.Width);

   procedure Repeat_Cluster is
      Remaining : Natural := Count;
      Available : Natural;
      Run_Characters : Natural;
      Run_Cells  : Natural;
      First      : Natural;
      Last       : Natural;
      Value      : constant Stored_Cell :=
        (Kind  => Character,
         Text  => T.Last_Printable_Text,
         Style => T.Current_Style,
         Link  => T.Hyperlinks.Current,
         Image => <>,
         Clipped_Wide => T.Last_Printable_Clipped_Wide,
         Wraps_To_Next => False);
   begin
      while Remaining > 0 loop
         if T.Pending_Wrap then
            Cells (Index (T, T.Cursor_Row, T.Cols)).Wraps_To_Next := True;
            T.Cursor_Col := 1;
            New_Line (T);
         end if;
         if Width = Width_Two
           and then T.Cols > 1
           and then T.Cursor_Col = T.Cols
         then
            Cells (Index (T, T.Cursor_Row, T.Cols)).Wraps_To_Next := True;
            T.Cursor_Col := 1;
            New_Line (T);
         end if;
         Available := T.Cols - T.Cursor_Col + 1;
         Run_Characters :=
           Natural'Min
             (Remaining,
              (if Width = Width_Two then Available / 2 else Available));
         pragma Assert (Run_Characters > 0);
         Run_Cells := Run_Characters * (if Width = Width_Two then 2 else 1);
         First := Index (T, T.Cursor_Row, T.Cursor_Col);
         Last := First + Run_Cells - 1;
         if T.Current_Modes.Insert_Mode then
            Shift_Row_Right (T, T.Cursor_Row, T.Cursor_Col, Run_Cells);
         else
            Clear_Wide_Overlap (T, T.Cursor_Row, T.Cursor_Col, Width);
            if Run_Cells > 1 then
               Clear_Wide_Overlap
                 (T, T.Cursor_Row, T.Cursor_Col + Run_Cells - 1, Width);
            end if;
         end if;
         if Width = Width_One then
            Cells (First .. Last) := (others => Value);
            if Value.Text.Code_Point = Kitty_Image_Placeholder then
               for Position in First .. Last loop
                  Decode_Image_Cell (T, Positive (Position));
               end loop;
            end if;
         else
            for Offset in 0 .. Run_Characters - 1 loop
               Cells (First + Offset * 2) := Value;
               Cells (First + Offset * 2 + 1) :=
                 (Kind  => Wide_Continuation,
                  Text  => (Code_Point => 0, Width => Width_Zero, others => <>),
                  Style => T.Current_Style,
                  Link  => T.Hyperlinks.Current,
                  Image => <>,
                  Clipped_Wide => False,
                  Wraps_To_Next => False);
               if Value.Text.Code_Point = Kitty_Image_Placeholder then
                  Decode_Image_Cell (T, Positive (First + Offset * 2));
               end if;
            end loop;
         end if;
         Mark_Dirty (T, T.Cursor_Row);
         Remaining := Remaining - Run_Characters;
         if T.Cursor_Col + Run_Cells - 1 = T.Cols then
            T.Cursor_Col := T.Cols;
            T.Pending_Wrap := T.Current_Modes.Autowrap;
            if Width = Width_One and then not T.Pending_Wrap then
               Remaining := 0;
            end if;
         else
            T.Cursor_Col := T.Cursor_Col + Run_Cells;
         end if;
      end loop;
      T.Last_Printable := Value.Text.Code_Point;
      T.Last_Printable_Text := Value.Text;
      T.Last_Printable_Clipped_Wide := Value.Clipped_Wide;
      T.Has_Last_Printable := True;
   end Repeat_Cluster;
begin
   if not T.Has_Last_Printable or else Cells = null or else Width = Width_Zero then
      return;
   end if;
   Repeat_Cluster;
end Repeat_Last_Printable;

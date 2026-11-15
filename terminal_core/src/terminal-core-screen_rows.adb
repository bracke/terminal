with Terminal.Core.Graphics_Scrolling;

package body Terminal.Core.Screen_Rows is
   function Cell_Index
     (T   : Terminal;
      Row : Positive;
      Col : Positive) return Positive is
     ((Row - 1) * T.Cols + Col);

   function Cells (T : Terminal'Class) return Stored_Cell_Array_Access is
     (if T.Active = Primary then T.Primary_Cells else T.Alt_Cells);

   function Blank (Style : Cell_Style) return Stored_Cell is
      Result : Stored_Cell;
   begin
      Result.Kind := Empty;
      Result.Text := (Code_Point => 0,
                      Width => Width_One,
                      Attachment_Count => 0,
                      Attachments => (others => 0));
      Result.Style := Style;
      Result.Link := null;
      Result.Image := (others => <>);
      Result.Clipped_Wide := False;
      Result.Wraps_To_Next := False;
      return Result;
   end Blank;

   procedure Mark_Dirty
     (T   : in out Terminal;
      Row : Positive) is
   begin
      if T.Dirty /= null and then Row in T.Dirty'Range then
         T.Dirty (Row) := True;
      end if;
   end Mark_Dirty;

   procedure Mark_All_Dirty (T : in out Terminal) is
   begin
      if T.Dirty /= null then
         T.Dirty.all := (others => True);
      end if;
   end Mark_All_Dirty;

   procedure Mark_Cursor_Move
     (T       : in out Terminal;
      Old_Row : Positive) is
   begin
      if T.Current_Modes.Cursor_Visible then
         Mark_Dirty (T, Old_Row);
         Mark_Dirty (T, T.Cursor_Row);
      end if;
   end Mark_Cursor_Move;

   procedure Reset_Tab_Stops (T : in out Terminal) is
   begin
      if T.Tab_Stops /= null then
         for C in T.Tab_Stops'Range loop
            T.Tab_Stops (C) := C > 1 and then (C - 1) mod 8 = 0;
         end loop;
      end if;
   end Reset_Tab_Stops;

   procedure Clear_Row
     (T     : in out Terminal;
      Row   : Positive;
      First : Positive;
      Last  : Positive)
   is
      Buffer : constant Stored_Cell_Array_Access := Cells (T);
      From   : Positive := First;
      To     : Positive := Last;
   begin
      if Buffer = null then
         return;
      end if;
      if Buffer (Cell_Index (T, Row, From)).Kind = Wide_Continuation
        and then From > 1
      then
         From := From - 1;
      end if;
      if Buffer (Cell_Index (T, Row, To)).Kind = Character
        and then Buffer (Cell_Index (T, Row, To)).Text.Width = Width_Two
        and then To < T.Cols
      then
         To := To + 1;
      end if;
      for C in From .. To loop
         Buffer (Cell_Index (T, Row, C)) := Blank (T.Current_Style);
      end loop;
      Mark_Dirty (T, Row);
   end Clear_Row;

   procedure Reset_Buffer
     (T : in out Terminal; Buffer : Stored_Cell_Array_Access) is
   begin
      if Buffer /= null then
         for I in Buffer'Range loop
            Buffer (I) := Blank (T.Current_Style);
         end loop;
         Mark_All_Dirty (T);
      end if;
   end Reset_Buffer;

   procedure Screen_Alignment_Test (T : in out Terminal) is
      Buffer : constant Stored_Cell_Array_Access := Cells (T);
   begin
      if Buffer = null then
         return;
      end if;
      for I in Buffer'Range loop
         Buffer (I) :=
           (Kind  => Character,
            Text  => (Code_Point => 16#45#, Width => Width_One, others => <>),
            Style => T.Current_Style,
            Link  => T.Hyperlinks.Current,
            Image => <>,
            Clipped_Wide => False,
            Wraps_To_Next => False);
      end loop;
      T.Pending_Wrap := False;
      Mark_All_Dirty (T);
   end Screen_Alignment_Test;

   procedure Horizontal_Tab_Set (T : in out Terminal) is
   begin
      if T.Tab_Stops /= null then
         T.Tab_Stops (T.Cursor_Col) := True;
      end if;
   end Horizontal_Tab_Set;

   procedure Save_Cursor_State (T : in out Terminal) is
   begin
      T.Saved_Row := T.Cursor_Row;
      T.Saved_Col := T.Cursor_Col;
      T.Saved_Style := T.Current_Style;
      T.Saved_G0_Charset := T.G0_Charset;
      T.Saved_G1_Charset := T.G1_Charset;
      T.Saved_G2_Charset := T.G2_Charset;
      T.Saved_G3_Charset := T.G3_Charset;
      T.Saved_Active_Charset := T.Active_Charset;
   end Save_Cursor_State;

   procedure Restore_Cursor_State (T : in out Terminal) is
      Old_Row : constant Positive := T.Cursor_Row;
   begin
      T.Cursor_Row := Positive'Min (T.Rows, T.Saved_Row);
      T.Cursor_Col := Positive'Min (T.Cols, T.Saved_Col);
      T.Current_Style := T.Saved_Style;
      T.G0_Charset := T.Saved_G0_Charset;
      T.G1_Charset := T.Saved_G1_Charset;
      T.G2_Charset := T.Saved_G2_Charset;
      T.G3_Charset := T.Saved_G3_Charset;
      T.Active_Charset := T.Saved_Active_Charset;
      T.Pending_Wrap := False;
      Mark_Cursor_Move (T, Old_Row);
   end Restore_Cursor_State;

   procedure Clear_Wide_Overlap
     (T         : in out Terminal;
      Row       : Positive;
      Col       : Positive;
      New_Width : Cell_Width)
   is
      Buffer : constant Stored_Cell_Array_Access := Cells (T);
      Last   : constant Positive :=
        (if New_Width = Width_Two and then Col < T.Cols then Col + 1 else Col);
   begin
      if Buffer = null then
         return;
      end if;
      if Buffer (Cell_Index (T, Row, Col)).Kind = Wide_Continuation
        and then Col > 1
      then
         Buffer (Cell_Index (T, Row, Col - 1)) := Blank (T.Current_Style);
      end if;
      for C in Col .. Last loop
         if Buffer (Cell_Index (T, Row, C)).Kind = Character
           and then Buffer (Cell_Index (T, Row, C)).Text.Width = Width_Two
           and then C < T.Cols
         then
            Buffer (Cell_Index (T, Row, C + 1)) := Blank (T.Current_Style);
         elsif Buffer (Cell_Index (T, Row, C)).Kind = Wide_Continuation
           and then C > 1
         then
            Buffer (Cell_Index (T, Row, C - 1)) := Blank (T.Current_Style);
         end if;
      end loop;
   end Clear_Wide_Overlap;

   procedure Normalize_Wide_Row
     (Buffer : Stored_Cell_Array_Access;
      Row    : Positive;
      Cols   : Positive;
      Style  : Cell_Style)
   is
      function Position (Col : Positive) return Positive is
        ((Row - 1) * Cols + Col);
   begin
      if Buffer = null then
         return;
      end if;
      for C in 1 .. Cols loop
         if Buffer (Position (C)).Clipped_Wide then
            if Buffer (Position (C)).Kind /= Character
              or else Buffer (Position (C)).Text.Width /= Width_Two
            then
               Buffer (Position (C)) := Blank (Style);
            elsif C < Cols then
               Buffer (Position (C)).Clipped_Wide := False;
               Buffer (Position (C + 1)) :=
                 (Kind  => Wide_Continuation,
                  Text  => (Code_Point => 0, Width => Width_Zero, others => <>),
                  Style => Buffer (Position (C)).Style,
                  Link  => Buffer (Position (C)).Link,
                  Image => <>,
                  Clipped_Wide => False,
                  Wraps_To_Next => False);
            end if;
         elsif Buffer (Position (C)).Kind = Wide_Continuation then
            if C = 1
              or else Buffer (Position (C - 1)).Kind /= Character
              or else Buffer (Position (C - 1)).Text.Width /= Width_Two
              or else Buffer (Position (C - 1)).Clipped_Wide
            then
               Buffer (Position (C)) := Blank (Style);
            end if;
         elsif Buffer (Position (C)).Kind = Character
           and then Buffer (Position (C)).Text.Width = Width_Two
           and then
             (C = Cols
              or else Buffer (Position (C + 1)).Kind /= Wide_Continuation)
         then
            Buffer (Position (C)) := Blank (Style);
         end if;
      end loop;
   end Normalize_Wide_Row;

   procedure Normalize_Wide_Row
     (T   : in out Terminal;
      Row : Positive) is
   begin
      Normalize_Wide_Row (Cells (T), Row, T.Cols, T.Current_Style);
   end Normalize_Wide_Row;

   procedure Shift_Right
     (T        : in out Terminal;
      Row      : Positive;
      Col      : Positive;
      Distance : Positive)
   is
      Buffer     : constant Stored_Cell_Array_Access := Cells (T);
      Blank_Last : constant Positive :=
        Positive'Min (T.Cols, Col + Distance - 1);
   begin
      if Buffer = null then
         return;
      end if;
      if Col + Distance <= T.Cols then
         for C in reverse Col + Distance .. T.Cols loop
            Buffer (Cell_Index (T, Row, C)) :=
              Buffer (Cell_Index (T, Row, C - Distance));
         end loop;
      end if;
      for C in Col .. Blank_Last loop
         Buffer (Cell_Index (T, Row, C)) := Blank (T.Current_Style);
      end loop;
      Normalize_Wide_Row (T, Row);
      Mark_Dirty (T, Row);
   end Shift_Right;

   procedure Shift_Left
     (T        : in out Terminal;
      Row      : Positive;
      Col      : Positive;
      Distance : Positive)
   is
      Buffer      : constant Stored_Cell_Array_Access := Cells (T);
      Blank_First : Positive;
   begin
      if Buffer = null then
         return;
      end if;
      if Col + Distance <= T.Cols then
         for C in Col .. T.Cols - Distance loop
            Buffer (Cell_Index (T, Row, C)) :=
              Buffer (Cell_Index (T, Row, C + Distance));
         end loop;
         Blank_First := T.Cols - Distance + 1;
      else
         Blank_First := Col;
      end if;
      for C in Blank_First .. T.Cols loop
         Buffer (Cell_Index (T, Row, C)) := Blank (T.Current_Style);
      end loop;
      Normalize_Wide_Row (T, Row);
      Mark_Dirty (T, Row);
   end Shift_Left;

   procedure Erase_Characters
     (T     : in out Terminal;
      Row   : Positive;
      Col   : Positive;
      Count : Positive)
   is
      Last : constant Positive := Positive'Min (T.Cols, Col + Count - 1);
   begin
      Clear_Row (T, Row, Col, Last);
   end Erase_Characters;

   procedure Insert_Blank_Lines
     (T     : in out Terminal;
      Row   : Positive;
      Count : Positive)
   is
      Buffer : constant Stored_Cell_Array_Access := Cells (T);
      Amount : Natural;
   begin
      if Buffer = null or else Row < T.Top_Margin or else Row > T.Bottom_Margin then
         return;
      end if;
      Amount := Natural'Min (Count, T.Bottom_Margin - Row + 1);
      if Amount = 0 then
         return;
      end if;
      if Row + Amount <= T.Bottom_Margin then
         for R in reverse Row + Amount .. T.Bottom_Margin loop
            for C in 1 .. T.Cols loop
               Buffer (Cell_Index (T, R, C)) :=
                 Buffer (Cell_Index (T, R - Amount, C));
            end loop;
            Mark_Dirty (T, R);
         end loop;
      end if;
      for R in Row .. Positive'Min (T.Bottom_Margin, Row + Amount - 1) loop
         Clear_Row (T, R, 1, T.Cols);
      end loop;
      Graphics_Scrolling.Note
        (T, Graphics_Scroll_Down, Row, T.Bottom_Margin, Positive (Amount));
   end Insert_Blank_Lines;

   procedure Delete_Lines
     (T     : in out Terminal;
      Row   : Positive;
      Count : Positive)
   is
      Buffer : constant Stored_Cell_Array_Access := Cells (T);
      Amount : Natural;
   begin
      if Buffer = null or else Row < T.Top_Margin or else Row > T.Bottom_Margin then
         return;
      end if;
      Amount := Natural'Min (Count, T.Bottom_Margin - Row + 1);
      if Amount = 0 then
         return;
      end if;
      if Row + Amount <= T.Bottom_Margin then
         for R in Row .. T.Bottom_Margin - Amount loop
            for C in 1 .. T.Cols loop
               Buffer (Cell_Index (T, R, C)) :=
                 Buffer (Cell_Index (T, R + Amount, C));
            end loop;
            Mark_Dirty (T, R);
         end loop;
      end if;
      for R in Positive'Max (Row, T.Bottom_Margin - Amount + 1) ..
        T.Bottom_Margin
      loop
         Clear_Row (T, R, 1, T.Cols);
      end loop;
      Graphics_Scrolling.Note
        (T, Graphics_Scroll_Up, Row, T.Bottom_Margin, Positive (Amount));
   end Delete_Lines;
end Terminal.Core.Screen_Rows;

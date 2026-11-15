private package Terminal.Core.Screen_Rows is
   function Cell_Index
     (T   : Terminal;
      Row : Positive;
      Col : Positive) return Positive;

   function Cells (T : Terminal'Class) return Stored_Cell_Array_Access;

   function Blank (Style : Cell_Style) return Stored_Cell;

   procedure Mark_Dirty
     (T   : in out Terminal;
      Row : Positive);

   procedure Mark_All_Dirty (T : in out Terminal);
   procedure Mark_Cursor_Move
     (T       : in out Terminal;
      Old_Row : Positive);
   procedure Reset_Tab_Stops (T : in out Terminal);
   procedure Clear_Row
     (T     : in out Terminal;
      Row   : Positive;
      First : Positive;
      Last  : Positive);
   procedure Reset_Buffer
     (T : in out Terminal; Buffer : Stored_Cell_Array_Access);
   procedure Screen_Alignment_Test (T : in out Terminal);
   procedure Horizontal_Tab_Set (T : in out Terminal);
   procedure Save_Cursor_State (T : in out Terminal);
   procedure Restore_Cursor_State (T : in out Terminal);

   procedure Clear_Wide_Overlap
     (T         : in out Terminal;
      Row       : Positive;
      Col       : Positive;
      New_Width : Cell_Width);

   procedure Normalize_Wide_Row
     (T   : in out Terminal;
      Row : Positive);

   procedure Normalize_Wide_Row
     (Buffer : Stored_Cell_Array_Access;
      Row    : Positive;
      Cols   : Positive;
      Style  : Cell_Style);

   procedure Shift_Right
     (T        : in out Terminal;
      Row      : Positive;
      Col      : Positive;
      Distance : Positive);

   procedure Shift_Left
     (T        : in out Terminal;
      Row      : Positive;
      Col      : Positive;
      Distance : Positive);

   procedure Erase_Characters
     (T     : in out Terminal;
      Row   : Positive;
      Col   : Positive;
      Count : Positive);

   procedure Insert_Blank_Lines
     (T     : in out Terminal;
      Row   : Positive;
      Count : Positive);

   procedure Delete_Lines
     (T     : in out Terminal;
      Row   : Positive;
      Count : Positive);
end Terminal.Core.Screen_Rows;

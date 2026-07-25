with Ada.Unchecked_Deallocation;
with Terminal.Core.Parser;

package body Terminal.Core is
   use Common;
   use Common.Bytes;

   procedure Free_Cells is new Ada.Unchecked_Deallocation
     (Cell_Array, Cell_Array_Access);
   procedure Free_Dirty is new Ada.Unchecked_Deallocation
     (Dirty_Row_Array, Dirty_Row_Array_Access);
   procedure Free_Tab_Stops is new Ada.Unchecked_Deallocation
     (Tab_Stop_Array, Tab_Stop_Array_Access);

   function Index (T : Terminal; Row : Positive; Col : Positive) return Positive is
     ((Row - 1) * T.Cols + Col);

   function Active_Cells (T : Terminal) return Cell_Array_Access is
     (if T.Active = Primary then T.Primary_Cells else T.Alt_Cells);

   procedure Scroll_Down_Region
     (T      : in out Terminal;
      Top    : Positive;
      Bottom : Positive;
      Count  : Positive := 1);

   procedure New_Line (T : in out Terminal);

   procedure Mark_Dirty (T : in out Terminal; Row : Positive) is
   begin
      if T.Dirty /= null and then Row in T.Dirty'Range then
         T.Dirty (Row) := True;
      end if;
   end Mark_Dirty;

   procedure Mark_All_Dirty (T : in out Terminal) is
   begin
      if T.Dirty /= null then
         for R in T.Dirty'Range loop
            T.Dirty (R) := True;
         end loop;
      end if;
   end Mark_All_Dirty;

   procedure Mark_Cursor_Move
     (T       : in out Terminal;
      Old_Row : Positive)
   is
   begin
      if T.Current_Modes.Cursor_Visible then
         Mark_Dirty (T, Old_Row);
         Mark_Dirty (T, T.Cursor_Row);
      end if;
   end Mark_Cursor_Move;

   procedure Reset_Tab_Stops (T : in out Terminal) is
   begin
      if T.Tab_Stops = null then
         return;
      end if;

      for C in T.Tab_Stops'Range loop
         T.Tab_Stops (C) := C > 1 and then (C - 1) mod 8 = 0;
      end loop;
   end Reset_Tab_Stops;

   function Blank_Cell (Style : Cell_Style) return Cell is
      C : Cell;
   begin
      C.Kind := Empty;
      C.Text.Code_Point := 0;
      C.Text.Width := Width_One;
      C.Style := Style;
      return C;
   end Blank_Cell;

   procedure Clear_Row
     (T     : in out Terminal;
      Row   : Positive;
      First : Positive;
      Last  : Positive)
   is
      Cells : constant Cell_Array_Access := Active_Cells (T);
      From  : Positive := First;
      To    : Positive := Last;
   begin
      if Cells = null then
         return;
      end if;

      if Cells (Index (T, Row, From)).Kind = Wide_Continuation
        and then From > 1
      then
         From := From - 1;
      end if;

      if Cells (Index (T, Row, To)).Kind = Character
        and then Cells (Index (T, Row, To)).Text.Width = Width_Two
        and then To < T.Cols
      then
         To := To + 1;
      end if;

      for C in From .. To loop
         Cells (Index (T, Row, C)) := Blank_Cell (T.Current_Style);
      end loop;
      Mark_Dirty (T, Row);
   end Clear_Row;

   procedure Reset_Buffer (T : in out Terminal; Cells : Cell_Array_Access) is
   begin
      if Cells = null then
         return;
      end if;

      for I in Cells'Range loop
         Cells (I) := Blank_Cell (T.Current_Style);
      end loop;
      Mark_All_Dirty (T);
   end Reset_Buffer;

   procedure Screen_Alignment_Test (T : in out Terminal) is
      Cells : constant Cell_Array_Access := Active_Cells (T);
   begin
      if Cells = null then
         return;
      end if;

      for I in Cells'Range loop
         Cells (I) :=
           (Kind  => Character,
            Text  => (Code_Point => 16#45#, Width => Width_One),
            Style => T.Current_Style);
      end loop;
      T.Pending_Wrap := False;
      Mark_All_Dirty (T);
   end Screen_Alignment_Test;

   procedure Index_Control (T : in out Terminal) is
   begin
      New_Line (T);
   end Index_Control;

   procedure Next_Line_Control (T : in out Terminal) is
   begin
      T.Cursor_Col := 1;
      New_Line (T);
   end Next_Line_Control;

   procedure Reverse_Index_Control (T : in out Terminal) is
      Old_Row : constant Positive := T.Cursor_Row;
   begin
      if T.Cursor_Row = T.Top_Margin then
         Scroll_Down_Region (T, T.Top_Margin, T.Bottom_Margin);
      elsif T.Cursor_Row > 1 then
         T.Cursor_Row := T.Cursor_Row - 1;
      end if;
      Mark_Cursor_Move (T, Old_Row);
   end Reverse_Index_Control;

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
      T.Active_Charset := T.Saved_Active_Charset;
      T.Pending_Wrap := False;
      Mark_Cursor_Move (T, Old_Row);
   end Restore_Cursor_State;

   procedure Reset_Terminal (T : in out Terminal) is
   begin
      T.Active := Primary;
      T.Current_Modes := (others => <>);
      T.Cursor_Row := 1;
      T.Cursor_Col := 1;
      T.Current_Cursor_Shape := Cursor_Block;
      T.Current_Cursor_Blinking := False;
      T.Saved_Row := 1;
      T.Saved_Col := 1;
      T.Pending_Wrap := False;
      T.Top_Margin := 1;
      T.Bottom_Margin := T.Rows;
      T.Scrollback_Rows := 0;
      T.Current_Style := (others => <>);
      T.Saved_Style := (others => <>);
      T.G0_Charset := ASCII_Charset;
      T.G1_Charset := ASCII_Charset;
      T.Active_Charset := G0;
      T.Charset_Target := G0;
      T.Saved_G0_Charset := ASCII_Charset;
      T.Saved_G1_Charset := ASCII_Charset;
      T.Saved_Active_Charset := G0;
      T.Last_Printable := 0;
      T.Has_Last_Printable := False;
      T.Window_Title := (others => <>);
      T.Response_Length := 0;
      T.State := Ground;
      T.CSI_Count := 0;
      T.CSI_Intermediates := (others => ASCII.NUL);
      T.CSI_Intermediate_Count := 0;
      T.OSC_Data := (others => ASCII.NUL);
      T.OSC_Count := 0;
      T.Ignored_String_Count := 0;
      T.UTF8_Need := 0;
      T.UTF8_Seen := 0;
      T.UTF8_Accum := 0;
      T.UTF8_Min := 0;
      Reset_Tab_Stops (T);
      Reset_Buffer (T, T.Primary_Cells);
      Reset_Buffer (T, T.Alt_Cells);
   end Reset_Terminal;

   procedure Allocate_Buffers
     (T      : in out Terminal;
      Rows   : Positive;
      Cols   : Positive;
      Status : out Boolean)
   is
      Count : constant Positive := Rows * Cols;
   begin
      if T.Primary_Cells /= null then
         Free_Cells (T.Primary_Cells);
         T.Primary_Cells := null;
      end if;
      if T.Alt_Cells /= null then
         Free_Cells (T.Alt_Cells);
         T.Alt_Cells := null;
      end if;
      if T.Scrollback /= null then
         Free_Cells (T.Scrollback);
         T.Scrollback := null;
      end if;
      if T.Dirty /= null then
         Free_Dirty (T.Dirty);
         T.Dirty := null;
      end if;
      if T.Tab_Stops /= null then
         Free_Tab_Stops (T.Tab_Stops);
         T.Tab_Stops := null;
      end if;

      T.Primary_Cells := new Cell_Array (1 .. Count);
      T.Alt_Cells := new Cell_Array (1 .. Count);
      if T.Scrollback_Limit > 0 then
         T.Scrollback := new Cell_Array (1 .. T.Scrollback_Limit * Cols);
      else
         T.Scrollback := null;
      end if;
      T.Dirty := new Dirty_Row_Array (1 .. Rows);
      T.Tab_Stops := new Tab_Stop_Array (1 .. Cols);
      T.Rows := Rows;
      T.Cols := Cols;
      T.Bottom_Margin := Rows;
      T.Scrollback_Rows := 0;
      Status := True;
      Reset_Tab_Stops (T);
      Reset_Buffer (T, T.Primary_Cells);
      Reset_Buffer (T, T.Alt_Cells);
      Mark_All_Dirty (T);
   exception
      when Storage_Error =>
         Status := False;
   end Allocate_Buffers;

   procedure Initialize
     (T                : out Terminal;
      Rows             : Positive;
      Cols             : Positive;
      Scrollback_Limit : Natural := 10_000;
      Status           : out Initialize_Status)
   is
      Allocated : Boolean;
   begin
      if Rows = 0 or else Cols = 0 then
         Status := Invalid_Size;
         return;
      end if;

      T.Initialized := False;
      T.Rows := Rows;
      T.Cols := Cols;
      T.Scrollback_Rows := 0;
      T.Active := Primary;
      T.Cursor_Row := 1;
      T.Cursor_Col := 1;
      T.Current_Cursor_Shape := Cursor_Block;
      T.Current_Cursor_Blinking := False;
      T.Saved_Row := 1;
      T.Saved_Col := 1;
      T.Pending_Wrap := False;
      T.Current_Style := (others => <>);
      T.Saved_Style := (others => <>);
      T.Current_Modes := (others => <>);
      T.G0_Charset := ASCII_Charset;
      T.G1_Charset := ASCII_Charset;
      T.Active_Charset := G0;
      T.Charset_Target := G0;
      T.Saved_G0_Charset := ASCII_Charset;
      T.Saved_G1_Charset := ASCII_Charset;
      T.Saved_Active_Charset := G0;
      T.Diag := (others => 0);
      T.Last_Printable := 0;
      T.Has_Last_Printable := False;
      T.Window_Title := (others => <>);
      T.Response_Length := 0;
      T.State := Ground;
      T.CSI_Private := ASCII.NUL;
      T.CSI_Params := (others => 0);
      T.CSI_Set := (others => False);
      T.CSI_Count := 0;
      T.CSI_Intermediates := (others => ASCII.NUL);
      T.CSI_Intermediate_Count := 0;
      T.OSC_Data := (others => ASCII.NUL);
      T.OSC_Count := 0;
      T.Ignored_String_Count := 0;
      T.UTF8_Need := 0;
      T.UTF8_Seen := 0;
      T.UTF8_Accum := 0;
      T.UTF8_Min := 0;
      T.Scrollback_Limit := Scrollback_Limit;
      Allocate_Buffers (T, Rows, Cols, Allocated);
      if not Allocated then
         Status := Allocation_Failed;
         return;
      end if;

      T.Initialized := True;
      Reset_Terminal (T);
      Status := Ok;
   end Initialize;

   procedure Append_OSC_Byte
     (T          : in out Terminal;
      Ch         : Standard.Character;
      Overflowed : in out Boolean)
   is
   begin
      if T.OSC_Count >= Parser.Max_OSC_Length then
         T.Diag.Parser_Overflow := T.Diag.Parser_Overflow + 1;
         Overflowed := True;
         T.State := OSC_Overflow;
      else
         T.OSC_Count := T.OSC_Count + 1;
         T.OSC_Data (T.OSC_Count) := Ch;
      end if;
   end Append_OSC_Byte;

   procedure Finish_OSC (T : in out Terminal) is
      Command : Natural := 0;
      Payload_First : Natural := 0;
      Title_Length : Natural;
   begin
      if T.OSC_Count < 3 then
         T.State := Ground;
         return;
      end if;

      for I in 1 .. T.OSC_Count loop
         if T.OSC_Data (I) = ';' then
            Payload_First := I + 1;
            exit;
         elsif T.OSC_Data (I) in '0' .. '9' then
            Command :=
              Natural'Min
                (Command * 10
                 + Standard.Character'Pos (T.OSC_Data (I))
                 - Standard.Character'Pos ('0'),
                 Natural'Last / 2);
         else
            T.State := Ground;
            return;
         end if;
      end loop;

      if Payload_First = 0 then
         T.State := Ground;
         return;
      end if;

      if Command in 0 .. 2 then
         Title_Length :=
           Natural'Min
             (T.OSC_Count - Payload_First + 1,
              Max_Title_Length);
         T.Window_Title := (others => <>);
         T.Window_Title.Length := Title_Length;
         for I in 1 .. Title_Length loop
            T.Window_Title.Text (I) := T.OSC_Data (Payload_First + I - 1);
         end loop;
      end if;

      T.State := Ground;
   end Finish_OSC;

   procedure Append_Ignored_String_Byte
     (T          : in out Terminal;
      Overflowed : in out Boolean)
   is
   begin
      if T.Ignored_String_Count >= Parser.Max_Escape_Length then
         T.Diag.Parser_Overflow := T.Diag.Parser_Overflow + 1;
         Overflowed := True;
         T.State := Ignored_String_Overflow;
      else
         T.Ignored_String_Count := T.Ignored_String_Count + 1;
      end if;
   end Append_Ignored_String_Byte;

   procedure Start_Ignored_String (T : in out Terminal) is
   begin
      T.Ignored_String_Count := 0;
      T.State := Ignored_String;
   end Start_Ignored_String;

   function In_String_Control (State : Parser_State) return Boolean is
     (State = OSC
      or else State = OSC_Escape
      or else State = OSC_Overflow
      or else State = OSC_Overflow_Escape
      or else State = Ignored_String
      or else State = Ignored_String_Escape
      or else State = Ignored_String_Overflow
      or else State = Ignored_String_Overflow_Escape);

   function Scrollback_Index
     (T   : Terminal;
      Row : Positive;
      Col : Positive) return Positive
   is
     ((Row - 1) * T.Cols + Col);

   procedure Append_Scrollback_Row
     (T      : in out Terminal;
      Cells  : Cell_Array_Access;
      Source : Positive)
   is
   begin
      if T.Scrollback_Limit = 0
        or else T.Scrollback = null
        or else Cells = null
      then
         return;
      end if;

      if T.Scrollback_Rows = T.Scrollback_Limit then
         for R in 1 .. T.Scrollback_Limit - 1 loop
            for C in 1 .. T.Cols loop
               T.Scrollback (Scrollback_Index (T, R, C)) :=
                 T.Scrollback (Scrollback_Index (T, R + 1, C));
            end loop;
         end loop;
      else
         T.Scrollback_Rows := T.Scrollback_Rows + 1;
      end if;

      for C in 1 .. T.Cols loop
         T.Scrollback (Scrollback_Index (T, T.Scrollback_Rows, C)) :=
           Cells (Index (T, Source, C));
      end loop;
   end Append_Scrollback_Row;

   procedure Scroll_Up_Region
     (T      : in out Terminal;
      Top    : Positive;
      Bottom : Positive;
      Count  : Positive := 1)
   is
      Cells : constant Cell_Array_Access := Active_Cells (T);
   begin
      if Cells = null or else Top >= Bottom then
         return;
      end if;

      for N in 1 .. Count loop
         if T.Active = Primary and then Top = 1 and then Bottom = T.Rows then
            Append_Scrollback_Row (T, Cells, Top);
         end if;

         for R in Top .. Bottom - 1 loop
            for C in 1 .. T.Cols loop
               Cells (Index (T, R, C)) := Cells (Index (T, R + 1, C));
            end loop;
            Mark_Dirty (T, R);
         end loop;
         Clear_Row (T, Bottom, 1, T.Cols);
      end loop;
   end Scroll_Up_Region;

   procedure Scroll_Down_Region
     (T      : in out Terminal;
      Top    : Positive;
      Bottom : Positive;
      Count  : Positive := 1)
   is
      Cells : constant Cell_Array_Access := Active_Cells (T);
   begin
      if Cells = null or else Top >= Bottom then
         return;
      end if;

      for N in 1 .. Count loop
         for R in reverse Top + 1 .. Bottom loop
            for C in 1 .. T.Cols loop
               Cells (Index (T, R, C)) := Cells (Index (T, R - 1, C));
            end loop;
            Mark_Dirty (T, R);
         end loop;
         Clear_Row (T, Top, 1, T.Cols);
      end loop;
   end Scroll_Down_Region;

   procedure New_Line (T : in out Terminal) is
      Old_Row : constant Positive := T.Cursor_Row;
   begin
      T.Pending_Wrap := False;
      if T.Cursor_Row = T.Bottom_Margin then
         Scroll_Up_Region (T, T.Top_Margin, T.Bottom_Margin);
      elsif T.Cursor_Row < T.Rows then
         T.Cursor_Row := T.Cursor_Row + 1;
      end if;
      Mark_Cursor_Move (T, Old_Row);
   end New_Line;

   function Is_Wide (CP : Common.Code_Point) return Boolean is
      V : constant Natural := Natural (CP);
   begin
      return
        (V in 16#1100# .. 16#115F#)
        or else (V in 16#2E80# .. 16#A4CF#)
        or else (V in 16#AC00# .. 16#D7A3#)
        or else (V in 16#F900# .. 16#FAFF#)
        or else (V in 16#FE10# .. 16#FE6F#)
        or else (V in 16#FF00# .. 16#FF60#)
        or else (V in 16#FFE0# .. 16#FFE6#);
   end Is_Wide;

   function Is_Combining (CP : Common.Code_Point) return Boolean is
      V : constant Natural := Natural (CP);
   begin
      return V in 16#0300# .. 16#036F#;
   end Is_Combining;

   procedure Clear_Wide_Overlap
     (T        : in out Terminal;
      Row      : Positive;
      Col      : Positive;
      New_Width : Cell_Width)
   is
      Cells : constant Cell_Array_Access := Active_Cells (T);
      Last  : constant Positive :=
        (if New_Width = Width_Two and then Col < T.Cols then Col + 1 else Col);
   begin
      if Cells = null then
         return;
      end if;

      if Cells (Index (T, Row, Col)).Kind = Wide_Continuation and then Col > 1 then
         Cells (Index (T, Row, Col - 1)) := Blank_Cell (T.Current_Style);
      end if;

      for C in Col .. Last loop
         if Cells (Index (T, Row, C)).Kind = Character
           and then Cells (Index (T, Row, C)).Text.Width = Width_Two
           and then C < T.Cols
         then
            Cells (Index (T, Row, C + 1)) := Blank_Cell (T.Current_Style);
         elsif Cells (Index (T, Row, C)).Kind = Wide_Continuation and then C > 1 then
            Cells (Index (T, Row, C - 1)) := Blank_Cell (T.Current_Style);
         end if;
      end loop;
   end Clear_Wide_Overlap;

   procedure Normalize_Wide_Row (T : in out Terminal; Row : Positive) is
      Cells : constant Cell_Array_Access := Active_Cells (T);
   begin
      if Cells = null then
         return;
      end if;

      for C in 1 .. T.Cols loop
         if Cells (Index (T, Row, C)).Kind = Wide_Continuation then
            if C = 1
              or else Cells (Index (T, Row, C - 1)).Kind /= Character
              or else Cells (Index (T, Row, C - 1)).Text.Width /= Width_Two
            then
               Cells (Index (T, Row, C)) := Blank_Cell (T.Current_Style);
            end if;
         elsif Cells (Index (T, Row, C)).Kind = Character
           and then Cells (Index (T, Row, C)).Text.Width = Width_Two
         then
            if C = T.Cols
              or else Cells (Index (T, Row, C + 1)).Kind /= Wide_Continuation
            then
               Cells (Index (T, Row, C)) := Blank_Cell (T.Current_Style);
            end if;
         end if;
      end loop;
   end Normalize_Wide_Row;

   procedure Shift_Row_Right
     (T        : in out Terminal;
      Row      : Positive;
      Col      : Positive;
      Distance : Positive)
   is
      Cells : constant Cell_Array_Access := Active_Cells (T);
      Blank_Last : constant Positive := Positive'Min (T.Cols, Col + Distance - 1);
   begin
      if Cells = null then
         return;
      end if;

      if Col + Distance <= T.Cols then
         for C in reverse Col + Distance .. T.Cols loop
            Cells (Index (T, Row, C)) := Cells (Index (T, Row, C - Distance));
         end loop;
      end if;

      for C in Col .. Blank_Last loop
         Cells (Index (T, Row, C)) := Blank_Cell (T.Current_Style);
      end loop;
      Normalize_Wide_Row (T, Row);
      Mark_Dirty (T, Row);
   end Shift_Row_Right;

   procedure Shift_Row_Left
     (T        : in out Terminal;
      Row      : Positive;
      Col      : Positive;
      Distance : Positive)
   is
      Cells : constant Cell_Array_Access := Active_Cells (T);
      Blank_First : Positive;
   begin
      if Cells = null then
         return;
      end if;

      if Col + Distance <= T.Cols then
         for C in Col .. T.Cols - Distance loop
            Cells (Index (T, Row, C)) := Cells (Index (T, Row, C + Distance));
         end loop;
         Blank_First := T.Cols - Distance + 1;
      else
         Blank_First := Col;
      end if;

      for C in Blank_First .. T.Cols loop
         Cells (Index (T, Row, C)) := Blank_Cell (T.Current_Style);
      end loop;
      Normalize_Wide_Row (T, Row);
      Mark_Dirty (T, Row);
   end Shift_Row_Left;

   procedure Erase_Characters
     (T     : in out Terminal;
      Row   : Positive;
      Col   : Positive;
      Count : Positive)
   is
      Last  : constant Positive := Positive'Min (T.Cols, Col + Count - 1);
   begin
      Clear_Row (T, Row, Col, Last);
   end Erase_Characters;

   procedure Insert_Blank_Lines
     (T     : in out Terminal;
      Row   : Positive;
      Count : Positive)
   is
      Cells  : constant Cell_Array_Access := Active_Cells (T);
      Amount : Natural;
   begin
      if Cells = null or else Row < T.Top_Margin or else Row > T.Bottom_Margin then
         return;
      end if;

      Amount := Natural'Min (Count, T.Bottom_Margin - Row + 1);

      if Amount = 0 then
         return;
      end if;

      if Row + Amount <= T.Bottom_Margin then
         for R in reverse Row + Amount .. T.Bottom_Margin loop
            for C in 1 .. T.Cols loop
               Cells (Index (T, R, C)) := Cells (Index (T, R - Amount, C));
            end loop;
            Mark_Dirty (T, R);
         end loop;
      end if;

      for R in Row .. Positive'Min (T.Bottom_Margin, Row + Amount - 1) loop
         Clear_Row (T, R, 1, T.Cols);
      end loop;
   end Insert_Blank_Lines;

   procedure Delete_Lines
     (T     : in out Terminal;
      Row   : Positive;
      Count : Positive)
   is
      Cells  : constant Cell_Array_Access := Active_Cells (T);
      Amount : Natural;
   begin
      if Cells = null or else Row < T.Top_Margin or else Row > T.Bottom_Margin then
         return;
      end if;

      Amount := Natural'Min (Count, T.Bottom_Margin - Row + 1);

      if Amount = 0 then
         return;
      end if;

      if Row + Amount <= T.Bottom_Margin then
         for R in Row .. T.Bottom_Margin - Amount loop
            for C in 1 .. T.Cols loop
               Cells (Index (T, R, C)) := Cells (Index (T, R + Amount, C));
            end loop;
            Mark_Dirty (T, R);
         end loop;
      end if;

      for R in Positive'Max (Row, T.Bottom_Margin - Amount + 1) .. T.Bottom_Margin loop
         Clear_Row (T, R, 1, T.Cols);
      end loop;
   end Delete_Lines;

   procedure Put_Code_Point (T : in out Terminal; CP : Common.Code_Point) is
      Cells : constant Cell_Array_Access := Active_Cells (T);
      W     : constant Cell_Width :=
        (if Is_Combining (CP) then Width_Zero
         elsif Is_Wide (CP) then Width_Two
         else Width_One);
   begin
      if Cells = null or else W = Width_Zero then
         return;
      end if;

      if T.Pending_Wrap then
         T.Cursor_Col := 1;
         New_Line (T);
      end if;

      if W = Width_Two and then T.Cursor_Col = T.Cols then
         T.Cursor_Col := 1;
         New_Line (T);
      end if;

      if T.Current_Modes.Insert_Mode then
         Shift_Row_Right
           (T,
            T.Cursor_Row,
            T.Cursor_Col,
            (if W = Width_Two then 2 else 1));
      else
         Clear_Wide_Overlap (T, T.Cursor_Row, T.Cursor_Col, W);
      end if;

      Cells (Index (T, T.Cursor_Row, T.Cursor_Col)) :=
        (Kind  => Character,
         Text  => (Code_Point => CP, Width => W),
         Style => T.Current_Style);
      T.Last_Printable := CP;
      T.Has_Last_Printable := True;
      Mark_Dirty (T, T.Cursor_Row);

      if W = Width_Two then
         if T.Cursor_Col < T.Cols then
            Cells (Index (T, T.Cursor_Row, T.Cursor_Col + 1)) :=
              (Kind => Wide_Continuation,
               Text => (Code_Point => 0, Width => Width_Zero),
               Style => T.Current_Style);
         end if;
         if T.Cursor_Col + 1 >= T.Cols then
            T.Cursor_Col := T.Cols;
            T.Pending_Wrap := T.Current_Modes.Autowrap;
         else
            T.Cursor_Col := T.Cursor_Col + 2;
         end if;
      elsif T.Cursor_Col = T.Cols then
         T.Pending_Wrap := T.Current_Modes.Autowrap;
      else
         T.Cursor_Col := T.Cursor_Col + 1;
      end if;
   end Put_Code_Point;

   procedure Clear_CSI (T : in out Terminal) is
   begin
      T.CSI_Private := ASCII.NUL;
      T.CSI_Params := (others => 0);
      T.CSI_Set := (others => False);
      T.CSI_Count := 0;
      T.CSI_Intermediates := (others => ASCII.NUL);
      T.CSI_Intermediate_Count := 0;
   end Clear_CSI;

   function Param
     (T       : Terminal;
      N       : Positive;
      Default : Natural) return Natural
   is
   begin
      if N <= T.CSI_Count and then T.CSI_Set (N) then
         return T.CSI_Params (N);
      else
         return Default;
      end if;
   end Param;

   procedure Append_Response_Byte
     (T : in out Terminal;
      B : Common.Bytes.Byte)
   is
   begin
      if T.Response_Length < Max_Response_Length then
         T.Response_Length := T.Response_Length + 1;
         T.Responses (T.Response_Length) := B;
      else
         T.Diag.Parser_Overflow := T.Diag.Parser_Overflow + 1;
      end if;
   end Append_Response_Byte;

   procedure Append_Response_Char
     (T  : in out Terminal;
      Ch : Standard.Character)
   is
   begin
      Append_Response_Byte (T, Common.Bytes.Byte (Standard.Character'Pos (Ch)));
   end Append_Response_Char;

   procedure Append_Response_String
     (T    : in out Terminal;
      Text : String)
   is
   begin
      for Ch of Text loop
         Append_Response_Char (T, Ch);
      end loop;
   end Append_Response_String;

   procedure Append_Response_Natural
     (T : in out Terminal;
      N : Natural)
   is
      Text : constant String := Natural'Image (N);
   begin
      for I in Text'Range loop
         if Text (I) /= ' ' then
            Append_Response_Char (T, Text (I));
         end if;
      end loop;
   end Append_Response_Natural;

   procedure Queue_Device_Status_Report
     (T    : in out Terminal;
      Kind : Natural)
   is
   begin
      case Kind is
         when 5 =>
            if T.CSI_Private = ASCII.NUL then
               Append_Response_Char (T, ASCII.ESC);
               Append_Response_Char (T, '[');
               Append_Response_Char (T, '0');
               Append_Response_Char (T, 'n');
            else
               T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
            end if;
         when 6 =>
            Append_Response_Char (T, ASCII.ESC);
            Append_Response_Char (T, '[');
            if T.CSI_Private = '?' then
               Append_Response_Char (T, '?');
            elsif T.CSI_Private /= ASCII.NUL then
               T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
               return;
            end if;
            Append_Response_Natural (T, T.Cursor_Row);
            Append_Response_Char (T, ';');
            Append_Response_Natural (T, T.Cursor_Col);
            Append_Response_Char (T, 'R');
         when others =>
            T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
      end case;
   end Queue_Device_Status_Report;

   procedure Queue_Device_Attributes
     (T : in out Terminal)
   is
   begin
      if T.CSI_Private = ASCII.NUL and then Param (T, 1, 0) = 0 then
         Append_Response_String (T, ASCII.ESC & "[?62;4;22c");
      elsif T.CSI_Private = '>' and then Param (T, 1, 0) = 0 then
         Append_Response_String (T, ASCII.ESC & "[>0;1;0c");
      else
         T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
      end if;
   end Queue_Device_Attributes;

   procedure Queue_Window_Operation_Report
     (T      : in out Terminal;
      Number : Natural)
   is
   begin
      if T.CSI_Private = ASCII.NUL
        and then Number = 14
        and then T.Window_Pixel_Width > 0
        and then T.Window_Pixel_Height > 0
      then
         Append_Response_Char (T, ASCII.ESC);
         Append_Response_Char (T, '[');
         Append_Response_Char (T, '4');
         Append_Response_Char (T, ';');
         Append_Response_Natural (T, T.Window_Pixel_Height);
         Append_Response_Char (T, ';');
         Append_Response_Natural (T, T.Window_Pixel_Width);
         Append_Response_Char (T, 't');
      elsif T.CSI_Private = ASCII.NUL
        and then Number = 16
        and then T.Cell_Pixel_Width > 0
        and then T.Cell_Pixel_Height > 0
      then
         Append_Response_Char (T, ASCII.ESC);
         Append_Response_Char (T, '[');
         Append_Response_Char (T, '6');
         Append_Response_Char (T, ';');
         Append_Response_Natural (T, T.Cell_Pixel_Height);
         Append_Response_Char (T, ';');
         Append_Response_Natural (T, T.Cell_Pixel_Width);
         Append_Response_Char (T, 't');
      elsif T.CSI_Private = ASCII.NUL and then Number = 18 then
         Append_Response_Char (T, ASCII.ESC);
         Append_Response_Char (T, '[');
         Append_Response_Char (T, '8');
         Append_Response_Char (T, ';');
         Append_Response_Natural (T, T.Rows);
         Append_Response_Char (T, ';');
         Append_Response_Natural (T, T.Cols);
         Append_Response_Char (T, 't');
      elsif T.CSI_Private = ASCII.NUL and then Number = 21 then
         Append_Response_Char (T, ASCII.ESC);
         Append_Response_Char (T, ']');
         Append_Response_Char (T, 'l');
         for I in 1 .. T.Window_Title.Length loop
            Append_Response_Char (T, T.Window_Title.Text (I));
         end loop;
         Append_Response_Char (T, ASCII.ESC);
         Append_Response_Char (T, '\');
      else
         T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
      end if;
   end Queue_Window_Operation_Report;

   function Mode_Report_State
     (T       : Terminal;
      Prefix  : Standard.Character;
      Number  : Natural)
      return Natural
   is
   begin
      if Prefix = '?' then
         case Number is
            when 1 =>
               return (if T.Current_Modes.Application_Cursor then 1 else 2);
            when 6 =>
               return (if T.Current_Modes.Origin_Mode then 1 else 2);
            when 7 =>
               return (if T.Current_Modes.Autowrap then 1 else 2);
            when 12 =>
               return (if T.Current_Modes.Cursor_Blinking then 1 else 2);
            when 25 =>
               return (if T.Current_Modes.Cursor_Visible then 1 else 2);
            when 47 | 1047 | 1049 =>
               return (if T.Current_Modes.Alternate_Screen then 1 else 2);
            when 1000 =>
               return (if T.Current_Modes.Mouse_Button then 1 else 2);
            when 1002 =>
               return (if T.Current_Modes.Mouse_Drag then 1 else 2);
            when 1003 =>
               return (if T.Current_Modes.Mouse_Any_Event then 1 else 2);
            when 1004 =>
               return (if T.Current_Modes.Focus_Reporting then 1 else 2);
            when 1006 =>
               return (if T.Current_Modes.Mouse_SGR then 1 else 2);
            when 2004 =>
               return (if T.Current_Modes.Bracketed_Paste then 1 else 2);
            when 2026 =>
               return (if T.Current_Modes.Synchronized_Update then 1 else 2);
            when others =>
               return 0;
         end case;
      elsif Prefix = ASCII.NUL and then Number = 4 then
         return (if T.Current_Modes.Insert_Mode then 1 else 2);
      else
         return 0;
      end if;
   end Mode_Report_State;

   procedure Queue_Mode_Report (T : in out Terminal) is
      Number : constant Natural := Param (T, 1, 0);
      State  : constant Natural :=
        Mode_Report_State (T, T.CSI_Private, Number);
   begin
      Append_Response_Char (T, ASCII.ESC);
      Append_Response_Char (T, '[');
      if T.CSI_Private /= ASCII.NUL then
         Append_Response_Char (T, T.CSI_Private);
      end if;
      Append_Response_Natural (T, Number);
      Append_Response_Char (T, ';');
      Append_Response_Natural (T, State);
      Append_Response_Char (T, '$');
      Append_Response_Char (T, 'y');
   end Queue_Mode_Report;

   procedure Move_Cursor
     (T   : in out Terminal;
      Row : Natural;
      Col : Natural)
   is
      Requested_Row : constant Positive := Positive'Max (1, Row);
      Requested_Col : constant Positive := Positive'Max (1, Col);
      Old_Row       : constant Positive := T.Cursor_Row;
   begin
      if T.Current_Modes.Origin_Mode then
         T.Cursor_Row :=
           Positive'Min
             (T.Bottom_Margin,
              T.Top_Margin + Positive'Min (Requested_Row, T.Bottom_Margin - T.Top_Margin + 1) - 1);
      else
         T.Cursor_Row := Positive'Min (T.Rows, Requested_Row);
      end if;
      T.Cursor_Col := Positive'Min (T.Cols, Requested_Col);
      T.Pending_Wrap := False;
      Mark_Cursor_Move (T, Old_Row);
   end Move_Cursor;

   function Next_Tab_Column (T : Terminal; Col : Positive) return Positive is
   begin
      if T.Tab_Stops /= null and then Col < T.Cols then
         for C in Col + 1 .. T.Cols loop
            if T.Tab_Stops (C) then
               return C;
            end if;
         end loop;
      end if;

      return T.Cols;
   end Next_Tab_Column;

   function Previous_Tab_Column (T : Terminal; Col : Positive) return Positive is
   begin
      if Col <= 1 then
         return 1;
      end if;

      if T.Tab_Stops /= null then
         for C in reverse 1 .. Col - 1 loop
            if T.Tab_Stops (C) then
               return C;
            end if;
         end loop;
      end if;

      return 1;
   end Previous_Tab_Column;

   procedure Move_Forward_Tabs (T : in out Terminal; Count : Positive) is
      Old_Row : constant Positive := T.Cursor_Row;
   begin
      for I in 1 .. Count loop
         T.Cursor_Col := Next_Tab_Column (T, T.Cursor_Col);
         exit when T.Cursor_Col = T.Cols;
      end loop;
      T.Pending_Wrap := False;
      Mark_Cursor_Move (T, Old_Row);
   end Move_Forward_Tabs;

   procedure Move_Backward_Tabs (T : in out Terminal; Count : Positive) is
      Old_Row : constant Positive := T.Cursor_Row;
   begin
      for I in 1 .. Count loop
         T.Cursor_Col := Previous_Tab_Column (T, T.Cursor_Col);
         exit when T.Cursor_Col = 1;
      end loop;
      T.Pending_Wrap := False;
      Mark_Cursor_Move (T, Old_Row);
   end Move_Backward_Tabs;

   procedure Repeat_Last_Printable
     (T     : in out Terminal;
      Count : Positive)
   is
   begin
      if not T.Has_Last_Printable then
         return;
      end if;

      for I in 1 .. Count loop
         Put_Code_Point (T, T.Last_Printable);
      end loop;
   end Repeat_Last_Printable;

   procedure Set_Mode (T : in out Terminal; Number : Natural; Enable : Boolean) is
   begin
      case Number is
         when 1 =>
            T.Current_Modes.Application_Cursor := Enable;
         when 6 =>
            T.Current_Modes.Origin_Mode := Enable;
            Move_Cursor (T, 1, 1);
         when 7 =>
            T.Current_Modes.Autowrap := Enable;
         when 12 =>
            T.Current_Modes.Cursor_Blinking := Enable;
            T.Current_Cursor_Blinking := Enable;
            Mark_Dirty (T, T.Cursor_Row);
         when 25 =>
            if T.Current_Modes.Cursor_Visible /= Enable then
               Mark_Dirty (T, T.Cursor_Row);
               T.Current_Modes.Cursor_Visible := Enable;
            end if;
         when 1000 =>
            T.Current_Modes.Mouse_Button := Enable;
            if Enable then
               T.Current_Modes.Mouse_Drag := False;
               T.Current_Modes.Mouse_Any_Event := False;
            end if;
         when 1002 =>
            T.Current_Modes.Mouse_Drag := Enable;
            if Enable then
               T.Current_Modes.Mouse_Button := False;
               T.Current_Modes.Mouse_Any_Event := False;
            end if;
         when 1003 =>
            T.Current_Modes.Mouse_Any_Event := Enable;
            if Enable then
               T.Current_Modes.Mouse_Button := False;
               T.Current_Modes.Mouse_Drag := False;
            end if;
         when 1004 =>
            T.Current_Modes.Focus_Reporting := Enable;
         when 1006 =>
            T.Current_Modes.Mouse_SGR := Enable;
         when 47 | 1047 =>
            T.Current_Modes.Alternate_Screen := Enable;
            T.Active := (if Enable then Alternate else Primary);
            T.Cursor_Row := 1;
            T.Cursor_Col := 1;
            T.Pending_Wrap := False;
            if Enable then
               Reset_Buffer (T, T.Alt_Cells);
            else
               Mark_All_Dirty (T);
            end if;
         when 1048 =>
            if Enable then
               Save_Cursor_State (T);
            else
               Restore_Cursor_State (T);
            end if;
            T.Pending_Wrap := False;
         when 1049 =>
            if Enable then
               Save_Cursor_State (T);
            end if;
            T.Current_Modes.Alternate_Screen := Enable;
            T.Active := (if Enable then Alternate else Primary);
            if Enable then
               T.Cursor_Row := 1;
               T.Cursor_Col := 1;
            else
               Restore_Cursor_State (T);
            end if;
            T.Pending_Wrap := False;
            if Enable then
               Reset_Buffer (T, T.Alt_Cells);
            else
               Mark_All_Dirty (T);
            end if;
         when 2004 =>
            T.Current_Modes.Bracketed_Paste := Enable;
         when 2026 =>
            T.Current_Modes.Synchronized_Update := Enable;
         when others =>
            T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
      end case;
   end Set_Mode;

   procedure Apply_SGR (T : in out Terminal) is
      I : Natural := 1;
      P : Natural;
   begin
      if T.CSI_Count = 0 then
         T.Current_Style := (others => <>);
         return;
      end if;

      while I <= T.CSI_Count loop
         P := Param (T, I, 0);
         case P is
            when 0 =>
               T.Current_Style := (others => <>);
            when 1 =>
               T.Current_Style.Bold := True;
            when 2 =>
               T.Current_Style.Faint := True;
            when 3 =>
               T.Current_Style.Italic := True;
            when 4 =>
               T.Current_Style.Underline := True;
            when 5 | 6 =>
               T.Current_Style.Blink := True;
            when 7 =>
               T.Current_Style.Inverse := True;
            when 8 =>
               T.Current_Style.Conceal := True;
            when 9 =>
               T.Current_Style.Strikethrough := True;
            when 21 =>
               T.Current_Style.Bold := False;
            when 22 =>
               T.Current_Style.Bold := False;
               T.Current_Style.Faint := False;
            when 23 =>
               T.Current_Style.Italic := False;
            when 24 =>
               T.Current_Style.Underline := False;
            when 25 =>
               T.Current_Style.Blink := False;
            when 27 =>
               T.Current_Style.Inverse := False;
            when 28 =>
               T.Current_Style.Conceal := False;
            when 29 =>
               T.Current_Style.Strikethrough := False;
            when 53 =>
               T.Current_Style.Overline := True;
            when 55 =>
               T.Current_Style.Overline := False;
            when 30 .. 37 =>
               T.Current_Style.Foreground := (Kind => Indexed, Index => P - 30, R => 0, G => 0, B => 0);
            when 40 .. 47 =>
               T.Current_Style.Background := (Kind => Indexed, Index => P - 40, R => 0, G => 0, B => 0);
            when 90 .. 97 =>
               T.Current_Style.Foreground := (Kind => Indexed, Index => P - 90 + 8, R => 0, G => 0, B => 0);
            when 100 .. 107 =>
               T.Current_Style.Background := (Kind => Indexed, Index => P - 100 + 8, R => 0, G => 0, B => 0);
            when 39 =>
               T.Current_Style.Foreground := (others => <>);
            when 49 =>
               T.Current_Style.Background := (others => <>);
            when 38 | 48 =>
               if I + 2 <= T.CSI_Count and then Param (T, I + 1, 0) = 5 then
                  declare
                     N : constant Natural := Param (T, I + 2, 0);
                     C : constant Color := (Kind => Indexed, Index => Natural'Min (N, 255), R => 0, G => 0, B => 0);
                  begin
                     if P = 38 then
                        T.Current_Style.Foreground := C;
                     else
                        T.Current_Style.Background := C;
                     end if;
                  end;
                  I := I + 2;
               elsif I + 4 <= T.CSI_Count and then Param (T, I + 1, 0) = 2 then
                  declare
                     C : constant Color :=
                       (Kind  => RGB,
                        Index => 0,
                        R     => Natural'Min (Param (T, I + 2, 0), 255),
                        G     => Natural'Min (Param (T, I + 3, 0), 255),
                        B     => Natural'Min (Param (T, I + 4, 0), 255));
                  begin
                     if P = 38 then
                        T.Current_Style.Foreground := C;
                     else
                        T.Current_Style.Background := C;
                     end if;
                  end;
                  I := I + 4;
               else
                  T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
               end if;
            when others =>
               T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
         end case;
         I := I + 1;
      end loop;
   end Apply_SGR;

   procedure Soft_Reset (T : in out Terminal) is
      Old_Row : constant Positive := T.Cursor_Row;
      Keep_Alternate : constant Boolean := T.Current_Modes.Alternate_Screen;
   begin
      T.Current_Style := (others => <>);
      T.Saved_Style := (others => <>);
      T.Current_Modes :=
        (Application_Cursor => False,
         Bracketed_Paste    => False,
         Mouse_Button       => False,
         Mouse_Drag         => False,
         Mouse_Any_Event    => False,
         Mouse_SGR          => False,
         Focus_Reporting    => False,
         Synchronized_Update => False,
         Alternate_Screen   => Keep_Alternate,
         Origin_Mode        => False,
         Autowrap           => True,
         Cursor_Visible     => True,
         Cursor_Blinking    => False,
         Insert_Mode        => False);
      T.Cursor_Row := 1;
      T.Cursor_Col := 1;
      T.Current_Cursor_Shape := Cursor_Block;
      T.Current_Cursor_Blinking := False;
      T.Saved_Row := 1;
      T.Saved_Col := 1;
      T.G0_Charset := ASCII_Charset;
      T.G1_Charset := ASCII_Charset;
      T.Active_Charset := G0;
      T.Charset_Target := G0;
      T.Saved_G0_Charset := ASCII_Charset;
      T.Saved_G1_Charset := ASCII_Charset;
      T.Saved_Active_Charset := G0;
      T.Pending_Wrap := False;
      T.Top_Margin := 1;
      T.Bottom_Margin := T.Rows;
      T.Last_Printable := 0;
      T.Has_Last_Printable := False;
      Mark_Cursor_Move (T, Old_Row);
   end Soft_Reset;

   procedure Execute_CSI (T : in out Terminal; Final : Standard.Character) is
      N : Natural;
      R : Natural;
      C : Natural;

      function Min_Row return Positive is
      begin
         return (if T.Current_Modes.Origin_Mode then T.Top_Margin else 1);
      end Min_Row;

      function Max_Row return Positive is
      begin
         return (if T.Current_Modes.Origin_Mode then T.Bottom_Margin else T.Rows);
      end Max_Row;
   begin
      if T.CSI_Intermediate_Count > 0 then
         if T.CSI_Intermediate_Count = 1 then
            if T.CSI_Intermediates (1) = '!'
              and then T.CSI_Private = ASCII.NUL
              and then Final = 'p'
            then
               Soft_Reset (T);
            elsif T.CSI_Intermediates (1) = ' '
              and then T.CSI_Private = ASCII.NUL
              and then Final = 'q'
            then
               case Param (T, 1, 1) is
                  when 0 | 1 =>
                     T.Current_Cursor_Shape := Cursor_Block;
                     T.Current_Cursor_Blinking := True;
                     T.Current_Modes.Cursor_Blinking := True;
                     Mark_Dirty (T, T.Cursor_Row);
                  when 2 =>
                     T.Current_Cursor_Shape := Cursor_Block;
                     T.Current_Cursor_Blinking := False;
                     T.Current_Modes.Cursor_Blinking := False;
                     Mark_Dirty (T, T.Cursor_Row);
                  when 3 =>
                     T.Current_Cursor_Shape := Cursor_Underline;
                     T.Current_Cursor_Blinking := True;
                     T.Current_Modes.Cursor_Blinking := True;
                     Mark_Dirty (T, T.Cursor_Row);
                  when 4 =>
                     T.Current_Cursor_Shape := Cursor_Underline;
                     T.Current_Cursor_Blinking := False;
                     T.Current_Modes.Cursor_Blinking := False;
                     Mark_Dirty (T, T.Cursor_Row);
                  when 5 =>
                     T.Current_Cursor_Shape := Cursor_Bar;
                     T.Current_Cursor_Blinking := True;
                     T.Current_Modes.Cursor_Blinking := True;
                     Mark_Dirty (T, T.Cursor_Row);
                  when 6 =>
                     T.Current_Cursor_Shape := Cursor_Bar;
                     T.Current_Cursor_Blinking := False;
                     T.Current_Modes.Cursor_Blinking := False;
                     Mark_Dirty (T, T.Cursor_Row);
                  when others =>
                     T.Diag.Unsupported_Sequence :=
                       T.Diag.Unsupported_Sequence + 1;
               end case;
            elsif T.CSI_Intermediates (1) = '$'
              and then Final = 'p'
            then
               Queue_Mode_Report (T);
            else
               T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
            end if;
         else
            T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
         end if;
         return;
      end if;

      case Final is
         when '@' =>
            Shift_Row_Right
              (T,
               T.Cursor_Row,
               T.Cursor_Col,
               Positive'Min (T.Cols - T.Cursor_Col + 1, Positive'Max (1, Param (T, 1, 1))));
         when 'A' =>
            declare
               Old_Row : constant Positive := T.Cursor_Row;
            begin
               N := Param (T, 1, 1);
               T.Cursor_Row :=
                 Positive'Max
                   (Min_Row, T.Cursor_Row - Natural'Max (N, 1));
               Mark_Cursor_Move (T, Old_Row);
            end;
         when 'B' =>
            declare
               Old_Row : constant Positive := T.Cursor_Row;
            begin
               N := Param (T, 1, 1);
               T.Cursor_Row :=
                 Positive'Min
                   (Max_Row, T.Cursor_Row + Natural'Max (N, 1));
               Mark_Cursor_Move (T, Old_Row);
            end;
         when 'C' =>
            N := Param (T, 1, 1);
            T.Cursor_Col := Positive'Min (T.Cols, T.Cursor_Col + Natural'Max (N, 1));
            Mark_Cursor_Move (T, T.Cursor_Row);
         when 'D' =>
            N := Param (T, 1, 1);
            T.Cursor_Col := Positive'Max (1, T.Cursor_Col - Natural'Max (N, 1));
            Mark_Cursor_Move (T, T.Cursor_Row);
         when 'E' =>
            declare
               Old_Row : constant Positive := T.Cursor_Row;
            begin
               N := Param (T, 1, 1);
               T.Cursor_Row :=
                 Positive'Min
                   (Max_Row, T.Cursor_Row + Natural'Max (N, 1));
               T.Cursor_Col := 1;
               Mark_Cursor_Move (T, Old_Row);
            end;
         when 'F' =>
            declare
               Old_Row : constant Positive := T.Cursor_Row;
            begin
               N := Param (T, 1, 1);
               T.Cursor_Row :=
                 Positive'Max
                   (Min_Row, T.Cursor_Row - Natural'Max (N, 1));
               T.Cursor_Col := 1;
               Mark_Cursor_Move (T, Old_Row);
            end;
         when 'G' =>
            C := Param (T, 1, 1);
            T.Cursor_Col := Positive'Min (T.Cols, Positive'Max (1, C));
            Mark_Cursor_Move (T, T.Cursor_Row);
         when 'H' | 'f' =>
            R := Param (T, 1, 1);
            C := Param (T, 2, 1);
            Move_Cursor (T, R, C);
         when 'I' =>
            Move_Forward_Tabs (T, Positive'Max (1, Param (T, 1, 1)));
         when 'J' =>
            N := Param (T, 1, 0);
            case N is
               when 0 =>
                  Clear_Row (T, T.Cursor_Row, T.Cursor_Col, T.Cols);
                  for Row in T.Cursor_Row + 1 .. T.Rows loop
                     Clear_Row (T, Row, 1, T.Cols);
                  end loop;
               when 1 =>
                  for Row in 1 .. T.Cursor_Row - 1 loop
                     Clear_Row (T, Row, 1, T.Cols);
                  end loop;
                  Clear_Row (T, T.Cursor_Row, 1, T.Cursor_Col);
               when 2 =>
                  for Row in 1 .. T.Rows loop
                     Clear_Row (T, Row, 1, T.Cols);
                  end loop;
               when 3 =>
                  for Row in 1 .. T.Rows loop
                     Clear_Row (T, Row, 1, T.Cols);
                  end loop;
                  T.Scrollback_Rows := 0;
               when others =>
                  T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
            end case;
         when 'K' =>
            N := Param (T, 1, 0);
            case N is
               when 0 => Clear_Row (T, T.Cursor_Row, T.Cursor_Col, T.Cols);
               when 1 => Clear_Row (T, T.Cursor_Row, 1, T.Cursor_Col);
               when 2 => Clear_Row (T, T.Cursor_Row, 1, T.Cols);
               when others => T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
            end case;
         when 'g' =>
            N := Param (T, 1, 0);
            case N is
               when 0 =>
                  if T.Tab_Stops /= null then
                     T.Tab_Stops (T.Cursor_Col) := False;
                  end if;
               when 3 =>
                  if T.Tab_Stops /= null then
                     for C in T.Tab_Stops'Range loop
                        T.Tab_Stops (C) := False;
                     end loop;
                  end if;
               when others =>
                  T.Diag.Unsupported_Sequence :=
                    T.Diag.Unsupported_Sequence + 1;
            end case;
         when 'L' =>
            Insert_Blank_Lines
              (T,
               T.Cursor_Row,
               Positive'Max (1, Param (T, 1, 1)));
         when 'M' =>
            Delete_Lines
              (T,
               T.Cursor_Row,
               Positive'Max (1, Param (T, 1, 1)));
         when 'P' =>
            Shift_Row_Left
              (T,
               T.Cursor_Row,
               T.Cursor_Col,
               Positive'Min (T.Cols - T.Cursor_Col + 1, Positive'Max (1, Param (T, 1, 1))));
         when 'S' =>
            Scroll_Up_Region (T, T.Top_Margin, T.Bottom_Margin, Positive'Max (1, Param (T, 1, 1)));
         when 'T' =>
            Scroll_Down_Region (T, T.Top_Margin, T.Bottom_Margin, Positive'Max (1, Param (T, 1, 1)));
         when 'X' =>
            Erase_Characters
              (T,
               T.Cursor_Row,
               T.Cursor_Col,
               Positive'Min (T.Cols - T.Cursor_Col + 1, Positive'Max (1, Param (T, 1, 1))));
         when 'Z' =>
            Move_Backward_Tabs (T, Positive'Max (1, Param (T, 1, 1)));
         when '`' =>
            C := Param (T, 1, 1);
            T.Cursor_Col := Positive'Min (T.Cols, Positive'Max (1, C));
            Mark_Cursor_Move (T, T.Cursor_Row);
         when 'a' =>
            N := Param (T, 1, 1);
            T.Cursor_Col := Positive'Min (T.Cols, T.Cursor_Col + Natural'Max (N, 1));
            Mark_Cursor_Move (T, T.Cursor_Row);
         when 'b' =>
            Repeat_Last_Printable (T, Positive'Max (1, Param (T, 1, 1)));
         when 'c' =>
            Queue_Device_Attributes (T);
         when 'd' =>
            R := Param (T, 1, 1);
            if T.Current_Modes.Origin_Mode then
               Move_Cursor (T, R, T.Cursor_Col);
            else
               declare
                  Old_Row : constant Positive := T.Cursor_Row;
               begin
                  T.Cursor_Row := Positive'Min (T.Rows, Positive'Max (1, R));
                  Mark_Cursor_Move (T, Old_Row);
               end;
            end if;
         when 'e' =>
            declare
               Old_Row : constant Positive := T.Cursor_Row;
            begin
               N := Param (T, 1, 1);
               T.Cursor_Row :=
                 Positive'Min
                   (Max_Row, T.Cursor_Row + Natural'Max (N, 1));
               Mark_Cursor_Move (T, Old_Row);
            end;
         when 'm' =>
            Apply_SGR (T);
         when 'n' =>
            Queue_Device_Status_Report (T, Param (T, 1, 0));
         when 's' =>
            Save_Cursor_State (T);
         when 't' =>
            Queue_Window_Operation_Report (T, Param (T, 1, 0));
         when 'u' =>
            Restore_Cursor_State (T);
         when 'h' | 'l' =>
            if T.CSI_Private = '?' then
               for I in 1 .. Natural'Max (T.CSI_Count, 1) loop
                  Set_Mode (T, Param (T, I, 0), Final = 'h');
               end loop;
            elsif Param (T, 1, 0) = 4 then
               T.Current_Modes.Insert_Mode := Final = 'h';
            else
               T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
            end if;
         when 'r' =>
            R := Param (T, 1, 1);
            C := Param (T, 2, T.Rows);
            if R >= 1 and then C >= R and then C <= T.Rows then
               T.Top_Margin := R;
               T.Bottom_Margin := C;
               Move_Cursor (T, 1, 1);
            else
               T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
            end if;
         when others =>
            T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
      end case;
      T.Pending_Wrap := False;
   end Execute_CSI;

   procedure Execute_C0 (T : in out Terminal; B : Common.Bytes.Byte) is
   begin
      case Natural (B) is
         when 7 =>
            null;
         when 8 =>
            if T.Cursor_Col > 1 then
               T.Cursor_Col := T.Cursor_Col - 1;
               Mark_Cursor_Move (T, T.Cursor_Row);
            end if;
            T.Pending_Wrap := False;
         when 9 =>
            Move_Forward_Tabs (T, 1);
         when 10 =>
            New_Line (T);
         when 13 =>
            T.Cursor_Col := 1;
            Mark_Cursor_Move (T, T.Cursor_Row);
            T.Pending_Wrap := False;
         when 14 =>
            T.Active_Charset := G1;
            T.Pending_Wrap := False;
         when 15 =>
            T.Active_Charset := G0;
            T.Pending_Wrap := False;
         when 27 =>
            T.State := Escape;
         when others =>
            null;
      end case;
   end Execute_C0;

   procedure Emit_UTF8_Replacement (T : in out Terminal) is
   begin
      T.Diag.Malformed_UTF8 := T.Diag.Malformed_UTF8 + 1;
      Put_Code_Point (T, 16#FFFD#);
      T.UTF8_Need := 0;
      T.UTF8_Seen := 0;
      T.UTF8_Accum := 0;
      T.UTF8_Min := 0;
   end Emit_UTF8_Replacement;

   procedure Recover_Incomplete_UTF8 (T : in out Terminal) is
   begin
      if T.State = Ground and then T.UTF8_Need > 0 then
         Emit_UTF8_Replacement (T);
      end if;
   end Recover_Incomplete_UTF8;

   procedure Decode_Printable (T : in out Terminal; B : Common.Bytes.Byte) is
      V : constant Natural := Natural (B);

      function Active_GL_Charset return Charset_Kind is
      begin
         return
           (if T.Active_Charset = G0 then T.G0_Charset else T.G1_Charset);
      end Active_GL_Charset;

      function Map_DEC_Special_Graphics
        (CP : Common.Code_Point) return Common.Code_Point
      is
         V : constant Natural := Natural (CP);
      begin
         case V is
            when 16#60# => return 16#25C6#;
            when 16#61# => return 16#2592#;
            when 16#62# => return 16#2409#;
            when 16#63# => return 16#240C#;
            when 16#64# => return 16#240D#;
            when 16#65# => return 16#240A#;
            when 16#66# => return 16#00B0#;
            when 16#67# => return 16#00B1#;
            when 16#68# => return 16#2424#;
            when 16#69# => return 16#240B#;
            when 16#6A# => return 16#2518#;
            when 16#6B# => return 16#2510#;
            when 16#6C# => return 16#250C#;
            when 16#6D# => return 16#2514#;
            when 16#6E# => return 16#253C#;
            when 16#6F# => return 16#23BA#;
            when 16#70# => return 16#23BB#;
            when 16#71# => return 16#2500#;
            when 16#72# => return 16#23BC#;
            when 16#73# => return 16#23BD#;
            when 16#74# => return 16#251C#;
            when 16#75# => return 16#2524#;
            when 16#76# => return 16#2534#;
            when 16#77# => return 16#252C#;
            when 16#78# => return 16#2502#;
            when 16#79# => return 16#2264#;
            when 16#7A# => return 16#2265#;
            when 16#7B# => return 16#03C0#;
            when 16#7C# => return 16#2260#;
            when 16#7D# => return 16#00A3#;
            when 16#7E# => return 16#00B7#;
            when others => return CP;
         end case;
      end Map_DEC_Special_Graphics;

      procedure Put_Mapped_ASCII is
         CP : Common.Code_Point := Common.Code_Point (V);
      begin
         if Active_GL_Charset = DEC_Special_Graphics then
            CP := Map_DEC_Special_Graphics (CP);
         end if;
         Put_Code_Point (T, CP);
      end Put_Mapped_ASCII;
   begin
      if T.UTF8_Need = 0 then
         if V < 16#80# then
            Put_Mapped_ASCII;
         elsif V in 16#C2# .. 16#DF# then
            T.UTF8_Need := 1;
            T.UTF8_Seen := 0;
            T.UTF8_Accum := Common.Code_Point (V mod 32);
            T.UTF8_Min := 16#80#;
         elsif V in 16#E0# .. 16#EF# then
            T.UTF8_Need := 2;
            T.UTF8_Seen := 0;
            T.UTF8_Accum := Common.Code_Point (V mod 16);
            T.UTF8_Min := 16#800#;
         elsif V in 16#F0# .. 16#F4# then
            T.UTF8_Need := 3;
            T.UTF8_Seen := 0;
            T.UTF8_Accum := Common.Code_Point (V mod 8);
            T.UTF8_Min := 16#10000#;
         else
            Emit_UTF8_Replacement (T);
         end if;
      elsif V in 16#80# .. 16#BF# then
         T.UTF8_Accum := Common.Code_Point (Natural (T.UTF8_Accum) * 64 + (V mod 64));
         T.UTF8_Seen := T.UTF8_Seen + 1;
         if T.UTF8_Seen = T.UTF8_Need then
            if Natural (T.UTF8_Accum) < T.UTF8_Min
              or else Natural (T.UTF8_Accum) in 16#D800# .. 16#DFFF#
              or else Natural (T.UTF8_Accum) > 16#10FFFF#
            then
               Emit_UTF8_Replacement (T);
            else
               Put_Code_Point (T, T.UTF8_Accum);
               T.UTF8_Need := 0;
               T.UTF8_Seen := 0;
               T.UTF8_Accum := 0;
               T.UTF8_Min := 0;
            end if;
         end if;
      else
         Emit_UTF8_Replacement (T);
         Decode_Printable (T, B);
      end if;
   end Decode_Printable;

   procedure Feed
     (T      : in out Terminal;
      Data   : Core_Byte_Array;
      Status : out Feed_Status)
   is
      Ch : Standard.Character;
      Overflowed : Boolean := False;
      Recovered  : Boolean := False;
   begin
      if not T.Initialized then
         Status := Invalid_State;
         return;
      end if;

      for B of Data loop
         if Natural (B) = 16#9C# then
            if T.State = OSC or else T.State = OSC_Escape then
               Finish_OSC (T);
               goto Continue;
            elsif T.State = OSC_Overflow
              or else T.State = OSC_Overflow_Escape
            then
               T.State := Ground;
               goto Continue;
            elsif T.State = Ignored_String
              or else T.State = Ignored_String_Escape
              or else T.State = Ignored_String_Overflow
              or else T.State = Ignored_String_Overflow_Escape
            then
               T.State := Ground;
               goto Continue;
            end if;
         elsif not In_String_Control (T.State) then
            if Natural (B) = 16#9B# then
               Recover_Incomplete_UTF8 (T);
               Clear_CSI (T);
               T.State := CSI;
               goto Continue;
            elsif Natural (B) = 16#90# then
               Recover_Incomplete_UTF8 (T);
               Start_Ignored_String (T);
               goto Continue;
            elsif Natural (B) = 16#98# then
               Recover_Incomplete_UTF8 (T);
               Start_Ignored_String (T);
               goto Continue;
            elsif Natural (B) = 16#9E# then
               Recover_Incomplete_UTF8 (T);
               Start_Ignored_String (T);
               goto Continue;
            elsif Natural (B) = 16#9F# then
               Recover_Incomplete_UTF8 (T);
               Start_Ignored_String (T);
               goto Continue;
            elsif Natural (B) = 16#84# then
               Recover_Incomplete_UTF8 (T);
               Index_Control (T);
               goto Continue;
            elsif Natural (B) = 16#85# then
               Recover_Incomplete_UTF8 (T);
               Next_Line_Control (T);
               goto Continue;
            elsif Natural (B) = 16#88# then
               Recover_Incomplete_UTF8 (T);
               Horizontal_Tab_Set (T);
               goto Continue;
            elsif Natural (B) = 16#8C# then
               Recover_Incomplete_UTF8 (T);
               Reset_Terminal (T);
               goto Continue;
            elsif Natural (B) = 16#8D# then
               Recover_Incomplete_UTF8 (T);
               Reverse_Index_Control (T);
               goto Continue;
            elsif Natural (B) = 16#9D# then
               Recover_Incomplete_UTF8 (T);
               T.OSC_Count := 0;
               T.State := OSC;
               goto Continue;
            end if;
         end if;

         if Natural (B) < 32 then
            if T.State = OSC and then Natural (B) = 27 then
               T.State := OSC_Escape;
               goto Continue;
            elsif T.State = OSC_Overflow and then Natural (B) = 27 then
               T.State := OSC_Overflow_Escape;
               goto Continue;
            elsif T.State = Ignored_String and then Natural (B) = 27 then
               T.State := Ignored_String_Escape;
               goto Continue;
            elsif T.State = Ignored_String_Overflow and then Natural (B) = 27 then
               T.State := Ignored_String_Overflow_Escape;
               goto Continue;
            elsif T.State = OSC and then Natural (B) = 7 then
               Finish_OSC (T);
               goto Continue;
            elsif T.State = OSC_Overflow and then Natural (B) = 7 then
               T.State := Ground;
               goto Continue;
            elsif T.State = Ignored_String and then Natural (B) = 7 then
               T.State := Ground;
               goto Continue;
            elsif T.State = Ignored_String_Overflow and then Natural (B) = 7 then
               T.State := Ground;
               goto Continue;
            elsif not In_String_Control (T.State) then
               Recover_Incomplete_UTF8 (T);
               Execute_C0 (T, B);
               goto Continue;
            end if;
         end if;

         Ch := Standard.Character'Val (Natural (B));
         case T.State is
            when Ground =>
               Decode_Printable (T, B);
            when Escape =>
               case Ch is
                  when 'c' =>
                     Reset_Terminal (T);
                     T.State := Ground;
                  when '7' =>
                     Save_Cursor_State (T);
                     T.State := Ground;
                  when '8' =>
                     Restore_Cursor_State (T);
                     T.State := Ground;
                  when 'D' =>
                     Index_Control (T);
                     T.State := Ground;
                  when 'E' =>
                     Next_Line_Control (T);
                     T.State := Ground;
                  when 'H' =>
                     Horizontal_Tab_Set (T);
                     T.State := Ground;
                  when 'M' =>
                     Reverse_Index_Control (T);
                     T.State := Ground;
                  when '[' =>
                     Clear_CSI (T);
                     T.State := CSI;
                  when ']' =>
                     T.OSC_Count := 0;
                     T.State := OSC;
                  when 'P' =>
                     Start_Ignored_String (T);
                  when 'X' =>
                     Start_Ignored_String (T);
                  when '^' | '_' =>
                     Start_Ignored_String (T);
                  when '(' | '*' | '-' =>
                     T.Charset_Target := G0;
                     T.State := Charset;
                  when ')' | '+' | '.' | '/' =>
                     T.Charset_Target := G1;
                     T.State := Charset;
                  when '%' =>
                     T.State := Coding_System;
                  when '#' =>
                     T.State := Screen_Alignment;
                  when '=' | '>' =>
                     T.State := Ground;
                  when others =>
                     T.Diag.Ignored_Escape := T.Diag.Ignored_Escape + 1;
                     Recovered := True;
                     T.State := Ground;
               end case;
            when CSI =>
               if (Ch = '?' or else Ch = '>')
                 and then T.CSI_Count = 0
                 and then T.CSI_Private = ASCII.NUL
               then
                  T.CSI_Private := Ch;
               elsif Ch in '0' .. '9' then
                  if T.CSI_Count = 0 then
                     T.CSI_Count := 1;
                  end if;
                  T.CSI_Set (T.CSI_Count) := True;
                  T.CSI_Params (T.CSI_Count) :=
                    Natural'Min (T.CSI_Params (T.CSI_Count) * 10 + Standard.Character'Pos (Ch) - Standard.Character'Pos ('0'), Natural'Last / 2);
               elsif Ch = ';' or else Ch = ':' then
                  if T.CSI_Count < Parser.Max_CSI_Params then
                     T.CSI_Count := T.CSI_Count + 1;
                  else
                     T.Diag.Parser_Overflow := T.Diag.Parser_Overflow + 1;
                     Overflowed := True;
                  end if;
               elsif Ch in ' ' .. '/' then
                  if T.CSI_Intermediate_Count < Parser.Max_CSI_Intermediate then
                     T.CSI_Intermediate_Count := T.CSI_Intermediate_Count + 1;
                     T.CSI_Intermediates (T.CSI_Intermediate_Count) := Ch;
                  else
                     T.Diag.Parser_Overflow := T.Diag.Parser_Overflow + 1;
                     Overflowed := True;
                  end if;
               elsif Ch in '@' .. '~' then
                  Execute_CSI (T, Ch);
                  Clear_CSI (T);
                  T.State := Ground;
               else
                  T.Diag.Ignored_Escape := T.Diag.Ignored_Escape + 1;
                  Recovered := True;
                  Clear_CSI (T);
                  T.State := Ground;
               end if;
            when OSC =>
               Append_OSC_Byte (T, Ch, Overflowed);
            when OSC_Escape =>
               if Ch = '\' then
                  Finish_OSC (T);
               else
                  Append_OSC_Byte (T, ASCII.ESC, Overflowed);
                  if T.State = OSC_Overflow then
                     goto Continue;
                  end if;
                  Append_OSC_Byte (T, Ch, Overflowed);
                  if T.State /= OSC_Overflow then
                     T.State := OSC;
                  end if;
               end if;
            when OSC_Overflow =>
               null;
            when OSC_Overflow_Escape =>
               if Ch = '\' then
                  T.State := Ground;
               else
                  T.State := OSC_Overflow;
               end if;
            when Ignored_String =>
               Append_Ignored_String_Byte (T, Overflowed);
            when Ignored_String_Escape =>
               if Ch = '\' then
                  T.State := Ground;
               else
                  Append_Ignored_String_Byte (T, Overflowed);
                  if T.State /= Ignored_String_Overflow then
                     Append_Ignored_String_Byte (T, Overflowed);
                     if T.State /= Ignored_String_Overflow then
                        T.State := Ignored_String;
                     end if;
                  end if;
               end if;
            when Ignored_String_Overflow =>
               null;
            when Ignored_String_Overflow_Escape =>
               if Ch = '\' then
                  T.State := Ground;
               else
                  T.State := Ignored_String_Overflow;
               end if;
            when Charset =>
               declare
                  New_Charset : constant Charset_Kind :=
                    (if Ch = '0' then DEC_Special_Graphics else ASCII_Charset);
               begin
                  if T.Charset_Target = G0 then
                     T.G0_Charset := New_Charset;
                  else
                     T.G1_Charset := New_Charset;
                  end if;
               end;
               T.State := Ground;
            when Coding_System =>
               if Ch /= 'G' and then Ch /= '@' then
                  T.Diag.Ignored_Escape := T.Diag.Ignored_Escape + 1;
                  Recovered := True;
               end if;
               T.State := Ground;
            when Screen_Alignment =>
               if Ch = '8' then
                  Screen_Alignment_Test (T);
               else
                  T.Diag.Ignored_Escape := T.Diag.Ignored_Escape + 1;
                  Recovered := True;
               end if;
               T.State := Ground;
         end case;

         <<Continue>>
         null;
      end loop;

      if Overflowed then
         Status := Parser_Overflow;
      elsif Recovered then
         Status := Parser_Recovered;
      else
         Status := Ok;
      end if;
   end Feed;

   procedure Resize
     (T      : in out Terminal;
      Rows   : Positive;
      Cols   : Positive;
      Status : out Resize_Status)
   is
      Old_Primary : Cell_Array_Access := T.Primary_Cells;
      Old_Alt     : Cell_Array_Access := T.Alt_Cells;
      Old_Tabs    : Tab_Stop_Array_Access := T.Tab_Stops;
      Old_Rows    : constant Positive := T.Rows;
      Old_Cols    : constant Positive := T.Cols;
      New_Count   : constant Positive := Rows * Cols;
   begin
      if not T.Initialized then
         Status := Allocation_Failed;
         return;
      end if;

      T.Primary_Cells := new Cell_Array (1 .. New_Count);
      T.Alt_Cells := new Cell_Array (1 .. New_Count);
      if T.Scrollback /= null then
         Free_Cells (T.Scrollback);
      end if;
      if T.Scrollback_Limit > 0 then
         T.Scrollback := new Cell_Array (1 .. T.Scrollback_Limit * Cols);
      else
         T.Scrollback := null;
      end if;
      if T.Dirty /= null then
         Free_Dirty (T.Dirty);
      end if;
      T.Dirty := new Dirty_Row_Array (1 .. Rows);
      T.Tab_Stops := new Tab_Stop_Array (1 .. Cols);

      T.Rows := Rows;
      T.Cols := Cols;
      T.Scrollback_Rows := 0;
      Reset_Tab_Stops (T);
      Reset_Buffer (T, T.Primary_Cells);
      Reset_Buffer (T, T.Alt_Cells);

      for R in 1 .. Positive'Min (Old_Rows, Rows) loop
         for C in 1 .. Positive'Min (Old_Cols, Cols) loop
            T.Primary_Cells (Index (T, R, C)) := Old_Primary ((R - 1) * Old_Cols + C);
            T.Alt_Cells (Index (T, R, C)) := Old_Alt ((R - 1) * Old_Cols + C);
         end loop;
      end loop;
      if Old_Tabs /= null then
         for C in 1 .. Positive'Min (Old_Cols, Cols) loop
            T.Tab_Stops (C) := Old_Tabs (C);
         end loop;
      end if;

      if Old_Primary /= null then
         Free_Cells (Old_Primary);
      end if;
      if Old_Alt /= null then
         Free_Cells (Old_Alt);
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
   exception
      when Storage_Error =>
         T.Primary_Cells := Old_Primary;
         T.Alt_Cells := Old_Alt;
         T.Tab_Stops := Old_Tabs;
         T.Rows := Old_Rows;
         T.Cols := Old_Cols;
         T.Scrollback_Rows := 0;
         Status := Allocation_Failed;
   end Resize;

   function Snapshot (T : Terminal) return Render_Snapshot is
      Count : constant Natural := T.Rows * T.Cols;
      S     : Render_Snapshot;
      Src   : constant Cell_Array_Access := Active_Cells (T);
   begin
      S.Rows := T.Rows;
      S.Cols := T.Cols;
      S.Cells := new Cell_Array (1 .. Count);
      S.Dirty := new Dirty_Row_Array (1 .. T.Rows);
      for I in 1 .. Count loop
         S.Cells (I) := Src (I);
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
      return S;
   end Snapshot;

   procedure Release (S : in out Render_Snapshot) is
   begin
      if S.Cells /= null then
         Free_Cells (S.Cells);
         S.Cells := null;
      end if;
      if S.Dirty /= null then
         Free_Dirty (S.Dirty);
         S.Dirty := null;
      end if;
      S.Rows := 0;
      S.Cols := 0;
      S.Cursor := (others => <>);
   end Release;

   procedure Set_Cell_Pixel_Size
     (T      : in out Terminal;
      Width  : Positive;
      Height : Positive)
   is
   begin
      T.Cell_Pixel_Width := Width;
      T.Cell_Pixel_Height := Height;
   end Set_Cell_Pixel_Size;

   procedure Set_Window_Pixel_Size
     (T      : in out Terminal;
      Width  : Natural;
      Height : Natural)
   is
   begin
      T.Window_Pixel_Width := Width;
      T.Window_Pixel_Height := Height;
   end Set_Window_Pixel_Size;

   function Modes (T : Terminal) return Mode_Snapshot is
   begin
      return T.Current_Modes;
   end Modes;

   function Diagnostics (T : Terminal) return Diagnostic_Snapshot is
   begin
      return T.Diag;
   end Diagnostics;

   function Title (T : Terminal) return Title_Text is
   begin
      return T.Window_Title;
   end Title;

   function Scrollback_Row_Count (T : Terminal) return Natural is
   begin
      return T.Scrollback_Rows;
   end Scrollback_Row_Count;

   function Pending_Response_Length (T : Terminal) return Natural is
   begin
      return T.Response_Length;
   end Pending_Response_Length;

   procedure Read_Response
     (T      : in out Terminal;
      Buffer : out Common.Bytes.Byte_Array;
      Last   : out Natural)
   is
      Count : constant Natural :=
        Natural'Min (Buffer'Length, T.Response_Length);
   begin
      Last := Count;
      if Count > 0 then
         for I in 1 .. Count loop
            Buffer (Buffer'First + I - 1) := T.Responses (I);
         end loop;

         if Count < T.Response_Length then
            for I in 1 .. T.Response_Length - Count loop
               T.Responses (I) := T.Responses (I + Count);
            end loop;
         end if;
         T.Response_Length := T.Response_Length - Count;
      end if;
   end Read_Response;

   procedure Clear_Damage (T : in out Terminal) is
   begin
      if T.Dirty /= null then
         for R in T.Dirty'Range loop
            T.Dirty (R) := False;
         end loop;
      end if;
   end Clear_Damage;

   function Cell_At
     (S   : Render_Snapshot;
      Row : Positive;
      Col : Positive) return Cell
   is
   begin
      if S.Cells = null or else Row > S.Rows or else Col > S.Cols then
         return (others => <>);
      end if;
      return S.Cells ((Row - 1) * S.Cols + Col);
   end Cell_At;

   function Scrollback_Cell_At
     (T   : Terminal;
      Row : Positive;
      Col : Positive) return Cell
   is
   begin
      if T.Scrollback = null
        or else Row > T.Scrollback_Rows
        or else Col > T.Cols
      then
         return (others => <>);
      end if;

      return T.Scrollback (Scrollback_Index (T, Row, Col));
   end Scrollback_Cell_At;
end Terminal.Core;

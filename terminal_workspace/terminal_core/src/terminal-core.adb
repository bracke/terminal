with Ada.Unchecked_Deallocation;
with Terminal.Core.Parser;

package body Terminal.Core is
   use Common;
   use Common.Bytes;

   procedure Free_Cells is new Ada.Unchecked_Deallocation
     (Cell_Array, Cell_Array_Access);
   procedure Free_Dirty is new Ada.Unchecked_Deallocation
     (Dirty_Row_Array, Dirty_Row_Array_Access);

   function Index (T : Terminal; Row : Positive; Col : Positive) return Positive is
     ((Row - 1) * T.Cols + Col);

   function Active_Cells (T : Terminal) return Cell_Array_Access is
     (if T.Active = Primary then T.Primary_Cells else T.Alt_Cells);

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
   begin
      if Cells = null then
         return;
      end if;

      for C in First .. Last loop
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

   procedure Reset_Terminal (T : in out Terminal) is
   begin
      T.Active := Primary;
      T.Current_Modes := (others => <>);
      T.Cursor_Row := 1;
      T.Cursor_Col := 1;
      T.Saved_Row := 1;
      T.Saved_Col := 1;
      T.Pending_Wrap := False;
      T.Top_Margin := 1;
      T.Bottom_Margin := T.Rows;
      T.Current_Style := (others => <>);
      T.State := Ground;
      T.CSI_Count := 0;
      T.OSC_Count := 0;
      T.UTF8_Need := 0;
      T.UTF8_Seen := 0;
      T.UTF8_Accum := 0;
      T.UTF8_Min := 0;
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
      end if;
      if T.Alt_Cells /= null then
         Free_Cells (T.Alt_Cells);
      end if;
      if T.Scrollback /= null then
         Free_Cells (T.Scrollback);
      end if;
      if T.Dirty /= null then
         Free_Dirty (T.Dirty);
      end if;

      T.Primary_Cells := new Cell_Array (1 .. Count);
      T.Alt_Cells := new Cell_Array (1 .. Count);
      if T.Scrollback_Limit > 0 then
         T.Scrollback := new Cell_Array (1 .. T.Scrollback_Limit * Cols);
      else
         T.Scrollback := null;
      end if;
      T.Dirty := new Dirty_Row_Array (1 .. Rows);
      T.Rows := Rows;
      T.Cols := Cols;
      T.Bottom_Margin := Rows;
      T.Scrollback_Rows := 0;
      Status := True;
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
      T.Saved_Row := 1;
      T.Saved_Col := 1;
      T.Pending_Wrap := False;
      T.Current_Style := (others => <>);
      T.Current_Modes := (others => <>);
      T.Diag := (others => 0);
      T.State := Ground;
      T.CSI_Private := ASCII.NUL;
      T.CSI_Params := (others => 0);
      T.CSI_Set := (others => False);
      T.CSI_Count := 0;
      T.OSC_Count := 0;
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
   begin
      T.Pending_Wrap := False;
      if T.Cursor_Row = T.Bottom_Margin then
         Scroll_Up_Region (T, T.Top_Margin, T.Bottom_Margin);
      elsif T.Cursor_Row < T.Rows then
         T.Cursor_Row := T.Cursor_Row + 1;
      end if;
      Mark_Dirty (T, T.Cursor_Row);
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

      Cells (Index (T, T.Cursor_Row, T.Cursor_Col)) :=
        (Kind  => Character,
         Text  => (Code_Point => CP, Width => W),
         Style => T.Current_Style);
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

   procedure Set_Mode (T : in out Terminal; Number : Natural; Enable : Boolean) is
   begin
      case Number is
         when 1 =>
            T.Current_Modes.Application_Cursor := Enable;
         when 6 =>
            T.Current_Modes.Origin_Mode := Enable;
         when 7 =>
            T.Current_Modes.Autowrap := Enable;
         when 25 =>
            T.Current_Modes.Cursor_Visible := Enable;
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
               T.Saved_Row := T.Cursor_Row;
               T.Saved_Col := T.Cursor_Col;
            else
               T.Cursor_Row := Positive'Min (T.Rows, T.Saved_Row);
               T.Cursor_Col := Positive'Min (T.Cols, T.Saved_Col);
            end if;
            T.Pending_Wrap := False;
         when 1049 =>
            if Enable then
               T.Saved_Row := T.Cursor_Row;
               T.Saved_Col := T.Cursor_Col;
            end if;
            T.Current_Modes.Alternate_Screen := Enable;
            T.Active := (if Enable then Alternate else Primary);
            if Enable then
               T.Cursor_Row := 1;
               T.Cursor_Col := 1;
            else
               T.Cursor_Row := Positive'Min (T.Rows, T.Saved_Row);
               T.Cursor_Col := Positive'Min (T.Cols, T.Saved_Col);
            end if;
            T.Pending_Wrap := False;
            if Enable then
               Reset_Buffer (T, T.Alt_Cells);
            else
               Mark_All_Dirty (T);
            end if;
         when 2004 =>
            T.Current_Modes.Bracketed_Paste := Enable;
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
            when 3 =>
               T.Current_Style.Italic := True;
            when 4 =>
               T.Current_Style.Underline := True;
            when 7 =>
               T.Current_Style.Inverse := True;
            when 22 =>
               T.Current_Style.Bold := False;
            when 23 =>
               T.Current_Style.Italic := False;
            when 24 =>
               T.Current_Style.Underline := False;
            when 27 =>
               T.Current_Style.Inverse := False;
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

   procedure Execute_CSI (T : in out Terminal; Final : Standard.Character) is
      N : Natural;
      R : Natural;
      C : Natural;
   begin
      case Final is
         when 'A' =>
            N := Param (T, 1, 1);
            T.Cursor_Row := Positive'Max (1, T.Cursor_Row - Natural'Max (N, 1));
         when 'B' =>
            N := Param (T, 1, 1);
            T.Cursor_Row := Positive'Min (T.Rows, T.Cursor_Row + Natural'Max (N, 1));
         when 'C' =>
            N := Param (T, 1, 1);
            T.Cursor_Col := Positive'Min (T.Cols, T.Cursor_Col + Natural'Max (N, 1));
         when 'D' =>
            N := Param (T, 1, 1);
            T.Cursor_Col := Positive'Max (1, T.Cursor_Col - Natural'Max (N, 1));
         when 'E' =>
            N := Param (T, 1, 1);
            T.Cursor_Row := Positive'Min (T.Rows, T.Cursor_Row + Natural'Max (N, 1));
            T.Cursor_Col := 1;
         when 'F' =>
            N := Param (T, 1, 1);
            T.Cursor_Row := Positive'Max (1, T.Cursor_Row - Natural'Max (N, 1));
            T.Cursor_Col := 1;
         when 'G' =>
            C := Param (T, 1, 1);
            T.Cursor_Col := Positive'Min (T.Cols, Positive'Max (1, C));
         when 'H' | 'f' =>
            R := Param (T, 1, 1);
            C := Param (T, 2, 1);
            T.Cursor_Row := Positive'Min (T.Rows, Positive'Max (1, R));
            T.Cursor_Col := Positive'Min (T.Cols, Positive'Max (1, C));
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
               when 2 | 3 =>
                  for Row in 1 .. T.Rows loop
                     Clear_Row (T, Row, 1, T.Cols);
                  end loop;
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
         when 'S' =>
            Scroll_Up_Region (T, T.Top_Margin, T.Bottom_Margin, Positive'Max (1, Param (T, 1, 1)));
         when 'T' =>
            Scroll_Down_Region (T, T.Top_Margin, T.Bottom_Margin, Positive'Max (1, Param (T, 1, 1)));
         when 'm' =>
            Apply_SGR (T);
         when 's' =>
            T.Saved_Row := T.Cursor_Row;
            T.Saved_Col := T.Cursor_Col;
         when 'u' =>
            T.Cursor_Row := Positive'Min (T.Rows, T.Saved_Row);
            T.Cursor_Col := Positive'Min (T.Cols, T.Saved_Col);
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
               T.Cursor_Row := 1;
               T.Cursor_Col := 1;
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
            end if;
            T.Pending_Wrap := False;
         when 9 =>
            T.Cursor_Col := Positive'Min (T.Cols, ((T.Cursor_Col - 1) / 8 + 1) * 8 + 1);
            T.Pending_Wrap := False;
         when 10 =>
            New_Line (T);
         when 13 =>
            T.Cursor_Col := 1;
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

   procedure Decode_Printable (T : in out Terminal; B : Common.Bytes.Byte) is
      V : constant Natural := Natural (B);
   begin
      if T.UTF8_Need = 0 then
         if V < 16#80# then
            Put_Code_Point (T, Common.Code_Point (V));
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
         if Natural (B) < 32 then
            if T.State = OSC and then Natural (B) = 27 then
               T.State := OSC_Escape;
               goto Continue;
            elsif T.State = OSC_Overflow and then Natural (B) = 27 then
               T.State := OSC_Overflow_Escape;
               goto Continue;
            elsif T.State = OSC and then Natural (B) = 7 then
               T.State := Ground;
               goto Continue;
            elsif T.State = OSC_Overflow and then Natural (B) = 7 then
               T.State := Ground;
               goto Continue;
            elsif T.State /= OSC and then T.State /= OSC_Overflow then
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
                     T.Saved_Row := T.Cursor_Row;
                     T.Saved_Col := T.Cursor_Col;
                     T.State := Ground;
                  when '8' =>
                     T.Cursor_Row := Positive'Min (T.Rows, T.Saved_Row);
                     T.Cursor_Col := Positive'Min (T.Cols, T.Saved_Col);
                     T.State := Ground;
                  when 'D' =>
                     New_Line (T);
                     T.State := Ground;
                  when 'E' =>
                     T.Cursor_Col := 1;
                     New_Line (T);
                     T.State := Ground;
                  when 'M' =>
                     if T.Cursor_Row = T.Top_Margin then
                        Scroll_Down_Region (T, T.Top_Margin, T.Bottom_Margin);
                     elsif T.Cursor_Row > 1 then
                        T.Cursor_Row := T.Cursor_Row - 1;
                     end if;
                     T.State := Ground;
                  when '[' =>
                     Clear_CSI (T);
                     T.State := CSI;
                  when ']' =>
                     T.OSC_Count := 0;
                     T.State := OSC;
                  when '(' =>
                     T.State := Charset;
                  when others =>
                     T.Diag.Ignored_Escape := T.Diag.Ignored_Escape + 1;
                     Recovered := True;
                     T.State := Ground;
               end case;
            when CSI =>
               if Ch = '?' and then T.CSI_Count = 0 then
                  T.CSI_Private := '?';
               elsif Ch in '0' .. '9' then
                  if T.CSI_Count = 0 then
                     T.CSI_Count := 1;
                  end if;
                  T.CSI_Set (T.CSI_Count) := True;
                  T.CSI_Params (T.CSI_Count) :=
                    Natural'Min (T.CSI_Params (T.CSI_Count) * 10 + Standard.Character'Pos (Ch) - Standard.Character'Pos ('0'), Natural'Last / 2);
               elsif Ch = ';' then
                  if T.CSI_Count < Parser.Max_CSI_Params then
                     T.CSI_Count := T.CSI_Count + 1;
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
               if T.OSC_Count >= Parser.Max_OSC_Length then
                  T.Diag.Parser_Overflow := T.Diag.Parser_Overflow + 1;
                  Overflowed := True;
                  T.State := OSC_Overflow;
               else
                  T.OSC_Count := T.OSC_Count + 1;
               end if;
            when OSC_Escape =>
               if Ch = '\' then
                  T.State := Ground;
               elsif T.OSC_Count >= Parser.Max_OSC_Length then
                  T.Diag.Parser_Overflow := T.Diag.Parser_Overflow + 1;
                  Overflowed := True;
                  T.State := OSC_Overflow;
               else
                  T.OSC_Count := T.OSC_Count + 1;
                  T.State := OSC;
               end if;
            when OSC_Overflow =>
               null;
            when OSC_Overflow_Escape =>
               if Ch = '\' then
                  T.State := Ground;
               else
                  T.State := OSC_Overflow;
               end if;
            when Charset =>
               T.Diag.Ignored_Escape := T.Diag.Ignored_Escape + 1;
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

      T.Rows := Rows;
      T.Cols := Cols;
      T.Scrollback_Rows := 0;
      Reset_Buffer (T, T.Primary_Cells);
      Reset_Buffer (T, T.Alt_Cells);

      for R in 1 .. Positive'Min (Old_Rows, Rows) loop
         for C in 1 .. Positive'Min (Old_Cols, Cols) loop
            T.Primary_Cells (Index (T, R, C)) := Old_Primary ((R - 1) * Old_Cols + C);
            T.Alt_Cells (Index (T, R, C)) := Old_Alt ((R - 1) * Old_Cols + C);
         end loop;
      end loop;

      if Old_Primary /= null then
         Free_Cells (Old_Primary);
      end if;
      if Old_Alt /= null then
         Free_Cells (Old_Alt);
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
      S.Cursor := (Row => T.Cursor_Row, Col => T.Cursor_Col, Visible => T.Current_Modes.Cursor_Visible);
      return S;
   end Snapshot;

   procedure Release (S : in out Render_Snapshot) is
   begin
      if S.Cells /= null then
         Free_Cells (S.Cells);
      end if;
      if S.Dirty /= null then
         Free_Dirty (S.Dirty);
      end if;
      S.Rows := 0;
      S.Cols := 0;
      S.Cursor := (others => <>);
   end Release;

   function Modes (T : Terminal) return Mode_Snapshot is
   begin
      return T.Current_Modes;
   end Modes;

   function Diagnostics (T : Terminal) return Diagnostic_Snapshot is
   begin
      return T.Diag;
   end Diagnostics;

   function Scrollback_Row_Count (T : Terminal) return Natural is
   begin
      return T.Scrollback_Rows;
   end Scrollback_Row_Count;

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

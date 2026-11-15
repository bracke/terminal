separate (Terminal.Core.Parser_Execution)
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
   if Final = 'u' and then T.Parser.CSI_Private /= ASCII.NUL and then T.Parser.CSI_Intermediate_Count = 0 then
      Apply_Keyboard_Protocol (T);
      return;
   elsif Final = 'q' and then T.Parser.CSI_Private = '>' and then T.Parser.CSI_Intermediate_Count = 0 then
      Queue_Version_Report (T);
      return;
   end if;

   if T.Parser.CSI_Private = '<' or else T.Parser.CSI_Private = '=' then
      Increment_Saturating (T.Diag.Unsupported_Sequence);
      return;
   end if;

   if T.Parser.CSI_Intermediate_Count > 0 then
      if T.Parser.CSI_Intermediate_Count = 1 then
         if T.Parser.CSI_Intermediates (1) = '!'
           and then T.Parser.CSI_Private = ASCII.NUL
           and then T.Parser.CSI_Count = 0
           and then Final = 'p'
         then
            Soft_Reset (T);
         elsif T.Parser.CSI_Intermediates (1) = ' '
           and then T.Parser.CSI_Private = ASCII.NUL
           and then T.Parser.CSI_Count <= 1
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
                  Increment_Saturating (T.Diag.Unsupported_Sequence);
            end case;
         elsif T.Parser.CSI_Intermediates (1) = '$'
           and then Final = 'p'
         then
            Queue_Mode_Report (T);
         else
            Increment_Saturating (T.Diag.Unsupported_Sequence);
         end if;
      else
         Increment_Saturating (T.Diag.Unsupported_Sequence);
      end if;
      return;
   end if;

   if T.Parser.CSI_Private /= ASCII.NUL
     and then Final not in 'c' | 'h' | 'i' | 'l' | 'n' | 't'
   then
      Increment_Saturating (T.Diag.Unsupported_Sequence);
      return;
   end if;

   case Final is
      when '@' =>
         Shift_Right
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
               if T.Active = Alternate then
                  T.Graphics.Alternate_Generation :=
                    T.Graphics.Alternate_Generation + 1;
                  if T.Graphics.Alternate_Generation = 0 then
                     T.Graphics.Alternate_Generation := 1;
                  end if;
               else
                  T.Graphics.Primary_Generation :=
                    T.Graphics.Primary_Generation + 1;
                  if T.Graphics.Primary_Generation = 0 then
                     T.Graphics.Primary_Generation := 1;
                  end if;
               end if;
            when 3 =>
               for Row in 1 .. T.Rows loop
                  Clear_Row (T, Row, 1, T.Cols);
               end loop;
               Scrollback_Storage.Clear
                 (T.Scrollback_State, T.Current_Style);
               if T.Active = Alternate then
                  T.Graphics.Alternate_Generation :=
                    T.Graphics.Alternate_Generation + 1;
                  if T.Graphics.Alternate_Generation = 0 then
                     T.Graphics.Alternate_Generation := 1;
                  end if;
               else
                  T.Graphics.Primary_Generation :=
                    T.Graphics.Primary_Generation + 1;
                  if T.Graphics.Primary_Generation = 0 then
                     T.Graphics.Primary_Generation := 1;
                  end if;
               end if;
            when others =>
               Increment_Saturating (T.Diag.Unsupported_Sequence);
         end case;
      when 'K' =>
         N := Param (T, 1, 0);
         case N is
            when 0 => Clear_Row (T, T.Cursor_Row, T.Cursor_Col, T.Cols);
            when 1 => Clear_Row (T, T.Cursor_Row, 1, T.Cursor_Col);
            when 2 => Clear_Row (T, T.Cursor_Row, 1, T.Cols);
            when others => Increment_Saturating (T.Diag.Unsupported_Sequence);
         end case;
      when 'g' =>
         for I in 1 .. Natural'Max (T.Parser.CSI_Count, 1) loop
            N := Param (T, I, 0);
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
                  Increment_Saturating (T.Diag.Unsupported_Sequence);
            end case;
         end loop;
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
         Shift_Left
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
      when 'i' =>
         if T.Parser.CSI_Private = ASCII.NUL then
            for I in 1 .. Natural'Max (T.Parser.CSI_Count, 1) loop
               case Param (T, I, 0) is
                  when 0 | 4 | 5 =>
                     null;
                  when others =>
                     Increment_Saturating (T.Diag.Unsupported_Sequence);
               end case;
            end loop;
         elsif T.Parser.CSI_Private = '?' then
            for I in 1 .. Natural'Max (T.Parser.CSI_Count, 1) loop
               case Param (T, I, 0) is
                  when 1 | 4 | 5 | 10 | 11 =>
                     null;
                  when others =>
                     Increment_Saturating (T.Diag.Unsupported_Sequence);
               end case;
            end loop;
         else
            Increment_Saturating (T.Diag.Unsupported_Sequence);
         end if;
      when 'm' =>
         Apply_SGR (T);
      when 'n' =>
         Queue_Device_Status_Report (T, Param (T, 1, 0));
      when 's' =>
         if T.Parser.CSI_Private = ASCII.NUL and then T.Parser.CSI_Count = 0 then
            Save_Cursor_State (T);
         else
            Increment_Saturating (T.Diag.Unsupported_Sequence);
         end if;
      when 't' =>
         Queue_Window_Operation_Report (T, Param (T, 1, 0));
      when 'u' =>
         if T.Parser.CSI_Private = ASCII.NUL and then T.Parser.CSI_Count = 0 then
            Restore_Cursor_State (T);
         else
            Increment_Saturating (T.Diag.Unsupported_Sequence);
         end if;
      when 'h' | 'l' =>
         if T.Parser.CSI_Private = '?' then
            for I in 1 .. Natural'Max (T.Parser.CSI_Count, 1) loop
               Set_Mode (T, Param (T, I, 0), Final = 'h');
            end loop;
         elsif T.Parser.CSI_Private = ASCII.NUL then
            for I in 1 .. Natural'Max (T.Parser.CSI_Count, 1) loop
               case Param (T, I, 0) is
                  when 2 =>
                     T.Current_Modes.Keyboard_Locked := Final = 'h';
                  when 4 =>
                     T.Current_Modes.Insert_Mode := Final = 'h';
                  when 20 =>
                     T.Current_Modes.Linefeed_New_Line := Final = 'h';
                  when others =>
                     Increment_Saturating (T.Diag.Unsupported_Sequence);
               end case;
            end loop;
         else
            Increment_Saturating (T.Diag.Unsupported_Sequence);
         end if;
      when 'r' =>
         R := Param (T, 1, 1);
         C := Param (T, 2, T.Rows);
         if R >= 1 and then C > R and then C <= T.Rows then
            T.Top_Margin := R;
            T.Bottom_Margin := C;
            Move_Cursor (T, 1, 1);
         else
            Increment_Saturating (T.Diag.Unsupported_Sequence);
         end if;
      when others =>
         Increment_Saturating (T.Diag.Unsupported_Sequence);
   end case;
   T.Pending_Wrap := False;
end Execute_CSI;

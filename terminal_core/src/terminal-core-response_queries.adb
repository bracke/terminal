with Terminal.Common.Counters;
with Terminal.Core.Parser_Primitives;
with Terminal.Core.Response_Facade;

package body Terminal.Core.Response_Queries is
   package Primitives renames Parser_Primitives;
   package Responses renames Response_Facade;

   function Mode_Report_State
     (T       : Terminal;
      Prefix  : Standard.Character;
      Number  : Natural) return Natural is
   begin
      if Prefix = '?' then
         case Number is
            when 1 => return (if T.Current_Modes.Application_Cursor then 1 else 2);
            when 6 => return (if T.Current_Modes.Origin_Mode then 1 else 2);
            when 7 => return (if T.Current_Modes.Autowrap then 1 else 2);
            when 12 => return (if T.Current_Modes.Cursor_Blinking then 1 else 2);
            when 25 => return (if T.Current_Modes.Cursor_Visible then 1 else 2);
            when 66 => return (if T.Current_Modes.Application_Keypad then 1 else 2);
            when 67 =>
               return (if T.Current_Modes.Backarrow_Key_Backspace then 1 else 2);
            when 47 | 1047 | 1049 =>
               return (if T.Current_Modes.Alternate_Screen then 1 else 2);
            when 1048 => return 2;
            when 1000 => return (if T.Current_Modes.Mouse_Button then 1 else 2);
            when 1002 => return (if T.Current_Modes.Mouse_Drag then 1 else 2);
            when 1003 => return (if T.Current_Modes.Mouse_Any_Event then 1 else 2);
            when 1004 => return (if T.Current_Modes.Focus_Reporting then 1 else 2);
            when 1005 => return (if T.Current_Modes.Mouse_UTF8 then 1 else 2);
            when 1006 => return (if T.Current_Modes.Mouse_SGR then 1 else 2);
            when 1015 => return (if T.Current_Modes.Mouse_URXVT then 1 else 2);
            when 2004 => return (if T.Current_Modes.Bracketed_Paste then 1 else 2);
            when 2026 =>
               return (if T.Current_Modes.Synchronized_Update then 1 else 2);
            when 2048 => return (if T.Current_Modes.In_Band_Resize then 1 else 2);
            when others => return 0;
         end case;
      elsif Prefix = ASCII.NUL and then Number = 2 then
         return (if T.Current_Modes.Keyboard_Locked then 1 else 2);
      elsif Prefix = ASCII.NUL and then Number = 4 then
         return (if T.Current_Modes.Insert_Mode then 1 else 2);
      elsif Prefix = ASCII.NUL and then Number = 20 then
         return (if T.Current_Modes.Linefeed_New_Line then 1 else 2);
      else
         return 0;
      end if;
   end Mode_Report_State;

   procedure Queue_Device_Status_Report
     (T : in out Terminal; Kind : Natural)
   is
      Valid_Report : constant Boolean := T.Parser.CSI_Count <= 1;
      procedure Unsupported is
      begin
         Common.Counters.Increment_Saturating
           (T.Diag.Unsupported_Sequence);
      end Unsupported;
      procedure Append_Private_DSR (Text : String) is
      begin
         Responses.Append_String (T, ASCII.ESC & "[?" & Text & "n");
      end Append_Private_DSR;
   begin
      Responses.Begin_Transaction (T);
      case Kind is
         when 5 =>
            if not Valid_Report then
               Unsupported;
            elsif T.Parser.CSI_Private = ASCII.NUL then
               Responses.Append_String (T, ASCII.ESC & "[0n");
            elsif T.Parser.CSI_Private = '?' then
               Responses.Append_String (T, ASCII.ESC & "[?0n");
            else
               Unsupported;
            end if;
         when 6 =>
            if not Valid_Report
              or else T.Parser.CSI_Private not in ASCII.NUL | '?'
            then
               Unsupported;
            else
               Responses.Append_String (T, ASCII.ESC & "[");
               if T.Parser.CSI_Private = '?' then
                  Responses.Append_Character (T, '?');
               end if;
               Responses.Append_Natural (T, T.Cursor_Row);
               Responses.Append_Character (T, ';');
               Responses.Append_Natural (T, T.Cursor_Col);
               Responses.Append_Character (T, 'R');
            end if;
         when 15 =>
            if T.Parser.CSI_Private = '?' and then Valid_Report then
               Append_Private_DSR ("11");
            else
               Unsupported;
            end if;
         when 25 =>
            if T.Parser.CSI_Private = '?' and then Valid_Report then
               Append_Private_DSR ("20");
            else
               Unsupported;
            end if;
         when 26 =>
            if T.Parser.CSI_Private = '?' and then Valid_Report then
               Append_Private_DSR ("27;1;0;0");
            else
               Unsupported;
            end if;
         when 53 | 55 =>
            if T.Parser.CSI_Private = '?' and then Valid_Report then
               Append_Private_DSR ("50");
            else
               Unsupported;
            end if;
         when 56 =>
            if T.Parser.CSI_Private = '?' and then Valid_Report then
               Append_Private_DSR ("57;0");
            else
               Unsupported;
            end if;
         when others =>
            Unsupported;
      end case;
      Responses.End_Transaction (T);
   end Queue_Device_Status_Report;

   procedure Queue_Mode_Report (T : in out Terminal) is
      Number : constant Natural := Primitives.Param (T, 1, 0);
      State : constant Natural :=
        Mode_Report_State (T, T.Parser.CSI_Private, Number);
   begin
      if T.Parser.CSI_Count /= 1
        or else not T.Parser.CSI_Set (1)
        or else T.Parser.CSI_Private not in ASCII.NUL | '?'
      then
         Common.Counters.Increment_Saturating
           (T.Diag.Unsupported_Sequence);
         return;
      end if;
      Responses.Begin_Transaction (T);
      Responses.Append_String (T, ASCII.ESC & "[");
      if T.Parser.CSI_Private /= ASCII.NUL then
         Responses.Append_Character (T, T.Parser.CSI_Private);
      end if;
      Responses.Append_Natural (T, Number);
      Responses.Append_Character (T, ';');
      Responses.Append_Natural (T, State);
      Responses.Append_String (T, "$y");
      Responses.End_Transaction (T);
   end Queue_Mode_Report;

   procedure Queue_Window_Operation_Report
     (T : in out Terminal; Number : Natural)
   is
      Target : constant Natural := Primitives.Param (T, 2, 0);
      function Valid_Report return Boolean is
        (T.Parser.CSI_Private = ASCII.NUL and then T.Parser.CSI_Count <= 1);
      function Valid_Title_Stack_Target return Boolean is
        (T.Parser.CSI_Private = ASCII.NUL
         and then T.Parser.CSI_Count <= 2 and then Target in 0 .. 2);
      procedure Append_Dimensions
        (Report : Standard.Character; Height, Width : Natural) is
      begin
         Responses.Append_String (T, ASCII.ESC & "[" & Report & ";");
         Responses.Append_Natural (T, Height);
         Responses.Append_Character (T, ';');
         Responses.Append_Natural (T, Width);
         Responses.Append_Character (T, 't');
      end Append_Dimensions;
      procedure Append_Title (Selector : Standard.Character) is
      begin
         Responses.Append_String (T, ASCII.ESC & "]" & Selector);
         for I in 1 .. T.Window_Title.Length loop
            Responses.Append_Character (T, T.Window_Title.Text (I));
         end loop;
         Responses.Append_String (T, ASCII.ESC & "\");
      end Append_Title;
   begin
      Responses.Begin_Transaction (T);
      if T.Parser.CSI_Private = ASCII.NUL and then Number in 1 .. 10 then
         null;
      elsif Valid_Report and then Number = 11 then
         Responses.Append_String (T, ASCII.ESC & "[1t");
      elsif Valid_Report and then Number = 13 then
         Responses.Append_String (T, ASCII.ESC & "[3;0;0t");
      elsif Valid_Report and then Number = 14 then
         Append_Dimensions ('4', T.Window_Pixel_Height, T.Window_Pixel_Width);
      elsif Valid_Report and then Number = 15 then
         Append_Dimensions ('5', T.Window_Pixel_Height, T.Window_Pixel_Width);
      elsif Valid_Report and then Number = 16 then
         Append_Dimensions ('6', T.Cell_Pixel_Height, T.Cell_Pixel_Width);
      elsif Valid_Report and then Number = 18 then
         Append_Dimensions ('8', T.Rows, T.Cols);
      elsif Valid_Report and then Number = 19 then
         Append_Dimensions ('9', T.Rows, T.Cols);
      elsif Valid_Report and then Number = 20 then
         Append_Title ('L');
      elsif Valid_Report and then Number = 21 then
         Append_Title ('l');
      elsif Number = 22 and then Valid_Title_Stack_Target then
         T.Saved_Window_Title := T.Window_Title;
         T.Saved_Window_Title_Valid := True;
      elsif Number = 23 and then Valid_Title_Stack_Target then
         if T.Saved_Window_Title_Valid then
            T.Window_Title := T.Saved_Window_Title;
         end if;
      else
         Common.Counters.Increment_Saturating
           (T.Diag.Unsupported_Sequence);
      end if;
      Responses.End_Transaction (T);
   end Queue_Window_Operation_Report;
end Terminal.Core.Response_Queries;

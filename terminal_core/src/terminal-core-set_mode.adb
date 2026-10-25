separate (Terminal.Core)
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
      when 66 =>
         T.Current_Modes.Application_Keypad := Enable;
      when 67 =>
         T.Current_Modes.Backarrow_Key_Backspace := Enable;
      when 80 =>
         T.Current_Modes.Sixel_Display_Mode := Enable;
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
      when 1005 =>
         T.Current_Modes.Mouse_UTF8 := Enable;
      when 1006 =>
         T.Current_Modes.Mouse_SGR := Enable;
      when 1015 =>
         T.Current_Modes.Mouse_URXVT := Enable;
      when 1070 =>
         T.Current_Modes.Sixel_Private_Colors := Enable;
      when 47 | 1047 =>
         if Enable then
            T.Alternate_Graphics_Generation :=
              T.Alternate_Graphics_Generation + 1;
            if T.Alternate_Graphics_Generation = 0 then
               T.Alternate_Graphics_Generation := 1;
            end if;
         end if;
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
            T.Alternate_Graphics_Generation :=
              T.Alternate_Graphics_Generation + 1;
            if T.Alternate_Graphics_Generation = 0 then
               T.Alternate_Graphics_Generation := 1;
            end if;
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
      when 8452 =>
         T.Current_Modes.Sixel_Scrolls_Right := Enable;
      when 2048 =>
         T.Current_Modes.In_Band_Resize := Enable;
         --  A program turning the reports on is told the size at once.
         if Enable then
            Queue_Resize_Report (T);
         end if;
      when others =>
         T.Diag.Unsupported_Sequence := T.Diag.Unsupported_Sequence + 1;
   end case;

   --  Switching screens switches keyboard stacks.
   Refresh_Keyboard_Flags (T);
end Set_Mode;

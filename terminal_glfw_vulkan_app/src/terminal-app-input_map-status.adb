package body Terminal.App.Input_Map.Status is
   function Paste_Label (Modes : Terminal.Core.Mode_Snapshot) return String is
     (if Modes.Bracketed_Paste
      then "Bracketed paste active"
      else "Plain paste active");

   function Focus_Label (Modes : Terminal.Core.Mode_Snapshot) return String is
     (if Modes.Focus_Reporting
      then "Focus reporting active"
      else "Focus reporting inactive");

   function Keyboard_Label (Modes : Terminal.Core.Mode_Snapshot) return String is
     (if Modes.Keyboard_Locked
      then "Keyboard input locked"
      else "Keyboard input active");

   function Key_Mode_Label
     (Modes : Terminal.Core.Mode_Snapshot) return String
   is
      Result : String (1 .. Max_Input_Status_Label_Length);
      Last   : Natural := 0;
      procedure Append (Text : String) is
      begin
         for Ch of Text loop
            exit when Last = Result'Last;
            Last := Last + 1;
            Result (Last) := Ch;
         end loop;
      end Append;
   begin
      Append ("Keys: ");
      Append (if Modes.Application_Cursor then "app cursor" else "normal cursor");
      Append (", ");
      Append (if Modes.Application_Keypad then "app keypad" else "numeric keypad");
      Append (", ");
      Append
        (if Modes.Backarrow_Key_Backspace
         then "Backspace=BS"
         else "Backspace=DEL");
      Append (", ");
      Append (if Modes.Linefeed_New_Line then "LF sends CRLF" else "LF sends LF");
      return Result (1 .. Last);
   end Key_Mode_Label;

   function Mouse_Reporting_Enabled
     (Modes : Terminal.Core.Mode_Snapshot) return Boolean is
     (Modes.Mouse_Button or else Modes.Mouse_Drag or else Modes.Mouse_Any_Event);

   function Input_Label (Modes : Terminal.Core.Mode_Snapshot) return String is
      Keyboard : constant String :=
        (if Modes.Keyboard_Locked then "keyboard locked" else "keyboard active");
      Paste : constant String :=
        (if Modes.Bracketed_Paste then "bracketed paste" else "plain paste");
      Focus : constant String :=
        (if Modes.Focus_Reporting then "focus reporting" else "focus local");
      Mouse : constant String :=
        (if Mouse_Reporting_Enabled (Modes)
         then "mouse reporting"
         else "local mouse");
   begin
      return "Input: " & Keyboard & ", " & Paste & ", " & Focus & ", " & Mouse;
   end Input_Label;

   function Mouse_Label (Modes : Terminal.Core.Mode_Snapshot) return String is
     (if Mouse_Reporting_Enabled (Modes)
      then "Mouse reporting active; Shift+Left keeps local selection"
      else "Local selection active; wheel scrolls scrollback");
end Terminal.App.Input_Map.Status;

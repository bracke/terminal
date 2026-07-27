with AUnit.Assertions;

with GLFW_Vulkan.Input;
with Terminal.App.Input_Map;
with Terminal.App.Queues;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Input_Map_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type GLFW_Vulkan.Input.Key_Action;

   package GI renames GLFW_Vulkan.Input;
   package IM renames Terminal.App.Input_Map;
   package Q renames Terminal.App.Queues;

   Modes : Terminal.Core.Mode_Snapshot;
   Chunk : Q.Byte_Chunk;

   function Key_Event
     (Key     : GI.Key;
      Action  : GI.Key_Action := GI.Press;
      Shift   : Boolean := False;
      Control : Boolean := False;
      Alt     : Boolean := False;
      Super   : Boolean := False) return GI.Key_Event
   is
   begin
      return
        (Key       => Key,
         Raw_Key   => 0,
         Scancode  => 0,
         Action    => Action,
         Modifiers =>
           (Shift => Shift, Control => Control, Alt => Alt, Super => Super));
   end Key_Event;

   function Mouse_Event
     (Button  : GI.Mouse_Button;
      Action  : GI.Key_Action := GI.Press;
      Shift   : Boolean := False;
      Control : Boolean := False;
      Alt     : Boolean := False) return GI.Mouse_Button_Event
   is
   begin
      return
        (Button    => Button,
         Raw_Button => 0,
         Action    => Action,
         Modifiers =>
           (Shift => Shift, Control => Control, Alt => Alt, Super => False),
         X         => 0.0,
         Y         => 0.0);
   end Mouse_Event;

   function Scroll_Event
     (Y_Offset : Float;
      X_Offset : Float := 0.0) return GI.Scroll_Event is
   begin
      return (X_Offset => X_Offset, Y_Offset => Y_Offset, X => 0.0, Y => 0.0);
   end Scroll_Event;

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   procedure Assert_Bytes
     (Actual  : Q.Byte_Chunk;
      Expect  : Byte_Array;
      Message : String)
   is
   begin
      Assert (Actual.Length = Expect'Length, Message & " length");
      for I in Expect'Range loop
         Assert
           (Actual.Data (I - Expect'First + 1) = Expect (I),
            Message & " byte" & Natural'Image (I - Expect'First + 1));
      end loop;
   end Assert_Bytes;
begin
   Assert
     (IM.Key_Mode_Status_Label (Modes) =
      "Keys: normal cursor, numeric keypad, Backspace=DEL, LF sends LF",
      "default key mode status label");
   Assert
     (IM.Key_Mode_Status_Label (Modes)'Length <=
      IM.Max_Input_Status_Label_Length,
      "key mode status label should be bounded");

   IM.Encode_Key (Key_Event (GI.Enter), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#0D#), "enter");

   Modes.Linefeed_New_Line := True;
   IM.Encode_Key (Key_Event (GI.Enter), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#0D#, 2 => 16#0A#), "LNM enter");
   Assert
     (IM.Key_Mode_Status_Label (Modes) =
      "Keys: normal cursor, numeric keypad, Backspace=DEL, LF sends CRLF",
      "LNM key mode status label");
   Modes.Linefeed_New_Line := False;

   IM.Encode_Key (Key_Event (GI.Backspace), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#7F#), "backspace");

   Modes.Backarrow_Key_Backspace := True;
   IM.Encode_Key (Key_Event (GI.Backspace), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#08#), "DECBKM backspace");
   Assert
     (IM.Key_Mode_Status_Label (Modes) =
      "Keys: normal cursor, numeric keypad, Backspace=BS, LF sends LF",
      "DECBKM key mode status label");

   IM.Encode_Key (Key_Event (GI.Backspace, Alt => True), Modes, Chunk);
   Assert_Bytes
     (Chunk,
      (1 => 16#1B#, 2 => 16#08#),
      "DECBKM alt-backspace");
   Modes.Backarrow_Key_Backspace := False;

   IM.Encode_Key (Key_Event (GI.Backspace, Control => True), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#08#), "ctrl-backspace");

   IM.Encode_Key (Key_Event (GI.Backspace, Alt => True), Modes, Chunk);
   Assert_Bytes
     (Chunk,
      (1 => 16#1B#, 2 => 16#7F#),
      "alt-backspace");

   IM.Encode_Key
     (Key_Event (GI.Backspace, Control => True, Alt => True), Modes, Chunk);
   Assert_Bytes
     (Chunk,
      (1 => 16#1B#, 2 => 16#08#),
      "ctrl-alt-backspace");

   IM.Encode_Key (Key_Event (GI.Space), Modes, Chunk);
   Assert (Chunk.Length = 0, "plain space is sent by character callback");

   IM.Encode_Key (Key_Event (GI.Space, Control => True), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#00#), "ctrl-space");

   IM.Encode_Key
     (Key_Event (GI.Space, Control => True, Alt => True), Modes, Chunk);
   Assert_Bytes
     (Chunk,
      (1 => 16#1B#, 2 => 16#00#),
      "ctrl-alt-space");

   IM.Encode_Key (Key_Event (GI.Space, Alt => True), Modes, Chunk);
   Assert_Bytes
     (Chunk,
      (1 => 16#1B#, 2 => Byte (Character'Pos (' '))),
      "alt-space");

   IM.Encode_Key (Key_Event (GI.Tab), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#09#), "tab");

   IM.Encode_Key (Key_Event (GI.Tab, Shift => True), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "[Z"), "shift-tab");

   IM.Encode_Key (Key_Event (GI.C, Control => True), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#03#), "ctrl-c");

   IM.Encode_Key (Key_Event (GI.C, Control => True, Alt => True), Modes, Chunk);
   Assert_Bytes
     (Chunk,
      (1 => 16#1B#, 2 => 16#03#),
      "ctrl-alt-c");

   IM.Encode_Key (Key_Event (GI.D, Control => True), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#04#), "ctrl-d");

   IM.Encode_Key (Key_Event (GI.A, Control => True), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#01#), "ctrl-a");

   IM.Encode_Key (Key_Event (GI.E, Control => True), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#05#), "ctrl-e");

   IM.Encode_Key (Key_Event (GI.K, Control => True), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#0B#), "ctrl-k");

   IM.Encode_Key (Key_Event (GI.L, Control => True), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#0C#), "ctrl-l");

   IM.Encode_Key (Key_Event (GI.U, Control => True), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#15#), "ctrl-u");

   IM.Encode_Key (Key_Event (GI.V, Control => True), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#16#), "ctrl-v");

   IM.Encode_Key (Key_Event (GI.W, Control => True), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#17#), "ctrl-w");

   IM.Encode_Key (Key_Event (GI.X, Alt => True), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "x"), "alt-x");

   IM.Encode_Key (Key_Event (GI.X, Shift => True, Alt => True), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "X"), "alt-shift-x");

   IM.Encode_Key (Key_Event (GI.Minus, Alt => True), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "-"), "alt-minus");

   IM.Encode_Key (Key_Event (GI.Minus, Shift => True, Alt => True), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "_"), "alt-shift-minus");

   IM.Encode_Key (Key_Event (GI.Slash, Shift => True, Alt => True), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "?"), "alt-shift-slash");

   IM.Encode_Key (Key_Event (GI.Kp_Add, Alt => True), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "+"), "alt-keypad-add");

   IM.Encode_Key (Key_Event (GI.Kp_Enter), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#0D#), "keypad enter");

   Modes.Linefeed_New_Line := True;
   IM.Encode_Key (Key_Event (GI.Kp_Enter), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#0D#, 2 => 16#0A#), "LNM keypad enter");
   Modes.Linefeed_New_Line := False;

   Modes.Application_Keypad := True;
   IM.Encode_Key (Key_Event (GI.Kp_1), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "Oq"), "application keypad one");
   Assert
     (IM.Key_Mode_Status_Label (Modes) =
      "Keys: normal cursor, app keypad, Backspace=DEL, LF sends LF",
      "application keypad status label");

   IM.Encode_Key (Key_Event (GI.Kp_Add), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "Ok"), "application keypad add");

   IM.Encode_Key (Key_Event (GI.Kp_Equal, Alt => True), Modes, Chunk);
   Assert_Bytes
     (Chunk,
      To_Bytes (ASCII.ESC & ASCII.ESC & "OX"),
      "alt application keypad equal");

   IM.Encode_Key (Key_Event (GI.Kp_Enter), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "OM"), "application keypad enter");
   Assert
     (IM.Suppressed_Character (Key_Event (GI.Kp_1), Modes) = '1',
      "application keypad one should suppress matching character event");
   Assert
     (IM.Suppressed_Character (Key_Event (GI.Kp_Enter), Modes) =
        Wide_Wide_Character'Val (0),
      "application keypad enter should not suppress character event");
   Modes.Application_Keypad := False;

   IM.Encode_Key
     (Key_Event (GI.Left_Bracket, Control => True), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#1B#), "ctrl-left-bracket");

   IM.Encode_Key
     (Key_Event (GI.Backslash, Control => True), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#1C#), "ctrl-backslash");

   IM.Encode_Key
     (Key_Event (GI.Right_Bracket, Control => True), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#1D#), "ctrl-right-bracket");

   IM.Encode_Key (Key_Event (GI.Num_6, Control => True), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#1E#), "ctrl-6");

   IM.Encode_Key (Key_Event (GI.Minus, Control => True), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#1F#), "ctrl-minus");

   IM.Encode_Key
     (Key_Event (GI.Slash, Control => True, Shift => True), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#7F#), "ctrl-question");

   IM.Encode_Key (Key_Event (GI.Up), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "[A"), "normal up");

   IM.Encode_Key (Key_Event (GI.Up, Shift => True), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "[1;2A"), "shift-up");

   IM.Encode_Key (Key_Event (GI.Right, Control => True), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "[1;5C"), "ctrl-right");

   IM.Encode_Key
     (Key_Event (GI.Left, Shift => True, Control => True, Alt => True),
      Modes,
      Chunk);
   Assert_Bytes
     (Chunk,
      To_Bytes (ASCII.ESC & "[1;8D"),
      "shift-ctrl-alt-left");

   Modes.Application_Cursor := True;
   IM.Encode_Key (Key_Event (GI.Up), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "OA"), "application up");
   Assert
     (IM.Key_Mode_Status_Label (Modes) =
      "Keys: app cursor, numeric keypad, Backspace=DEL, LF sends LF",
      "application cursor status label");

   IM.Encode_Key (Key_Event (GI.Up, Shift => True), Modes, Chunk);
   Assert_Bytes
     (Chunk,
      To_Bytes (ASCII.ESC & "[1;2A"),
      "modified application up uses CSI");
   Modes.Application_Cursor := False;

   IM.Encode_Key (Key_Event (GI.Home, Alt => True), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "[1;3H"), "alt-home");

   IM.Encode_Key (Key_Event (GI.Delete, Control => True), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "[3;5~"), "ctrl-delete");

   IM.Encode_Key (Key_Event (GI.Page_Down, Shift => True), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "[6;2~"), "shift-page-down");

   IM.Encode_Key (Key_Event (GI.F5), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "[15~"), "f5");

   IM.Encode_Key (Key_Event (GI.F1, Shift => True), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "[1;2P"), "shift-f1");

   IM.Encode_Key (Key_Event (GI.F4, Control => True), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "[1;5S"), "ctrl-f4");

   IM.Encode_Key (Key_Event (GI.F6, Alt => True), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "[17;3~"), "alt-f6");

   IM.Encode_Key
     (Key_Event (GI.F12, Shift => True, Control => True, Alt => True),
      Modes,
      Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "[24;8~"), "shift-ctrl-alt-f12");

   IM.Encode_Key (Key_Event (GI.A, Action => GI.Release), Modes, Chunk);
   Assert (Chunk.Length = 0, "release should not encode");

   Assert
     (IM.Is_Paste_Shortcut (Key_Event (GI.V, Shift => True, Control => True)),
      "ctrl-shift-v should paste");
   Assert
     (IM.Is_Paste_Shortcut (Key_Event (GI.V, Super => True)),
      "super-v should paste");
   Assert
     (IM.Is_Paste_Shortcut (Key_Event (GI.Insert, Shift => True)),
      "shift-insert should paste");
   Assert
     (not IM.Is_Paste_Shortcut (Key_Event (GI.V, Control => True)),
      "ctrl-v is left to terminal programs");
   Assert
     (not IM.Is_Paste_Shortcut
        (Key_Event (GI.Insert, Shift => True, Control => True)),
      "modified shift-insert should be left to terminal programs");

   IM.Encode_Key (Key_Event (GI.V, Shift => True, Control => True), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#16#), "ctrl-shift-v encodes if not intercepted");

   Assert
     (not IM.Is_Paste_Shortcut
        (Key_Event (GI.V, Action => GI.Release, Shift => True, Control => True)),
      "released paste shortcut should be ignored");

   Assert
     (IM.Is_Copy_Shortcut (Key_Event (GI.C, Shift => True, Control => True)),
      "ctrl-shift-c should copy");
   Assert
     (IM.Is_Copy_Shortcut (Key_Event (GI.C, Super => True)),
      "super-c should copy");
   Assert
     (IM.Is_Copy_Shortcut (Key_Event (GI.Insert, Control => True)),
      "ctrl-insert should copy");
   Assert
     (not IM.Is_Copy_Shortcut (Key_Event (GI.C, Control => True)),
      "ctrl-c is left to terminal programs");
   Assert
     (not IM.Is_Copy_Shortcut
        (Key_Event (GI.Insert, Shift => True, Control => True)),
      "modified ctrl-insert should be left to terminal programs");
   Assert
     (not IM.Is_Copy_Shortcut
        (Key_Event (GI.C, Action => GI.Release, Shift => True, Control => True)),
      "released copy shortcut should be ignored");

   IM.Encode_Key (Key_Event (GI.C, Shift => True, Control => True), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#03#), "ctrl-shift-c encodes if not intercepted");

   Assert
     (IM.Is_Primary_Paste_Button (Mouse_Event (GI.Middle)),
      "middle press should paste primary selection");
   Assert
     (not IM.Is_Primary_Paste_Button
        (Mouse_Event (GI.Middle, Action => GI.Release)),
      "middle release should not paste primary selection");
   Assert
     (not IM.Is_Primary_Paste_Button (Mouse_Event (GI.Left)),
      "left press should not paste primary selection");
   Assert
     (not IM.Is_Primary_Paste_Button
        (Mouse_Event (GI.Middle, Control => True)),
      "modified middle press should not paste primary selection");
   Assert
     (IM.Local_Mouse_Selection_Override
        (Mouse_Event (GI.Left, Shift => True)),
      "shift left mouse should override reporting for local selection");
   Assert
     (IM.Local_Mouse_Selection_Override
        (Mouse_Event (GI.Left, Shift => True, Alt => True)),
      "shift alt left mouse should keep local selection override");
   Assert
     (not IM.Local_Mouse_Selection_Override
        (Mouse_Event (GI.Left, Control => True)),
      "ctrl left mouse should not force local selection");
   Assert
     (not IM.Local_Mouse_Selection_Override (Mouse_Event (GI.Middle)),
      "middle mouse should not force local selection");

   IM.Encode_Character ((Code_Point => Wide_Wide_Character'Val (16#00E9#)), Chunk);
   Assert_Bytes (Chunk, (1 => 16#C3#, 2 => 16#A9#), "utf8 e-acute");

   IM.Encode_Character ((Code_Point => Wide_Wide_Character'Val (16#1F642#)), Chunk);
   Assert_Bytes
     (Chunk,
      (1 => 16#F0#, 2 => 16#9F#, 3 => 16#99#, 4 => 16#82#),
      "utf8 smile");

   IM.Encode_Character ((Code_Point => Wide_Wide_Character'Val (16#D800#)), Chunk);
   Assert (Chunk.Length = 0, "surrogate input should be dropped");

   IM.Encode_Character ((Code_Point => Wide_Wide_Character'Val (16#110000#)), Chunk);
   Assert (Chunk.Length = 0, "out-of-range Unicode input should be dropped");

   IM.Encode_Paste_Text ("abc", Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes ("abc"), "plain paste");
   Assert
     (IM.Paste_Status_Label (Modes) = "Plain paste active",
      "plain paste status label");
   Assert
     (IM.Paste_Status_Label (Modes)'Length <= IM.Max_Input_Status_Label_Length,
      "paste status label should be bounded");
   Assert
     (IM.Keyboard_Status_Label (Modes) = "Keyboard input active",
      "active keyboard status label");
   Assert
     (IM.Keyboard_Status_Label (Modes)'Length <= IM.Max_Input_Status_Label_Length,
      "keyboard status label should be bounded");
   Assert
     (IM.Input_Status_Label (Modes) =
      "Input: keyboard active, plain paste, focus local, local mouse",
      "default input status label");
   Assert
     (IM.Input_Status_Label (Modes)'Length <= IM.Max_Input_Status_Label_Length,
      "input status label should be bounded");

   Modes.Keyboard_Locked := True;
   Assert
     (IM.Keyboard_Status_Label (Modes) = "Keyboard input locked",
      "locked keyboard status label");
   Assert
     (IM.Input_Status_Label (Modes) =
      "Input: keyboard locked, plain paste, focus local, local mouse",
      "keyboard-locked input status label");
   Modes.Keyboard_Locked := False;

   Modes.Bracketed_Paste := True;
   IM.Encode_Paste_Text ("abc", Modes, Chunk);
   Assert_Bytes
     (Chunk,
      To_Bytes (ASCII.ESC & "[200~abc" & ASCII.ESC & "[201~"),
      "bracketed paste");
   Assert
     (IM.Paste_Status_Label (Modes) = "Bracketed paste active",
      "bracketed paste status label");
   Assert
     (IM.Input_Status_Label (Modes) =
      "Input: keyboard active, bracketed paste, focus local, local mouse",
      "bracketed input status label");

   Modes := (others => <>);
   Assert (not IM.Mouse_Reporting_Enabled (Modes), "mouse reporting disabled");
   Assert
     (IM.Mouse_Status_Label (Modes) =
      "Local selection active; wheel scrolls scrollback",
      "local mouse status label");
   Assert
     (IM.Mouse_Status_Label (Modes)'Length <= IM.Max_Mouse_Status_Label_Length,
      "mouse status label should be bounded");
   IM.Encode_Mouse_Button (Mouse_Event (GI.Left), Modes, 2, 3, Chunk);
   Assert (Chunk.Length = 0, "disabled mouse should not encode");

   Modes.Mouse_Button := True;
   Modes.Mouse_SGR := True;
   Assert (IM.Mouse_Reporting_Enabled (Modes), "mouse reporting enabled");
   Assert
     (IM.Mouse_Status_Label (Modes) =
      "Mouse reporting active; Shift+Left keeps local selection",
      "reported mouse status label");
   Assert
     (IM.Input_Status_Label (Modes) =
      "Input: keyboard active, plain paste, focus local, mouse reporting",
      "mouse-reporting input status label");
   IM.Encode_Mouse_Button (Mouse_Event (GI.Other), Modes, 2, 3, Chunk);
   Assert (Chunk.Length = 0, "unknown mouse button should not encode");

   IM.Encode_Mouse_Button (Mouse_Event (GI.Left), Modes, 2, 3, Chunk);
   Assert_Bytes
     (Chunk,
      To_Bytes (ASCII.ESC & "[<0;3;2M"),
      "sgr left press");

   IM.Encode_Mouse_Button
     (Mouse_Event (GI.Left, Action => GI.Release), Modes, 2, 3, Chunk);
   Assert_Bytes
     (Chunk,
      To_Bytes (ASCII.ESC & "[<3;3;2m"),
      "sgr left release");

   Modes.Mouse_Drag := True;
   IM.Encode_Mouse_Motion
     ((X => 0.0, Y => 0.0),
      Modes,
      2,
      3,
      Button_Down => True,
      Button_Code => 0,
      Modifiers   => (others => False),
      Chunk       => Chunk);
   Assert_Bytes
     (Chunk,
      To_Bytes (ASCII.ESC & "[<32;3;2M"),
      "sgr left drag");

   Modes.Mouse_SGR := False;
   IM.Encode_Mouse_Button (Mouse_Event (GI.Right, Control => True), Modes, 4, 5, Chunk);
   Assert_Bytes
     (Chunk,
      (1 => 16#1B#, 2 => Byte (Character'Pos ('[')),
       3 => Byte (Character'Pos ('M')), 4 => Byte (2 + 16 + 32),
       5 => Byte (5 + 32), 6 => Byte (4 + 32)),
      "legacy right ctrl press");

   Modes.Mouse_SGR := True;
   IM.Encode_Mouse_Wheel (Scroll_Event (1.0), Modes, 4, 5, Chunk);
   Assert_Bytes
     (Chunk,
      To_Bytes (ASCII.ESC & "[<64;5;4M"),
      "sgr wheel up");

   IM.Encode_Mouse_Wheel (Scroll_Event (-1.0), Modes, 4, 5, Chunk);
   Assert_Bytes
     (Chunk,
      To_Bytes (ASCII.ESC & "[<65;5;4M"),
      "sgr wheel down");

   IM.Encode_Mouse_Wheel (Scroll_Event (0.0, X_Offset => 1.0), Modes, 4, 5, Chunk);
   Assert_Bytes
     (Chunk,
      To_Bytes (ASCII.ESC & "[<66;5;4M"),
      "sgr wheel right");

   IM.Encode_Mouse_Wheel (Scroll_Event (0.0, X_Offset => -1.0), Modes, 4, 5, Chunk);
   Assert_Bytes
     (Chunk,
      To_Bytes (ASCII.ESC & "[<67;5;4M"),
      "sgr wheel left");

   IM.Encode_Mouse_Wheel (Scroll_Event (0.0), Modes, 4, 5, Chunk);
   Assert (Chunk.Length = 0, "zero scroll should not encode");

   Modes := (others => <>);
   IM.Encode_Focus ((Focused => True), Modes, Chunk);
   Assert (Chunk.Length = 0, "disabled focus should not encode");
   Assert
     (IM.Focus_Status_Label (Modes) = "Focus reporting inactive",
      "inactive focus status label");
   Assert
     (IM.Focus_Status_Label (Modes)'Length <= IM.Max_Input_Status_Label_Length,
      "focus status label should be bounded");

   Modes.Focus_Reporting := True;
   Assert
     (IM.Focus_Status_Label (Modes) = "Focus reporting active",
      "active focus status label");
   Assert
     (IM.Input_Status_Label (Modes) =
      "Input: keyboard active, plain paste, focus reporting, local mouse",
      "focus-reporting input status label");
   IM.Encode_Focus ((Focused => True), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "[I"), "focus in");

   IM.Encode_Focus ((Focused => False), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "[O"), "focus out");
end Input_Map_Smoke;

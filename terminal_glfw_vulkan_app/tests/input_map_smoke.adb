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
   IM.Encode_Key (Key_Event (GI.Enter), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#0D#), "enter");

   IM.Encode_Key (Key_Event (GI.Backspace), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#7F#), "backspace");

   IM.Encode_Key (Key_Event (GI.Tab), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#09#), "tab");

   IM.Encode_Key (Key_Event (GI.Tab, Shift => True), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "[Z"), "shift-tab");

   IM.Encode_Key (Key_Event (GI.C, Control => True), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#03#), "ctrl-c");

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

   IM.Encode_Key (Key_Event (GI.A, Action => GI.Release), Modes, Chunk);
   Assert (Chunk.Length = 0, "release should not encode");

   Assert
     (IM.Is_Paste_Shortcut (Key_Event (GI.V, Shift => True, Control => True)),
      "ctrl-shift-v should paste");
   Assert
     (IM.Is_Paste_Shortcut (Key_Event (GI.V, Super => True)),
      "super-v should paste");
   Assert
     (not IM.Is_Paste_Shortcut (Key_Event (GI.V, Control => True)),
      "ctrl-v is left to terminal programs");

   IM.Encode_Key (Key_Event (GI.V, Shift => True, Control => True), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#16#), "ctrl-shift-v encodes if not intercepted");

   Assert
     (not IM.Is_Paste_Shortcut
        (Key_Event (GI.V, Action => GI.Release, Shift => True, Control => True)),
      "released paste shortcut should be ignored");

   IM.Encode_Character ((Code_Point => Wide_Wide_Character'Val (16#00E9#)), Chunk);
   Assert_Bytes (Chunk, (1 => 16#C3#, 2 => 16#A9#), "utf8 e-acute");

   IM.Encode_Character ((Code_Point => Wide_Wide_Character'Val (16#1F642#)), Chunk);
   Assert_Bytes
     (Chunk,
      (1 => 16#F0#, 2 => 16#9F#, 3 => 16#99#, 4 => 16#82#),
      "utf8 smile");

   IM.Encode_Paste_Text ("abc", Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes ("abc"), "plain paste");

   Modes.Bracketed_Paste := True;
   IM.Encode_Paste_Text ("abc", Modes, Chunk);
   Assert_Bytes
     (Chunk,
      To_Bytes (ASCII.ESC & "[200~abc" & ASCII.ESC & "[201~"),
      "bracketed paste");

   Modes := (others => <>);
   Assert (not IM.Mouse_Reporting_Enabled (Modes), "mouse reporting disabled");
   IM.Encode_Mouse_Button (Mouse_Event (GI.Left), Modes, 2, 3, Chunk);
   Assert (Chunk.Length = 0, "disabled mouse should not encode");

   Modes.Mouse_Button := True;
   Modes.Mouse_SGR := True;
   Assert (IM.Mouse_Reporting_Enabled (Modes), "mouse reporting enabled");
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
end Input_Map_Smoke;

with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_Modes_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Core.Cell_Kind;
   use type Terminal.Common.Code_Point;
   use type Terminal.Core.Color_Kind;
   use type Terminal.Core.Cursor_Shape;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.Core.Feed_Status;

   T : Terminal.Core.Terminal;
   Init : Terminal.Core.Initialize_Status;
   Feed_Status : Terminal.Core.Feed_Status;

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   procedure Feed_Text (Text : String; Message : String) is
   begin
      Terminal.Core.Feed (T, To_Bytes (Text), Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, Message);
   end Feed_Text;
begin
   Terminal.Core.Initialize (T, 5, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "initialize failed");

   Terminal.Core.Feed
     (T,
      (1 => 16#1B#, 2 => Byte (Character'Pos ('[')),
       3 => Byte (Character'Pos ('?')), 4 => Byte (Character'Pos ('2')),
       5 => Byte (Character'Pos ('0')), 6 => Byte (Character'Pos ('0')),
       7 => Byte (Character'Pos ('4')), 8 => Byte (Character'Pos ('h'))),
      Feed_Status);

   Assert (Feed_Status = Terminal.Core.Ok, "feed failed");
   Assert (Terminal.Core.Modes (T).Bracketed_Paste, "bracketed paste");

   Feed_Text (ASCII.ESC & "=", "application keypad mode feed failed");
   Assert
     (Terminal.Core.Modes (T).Application_Keypad,
      "application keypad mode");

   Feed_Text (ASCII.ESC & ">", "numeric keypad mode feed failed");
   Assert
     (not Terminal.Core.Modes (T).Application_Keypad,
      "numeric keypad mode");

   Feed_Text (ASCII.ESC & "[?66h", "DECNKM application keypad feed failed");
   Assert
     (Terminal.Core.Modes (T).Application_Keypad,
      "DECNKM application keypad mode");

   Feed_Text (ASCII.ESC & "[?66l", "DECNKM numeric keypad feed failed");
   Assert
     (not Terminal.Core.Modes (T).Application_Keypad,
      "DECNKM numeric keypad mode");

   Feed_Text (ASCII.ESC & "[?67h", "DECBKM backspace feed failed");
   Assert
     (Terminal.Core.Modes (T).Backarrow_Key_Backspace,
      "DECBKM backspace mode");

   Feed_Text (ASCII.ESC & "[?67l", "DECBKM delete feed failed");
   Assert
     (not Terminal.Core.Modes (T).Backarrow_Key_Backspace,
      "DECBKM delete mode");

   Feed_Text
     (ASCII.ESC & "[?2026h",
      "synchronized update mode set feed failed");
   Assert
     (Terminal.Core.Modes (T).Synchronized_Update,
      "synchronized update mode");

   Feed_Text
     (ASCII.ESC & "[?2026l",
      "synchronized update mode reset feed failed");
   Assert
     (not Terminal.Core.Modes (T).Synchronized_Update,
      "synchronized update mode reset");

   Feed_Text (ASCII.ESC & "[2h", "keyboard lock mode set feed failed");
   Assert
     (Terminal.Core.Modes (T).Keyboard_Locked,
      "keyboard lock mode");

   Feed_Text (ASCII.ESC & "[2l", "keyboard lock mode reset feed failed");
   Assert
     (not Terminal.Core.Modes (T).Keyboard_Locked,
      "keyboard lock mode reset");

   Feed_Text
     (ASCII.ESC & "[?1000h",
      "mouse mode set feed failed");
   declare
      M : constant Terminal.Core.Mode_Snapshot := Terminal.Core.Modes (T);
   begin
      Assert (M.Mouse_Button, "mouse button reporting");
      Assert (not M.Mouse_Drag, "mouse drag reporting initially off");
      Assert (not M.Mouse_Any_Event, "mouse any-event reporting initially off");
   end;

   Feed_Text
     (ASCII.ESC & "[?1002h",
      "mouse drag mode set feed failed");
   declare
      M : constant Terminal.Core.Mode_Snapshot := Terminal.Core.Modes (T);
   begin
      Assert (not M.Mouse_Button, "mouse drag disables button mode");
      Assert (M.Mouse_Drag, "mouse drag reporting");
      Assert (not M.Mouse_Any_Event, "mouse any-event reporting still off");
   end;

   Feed_Text
     (ASCII.ESC & "[?1003;1004;1006h",
      "mouse any-event mode set feed failed");
   declare
      M : constant Terminal.Core.Mode_Snapshot := Terminal.Core.Modes (T);
   begin
      Assert (not M.Mouse_Button, "mouse any-event disables button mode");
      Assert (not M.Mouse_Drag, "mouse any-event disables drag mode");
      Assert (M.Mouse_Any_Event, "mouse any-event reporting");
      Assert (M.Focus_Reporting, "focus reporting");
      Assert (M.Mouse_SGR, "mouse SGR reporting");
      Assert (not M.Synchronized_Update, "synchronized update still off");
   end;

   Feed_Text
     (ASCII.ESC & "[?1000;1002;1003;1004;1006l",
      "mouse mode reset feed failed");
   declare
      M : constant Terminal.Core.Mode_Snapshot := Terminal.Core.Modes (T);
   begin
      Assert (not M.Mouse_Button, "mouse button reporting reset");
      Assert (not M.Mouse_Drag, "mouse drag reporting reset");
      Assert (not M.Mouse_Any_Event, "mouse any-event reporting reset");
      Assert (not M.Focus_Reporting, "focus reporting reset");
      Assert (not M.Mouse_SGR, "mouse SGR reporting reset");
      Assert (not M.Synchronized_Update, "synchronized update mode reset");
   end;

   Terminal.Core.Feed
     (T,
      (1  => 16#1B#, 2  => Byte (Character'Pos ('[')),
       3  => Byte (Character'Pos ('2')), 4 => Byte (Character'Pos (';')),
       5  => Byte (Character'Pos ('4')), 6 => Byte (Character'Pos ('r')),
       7  => 16#1B#, 8  => Byte (Character'Pos ('[')),
       9  => Byte (Character'Pos ('1')), 10 => Byte (Character'Pos (';')),
       11 => Byte (Character'Pos ('1')), 12 => Byte (Character'Pos ('H'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "absolute CUP feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Cursor.Row = 1 and then S.Cursor.Col = 1,
         "CUP should be absolute with origin mode disabled");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Feed
     (T,
      (1  => 16#1B#, 2  => Byte (Character'Pos ('[')),
       3  => Byte (Character'Pos ('?')), 4 => Byte (Character'Pos ('6')),
       5  => Byte (Character'Pos ('h')),
       6  => 16#1B#, 7  => Byte (Character'Pos ('[')),
       8  => Byte (Character'Pos ('2')), 9 => Byte (Character'Pos (';')),
       10 => Byte (Character'Pos ('3')), 11 => Byte (Character'Pos ('H'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "origin CUP feed failed");
   Assert (Terminal.Core.Modes (T).Origin_Mode, "origin mode should be enabled");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Cursor.Row = 3 and then S.Cursor.Col = 3,
         "CUP should be relative to the top margin in origin mode");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Feed
     (T,
      (1 => 16#1B#, 2 => Byte (Character'Pos ('[')),
       3 => Byte (Character'Pos ('9')), 4 => Byte (Character'Pos ('H'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "origin clamp feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert (S.Cursor.Row = 4, "origin CUP should clamp to bottom margin");
      Terminal.Core.Release (S);
   end;

   Feed_Text (ASCII.ESC & "[9B", "origin CUD feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert (S.Cursor.Row = 4, "origin CUD should clamp to bottom margin");
      Terminal.Core.Release (S);
   end;

   Feed_Text (ASCII.ESC & "[9A", "origin CUU feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert (S.Cursor.Row = 2, "origin CUU should clamp to top margin");
      Terminal.Core.Release (S);
   end;

   Feed_Text (ASCII.ESC & "[9e", "origin VPR feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert (S.Cursor.Row = 4, "origin VPR should clamp to bottom margin");
      Terminal.Core.Release (S);
   end;

   Feed_Text (ASCII.ESC & "[1d", "origin VPA feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert (S.Cursor.Row = 2, "origin VPA should be relative to top margin");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Feed
     (T,
      (1 => 16#1B#, 2 => Byte (Character'Pos ('[')),
       3 => Byte (Character'Pos ('?')), 4 => Byte (Character'Pos ('6')),
       5 => Byte (Character'Pos ('l'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "origin reset feed failed");
   Assert (not Terminal.Core.Modes (T).Origin_Mode, "origin mode should be disabled");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Cursor.Row = 1 and then S.Cursor.Col = 1,
         "resetting origin mode should home to absolute row one");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 5, 3, 100, Init);
   Assert (Init = Terminal.Core.Ok, "DECSTBM invalid initialize failed");
   Feed_Text
     (ASCII.ESC & "[2;4r"
      & ASCII.ESC & "[3;3r"
      & ASCII.ESC & "[2;1HA"
      & ASCII.ESC & "[3;1HB"
      & ASCII.ESC & "[4;1HC"
      & ASCII.ESC & "[4;1H"
      & ASCII.LF,
      "DECSTBM invalid feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      D : constant Terminal.Core.Diagnostic_Snapshot :=
        Terminal.Core.Diagnostics (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 2, 1).Text.Code_Point = 16#42#,
         "invalid one-row margin should leave prior region row 2 scrolling");
      Assert
        (Terminal.Core.Cell_At (S, 3, 1).Text.Code_Point = 16#43#,
         "invalid one-row margin should leave prior region row 3 scrolling");
      Assert
        (Terminal.Core.Cell_At (S, 4, 1).Kind = Terminal.Core.Empty,
         "invalid one-row margin should leave prior region bottom cleared");
      Assert
        (D.Unsupported_Sequence = 1,
         "invalid one-row margin should be diagnosed");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 5, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "DECSTR initialize failed");
   Feed_Text
     ("z"
      & ASCII.ESC & "[31;1m"
      & ASCII.ESC & "[2;4r"
      & ASCII.ESC & "="
      & ASCII.ESC & "[?1;6;7;25;67;2004;2026h"
      & ASCII.ESC & "[2h"
      & ASCII.ESC & "[4h"
      & ASCII.ESC & "[4;5H"
      & ASCII.ESC & "[!p"
      & ASCII.ESC & "[2G"
      & "X",
      "DECSTR feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      M : constant Terminal.Core.Mode_Snapshot := Terminal.Core.Modes (T);
      Z : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 1);
      X : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 2);
   begin
      Assert
        (S.Cursor.Row = 1 and then S.Cursor.Col = 3,
         "DECSTR should home before later cursor movement");
      Assert
        (Z.Text.Code_Point = 16#7A#,
         "DECSTR should not clear visible text");
      Assert
        (X.Text.Code_Point = 16#58#,
         "post-DECSTR write should land after explicit cursor movement");
      Assert (not X.Style.Bold, "DECSTR should reset current bold style");
      Assert
        (X.Style.Foreground.Kind = Terminal.Core.Default,
         "DECSTR should reset current foreground");
      Assert (not M.Application_Cursor, "DECSTR should reset app cursor");
      Assert (not M.Application_Keypad, "DECSTR should reset app keypad");
      Assert (not M.Backarrow_Key_Backspace, "DECSTR should reset DECBKM");
      Assert (not M.Bracketed_Paste, "DECSTR should reset bracketed paste");
      Assert (not M.Mouse_Button, "DECSTR should reset mouse button");
      Assert (not M.Mouse_Drag, "DECSTR should reset mouse drag");
      Assert (not M.Mouse_Any_Event, "DECSTR should reset mouse any-event");
      Assert (not M.Mouse_SGR, "DECSTR should reset mouse SGR");
      Assert (not M.Focus_Reporting, "DECSTR should reset focus reporting");
      Assert (not M.Synchronized_Update, "DECSTR should reset synchronized update");
      Assert (not M.Origin_Mode, "DECSTR should reset origin mode");
      Assert (M.Autowrap, "DECSTR should enable autowrap");
      Assert (M.Cursor_Visible, "DECSTR should show cursor");
      Assert (not M.Cursor_Blinking, "DECSTR should reset cursor blinking");
      Assert (not M.Keyboard_Locked, "DECSTR should reset keyboard lock");
      Assert (not M.Insert_Mode, "DECSTR should reset insert mode");
      Assert (not S.Cursor.Blinking, "DECSTR should reset snapshot cursor blinking");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 5, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "malformed DECSTR initialize failed");
   declare
      Before : constant Natural :=
        Terminal.Core.Diagnostics (T).Unsupported_Sequence;
   begin
      Feed_Text
        (ASCII.ESC & "[31;1m"
         & ASCII.ESC & "[4h"
         & ASCII.ESC & "[4;5H"
         & ASCII.ESC & "[0!p",
         "malformed DECSTR feed failed");
      declare
         S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
         M : constant Terminal.Core.Mode_Snapshot := Terminal.Core.Modes (T);
      begin
         Assert
           (S.Cursor.Row = 4 and then S.Cursor.Col = 5,
            "malformed DECSTR should not home cursor");
         Assert (M.Insert_Mode, "malformed DECSTR should not reset insert mode");
         Assert
           (Terminal.Core.Diagnostics (T).Unsupported_Sequence = Before + 1,
            "malformed DECSTR should be diagnosed");
         Terminal.Core.Release (S);
      end;
   end;

   Terminal.Core.Initialize (T, 5, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "DECSCUSR initialize failed");
   Feed_Text (ASCII.ESC & "[ q", "DECSCUSR default feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Cursor.Shape = Terminal.Core.Cursor_Block,
         "DECSCUSR default should select block cursor");
      Assert (S.Cursor.Blinking, "DECSCUSR default should select blinking cursor");
      Terminal.Core.Release (S);
   end;

   Feed_Text (ASCII.ESC & "[2 q", "DECSCUSR steady block feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Cursor.Shape = Terminal.Core.Cursor_Block,
         "DECSCUSR 2 should select block cursor");
      Assert (not S.Cursor.Blinking, "DECSCUSR 2 should select steady cursor");
      Terminal.Core.Release (S);
   end;

   Feed_Text (ASCII.ESC & "[3 q", "DECSCUSR blinking underline feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Cursor.Shape = Terminal.Core.Cursor_Underline,
         "DECSCUSR 3 should select underline cursor");
      Assert (S.Cursor.Blinking, "DECSCUSR 3 should select blinking cursor");
      Terminal.Core.Release (S);
   end;

   Feed_Text (ASCII.ESC & "[4 q", "DECSCUSR underline feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Cursor.Shape = Terminal.Core.Cursor_Underline,
         "DECSCUSR 4 should select underline cursor");
      Assert (not S.Cursor.Blinking, "DECSCUSR 4 should select steady cursor");
      Terminal.Core.Release (S);
   end;

   Feed_Text (ASCII.ESC & "[5 q", "DECSCUSR blinking bar feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Cursor.Shape = Terminal.Core.Cursor_Bar,
         "DECSCUSR 5 should select bar cursor");
      Assert (S.Cursor.Blinking, "DECSCUSR 5 should select blinking cursor");
      Terminal.Core.Release (S);
   end;

   Feed_Text (ASCII.ESC & "[6 q", "DECSCUSR bar feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Cursor.Shape = Terminal.Core.Cursor_Bar,
         "DECSCUSR 6 should select bar cursor");
      Assert (not S.Cursor.Blinking, "DECSCUSR 6 should select steady cursor");
      Terminal.Core.Release (S);
   end;

   declare
      Before : constant Natural :=
        Terminal.Core.Diagnostics (T).Unsupported_Sequence;
   begin
      Feed_Text
        (ASCII.ESC & "[6;0 q",
         "malformed DECSCUSR feed failed");
      declare
         S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      begin
         Assert
           (S.Cursor.Shape = Terminal.Core.Cursor_Bar,
            "malformed DECSCUSR should not change cursor shape");
         Assert
           (not S.Cursor.Blinking,
            "malformed DECSCUSR should not change cursor blinking");
         Assert
           (Terminal.Core.Diagnostics (T).Unsupported_Sequence = Before + 1,
            "malformed DECSCUSR should be diagnosed");
         Terminal.Core.Release (S);
      end;
   end;

   Feed_Text (ASCII.ESC & "[?12h", "cursor blink mode set feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      M : constant Terminal.Core.Mode_Snapshot := Terminal.Core.Modes (T);
   begin
      Assert (M.Cursor_Blinking, "DECSET ?12 should enable cursor blinking");
      Assert (S.Cursor.Blinking, "DECSET ?12 should update cursor snapshot");
      Terminal.Core.Release (S);
   end;

   Feed_Text (ASCII.ESC & "[?12l", "cursor blink mode reset feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      M : constant Terminal.Core.Mode_Snapshot := Terminal.Core.Modes (T);
   begin
      Assert (not M.Cursor_Blinking, "DECRST ?12 should disable cursor blinking");
      Assert (not S.Cursor.Blinking, "DECRST ?12 should update cursor snapshot");
      Terminal.Core.Release (S);
   end;

   Feed_Text (ASCII.ESC & "[2 q" & ASCII.ESC & "[!p", "DECSCUSR DECSTR feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Cursor.Shape = Terminal.Core.Cursor_Block,
         "DECSTR should reset cursor shape");
      Assert (not S.Cursor.Blinking, "DECSTR should reset cursor blinking");
      Terminal.Core.Release (S);
   end;

   Feed_Text (ASCII.ESC & "[6 q" & ASCII.ESC & "c", "DECSCUSR RIS feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Cursor.Shape = Terminal.Core.Cursor_Block,
         "RIS should reset cursor shape");
      Assert (not S.Cursor.Blinking, "RIS should reset cursor blinking");
      Terminal.Core.Release (S);
   end;

   Feed_Text
     (ASCII.ESC & "[?66;67;2004h"
      & ASCII.ESC & "[2h"
      & ASCII.ESC & "c",
      "RIS keyboard modes feed failed");
   declare
      M : constant Terminal.Core.Mode_Snapshot := Terminal.Core.Modes (T);
   begin
      Assert (not M.Application_Keypad, "RIS should reset app keypad");
      Assert (not M.Backarrow_Key_Backspace, "RIS should reset DECBKM");
      Assert (not M.Bracketed_Paste, "RIS should reset bracketed paste");
      Assert (not M.Keyboard_Locked, "RIS should reset keyboard lock");
      Assert (M.Autowrap, "RIS should enable autowrap");
      Assert (M.Cursor_Visible, "RIS should show cursor");
   end;

   Feed_Text (ASCII.ESC & "[6 q", "DECSCUSR reinitialize setup feed failed");
   Terminal.Core.Initialize (T, 5, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "DECSCUSR reinitialize failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Cursor.Shape = Terminal.Core.Cursor_Block,
         "Initialize should reset cursor shape");
      Assert (not S.Cursor.Blinking, "Initialize should reset cursor blinking");
      Terminal.Core.Release (S);
   end;

   declare
      D : constant Terminal.Core.Diagnostic_Snapshot :=
        Terminal.Core.Diagnostics (T);
   begin
      Assert
        (D.Unsupported_Sequence = 0,
         "valid DECSCUSR shapes should not increment diagnostics");
   end;

   Terminal.Core.Initialize (T, 2, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "CAN/SUB initialize failed");

   Terminal.Core.Feed
     (T,
      (1  => 16#1B#,
       2  => Byte (Character'Pos ('[')),
       3  => Byte (Character'Pos ('?')),
       4  => Byte (Character'Pos ('2')),
       5  => Byte (Character'Pos ('0')),
       6  => Byte (Character'Pos ('0')),
       7  => Byte (Character'Pos ('4')),
       8  => 16#18#,
       9  => Byte (Character'Pos ('x')),
       10 => 16#1B#,
       11 => Byte (Character'Pos ('[')),
       12 => Byte (Character'Pos ('?')),
       13 => Byte (Character'Pos ('2')),
       14 => Byte (Character'Pos ('5')),
       15 => 16#1A#,
       16 => Byte (Character'Pos ('y'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "CAN/SUB feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      M : constant Terminal.Core.Mode_Snapshot := Terminal.Core.Modes (T);
   begin
      Assert
        (not M.Bracketed_Paste,
         "CAN should cancel bracketed-paste DECSET before final byte");
      Assert
        (M.Cursor_Visible,
         "SUB should cancel cursor-visibility DECRST before final byte");
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#78#,
         "printable text after CAN should render");
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Text.Code_Point = 16#79#,
         "printable text after SUB should render");
      Terminal.Core.Release (S);
   end;
end Core_Modes_Smoke;

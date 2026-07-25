with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_Modes_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
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

   Terminal.Core.Initialize (T, 5, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "DECSTR initialize failed");
   Feed_Text
     ("z"
      & ASCII.ESC & "[31;1m"
      & ASCII.ESC & "[2;4r"
      & ASCII.ESC & "[?1;6;7;25;2004h"
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
      Assert (not M.Bracketed_Paste, "DECSTR should reset bracketed paste");
      Assert (not M.Mouse_Button, "DECSTR should reset mouse button");
      Assert (not M.Mouse_Drag, "DECSTR should reset mouse drag");
      Assert (not M.Mouse_Any_Event, "DECSTR should reset mouse any-event");
      Assert (not M.Mouse_SGR, "DECSTR should reset mouse SGR");
      Assert (not M.Focus_Reporting, "DECSTR should reset focus reporting");
      Assert (not M.Origin_Mode, "DECSTR should reset origin mode");
      Assert (M.Autowrap, "DECSTR should enable autowrap");
      Assert (M.Cursor_Visible, "DECSTR should show cursor");
      Assert (not M.Insert_Mode, "DECSTR should reset insert mode");
      Terminal.Core.Release (S);
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
      Terminal.Core.Release (S);
   end;

   Feed_Text (ASCII.ESC & "[4 q", "DECSCUSR underline feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Cursor.Shape = Terminal.Core.Cursor_Underline,
         "DECSCUSR 4 should select underline cursor");
      Terminal.Core.Release (S);
   end;

   Feed_Text (ASCII.ESC & "[6 q", "DECSCUSR bar feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Cursor.Shape = Terminal.Core.Cursor_Bar,
         "DECSCUSR 6 should select bar cursor");
      Terminal.Core.Release (S);
   end;

   Feed_Text (ASCII.ESC & "[2 q" & ASCII.ESC & "[!p", "DECSCUSR DECSTR feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Cursor.Shape = Terminal.Core.Cursor_Block,
         "DECSTR should reset cursor shape");
      Terminal.Core.Release (S);
   end;

   Feed_Text (ASCII.ESC & "[6 q" & ASCII.ESC & "c", "DECSCUSR RIS feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Cursor.Shape = Terminal.Core.Cursor_Block,
         "RIS should reset cursor shape");
      Terminal.Core.Release (S);
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
end Core_Modes_Smoke;

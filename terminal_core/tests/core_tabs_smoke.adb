with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_Tabs_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;

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

   procedure Assert_Cursor_Col (Expected : Positive; Message : String) is
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert (S.Cursor.Col = Expected, Message);
      Terminal.Core.Release (S);
   end Assert_Cursor_Col;
begin
   Terminal.Core.Initialize (T, 1, 20, 10, Init);
   Assert (Init = Terminal.Core.Ok, "initialize failed");

   Feed_Text ((1 => ASCII.HT), "HT feed failed");
   Assert_Cursor_Col (9, "HT should move to the next default tab stop");

   Feed_Text (ASCII.ESC & "[I", "CHT default feed failed");
   Assert_Cursor_Col (17, "CHT default should move one tab stop");

   Feed_Text (ASCII.ESC & "[Z", "CBT default feed failed");
   Assert_Cursor_Col (9, "CBT default should move one tab stop back");

   Feed_Text (ASCII.ESC & "[2Z", "CBT count feed failed");
   Assert_Cursor_Col (1, "CBT count should clamp at column one");

   Feed_Text (ASCII.ESC & "[3I", "CHT count feed failed");
   Assert_Cursor_Col (20, "CHT count should clamp at the last column");

   Feed_Text ((1 => ASCII.HT), "HT clamp feed failed");
   Assert_Cursor_Col (20, "HT should stay clamped at the last column");

   Feed_Text (ASCII.ESC & "c", "reset feed failed");
   Assert_Cursor_Col (1, "reset should return cursor to column one");

   Feed_Text (ASCII.ESC & "[5G" & ASCII.ESC & "H", "HTS feed failed");
   Assert_Cursor_Col (5, "HTS setup should leave cursor at custom stop");

   Feed_Text (ASCII.ESC & "[G" & (1 => ASCII.HT), "custom HT feed failed");
   Assert_Cursor_Col (5, "HT should move to custom tab stop");

   Feed_Text (ASCII.ESC & "[g" & ASCII.ESC & "[G" & (1 => ASCII.HT), "TBC current feed failed");
   Assert_Cursor_Col (9, "TBC current should remove custom tab stop");

   Feed_Text (ASCII.ESC & "[3g" & ASCII.ESC & "[G" & (1 => ASCII.HT), "TBC all feed failed");
   Assert_Cursor_Col (20, "TBC all should clamp HT to the last column");

   Feed_Text (ASCII.ESC & "c" & (1 => ASCII.HT), "reset tabs feed failed");
   Assert_Cursor_Col (9, "reset should restore default tab stops");

   Feed_Text
     (ASCII.ESC & "[5G" & ASCII.ESC & "H"
      & ASCII.ESC & "[13G" & ASCII.ESC & "H",
      "TBC parameter list setup feed failed");
   Feed_Text
     (ASCII.ESC & "[5G" & ASCII.ESC & "[0;3g" & ASCII.ESC & "[G"
      & (1 => ASCII.HT),
      "TBC parameter list feed failed");
   Assert_Cursor_Col (20, "TBC parameter list should clear all tab stops");

   declare
      Before : constant Natural :=
        Terminal.Core.Diagnostics (T).Unsupported_Sequence;
   begin
      Feed_Text
        (ASCII.ESC & "c"
         & ASCII.ESC & "[5G" & ASCII.ESC & "H"
         & ASCII.ESC & "[9;0g" & ASCII.ESC & "[G" & (1 => ASCII.HT),
         "TBC mixed unsupported parameter feed failed");
      Assert_Cursor_Col
        (9,
         "TBC mixed unsupported parameter should still clear supported stops");
      Assert
        (Terminal.Core.Diagnostics (T).Unsupported_Sequence = Before + 1,
         "TBC unsupported parameter should be diagnosed once");
   end;

   Terminal.Core.Initialize (T, 1, 20, 10, Init);
   Assert (Init = Terminal.Core.Ok, "C1 HTS initialize failed");
   Feed_Text (ASCII.ESC & "[5G", "C1 HTS setup cursor feed failed");
   Terminal.Core.Feed (T, (1 => 16#88#), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "C1 HTS feed failed");
   Assert_Cursor_Col (5, "C1 HTS should not move the cursor");

   Feed_Text (ASCII.ESC & "[G" & (1 => ASCII.HT), "C1 HTS custom tab feed failed");
   Assert_Cursor_Col (5, "HT should move to C1 HTS tab stop");
   Assert
     (Terminal.Core.Diagnostics (T).Malformed_UTF8 = 0,
      "C1 HTS should not count as malformed UTF-8");
end Core_Tabs_Smoke;

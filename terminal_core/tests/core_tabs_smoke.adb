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
end Core_Tabs_Smoke;

with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_Insert_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Common.Code_Point;
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
begin
   Terminal.Core.Initialize (T, 1, 6, 10, Init);
   Assert (Init = Terminal.Core.Ok, "initialize failed");

   Terminal.Core.Feed (T, To_Bytes ("abcd" & ASCII.ESC & "[2GX"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "replace feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#61#, "replace a");
      Assert (Terminal.Core.Cell_At (S, 1, 2).Text.Code_Point = 16#58#, "replace X");
      Assert (Terminal.Core.Cell_At (S, 1, 3).Text.Code_Point = 16#63#, "replace c");
      Assert (Terminal.Core.Cell_At (S, 1, 4).Text.Code_Point = 16#64#, "replace d");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 6, 10, Init);
   Assert (Init = Terminal.Core.Ok, "reinitialize failed");

   Terminal.Core.Feed
     (T,
      To_Bytes ("abcd" & ASCII.ESC & "[2G" & ASCII.ESC & "[4hX"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "insert feed failed");
   Assert (Terminal.Core.Modes (T).Insert_Mode, "insert mode should be enabled");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#61#, "insert a");
      Assert (Terminal.Core.Cell_At (S, 1, 2).Text.Code_Point = 16#58#, "insert X");
      Assert (Terminal.Core.Cell_At (S, 1, 3).Text.Code_Point = 16#62#, "insert b");
      Assert (Terminal.Core.Cell_At (S, 1, 4).Text.Code_Point = 16#63#, "insert c");
      Assert (Terminal.Core.Cell_At (S, 1, 5).Text.Code_Point = 16#64#, "insert d");
      Assert (S.Cursor.Col = 3, "insert cursor");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "[4l" & ASCII.ESC & "[3GY"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "replace-after-insert feed failed");
   Assert (not Terminal.Core.Modes (T).Insert_Mode, "insert mode should be disabled");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#61#, "final a");
      Assert (Terminal.Core.Cell_At (S, 1, 2).Text.Code_Point = 16#58#, "final X");
      Assert (Terminal.Core.Cell_At (S, 1, 3).Text.Code_Point = 16#59#, "final Y");
      Assert (Terminal.Core.Cell_At (S, 1, 4).Text.Code_Point = 16#63#, "final c");
      Assert (Terminal.Core.Cell_At (S, 1, 5).Text.Code_Point = 16#64#, "final d");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 6, 10, Init);
   Assert (Init = Terminal.Core.Ok, "SM/RM list initialize failed");

   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "[4;4h"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "SM list feed failed");
   Assert (Terminal.Core.Modes (T).Insert_Mode, "SM list should enable insert");
   Assert
     (Terminal.Core.Diagnostics (T).Unsupported_Sequence = 0,
      "known SM list should not increment diagnostics");

   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "[4;4l"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "RM list feed failed");
   Assert
     (not Terminal.Core.Modes (T).Insert_Mode,
      "RM list should disable insert");
   Assert
     (Terminal.Core.Diagnostics (T).Unsupported_Sequence = 0,
      "known RM list should not increment diagnostics");

   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "[4;20h"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "mixed SM list feed failed");
   Assert
     (Terminal.Core.Modes (T).Insert_Mode,
      "mixed SM list should still apply known insert mode");
   Assert
     (Terminal.Core.Diagnostics (T).Unsupported_Sequence = 1,
      "mixed SM list should diagnose unknown normal mode");
end Core_Insert_Smoke;

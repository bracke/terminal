with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_OSC_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Common.Code_Point;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;

   function To_Bytes (S : String) return Byte_Array is
      Result : Byte_Array (1 .. S'Length);
   begin
      for I in S'Range loop
         Result (I - S'First + 1) := Byte (Character'Pos (S (I)));
      end loop;
      return Result;
   end To_Bytes;

   T : Terminal.Core.Terminal;
   Init : Terminal.Core.Initialize_Status;
   Feed_Status : Terminal.Core.Feed_Status;
begin
   Terminal.Core.Initialize (T, 2, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "initialize failed");

   Terminal.Core.Feed
     (T,
      (1  => 16#1B#, 2 => Byte (Character'Pos (']')),
       3  => Byte (Character'Pos ('0')), 4 => Byte (Character'Pos (';')),
       5  => Byte (Character'Pos ('t')), 6 => Byte (Character'Pos ('i')),
       7  => Byte (Character'Pos ('t')), 8 => Byte (Character'Pos ('l')),
       9  => Byte (Character'Pos ('e')), 10 => 16#1B#,
       11 => Byte (Character'Pos ('\')), 12 => Byte (Character'Pos ('x'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "OSC ST feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#78#, "OSC payload leaked or x missing");
      Terminal.Core.Release (S);
   end;

   declare
      Title : constant Terminal.Core.Title_Text := Terminal.Core.Title (T);
   begin
      Assert (Title.Length = 5, "OSC 0 title length");
      Assert (Title.Text (1 .. Title.Length) = "title", "OSC 0 title text");
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "]2;editor" & ASCII.BEL),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "OSC BEL title feed failed");

   declare
      Title : constant Terminal.Core.Title_Text := Terminal.Core.Title (T);
   begin
      Assert (Title.Length = 6, "OSC 2 title length");
      Assert (Title.Text (1 .. Title.Length) = "editor", "OSC 2 title text");
   end;

   Terminal.Core.Feed
     (T,
      To_Bytes (ASCII.ESC & "]8;ignored" & ASCII.BEL),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "unknown OSC feed failed");

   declare
      Title : constant Terminal.Core.Title_Text := Terminal.Core.Title (T);
   begin
      Assert (Title.Length = 6, "unknown OSC must not clear title length");
      Assert
        (Title.Text (1 .. Title.Length) = "editor",
         "unknown OSC must not change title");
   end;
end Core_OSC_Smoke;

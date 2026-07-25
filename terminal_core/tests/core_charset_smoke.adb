with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_Charset_Smoke is
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
   Terminal.Core.Initialize (T, 2, 12, 100, Init);
   Assert (Init = Terminal.Core.Ok, "initialize failed");

   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "(0"
         & "lqk"
         & ASCII.ESC & "(B"
         & "x"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "G0 charset feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#250C#,
         "DEC l should map to upper-left corner");
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Text.Code_Point = 16#2500#,
         "DEC q should map to horizontal line");
      Assert
        (Terminal.Core.Cell_At (S, 1, 3).Text.Code_Point = 16#2510#,
         "DEC k should map to upper-right corner");
      Assert
        (Terminal.Core.Cell_At (S, 1, 4).Text.Code_Point = 16#78#,
         "ASCII designation should restore plain x");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 2, 12, 100, Init);
   Assert (Init = Terminal.Core.Ok, "G1 initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & ")0"
         & Character'Val (14)
         & "x"
         & Character'Val (15)
         & "x"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "G1 charset feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#2502#,
         "SO should select G1 DEC vertical line");
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Text.Code_Point = 16#78#,
         "SI should return to G0 ASCII");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 2, 12, 100, Init);
   Assert (Init = Terminal.Core.Ok, "G2 initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "*0"
         & "x"
         & ASCII.ESC & "N"
         & "x"
         & "x"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "G2 charset feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#78#,
         "G2 designation should not affect active G0 text");
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Text.Code_Point = 16#2502#,
         "SS2 should map next byte through G2 DEC charset");
      Assert
        (Terminal.Core.Cell_At (S, 1, 3).Text.Code_Point = 16#78#,
         "SS2 should affect only one byte");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 2, 12, 100, Init);
   Assert (Init = Terminal.Core.Ok, "G3 initialize failed");
   Terminal.Core.Feed
     (T,
      (1 => 16#1B#,
       2 => Byte (Character'Pos ('+')),
       3 => Byte (Character'Pos ('0')),
       4 => Byte (Character'Pos ('x')),
       5 => 16#8F#,
       6 => Byte (Character'Pos ('x')),
       7 => Byte (Character'Pos ('x'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "G3 charset feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#78#,
         "G3 designation should not affect active G0 text");
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Text.Code_Point = 16#2502#,
         "SS3 should map next byte through G3 DEC charset");
      Assert
        (Terminal.Core.Cell_At (S, 1, 3).Text.Code_Point = 16#78#,
         "SS3 should affect only one byte");
      Terminal.Core.Release (S);
   end;

   declare
      D : constant Terminal.Core.Diagnostic_Snapshot :=
        Terminal.Core.Diagnostics (T);
   begin
      Assert
        (D.Ignored_Escape = 0,
         "supported charset designations should not increment ignored escape");
   end;

   Terminal.Core.Initialize (T, 2, 12, 100, Init);
   Assert (Init = Terminal.Core.Ok, "save charset initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "(0"
         & ASCII.ESC & "7"
         & ASCII.ESC & "(B"
         & "x"
         & ASCII.ESC & "8"
         & "x"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "save charset feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#2502#,
         "restored G0 DEC charset should map x to vertical line");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 2, 12, 100, Init);
   Assert (Init = Terminal.Core.Ok, "soft reset charset initialize failed");
   Terminal.Core.Feed
     (T,
      To_Bytes
        (ASCII.ESC & "(0"
         & ASCII.ESC & "[!p"
         & "x"),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "soft reset charset feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#78#,
         "DECSTR should restore ASCII charset");
      Terminal.Core.Release (S);
   end;
end Core_Charset_Smoke;

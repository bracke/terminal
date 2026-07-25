with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_SGR_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Common.Code_Point;
   use type Terminal.Core.Color_Kind;
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
   Terminal.Core.Initialize (T, 2, 10, 100, Init);
   Assert (Init = Terminal.Core.Ok, "initialize failed");

   Terminal.Core.Feed
     (T,
      (1  => 16#1B#, 2 => Byte (Character'Pos ('[')),
       3  => Byte (Character'Pos ('3')), 4 => Byte (Character'Pos ('1')),
       5  => Byte (Character'Pos (';')), 6 => Byte (Character'Pos ('1')),
       7  => Byte (Character'Pos ('m')), 8 => Byte (Character'Pos ('x'))),
      Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      C : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 1);
   begin
      Assert (C.Text.Code_Point = 16#78#, "text");
      Assert (C.Style.Bold, "bold style");
      Assert (C.Style.Foreground.Kind = Terminal.Core.Indexed, "indexed foreground");
      Assert (C.Style.Foreground.Index = 1, "red foreground index");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 2, 100, Init);
   Assert (Init = Terminal.Core.Ok, "colon SGR initialize failed");
   Feed_Text
     (ASCII.ESC & "[38:5:196mA" & ASCII.ESC & "[48:2:1:2:3mB",
      "colon SGR feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      A : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 1);
      B : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 2);
   begin
      Assert
        (A.Style.Foreground.Kind = Terminal.Core.Indexed,
         "colon indexed foreground kind");
      Assert
        (A.Style.Foreground.Index = 196,
         "colon indexed foreground value");
      Assert
        (B.Style.Background.Kind = Terminal.Core.RGB,
         "colon truecolor background kind");
      Assert
        (B.Style.Background.R = 1
         and then B.Style.Background.G = 2
         and then B.Style.Background.B = 3,
         "colon truecolor background values");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 2, 100, Init);
   Assert (Init = Terminal.Core.Ok, "SGR aliases initialize failed");
   Feed_Text
     (ASCII.ESC & "[1mA" & ASCII.ESC & "[21;29mB",
      "SGR aliases feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      A : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 1);
      B : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 2);
      D : constant Terminal.Core.Diagnostic_Snapshot :=
        Terminal.Core.Diagnostics (T);
   begin
      Assert (A.Style.Bold, "SGR 1 should make first cell bold");
      Assert (not B.Style.Bold, "SGR 21 should clear bold");
      Assert
        (D.Unsupported_Sequence = 0,
         "SGR 21/29 should not increment unsupported diagnostics");
      Terminal.Core.Release (S);
   end;
end Core_SGR_Smoke;

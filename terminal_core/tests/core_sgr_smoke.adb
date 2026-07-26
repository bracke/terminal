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
     (ASCII.ESC & "[1;2mA" & ASCII.ESC & "[21;22;29mB",
      "SGR aliases feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      A : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 1);
      B : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 2);
      D : constant Terminal.Core.Diagnostic_Snapshot :=
        Terminal.Core.Diagnostics (T);
   begin
      Assert (A.Style.Bold, "SGR 1 should make first cell bold");
      Assert (A.Style.Faint, "SGR 2 should make first cell faint");
      Assert (not B.Style.Bold, "SGR 21 should clear bold");
      Assert (not B.Style.Faint, "SGR 22 should clear faint");
      Assert
        (D.Unsupported_Sequence = 0,
         "SGR 21/22/29 should not increment unsupported diagnostics");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 2, 100, Init);
   Assert (Init = Terminal.Core.Ok, "SGR font selectors initialize failed");
   Feed_Text
     (ASCII.ESC & "[11;19mA" & ASCII.ESC & "[10mB",
      "SGR font selectors feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      A : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 1);
      B : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 2);
      D : constant Terminal.Core.Diagnostic_Snapshot :=
        Terminal.Core.Diagnostics (T);
   begin
      Assert
        (A.Text.Code_Point = 16#41# and then B.Text.Code_Point = 16#42#,
         "SGR font selectors should not leak into text");
      Assert
        (D.Unsupported_Sequence = 0,
         "SGR font selectors should not increment unsupported diagnostics");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 4, 100, Init);
   Assert (Init = Terminal.Core.Ok, "SGR underline color initialize failed");
   Feed_Text
     (ASCII.ESC & "[58;5;196mA"
      & ASCII.ESC & "[58;2;1;2;3mB"
      & ASCII.ESC & "[58:5:42mC"
      & ASCII.ESC & "[59mD",
      "SGR underline color feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      A : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 1);
      B : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 2);
      C : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 3);
      D_Cell : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 4);
      D : constant Terminal.Core.Diagnostic_Snapshot :=
        Terminal.Core.Diagnostics (T);
   begin
      Assert
        (A.Text.Code_Point = 16#41#
         and then B.Text.Code_Point = 16#42#
         and then C.Text.Code_Point = 16#43#
         and then D_Cell.Text.Code_Point = 16#44#,
         "SGR underline color selectors should not leak into text");
      Assert
        (A.Style.Underline_Color.Kind = Terminal.Core.Indexed
         and then A.Style.Underline_Color.Index = 196,
         "SGR indexed underline color");
      Assert
        (B.Style.Underline_Color.Kind = Terminal.Core.RGB
         and then B.Style.Underline_Color.R = 1
         and then B.Style.Underline_Color.G = 2
         and then B.Style.Underline_Color.B = 3,
         "SGR truecolor underline color");
      Assert
        (C.Style.Underline_Color.Kind = Terminal.Core.Indexed
         and then C.Style.Underline_Color.Index = 42,
         "colon SGR indexed underline color");
      Assert
        (D_Cell.Style.Underline_Color.Kind = Terminal.Core.Default,
         "SGR 59 should reset underline color");
      Assert
        (D.Unsupported_Sequence = 0,
         "SGR underline color selectors should not increment diagnostics");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Feed (T, To_Bytes (ASCII.ESC & "[58;4m"), Feed_Status);
   Assert
     (Feed_Status = Terminal.Core.Ok,
      "malformed SGR underline color feed failed");
   Assert
     (Terminal.Core.Diagnostics (T).Unsupported_Sequence = 1,
      "malformed SGR underline color should be diagnosed");

   Terminal.Core.Initialize (T, 1, 3, 100, Init);
   Assert (Init = Terminal.Core.Ok, "SGR underline style initialize failed");
   Feed_Text
     (ASCII.ESC & "[4:2mA"
      & ASCII.ESC & "[4:0mB"
      & ASCII.ESC & "[4:5mC",
      "SGR underline style feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      A : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 1);
      B : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 2);
      C : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 3);
      D : constant Terminal.Core.Diagnostic_Snapshot :=
        Terminal.Core.Diagnostics (T);
   begin
      Assert (A.Style.Underline, "SGR 4:2 should enable underline");
      Assert (not A.Style.Faint, "SGR 4:2 should not enable faint");
      Assert (not B.Style.Underline, "SGR 4:0 should disable underline");
      Assert (C.Style.Underline, "SGR 4:5 should enable underline");
      Assert
        (D.Unsupported_Sequence = 0,
         "SGR underline styles should not increment diagnostics");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 2, 100, Init);
   Assert (Init = Terminal.Core.Ok, "SGR rapid blink initialize failed");
   Feed_Text
     (ASCII.ESC & "[6mC",
      "SGR rapid blink feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      C : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 1);
      D : constant Terminal.Core.Diagnostic_Snapshot :=
        Terminal.Core.Diagnostics (T);
   begin
      Assert
        (C.Text.Code_Point = 16#43#,
         "SGR rapid blink should not suppress text");
      Assert (C.Style.Blink, "SGR 6 should enable blink");
      Assert
        (D.Unsupported_Sequence = 0,
         "SGR 6 should not increment unsupported diagnostics");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 2, 100, Init);
   Assert (Init = Terminal.Core.Ok, "SGR blink initialize failed");
   Feed_Text
     (ASCII.ESC & "[5mA" & ASCII.ESC & "[25mB",
      "SGR blink feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      A : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 1);
      B : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 2);
      D : constant Terminal.Core.Diagnostic_Snapshot :=
        Terminal.Core.Diagnostics (T);
   begin
      Assert (A.Style.Blink, "SGR 5 should enable blink");
      Assert (not B.Style.Blink, "SGR 25 should disable blink");
      Assert
        (D.Unsupported_Sequence = 0,
         "SGR 5/25 should not increment unsupported diagnostics");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 2, 100, Init);
   Assert (Init = Terminal.Core.Ok, "SGR overline initialize failed");
   Feed_Text
     (ASCII.ESC & "[53mA" & ASCII.ESC & "[55mB",
      "SGR overline feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      A : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 1);
      B : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 2);
      D : constant Terminal.Core.Diagnostic_Snapshot :=
        Terminal.Core.Diagnostics (T);
   begin
      Assert (A.Style.Overline, "SGR 53 should enable overline");
      Assert (not B.Style.Overline, "SGR 55 should disable overline");
      Assert
        (D.Unsupported_Sequence = 0,
         "SGR 53/55 should not increment unsupported diagnostics");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 2, 100, Init);
   Assert (Init = Terminal.Core.Ok, "SGR conceal initialize failed");
   Feed_Text
     (ASCII.ESC & "[8mA" & ASCII.ESC & "[28mB",
      "SGR conceal feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      A : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 1);
      B : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 2);
      D : constant Terminal.Core.Diagnostic_Snapshot :=
        Terminal.Core.Diagnostics (T);
   begin
      Assert (A.Style.Conceal, "SGR 8 should enable conceal");
      Assert (not B.Style.Conceal, "SGR 28 should disable conceal");
      Assert
        (D.Unsupported_Sequence = 0,
         "SGR 8/28 should not increment unsupported diagnostics");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 2, 100, Init);
   Assert (Init = Terminal.Core.Ok, "SGR strikethrough initialize failed");
   Feed_Text
     (ASCII.ESC & "[9mA" & ASCII.ESC & "[29mB",
      "SGR strikethrough feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      A : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 1);
      B : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 2);
      D : constant Terminal.Core.Diagnostic_Snapshot :=
        Terminal.Core.Diagnostics (T);
   begin
      Assert (A.Style.Strikethrough, "SGR 9 should enable strikethrough");
      Assert (not B.Style.Strikethrough, "SGR 29 should disable strikethrough");
      Assert
        (D.Unsupported_Sequence = 0,
         "SGR 9/29 should not increment unsupported diagnostics");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 2, 100, Init);
   Assert (Init = Terminal.Core.Ok, "ESC save style initialize failed");
   Feed_Text
     (ASCII.ESC & "[31;1m"
      & ASCII.ESC & "7"
      & ASCII.ESC & "[0m"
      & ASCII.ESC & "8"
      & "X",
      "ESC save style feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      X : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 1);
   begin
      Assert (X.Style.Bold, "ESC restore should restore bold");
      Assert
        (X.Style.Foreground.Kind = Terminal.Core.Indexed
         and then X.Style.Foreground.Index = 1,
         "ESC restore should restore foreground");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 2, 100, Init);
   Assert (Init = Terminal.Core.Ok, "CSI save style initialize failed");
   Feed_Text
     (ASCII.ESC & "[3;4m"
      & ASCII.ESC & "[s"
      & ASCII.ESC & "[0m"
      & ASCII.ESC & "[u"
      & "Y",
      "CSI save style feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      Y : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 1);
   begin
      Assert (Y.Style.Italic, "CSI restore should restore italic");
      Assert (Y.Style.Underline, "CSI restore should restore underline");
      Terminal.Core.Release (S);
   end;
end Core_SGR_Smoke;

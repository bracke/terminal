with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_Edit_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Common.Code_Point;
   use type Terminal.Core.Cell_Kind;
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

   procedure Assert_Row
     (S       : Terminal.Core.Render_Snapshot;
      Row     : Positive;
      Pattern : String;
      Message : String)
   is
      Cell : Terminal.Core.Cell;
   begin
      for Col in Pattern'Range loop
         Cell := Terminal.Core.Cell_At (S, Row, Col - Pattern'First + 1);
         if Pattern (Col) = ' ' then
            Assert (Cell.Kind = Terminal.Core.Empty, Message & " blank" & Natural'Image (Col));
         else
            Assert
              (Cell.Text.Code_Point = Terminal.Common.Code_Point (Character'Pos (Pattern (Col))),
               Message & " col" & Natural'Image (Col));
         end if;
      end loop;
   end Assert_Row;
begin
   Terminal.Core.Initialize (T, 1, 6, 10, Init);
   Assert (Init = Terminal.Core.Ok, "initialize ICH failed");
   Feed_Text ("abcd" & ASCII.ESC & "[2G" & ASCII.ESC & "[2@", "ICH feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert_Row (S, 1, "a  bcd", "ICH");
      Assert (S.Cursor.Col = 2, "ICH cursor should not move");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 6, 10, Init);
   Assert (Init = Terminal.Core.Ok, "initialize DCH failed");
   Feed_Text ("abcdef" & ASCII.ESC & "[3G" & ASCII.ESC & "[2P", "DCH feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert_Row (S, 1, "abef  ", "DCH");
      Assert (S.Cursor.Col = 3, "DCH cursor should not move");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 6, 10, Init);
   Assert (Init = Terminal.Core.Ok, "initialize ECH failed");
   Feed_Text ("abcdef" & ASCII.ESC & "[3G" & ASCII.ESC & "[2X", "ECH feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert_Row (S, 1, "ab  ef", "ECH");
      Assert (S.Cursor.Col = 3, "ECH cursor should not move");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 4, 5, 10, Init);
   Assert (Init = Terminal.Core.Ok, "initialize IL/DL failed");
   Feed_Text
     ("11111" & ASCII.CR & ASCII.LF
      & "22222" & ASCII.CR & ASCII.LF
      & "33333" & ASCII.CR & ASCII.LF
      & "44444"
      & ASCII.ESC & "[2;3r" & ASCII.ESC & "[2H" & ASCII.ESC & "[L",
      "IL feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert_Row (S, 1, "11111", "IL row1");
      Assert_Row (S, 2, "     ", "IL row2");
      Assert_Row (S, 3, "22222", "IL row3");
      Assert_Row (S, 4, "44444", "IL row4");
      Terminal.Core.Release (S);
   end;

   Feed_Text (ASCII.ESC & "[2H" & ASCII.ESC & "[M", "DL feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert_Row (S, 1, "11111", "DL row1");
      Assert_Row (S, 2, "22222", "DL row2");
      Assert_Row (S, 3, "     ", "DL row3");
      Assert_Row (S, 4, "44444", "DL row4");
      Assert (Terminal.Core.Scrollback_Row_Count (T) = 0, "DL must not append scrollback");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 6, 10, Init);
   Assert (Init = Terminal.Core.Ok, "initialize REP failed");
   Feed_Text ("a" & ASCII.ESC & "[3b", "REP count feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert_Row (S, 1, "aaaa  ", "REP count");
      Assert (S.Cursor.Col = 5, "REP count cursor");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 6, 10, Init);
   Assert (Init = Terminal.Core.Ok, "initialize REP default failed");
   Feed_Text ("b" & ASCII.ESC & "[b", "REP default feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert_Row (S, 1, "bb    ", "REP default");
      Assert (S.Cursor.Col = 3, "REP default cursor");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 6, 10, Init);
   Assert (Init = Terminal.Core.Ok, "initialize REP empty failed");
   Feed_Text (ASCII.ESC & "[3b", "REP empty feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert_Row (S, 1, "      ", "REP empty");
      Assert (S.Cursor.Col = 1, "REP empty cursor");
      Terminal.Core.Release (S);
   end;
end Core_Edit_Smoke;

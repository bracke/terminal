with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_Wide_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Common.Code_Point;
   use type Terminal.Core.Cell_Kind;
   use type Terminal.Core.Cell_Width;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;

   T : Terminal.Core.Terminal;
   Init : Terminal.Core.Initialize_Status;
   Feed_Status : Terminal.Core.Feed_Status;

   procedure Feed_Bytes (Data : Byte_Array; Message : String) is
   begin
      Terminal.Core.Feed (T, Data, Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, Message);
   end Feed_Bytes;

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
      Feed_Bytes (To_Bytes (Text), Message);
   end Feed_Text;

   procedure Feed_A_Wide_B is
   begin
      Feed_Bytes
        ((1 => Byte (Character'Pos ('a')),
          2 => 16#E4#,
          3 => 16#B8#,
          4 => 16#80#,
          5 => Byte (Character'Pos ('b'))),
         "wide feed failed");
   end Feed_A_Wide_B;

   procedure Assert_Empty
     (S       : Terminal.Core.Render_Snapshot;
      Col     : Positive;
      Message : String)
   is
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, Col).Kind = Terminal.Core.Empty,
         Message);
   end Assert_Empty;

   procedure Assert_Char
     (S       : Terminal.Core.Render_Snapshot;
      Col     : Positive;
      CP      : Terminal.Common.Code_Point;
      Message : String)
   is
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, Col).Text.Code_Point = CP,
         Message);
   end Assert_Char;
begin
   Terminal.Core.Initialize (T, 1, 6, 10, Init);
   Assert (Init = Terminal.Core.Ok, "initialize wide placement failed");
   Feed_A_Wide_B;

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      Wide : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 2);
      Continuation : constant Terminal.Core.Cell :=
        Terminal.Core.Cell_At (S, 1, 3);
   begin
      Assert_Char (S, 1, 16#61#, "wide placement prefix");
      Assert (Wide.Text.Code_Point = 16#4E00#, "wide code point");
      Assert (Wide.Text.Width = Terminal.Core.Width_Two, "wide width");
      Assert
        (Continuation.Kind = Terminal.Core.Wide_Continuation,
         "wide continuation");
      Assert_Char (S, 4, 16#62#, "wide placement suffix");
      Assert (S.Cursor.Col = 5, "wide placement cursor");
      Terminal.Core.Release (S);
   end;

   Feed_Text (ASCII.ESC & "[3GX", "wide overwrite feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert_Empty (S, 2, "overwriting continuation clears wide head");
      Assert_Char (S, 3, 16#58#, "overwriting continuation writes new char");
      Assert_Char (S, 4, 16#62#, "overwriting continuation keeps suffix");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 6, 10, Init);
   Assert (Init = Terminal.Core.Ok, "initialize wide erase head failed");
   Feed_A_Wide_B;
   Feed_Text (ASCII.ESC & "[2G" & ASCII.ESC & "[X", "wide erase head feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert_Empty (S, 2, "erasing wide head clears head");
      Assert_Empty (S, 3, "erasing wide head clears continuation");
      Assert_Char (S, 4, 16#62#, "erasing wide head keeps suffix");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 6, 10, Init);
   Assert (Init = Terminal.Core.Ok, "initialize wide erase continuation failed");
   Feed_A_Wide_B;
   Feed_Text
     (ASCII.ESC & "[3G" & ASCII.ESC & "[X",
      "wide erase continuation feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert_Empty (S, 2, "erasing continuation clears wide head");
      Assert_Empty (S, 3, "erasing continuation clears continuation");
      Assert_Char (S, 4, 16#62#, "erasing continuation keeps suffix");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 6, 10, Init);
   Assert (Init = Terminal.Core.Ok, "initialize wide DCH head failed");
   Feed_A_Wide_B;
   Feed_Text
     (ASCII.ESC & "[2G" & ASCII.ESC & "[P",
      "wide DCH head feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert_Char (S, 1, 16#61#, "DCH head keeps prefix");
      Assert_Empty (S, 2, "DCH head clears split continuation");
      Assert_Char (S, 3, 16#62#, "DCH head shifts suffix");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 6, 10, Init);
   Assert (Init = Terminal.Core.Ok, "initialize wide DCH continuation failed");
   Feed_A_Wide_B;
   Feed_Text
     (ASCII.ESC & "[3G" & ASCII.ESC & "[P",
      "wide DCH continuation feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert_Char (S, 1, 16#61#, "DCH continuation keeps prefix");
      Assert_Empty (S, 2, "DCH continuation clears split head");
      Assert_Char (S, 3, 16#62#, "DCH continuation shifts suffix");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 6, 10, Init);
   Assert (Init = Terminal.Core.Ok, "initialize wide ICH continuation failed");
   Feed_A_Wide_B;
   Feed_Text
     (ASCII.ESC & "[3G" & ASCII.ESC & "[@",
      "wide ICH continuation feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert_Char (S, 1, 16#61#, "ICH continuation keeps prefix");
      Assert_Empty (S, 2, "ICH continuation clears split head");
      Assert_Empty (S, 3, "ICH continuation inserts blank");
      Assert_Empty (S, 4, "ICH continuation clears split continuation");
      Assert_Char (S, 5, 16#62#, "ICH continuation shifts suffix");
      Terminal.Core.Release (S);
   end;
end Core_Wide_Smoke;

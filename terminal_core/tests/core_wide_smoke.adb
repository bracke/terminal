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
   Assert
     (Terminal.Core.Is_Renderable_Attachment (16#0301#),
      "combining acute should be renderable as an attachment");
   Assert
     (not Terminal.Core.Is_Renderable_Attachment (16#200D#),
      "ZWJ should remain a non-rendering attachment");
   Assert
     (not Terminal.Core.Is_Renderable_Attachment (16#FE0F#),
      "variation selector should remain a non-rendering attachment");

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

   Terminal.Core.Initialize (T, 1, 4, 10, Init);
   Assert (Init = Terminal.Core.Ok, "initialize cluster overflow failed");
   Feed_Bytes
     ((1  => Byte (Character'Pos ('a')),
       2  => 16#CC#, 3  => 16#80#,
       4  => 16#CC#, 5  => 16#81#,
       6  => 16#CC#, 7  => 16#82#,
       8  => 16#CC#, 9  => 16#83#,
       10 => 16#CC#, 11 => 16#84#,
       12 => 16#CC#, 13 => 16#85#,
       14 => 16#CC#, 15 => 16#86#,
       16 => 16#CC#, 17 => 16#87#,
       18 => 16#CC#, 19 => 16#88#),
      "cluster overflow feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      A : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 1);
      D : constant Terminal.Core.Diagnostic_Snapshot :=
        Terminal.Core.Diagnostics (T);
   begin
      Assert (A.Text.Code_Point = 16#61#, "cluster overflow base");
      Assert
        (A.Text.Attachment_Count = Terminal.Core.Max_Cluster_Attachments,
         "cluster should keep bounded attachments");
      Assert
        (D.Text_Cluster_Overflow = 1,
         "cluster overflow should be diagnosed");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 8, 10, Init);
   Assert (Init = Terminal.Core.Ok, "initialize zero width failed");
   Feed_Bytes
     ((1  => Byte (Character'Pos ('a')),
       2  => 16#CC#, 3  => 16#81#,
       4  => Byte (Character'Pos ('b')),
       5  => 16#E2#, 6  => 16#80#, 7  => 16#8D#,
       8  => 16#EF#, 9  => 16#B8#, 10 => 16#8F#,
       11 => Byte (Character'Pos ('c')),
       12 => 16#E2#, 13 => 16#83#, 14 => 16#9D#,
       15 => Byte (Character'Pos ('d'))),
      "zero width feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      A : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 1);
      B : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 2);
      C : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 3);
   begin
      Assert_Char (S, 1, 16#61#, "zero width keeps a");
      Assert_Char (S, 2, 16#62#, "combining acute should not occupy a cell");
      Assert_Char (S, 3, 16#63#, "ZWJ and VS16 should not occupy cells");
      Assert_Char (S, 4, 16#64#, "enclosing mark should not occupy a cell");
      Assert (A.Text.Attachment_Count = 1, "acute should attach to a");
      Assert (A.Text.Attachments (1) = 16#0301#, "a acute attachment");
      Assert (B.Text.Attachment_Count = 2, "ZWJ and VS16 should attach to b");
      Assert (B.Text.Attachments (1) = 16#200D#, "b ZWJ attachment");
      Assert (B.Text.Attachments (2) = 16#FE0F#, "b VS16 attachment");
      Assert (C.Text.Attachment_Count = 1, "enclosing mark should attach to c");
      Assert (C.Text.Attachments (1) = 16#20DD#, "c enclosing attachment");
      Assert (S.Cursor.Col = 5, "zero width cursor");
      Assert
        (Terminal.Core.Diagnostics (T).Malformed_UTF8 = 0,
         "zero width fixtures should be valid UTF-8");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 8, 10, Init);
   Assert (Init = Terminal.Core.Ok, "initialize zero width format failed");
   Feed_Bytes
     ((1  => Byte (Character'Pos ('w')),
       2  => 16#CD#, 3  => 16#8F#,
       4  => Byte (Character'Pos ('x')),
       5  => 16#E2#, 6  => 16#81#, 7  => 16#A0#,
       8  => Byte (Character'Pos ('y')),
       9  => 16#EF#, 10 => 16#BB#, 11 => 16#BF#,
       12 => Byte (Character'Pos ('z')),
       13 => 16#F3#, 14 => 16#A0#, 15 => 16#84#, 16 => 16#80#),
      "zero width format feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      W : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 1);
      X : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 2);
      Y : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 3);
      Z : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 4);
   begin
      Assert_Char (S, 1, 16#77#, "combining grapheme joiner keeps w");
      Assert_Char (S, 2, 16#78#, "word joiner should not occupy a cell");
      Assert_Char (S, 3, 16#79#, "BOM should not occupy a cell");
      Assert_Char (S, 4, 16#7A#, "variation selector should not occupy a cell");
      Assert (W.Text.Attachment_Count = 1, "CGJ should attach to w");
      Assert (W.Text.Attachments (1) = 16#034F#, "w CGJ attachment");
      Assert (X.Text.Attachment_Count = 1, "word joiner should attach to x");
      Assert (X.Text.Attachments (1) = 16#2060#, "x word joiner attachment");
      Assert (Y.Text.Attachment_Count = 1, "BOM should attach to y");
      Assert (Y.Text.Attachments (1) = 16#FEFF#, "y BOM attachment");
      Assert (Z.Text.Attachment_Count = 1, "VS17 should attach to z");
      Assert (Z.Text.Attachments (1) = 16#E0100#, "z VS17 attachment");
      Assert (S.Cursor.Col = 5, "zero width format cursor");
      Assert
        (Terminal.Core.Diagnostics (T).Malformed_UTF8 = 0,
         "zero width format fixtures should be valid UTF-8");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 6, 10, Init);
   Assert (Init = Terminal.Core.Ok, "initialize supplementary CJK failed");
   Feed_Bytes
     ((1 => Byte (Character'Pos ('a')),
       2 => 16#F0#, 3 => 16#A0#, 4 => 16#80#, 5 => 16#80#,
       6 => Byte (Character'Pos ('b'))),
      "supplementary CJK feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      Wide : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 2);
      Continuation : constant Terminal.Core.Cell :=
        Terminal.Core.Cell_At (S, 1, 3);
   begin
      Assert_Char (S, 1, 16#61#, "supplementary CJK prefix");
      Assert (Wide.Text.Code_Point = 16#20000#, "supplementary CJK code point");
      Assert (Wide.Text.Width = Terminal.Core.Width_Two, "supplementary CJK width");
      Assert
        (Continuation.Kind = Terminal.Core.Wide_Continuation,
         "supplementary CJK continuation");
      Assert_Char (S, 4, 16#62#, "supplementary CJK suffix");
      Assert (S.Cursor.Col = 5, "supplementary CJK cursor");
      Terminal.Core.Release (S);
   end;
end Core_Wide_Smoke;

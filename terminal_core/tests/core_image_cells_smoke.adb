with AUnit.Assertions;
with Terminal.Common;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_Image_Cells_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Common.Code_Point;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Graphics_ID;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.Core.Resize_Status;

   T      : Terminal.Core.Terminal;
   Init   : Terminal.Core.Initialize_Status;
   Feed   : Terminal.Core.Feed_Status;

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   procedure Feed_Text (Text : String) is
   begin
      Terminal.Core.Feed (T, To_Bytes (Text), Feed);
      Assert (Feed = Terminal.Core.Ok, "text feed");
   end Feed_Text;

   procedure Feed_Code_Point (CP : Terminal.Common.Code_Point) is
      Value  : constant Natural := Natural (CP);
      Bytes  : Byte_Array (1 .. 4) := (others => 0);
      Length : Positive;
   begin
      if Value <= 16#7F# then
         Length := 1;
         Bytes (1) := Byte (Value);
      elsif Value <= 16#7FF# then
         Length := 2;
         Bytes (1) := Byte (16#C0# + Value / 64);
         Bytes (2) := Byte (16#80# + Value mod 64);
      elsif Value <= 16#FFFF# then
         Length := 3;
         Bytes (1) := Byte (16#E0# + Value / 4_096);
         Bytes (2) := Byte (16#80# + (Value / 64) mod 64);
         Bytes (3) := Byte (16#80# + Value mod 64);
      else
         Length := 4;
         Bytes (1) := Byte (16#F0# + Value / 262_144);
         Bytes (2) := Byte (16#80# + (Value / 4_096) mod 64);
         Bytes (3) := Byte (16#80# + (Value / 64) mod 64);
         Bytes (4) := Byte (16#80# + Value mod 64);
      end if;

      Terminal.Core.Feed (T, Bytes (1 .. Length), Feed);
      Assert (Feed = Terminal.Core.Ok, "code point feed");
   end Feed_Code_Point;

   procedure Feed_Placeholder
     (Row_Diacritic    : Terminal.Common.Code_Point := 0;
      Column_Diacritic : Terminal.Common.Code_Point := 0;
      High_Diacritic   : Terminal.Common.Code_Point := 0)
   is
   begin
      Feed_Code_Point (Terminal.Core.Kitty_Image_Placeholder);
      if Row_Diacritic /= 0 then
         Feed_Code_Point (Row_Diacritic);
      end if;
      if Column_Diacritic /= 0 then
         Feed_Code_Point (Column_Diacritic);
      end if;
      if High_Diacritic /= 0 then
         Feed_Code_Point (High_Diacritic);
      end if;
   end Feed_Placeholder;
begin
   Terminal.Core.Initialize (T, 2, 8, 100, Init);
   Assert (Init = Terminal.Core.Ok, "initialize");

   Feed_Text (ASCII.ESC & "[38;2;1;2;3;58;2;4;5;6m");
   Feed_Placeholder
     (Row_Diacritic    => 16#030D#,
      Column_Diacritic => 16#030E#,
      High_Diacritic   => 16#0310#);

   declare
      S    : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      Cell : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 1);
   begin
      Assert (S.Image_Cell_Count = 1, "snapshot placeholder count");
      Assert (Cell.Image.Is_Placeholder, "placeholder classification");
      Assert (Cell.Image.Image_ID_Valid, "RGB image ID validity");
      Assert
        (Cell.Image.Image_ID = 16#0301_0203#,
         "RGB plus high-byte image ID");
      Assert
        (Cell.Image.Placement_ID = 16#0004_0506#,
         "underline-color placement ID");
      Assert
        (Cell.Image.Image_Row = 1 and then Cell.Image.Image_Column = 2,
         "explicit placeholder coordinates");
      Assert
        (Cell.Image.Row_Specified
         and then Cell.Image.Column_Specified
         and then Cell.Image.High_Byte_Specified,
         "explicit placeholder metadata flags");
      Assert
        (Cell.Text.Code_Point = Terminal.Core.Kitty_Image_Placeholder
         and then Cell.Text.Attachment_Count = 3,
         "placeholder remains an ordinary text cluster");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 8, 100, Init);
   Assert (Init = Terminal.Core.Ok, "inheritance initialize");
   Feed_Text (ASCII.ESC & "[38;5;42;58;5;7m");
   Feed_Placeholder (16#0305#, 16#0305#, 16#030E#);
   Feed_Placeholder (16#0305#, 16#030D#);
   Feed_Placeholder;

   declare
      S     : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      First : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 1);
      Second : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 2);
      Third : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 3);
   begin
      Assert (S.Image_Cell_Count = 3, "inherited placeholder count");
      Assert
        (First.Image.Image_ID = 16#0200_002A#
         and then First.Image.Image_Row = 0
         and then First.Image.Image_Column = 0,
         "indexed image ID and explicit origin");
      Assert
        (Second.Image.Image_ID = First.Image.Image_ID
         and then Second.Image.Image_Row = 0
         and then Second.Image.Image_Column = 1
         and then not Second.Image.High_Byte_Specified,
         "row and column inherit the omitted high byte");
      Assert
        (Third.Image.Image_ID = First.Image.Image_ID
         and then Third.Image.Image_Row = 0
         and then Third.Image.Image_Column = 2
         and then not Third.Image.Row_Specified
         and then not Third.Image.Column_Specified,
         "empty metadata inherits row and next column");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 4, 100, Init);
   Assert (Init = Terminal.Core.Ok, "full diacritic table initialize");
   Feed_Text (ASCII.ESC & "[38;5;1m");
   Feed_Placeholder (16#1D244#);
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      Cell : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 1);
   begin
      Assert
        (Cell.Image.Image_Row = 296 and then Cell.Image.Row_Specified,
         "last official row/column diacritic maps to 296");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 1, 4, 100, Init);
   Assert (Init = Terminal.Core.Ok, "ordinary cluster initialize");
   Feed_Text ("A");
   Feed_Code_Point (16#0305#);
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      Cell : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 1, 1);
   begin
      Assert
        (S.Image_Cell_Count = 0
         and then not Cell.Image.Is_Placeholder
         and then Cell.Text.Attachment_Count = 1
         and then Cell.Text.Attachments (1) = 16#0305#,
         "ordinary combining clusters are unchanged");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 2, 5, 100, Init);
   Assert (Init = Terminal.Core.Ok, "screen operation initialize");
   Feed_Text (ASCII.ESC & "[38;5;42mX");
   Feed_Placeholder (16#030D#, 16#030E#);
   Feed_Text (ASCII.ESC & "[1G" & ASCII.ESC & "[@");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 3).Image.Is_Placeholder,
         "insert-character preserves placeholder metadata");
      Terminal.Core.Release (S);
   end;
   Feed_Text (ASCII.ESC & "[1G" & ASCII.ESC & "[P");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Image.Is_Placeholder,
         "delete-character preserves placeholder metadata");
      Terminal.Core.Release (S);
   end;

   declare
      Resize_Result : Terminal.Core.Resize_Status;
      S : Terminal.Core.Render_Snapshot;
   begin
      Terminal.Core.Resize (T, 3, 6, Resize_Result);
      Assert (Resize_Result = Terminal.Core.Ok, "placeholder resize");
      S := Terminal.Core.Snapshot (T);
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Image.Is_Placeholder
         and then Terminal.Core.Cell_At (S, 1, 2).Image.Image_ID = 42,
         "resize preserves placeholder metadata");
      Terminal.Core.Release (S);
   end;

   Feed_Text (ASCII.ESC & "[?1049h");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (not Terminal.Core.Cell_At (S, 1, 2).Image.Is_Placeholder,
         "alternate screen starts without primary placeholder metadata");
      Terminal.Core.Release (S);
   end;
   Feed_Text (ASCII.ESC & "[38;5;7m");
   Feed_Placeholder (16#0305#, 16#0305#);
   Feed_Text (ASCII.ESC & "[?1049l");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 2).Image.Is_Placeholder
         and then Terminal.Core.Cell_At (S, 1, 2).Image.Image_ID = 42,
         "primary placeholder metadata survives alternate screen");
      Terminal.Core.Release (S);
   end;

   Feed_Text (ASCII.ESC & "[1;2H" & ASCII.ESC & "[X");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (S.Image_Cell_Count = 0
         and then not Terminal.Core.Cell_At (S, 1, 2).Image.Is_Placeholder,
         "erase clears placeholder metadata");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 4, 4, 100, Init);
   Assert (Init = Terminal.Core.Ok, "line operation initialize");
   Feed_Text (ASCII.ESC & "[38;5;42m" & ASCII.ESC & "[2;1H");
   Feed_Placeholder (16#030D#, 16#030E#);
   Feed_Text (ASCII.ESC & "[1;1H" & ASCII.ESC & "[L");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      Cell : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 3, 1);
   begin
      Assert
        (Cell.Image.Is_Placeholder
         and then Cell.Image.Image_ID = 42
         and then Cell.Image.Image_Row = 1
         and then Cell.Image.Image_Column = 2,
         "insert-line moves resolved placeholder metadata with its cell");
      Terminal.Core.Release (S);
   end;
   Feed_Text (ASCII.ESC & "[1;1H" & ASCII.ESC & "[M");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      Cell : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 2, 1);
   begin
      Assert
        (Cell.Image.Is_Placeholder
         and then Cell.Image.Image_ID = 42
         and then Cell.Image.Image_Row = 1
         and then Cell.Image.Image_Column = 2,
         "delete-line moves resolved placeholder metadata with its cell");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 4, 4, 100, Init);
   Assert (Init = Terminal.Core.Ok, "margin scroll initialize");
   Feed_Text (ASCII.ESC & "[38;5;42m" & ASCII.ESC & "[3;1H");
   Feed_Placeholder (16#030D#, 16#030E#);
   Feed_Text
     (ASCII.ESC & "[2;4r" & ASCII.ESC & "[4;1H" & ASCII.LF);
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      Cell : constant Terminal.Core.Cell := Terminal.Core.Cell_At (S, 2, 1);
   begin
      Assert
        (Cell.Image.Is_Placeholder
         and then Cell.Image.Image_ID = 42
         and then Cell.Image.Image_Row = 1
         and then Cell.Image.Image_Column = 2,
         "margin scrolling preserves placeholder metadata");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 2, 4, 100, Init);
   Assert (Init = Terminal.Core.Ok, "scroll persistence initialize");
   Feed_Text (ASCII.ESC & "[38;5;42m" & ASCII.ESC & "[2;1H");
   Feed_Placeholder (16#030D#, 16#030E#);
   Feed_Text (ASCII.LF & ASCII.LF);
   declare
      Cell : constant Terminal.Core.Cell :=
        Terminal.Core.Scrollback_Cell_At (T, 2, 1);
   begin
      Assert
        (Cell.Image.Is_Placeholder
         and then Cell.Image.Image_ID = 42
         and then Cell.Image.Image_Row = 1
         and then Cell.Image.Image_Column = 2,
         "scrollback preserves placeholder metadata");
   end;

   Terminal.Core.Finalize (T);
end Core_Image_Cells_Smoke;

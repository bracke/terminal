with Terminal.Core.Snapshot_Editing;
with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_Damage_Smoke is
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

   procedure Feed_Text (Text : String; Message : String) is
   begin
      Terminal.Core.Feed (T, To_Bytes (Text), Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, Message);
   end Feed_Text;

   procedure Assert_Dirty
     (Row      : Positive;
      Expected : Boolean;
      Message  : String;
      Any_Dirty : Boolean := True)
   is
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert
        (Terminal.Core.Has_Dirty_Rows (S) = Any_Dirty,
         Message & " dirty summary");
      Assert (Terminal.Core.Dirty_Row (S, Row) = Expected, Message);
      Terminal.Core.Release (S);
   end Assert_Dirty;
begin
   Terminal.Core.Initialize (T, 3, 8, 10, Init);
   Assert (Init = Terminal.Core.Ok, "initialize failed");

   Terminal.Core.Clear_Damage (T);
   Feed_Text (ASCII.ESC & "[2;1H", "cursor movement feed failed");
   Assert_Dirty (1, True, "old cursor row should be dirty");
   Assert_Dirty (2, True, "new cursor row should be dirty");
   Assert_Dirty (3, False, "unaffected row should stay clean");

   Terminal.Core.Clear_Damage (T);
   Feed_Text (ASCII.ESC & "[?25l", "cursor hide feed failed");
   Assert_Dirty (2, True, "cursor hide should dirty current row");

   Terminal.Core.Clear_Damage (T);
   Feed_Text (ASCII.ESC & "[3;1H", "hidden cursor movement feed failed");
   Assert_Dirty
     (2, False, "hidden cursor old row should stay clean", Any_Dirty => False);
   Assert_Dirty
     (3, False, "hidden cursor new row should stay clean", Any_Dirty => False);

   Terminal.Core.Clear_Damage (T);
   Feed_Text (ASCII.ESC & "[?25h", "cursor show feed failed");
   Assert_Dirty (3, True, "cursor show should dirty current row");

   Terminal.Core.Initialize (T, 3, 8, 10, Init);
   Assert (Init = Terminal.Core.Ok, "snapshot reuse initialize failed");
   Feed_Text
     ("A" & ASCII.ESC & "[3;1HZ",
      "snapshot reuse baseline feed failed");
   declare
      S : Terminal.Core.Render_Snapshot;
   begin
      Terminal.Core.Snapshot (T, S);
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#41#
         and then Terminal.Core.Cell_At (S, 3, 1).Text.Code_Point = 16#5A#,
         "snapshot reuse baseline cells");

      Feed_Text (ASCII.ESC & "[?25l", "snapshot reuse hide cursor failed");
      Terminal.Core.Clear_Damage (T);
      Feed_Text
        (ASCII.ESC & "[2;1HB", "snapshot reuse dirty-row feed failed");
      Terminal.Core.Snapshot (T, S);
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#41#
         and then Terminal.Core.Cell_At (S, 2, 1).Text.Code_Point = 16#42#
         and then Terminal.Core.Cell_At (S, 3, 1).Text.Code_Point = 16#5A#,
         "snapshot reuse should refresh damage without losing clean rows");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Clear_Damage (T);
   declare
      S : Terminal.Core.Render_Snapshot;
      Cell : Terminal.Core.Cell;
   begin
      Terminal.Core.Snapshot (T, S);
      Cell := Terminal.Core.Cell_At (S, 1, 1);
      Cell.Style.Inverse := True;
      Cell.Style.Conceal := True;
      Terminal.Core.Snapshot_Editing.Set_Cell (S, 1, Cell);
      Terminal.Core.Snapshot_Editing.Set_Dirty_Row (S, 1, True);

      --  No core row is dirty here.  The reusable snapshot's presentation
      --  damage must still restore transient selection or blink decoration.
      Terminal.Core.Snapshot (T, S);
      Assert
        (not Terminal.Core.Cell_At (S, 1, 1).Style.Inverse
         and then not Terminal.Core.Cell_At (S, 1, 1).Style.Conceal,
         "snapshot refresh should discard transient decorations");
      Terminal.Core.Release (S);
   end;
end Core_Damage_Smoke;

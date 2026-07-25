with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_Wrap_Smoke is
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

   procedure Assert_Cell
     (S       : Terminal.Core.Render_Snapshot;
      Row     : Positive;
      Col     : Positive;
      Expected : Character;
      Message  : String)
   is
   begin
      Assert
        (Terminal.Core.Cell_At (S, Row, Col).Text.Code_Point =
         Terminal.Common.Code_Point (Character'Pos (Expected)),
         Message);
   end Assert_Cell;
begin
   Terminal.Core.Initialize (T, 2, 3, 10, Init);
   Assert (Init = Terminal.Core.Ok, "initialize autowrap failed");
   Feed_Text ("abcX", "autowrap feed failed");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert_Cell (S, 1, 1, 'a', "autowrap row1 col1");
      Assert_Cell (S, 1, 2, 'b', "autowrap row1 col2");
      Assert_Cell (S, 1, 3, 'c', "autowrap row1 col3");
      Assert_Cell (S, 2, 1, 'X', "autowrap row2 col1");
      Assert
        (S.Cursor.Row = 2 and then S.Cursor.Col = 2,
         "autowrap cursor");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 2, 3, 10, Init);
   Assert (Init = Terminal.Core.Ok, "initialize wrap-off failed");
   Feed_Text (ASCII.ESC & "[?7labcX", "wrap-off feed failed");
   Assert (not Terminal.Core.Modes (T).Autowrap, "autowrap should be disabled");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert_Cell (S, 1, 1, 'a', "wrap-off row1 col1");
      Assert_Cell (S, 1, 2, 'b', "wrap-off row1 col2");
      Assert_Cell (S, 1, 3, 'X', "wrap-off should overwrite final column");
      Assert
        (S.Cursor.Row = 1 and then S.Cursor.Col = 3,
         "wrap-off cursor");
      Terminal.Core.Release (S);
   end;

   Feed_Text (ASCII.ESC & "[?7hY", "wrap-on feed failed");
   Assert (Terminal.Core.Modes (T).Autowrap, "autowrap should be enabled");

   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert_Cell (S, 1, 3, 'Y', "wrap-on writes final column first");
      Assert
        (S.Cursor.Row = 1 and then S.Cursor.Col = 3,
         "wrap-on pending cursor");
      Terminal.Core.Release (S);
   end;

   Feed_Text ("Z", "wrap-on pending feed failed");
   declare
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert_Cell (S, 2, 1, 'Z', "wrap-on pending wraps next character");
      Assert
        (S.Cursor.Row = 2 and then S.Cursor.Col = 2,
         "wrap-on wrapped cursor");
      Terminal.Core.Release (S);
   end;
end Core_Wrap_Smoke;

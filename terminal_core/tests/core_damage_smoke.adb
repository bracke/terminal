with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Core_Damage_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Core.Dirty_Row_Array_Access;
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
      Message  : String)
   is
      S : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Assert (S.Dirty /= null, Message & " dirty array");
      Assert (S.Dirty (Row) = Expected, Message);
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
   Assert_Dirty (2, False, "hidden cursor old row should stay clean");
   Assert_Dirty (3, False, "hidden cursor new row should stay clean");

   Terminal.Core.Clear_Damage (T);
   Feed_Text (ASCII.ESC & "[?25h", "cursor show feed failed");
   Assert_Dirty (3, True, "cursor show should dirty current row");
end Core_Damage_Smoke;

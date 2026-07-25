with AUnit.Assertions;

with Terminal.App.Scrollback_View;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Scrollback_View_Smoke is
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
begin
   Terminal.Core.Initialize (T, 2, 4, 3, Init);
   Assert (Init = Terminal.Core.Ok, "initialize failed");
   Feed_Text
     ("a" & ASCII.CR & ASCII.LF
      & "b" & ASCII.CR & ASCII.LF
      & "c" & ASCII.CR & ASCII.LF
      & "d" & ASCII.CR & ASCII.LF
      & "e",
      "feed failed");

   Assert
     (Terminal.App.Scrollback_View.Max_Offset (T) = 3,
      "scrollback max offset");
   Assert
     (Terminal.App.Scrollback_View.Clamp_Offset (T, 99) = 3,
      "scrollback offset should clamp to retained history");

   declare
      S : Terminal.Core.Render_Snapshot :=
        Terminal.App.Scrollback_View.Snapshot (T, 1);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#63#,
         "offset one should show newest scrollback row first");
      Assert
        (Terminal.Core.Cell_At (S, 2, 1).Text.Code_Point = 16#64#,
         "offset one should include top live row");
      Assert (not S.Cursor.Visible, "scrolled snapshot should hide cursor");
      Assert (S.Dirty (1) and then S.Dirty (2), "scrolled view is fully dirty");
      Terminal.Core.Release (S);
   end;

   declare
      S : Terminal.Core.Render_Snapshot :=
        Terminal.App.Scrollback_View.Snapshot (T, 3);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#61#,
         "max offset should show oldest retained row");
      Assert
        (Terminal.Core.Cell_At (S, 2, 1).Text.Code_Point = 16#62#,
         "max offset should show next retained row");
      Terminal.Core.Release (S);
   end;

   declare
      S : Terminal.Core.Render_Snapshot :=
        Terminal.App.Scrollback_View.Snapshot (T, 0);
   begin
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#64#,
         "zero offset should return live top row");
      Assert (S.Cursor.Visible, "live snapshot should keep cursor visibility");
      Terminal.Core.Release (S);
   end;
end Scrollback_View_Smoke;

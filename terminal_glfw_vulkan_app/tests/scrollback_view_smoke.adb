with AUnit.Assertions;

with Terminal.App.Scrollback_View;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Scrollback_View_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Common.Code_Point;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Graphics_Screen_Generation;
   use type Terminal.Core.Graphics_Stream_ID;
   use type Terminal.Core.Graphics_Transaction_Generation;
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
   Terminal.Core.Set_Graphics_Stream_ID (T, 88);
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
   Assert
     (Terminal.App.Scrollback_View.Status_Label (T, 0) = "Scrollback live",
      "live scrollback status label");
   Assert
     (Terminal.App.Scrollback_View.Status_Label (T, 1) = "Scrollback 1/3",
      "offset scrollback status label");
   Assert
     (Terminal.App.Scrollback_View.Status_Label (T, 99) =
      "Scrollback 3/3 (clamped)",
      "clamped scrollback status label");
   Assert
     (Terminal.App.Scrollback_View.Status_Label (T, 99)'Length <=
      Terminal.App.Scrollback_View.Max_Status_Label_Length,
      "scrollback status label should be bounded");

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
      Assert
        (Terminal.Core.Image_Cell_Count (S) = 0,
         "scrolled snapshot image count");
      Assert
        (Terminal.Core.Dirty_Row (S, 1)
         and then Terminal.Core.Dirty_Row (S, 2),
         "scrolled view is fully dirty");
      Assert
        (S.Graphics_Stream = 88
         and then S.Graphics_Transaction /= 0
         and then not S.Alternate_Screen
         and then S.Screen_Generation /= 0,
         "scrolled snapshot preserves graphics screen identity");
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
      Terminal.App.Scrollback_View.Snapshot (T, 1, S);
      Assert
        (Terminal.Core.Cell_Count (S) = S.Rows * S.Cols
         and then Terminal.Core.Has_Dirty_Rows (S),
         "same-size snapshot refresh should retain complete storage");
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#63#
         and then
           Terminal.Core.Cell_At (S, 2, 1).Text.Code_Point = 16#64#,
         "reused snapshot should preserve scrollback ordering");

      --  Successful presentation clears core damage while the reusable
      --  snapshot still contains the composed history view.  Repeating that
      --  view must restore live rows before composing it again.
      Terminal.Core.Clear_Damage (T);
      Terminal.App.Scrollback_View.Snapshot (T, 1, S);
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#63#
         and then
           Terminal.Core.Cell_At (S, 2, 1).Text.Code_Point = 16#64#,
         "repeated reused scrollback snapshot should not drift");
      Terminal.App.Scrollback_View.Snapshot (T, 0, S);
      Assert
        (Terminal.Core.Cell_At (S, 1, 1).Text.Code_Point = 16#64#
         and then
           Terminal.Core.Cell_At (S, 2, 1).Text.Code_Point = 16#65#,
         "returning to zero offset should restore the live screen");
      Terminal.Core.Release (S);
   end;

   Terminal.Core.Initialize (T, 2, 4, 10, Init);
   Assert (Init = Terminal.Core.Ok, "shell marks initialize failed");
   Feed_Text
     (ASCII.ESC & "]133;A" & ASCII.BEL
      & "a" & ASCII.CR & ASCII.LF
      & ASCII.ESC & "]133;B" & ASCII.BEL
      & "b" & ASCII.CR & ASCII.LF
      & ASCII.ESC & "]133;A" & ASCII.BEL
      & "c" & ASCII.CR & ASCII.LF,
      "shell marks feed failed");
   Assert
     (Terminal.Core.Shell_Mark_Count (T) = 3
      and then Terminal.App.Scrollback_View.Previous_Mark_Offset (T, 0) = 1
      and then Terminal.App.Scrollback_View.Next_Mark_Offset (T, 1) = 0,
      "OSC 133 marks support previous/next scrollback navigation");

   --  Replacing a live placeholder while constructing a history view must
   --  update the cached placeholder count exactly once.
   Terminal.Core.Initialize (T, 2, 4, 3, Init);
   Assert (Init = Terminal.Core.Ok, "image scrollback initialize failed");
   Feed_Text
     ("a" & ASCII.CR & ASCII.LF
      & "b" & ASCII.CR & ASCII.LF
      & ASCII.ESC & "[38;2;1;2;3m"
      & Character'Val (16#F4#)
      & Character'Val (16#8E#)
      & Character'Val (16#BB#)
      & Character'Val (16#AE#),
      "image scrollback feed failed");
   declare
      Live : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      History : Terminal.Core.Render_Snapshot;
   begin
      Assert
        (Terminal.Core.Image_Cell_Count (Live) = 1,
         "live placeholder count");
      Terminal.App.Scrollback_View.Snapshot (T, 1, History);
      Assert
        (Terminal.Core.Image_Cell_Count (History) = 0,
         "history placeholder count follows transformed cells");
      Terminal.Core.Release (Live);
      Terminal.Core.Release (History);
   end;
end Scrollback_View_Smoke;

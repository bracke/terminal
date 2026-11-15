with AUnit.Assertions;
with Terminal.App.Copy_Mode;
with Terminal.App.Scrollback_View;
with Terminal.App.Selection;
with Terminal.Common;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Copy_Mode_Smoke is
   use AUnit.Assertions;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;

   function To_Bytes (Text : String) return Terminal.Common.Bytes.Byte_Array is
      Result : Terminal.Common.Bytes.Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) :=
           Terminal.Common.Bytes.Byte (Standard.Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   Core : Terminal.Core.Terminal;
   Init : Terminal.Core.Initialize_Status;
   Feed : Terminal.Core.Feed_Status;
   Mode : Terminal.App.Copy_Mode.State;
   Selection : Terminal.App.Selection.Selection_State;
   Query : constant String := "first";
   Upper_Query : constant String := "THIRD";
   Regex_Query : constant String := "s.cond";
begin
   Terminal.Core.Initialize (Core, 2, 8, 20, Init);
   Assert (Init = Terminal.Core.Ok, "copy mode initialize");
   Terminal.Core.Feed
     (Core, To_Bytes ("first" & ASCII.CR & ASCII.LF
                      & "second" & ASCII.CR & ASCII.LF
                      & "third"), Feed);
   Assert (Feed = Terminal.Core.Ok, "copy mode fixture feed");

   Terminal.App.Copy_Mode.Enter_Search (Mode, Core);
   for Ch of Query loop
      Terminal.App.Copy_Mode.Append
        (Mode, Terminal.Common.Code_Point (Standard.Character'Pos (Ch)));
   end loop;
   Terminal.App.Copy_Mode.Find (Mode, Core, Restart => True);
   Assert (Terminal.App.Copy_Mode.Match_Found (Mode), "scrollback search match");
   declare
      Offset : constant Natural :=
        Terminal.App.Copy_Mode.Recommended_Offset (Mode, Core);
      Snapshot : Terminal.Core.Render_Snapshot :=
        Terminal.App.Scrollback_View.Snapshot (Core, Offset);
   begin
      Assert (Offset > 0, "search scrolls to history match");
      Terminal.App.Copy_Mode.Select_Cursor
        (Mode, Core, Offset, Selection);
      Assert
        (Terminal.App.Selection.Selected_Text (Snapshot, Selection) = "first",
         "search highlights complete match");
      Terminal.App.Copy_Mode.Apply_Match_Highlights (Mode, Snapshot);
      declare
         Underlined : Boolean := False;
      begin
         for I in 1 .. Terminal.Core.Cell_Count (Snapshot) loop
            Underlined := Underlined or else
              Terminal.Core.Cell_Style_At_Index (Snapshot, I).Underline;
         end loop;
         Assert (Underlined, "search underlines all visible literal matches");
      end;
      Terminal.Core.Release (Snapshot);
   end;

   Terminal.App.Copy_Mode.Remember_Query (Mode);
   Terminal.App.Copy_Mode.Leave (Mode);
   Terminal.App.Copy_Mode.Enter_Search (Mode, Core);
   Terminal.App.Copy_Mode.History_Move (Mode, -1);
   Assert
     (Terminal.App.Copy_Mode.Query_Length (Mode) = Query'Length,
      "search history restores the previous query");

   Terminal.App.Copy_Mode.Leave (Mode);
   Terminal.App.Copy_Mode.Enter_Search (Mode, Core);
   for Ch of Upper_Query loop
      Terminal.App.Copy_Mode.Append
        (Mode, Terminal.Common.Code_Point (Standard.Character'Pos (Ch)));
   end loop;
   Terminal.App.Copy_Mode.Toggle_Case (Mode);
   Terminal.App.Copy_Mode.Find (Mode, Core, Restart => True);
   Assert (Terminal.App.Copy_Mode.Match_Found (Mode), "case-insensitive search");

   Terminal.App.Copy_Mode.Leave (Mode);
   Terminal.App.Copy_Mode.Enter_Search (Mode, Core);
   for Ch of Regex_Query loop
      Terminal.App.Copy_Mode.Append
        (Mode, Terminal.Common.Code_Point (Standard.Character'Pos (Ch)));
   end loop;
   Terminal.App.Copy_Mode.Toggle_Regex (Mode);
   Terminal.App.Copy_Mode.Find (Mode, Core, Restart => True);
   Assert (Terminal.App.Copy_Mode.Match_Found (Mode), "regular-expression search");

   Terminal.App.Copy_Mode.Leave (Mode);
   Assert (not Terminal.App.Copy_Mode.Active (Mode), "copy mode leaves");
   Terminal.App.Copy_Mode.Enter_Copy (Mode, Core);
   Terminal.App.Copy_Mode.Move (Mode, Core, -1, -1);
   Assert
     (Terminal.App.Copy_Mode.Status_Label (Mode) = "COPY",
      "copy mode status");
end Copy_Mode_Smoke;

separate (Terminal.App.Main_Loop.Run.Run_Frame.Handle_Input_Event)
procedure Handle_Mouse_Button_Event is
begin
   Chunk := (others => <>);
   declare
      Pos : constant Terminal.App.Selection.Cell_Position :=
        Active_Cell_From_Pixels
          (Event.Button_Event.X, Event.Button_Event.Y);
      Modes : constant Terminal.Core.Mode_Snapshot :=
        Terminal.Core.Modes (Active_Core.all);
   begin
      if Terminal.App.Input_Map.Mouse_Reporting_Enabled
        (Modes)
        and then not
          Terminal.App.Input_Map
            .Local_Mouse_Selection_Override
              (Event.Button_Event)
      then
         if Terminal.App.Selection.Has_Selection
            (Selection)
         then
            Terminal.App.Selection.Clear (Selection);
            Dirty := True;
            Need_Redraw := True;
            Local_Redraw := True;
         end if;
         Terminal.App.Input_Map.Encode_Mouse_Button
           (Event.Button_Event, Modes, Pos.Row, Pos.Col, Chunk);
         if Event.Button_Event.Action =
           GLFW_Vulkan.Input.Press
           and then Event.Button_Event.Button /=
             GLFW_Vulkan.Input.Other
         then
            Mouse_Button_Down := True;
            Mouse_Button_Code_Value :=
              Mouse_Button_Code (Event.Button_Event.Button);
            Mouse_Modifiers := Event.Button_Event.Modifiers;
         elsif Event.Button_Event.Action =
           GLFW_Vulkan.Input.Release
         then
            Mouse_Button_Down := False;
            Mouse_Modifiers := Event.Button_Event.Modifiers;
         end if;
      elsif Event.Button_Event.Button = GLFW_Vulkan.Input.Left
      then
         if Event.Button_Event.Action =
           GLFW_Vulkan.Input.Press
         then
            if Event.Button_Event.Modifiers.Control then
               if Terminal.App.Selection.Has_Selection
                 (Selection)
               then
                  Terminal.App.Selection.Clear (Selection);
                  Dirty := True;
                  Need_Redraw := True;
                  Local_Redraw := True;
               end if;
               declare
                  Link_Snap : Terminal.Core.Render_Snapshot :=
                    Terminal.App.Scrollback_View.Snapshot
                      (Active_Core.all, Scroll_Offset);
                  Link : constant Terminal.Core.Hyperlink :=
                    Terminal.App.Hyperlinks.Link_At
                      (Link_Snap, Pos);
                  Link_Status :
                    Terminal.App.Hyperlinks.Activation_Status;
               begin
                  Terminal.App.Hyperlinks.Activate
                    (Link, Link_Status);
                  Has_Link_Activation := True;
                  Link_Activation := Link_Status;
                  Terminal.Core.Release (Link_Snap);
                  Apply_Title
                    (W,
                     Terminal.Core.Title (Active_Core.all),
                     Hovered_Link,
                     Has_Link_Activation,
                     Link_Activation,
                     Tabs,
                     Splits);
               end;
            elsif Event.Button_Event.Modifiers.Alt then
               Terminal.App.Selection
                 .Begin_Rectangular_Selection
                   (Selection, Pos);
               Dirty := True;
               Need_Redraw := True;
               Local_Redraw := True;
            else
               declare
                  Now : constant Ada.Real_Time.Time :=
                    Ada.Real_Time.Clock;
                  Repeated_Click : constant Boolean :=
                    Have_Last_Click
                    and then Same_Position
                      (Last_Click_Pos, Pos)
                    and then
                      Ada.Real_Time.To_Duration
                        (Now - Last_Click_Time)
                        <= Double_Click_Interval;
               begin
                  if Repeated_Click then
                     Click_Count :=
                       Natural'Min (Click_Count + 1, 3);
                  else
                     Click_Count := 1;
                  end if;
                  Last_Click_Time := Now;
                  Last_Click_Pos := Pos;
                  Have_Last_Click := True;
               end;

               if Event.Button_Event.Modifiers.Shift then
                  Terminal.App.Selection.Extend_Selection
                    (Selection, Pos);
               elsif Click_Count >= 3
               then
                  declare
                     Line_Snap :
                       Terminal.Core.Render_Snapshot :=
                         Terminal.App.Scrollback_View
                           .Snapshot
                             (Active_Core.all,
                              Scroll_Offset);
                  begin
                     Terminal.App.Selection.Select_Line
                       (Selection, Line_Snap, Pos);
                     Terminal.Core.Release (Line_Snap);
                  end;
               elsif Click_Count = 2 then
                  declare
                     Word_Snap :
                       Terminal.Core.Render_Snapshot :=
                         Terminal.App.Scrollback_View
                           .Snapshot
                             (Active_Core.all,
                              Scroll_Offset);
                  begin
                     Terminal.App.Selection.Select_Word
                       (Selection, Word_Snap, Pos);
                     Terminal.Core.Release (Word_Snap);
                  end;
               else
                  Terminal.App.Selection.Begin_Selection
                    (Selection, Pos);
               end if;
               Dirty := True;
               Need_Redraw := True;
               Local_Redraw := True;
            end if;
         elsif Event.Button_Event.Action =
           GLFW_Vulkan.Input.Release
         then
            Terminal.App.Selection.Finish_Selection
              (Selection, Pos);
            Copy_Selection;
            Dirty := True;
            Need_Redraw := True;
            Local_Redraw := True;
         end if;
      elsif Terminal.App.Input_Map.Is_Primary_Paste_Button
        (Event.Button_Event)
      then
         Scroll_Offset := 0;
         Terminal.App.Input_Map.Encode_Paste_Text
           (Terminal.App.Clipboard_OSC52.Text
              (Clipboard_Targets,
               Terminal.Core.Clipboard_Primary),
            Modes,
            Chunk);
      end if;
   end;
end Handle_Mouse_Button_Event;

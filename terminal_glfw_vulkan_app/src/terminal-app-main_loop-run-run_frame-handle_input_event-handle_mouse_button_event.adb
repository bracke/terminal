separate (Terminal.App.Main_Loop.Run.Run_Frame.Handle_Input_Event)
procedure Handle_Mouse_Button_Event is
   Handled : Boolean := False;
   Scrollbar_Available : Boolean := False;
   procedure Set_Scroll_From_Pixel (Core : in out Terminal.Core.Terminal) is
      Max : constant Natural := Terminal.App.Scrollback_View.Max_Offset (Core);
      Top : constant Float :=
        Float (Active_Pane_Origin_Y + Terminal.App.Renderer.Content_Margin);
      Height : constant Float :=
        Float (Active_Pane_Rows * Terminal.App.Renderer.Cell_Height (R));
      Position : Float := Event.Button_Event.Y - Top;
   begin
      Scrollbar_Available := Max > 0;
      if Max = 0 or else Height <= 0.0 then
         Scroll_Offset := 0;
         return;
      end if;
      Position := Float'Max (0.0, Float'Min (Height, Position));
      Scroll_Offset := Natural (Float (Max) * (Height - Position) / Height);
      Scroll_Offset := Terminal.App.Scrollback_View.Clamp_Offset
        (Core, Scroll_Offset);
   end Set_Scroll_From_Pixel;

   procedure Close_Selected_Tab is
      Closed_Index : constant Terminal.App.Sessions.Session_Index :=
        Terminal.App.Session_Table.Active (Sessions);
      Closed_Stream : constant Terminal.Core.Graphics_Stream_ID :=
        Terminal.App.Session_Table.Graphics_Stream_ID (Active_Runtime);
   begin
      Terminal.App.Session_Table.Close_Tab (Sessions, Session_Table_Status);
      if Session_Table_Status = Terminal.App.Session_Table.Ok then
         Forget_Session_Command (Closed_Index);
         Terminal.App.Renderer.Graphics.Release_Stream (R, Closed_Stream);
         Configure_Visible_Cores;
         Scroll_Offset := 0;
         Terminal.App.Selection.Clear (Selection);
         Apply_Hovered_Link ((others => <>));
      end if;
   end Close_Selected_Tab;

   procedure Process (Core : in out Terminal.Core.Terminal) is
      Pos : constant Terminal.App.Selection.Cell_Position :=
        Active_Cell_From_Pixels
          (Event.Button_Event.X, Event.Button_Event.Y);
      Modes : constant Terminal.Core.Mode_Snapshot := Terminal.Core.Modes (Core);
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
                    Terminal.App.Scrollback_View.Snapshot (Core, Scroll_Offset);
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
                     Terminal.Core.Title (Core),
                     Hovered_Link,
                     Has_Link_Activation,
                     Link_Activation,
                     Interaction_Status,
                     Sessions);
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
                         Terminal.App.Scrollback_View.Snapshot
                           (Core, Scroll_Offset);
                  begin
                     Terminal.App.Selection.Select_Line
                       (Selection, Line_Snap, Pos);
                     Terminal.Core.Release (Line_Snap);
                  end;
               elsif Click_Count = 2 then
                  declare
                     Word_Snap :
                       Terminal.Core.Render_Snapshot :=
                         Terminal.App.Scrollback_View.Snapshot
                           (Core, Scroll_Offset);
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
         Terminal.App.Session_Table.Write_Paste
           (Active_Runtime,
            Terminal.App.Clipboard_OSC52.Text
              (Clipboard_Targets,
               Terminal.Core.Clipboard_Primary),
            Modes.Bracketed_Paste,
            Write_Stat);
         Last_Write_Status := Write_Stat;
         if Fatal_Write (Write_Stat)
           and then Terminal.App.Session_Table.Count (Sessions) = 1
         then
            GLFW_Vulkan.Windows.Set_Should_Close (W, True);
         end if;
         Chunk := (others => <>);
      end if;
   end Process;
begin
   Chunk := (others => <>);
   if Event.Button_Event.Action = GLFW_Vulkan.Input.Release
     and then Suppress_Chrome_Release
     and then Event.Button_Event.Button = Chrome_Press_Button
   then
      Chrome_Drag := No_Chrome_Drag;
      Suppress_Chrome_Release := False;
      Chrome_Press_Button := GLFW_Vulkan.Input.Other;
      Handled := True;
   elsif Event.Button_Event.Action = GLFW_Vulkan.Input.Press then
      declare
         Tab_Hit : constant Terminal.App.Tabs.Tab_Count :=
           Tab_At_Pixels (Event.Button_Event.X, Event.Button_Event.Y);
         Divider_Hit : constant Natural :=
           Divider_At_Pixels (Event.Button_Event.X, Event.Button_Event.Y);
      begin
         if Tab_Hit > 0
           and then Event.Button_Event.Button in
             GLFW_Vulkan.Input.Left | GLFW_Vulkan.Input.Middle
         then
            Terminal.App.Session_Table.Activate
              (Sessions,
               Terminal.App.Sessions.Session_Index (Tab_Hit),
               Session_Table_Status);
            if Session_Table_Status = Terminal.App.Session_Table.Ok then
               if Event.Button_Event.Button = GLFW_Vulkan.Input.Middle
                 or else Tab_Close_At_Pixels
                   (Terminal.App.Tabs.Tab_Index (Tab_Hit), Event.Button_Event.X)
               then
                  Close_Selected_Tab;
               else
                  Drag_Tab := Terminal.App.Tabs.Tab_Index (Tab_Hit);
                  Chrome_Drag := Tab_Chrome_Drag;
                  Configure_Visible_Cores;
                  Scroll_Offset := 0;
                  Terminal.App.Selection.Clear (Selection);
                  Apply_Hovered_Link ((others => <>));
               end if;
            end if;
            Suppress_Chrome_Release := True;
            Chrome_Press_Button := Event.Button_Event.Button;
            Handled := True;
         elsif Divider_Hit > 0
           and then Event.Button_Event.Button = GLFW_Vulkan.Input.Left
         then
            Drag_Divider := Terminal.App.Splits.Divider_Index (Divider_Hit);
            Chrome_Drag := Divider_Chrome_Drag;
            Suppress_Chrome_Release := True;
            Chrome_Press_Button := Event.Button_Event.Button;
            Handled := True;
         elsif Event.Button_Event.Button = GLFW_Vulkan.Input.Left
           and then Scrollbar_At_Pixels
             (Event.Button_Event.X, Event.Button_Event.Y)
         then
            Terminal.App.Session_Runtime.With_Core
              (Active_Core, Set_Scroll_From_Pixel'Access);
            if Scrollbar_Available then
               Chrome_Drag := Scrollbar_Chrome_Drag;
               Suppress_Chrome_Release := True;
               Chrome_Press_Button := Event.Button_Event.Button;
               Handled := True;
            end if;
         elsif Event.Button_Event.Button = GLFW_Vulkan.Input.Left then
            declare
               Pane_Hit : constant Terminal.App.Splits.Pane_Count :=
                 Pane_At_Pixels (Event.Button_Event.X, Event.Button_Event.Y);
            begin
               if Pane_Hit > 0
                 and then Pane_Hit /= Terminal.App.Splits.Active (Splits)
               then
                  Terminal.App.Session_Table.Activate
                    (Sessions,
                     Terminal.App.Sessions.Session_Index (Pane_Hit),
                     Session_Table_Status);
                  if Session_Table_Status = Terminal.App.Session_Table.Ok then
                     Scroll_Offset := 0;
                     Terminal.App.Selection.Clear (Selection);
                     Apply_Hovered_Link ((others => <>));
                  end if;
               end if;
            end;
         end if;
      end;
   end if;

   if Handled then
      Dirty := True;
      Need_Redraw := True;
      Local_Redraw := True;
   else
      Terminal.App.Session_Runtime.With_Core (Active_Core, Process'Access);
   end if;
end Handle_Mouse_Button_Event;

separate (Terminal.App.Main_Loop.Run.Run_Frame)
      procedure Handle_Input_Event (Stop : out Boolean) is
      begin
         Stop := False;
         case Event.Kind is
            when Terminal.App.Queues.Key =>
               declare
                  Modes : constant Terminal.Core.Mode_Snapshot :=
                    Terminal.Core.Modes (Active_Core.all);
                  Tab_Command : constant Terminal.App.Tabs.Tab_Command :=
                    Terminal.App.Input_Map.Tab_Command (Event.Key_Event);
                  Tab_Status : Terminal.App.Tabs.Tab_Status;
                  Split_Command : constant
                    Terminal.App.Splits.Split_Command :=
                      Terminal.App.Input_Map.Split_Command
                        (Event.Key_Event);
                  Split_Status : Terminal.App.Splits.Split_Status;
               begin
               if Tab_Command /= Terminal.App.Tabs.No_Command then
                  case Tab_Command is
                     when Terminal.App.Tabs.New_Tab =>
                        Terminal.App.Session_Table.New_Tab
                          (Sessions,
                           Tabs,
                           Splits,
                           Last_Rows,
                           Last_Cols,
                           App_Config.Scrollback_Limit,
                           Session_Table_Status);
                        if Session_Table_Status =
                          Terminal.App.Session_Table.Ok
                        then
                           Configure_Active_Core;
                           Scroll_Offset := 0;
                           Terminal.App.Selection.Clear (Selection);
                           Apply_Hovered_Link ((others => <>));
                        end if;
                     when Terminal.App.Tabs.Close_Tab =>
                        declare
                           Closed_Stream : constant
                             Terminal.Core.Graphics_Stream_ID :=
                               Terminal.App.Session_Runtime
                                 .Graphics_Stream_ID
                                   (Active_Runtime.all);
                        begin
                           Terminal.App.Session_Table.Close_Tab
                             (Sessions, Tabs, Session_Table_Status);
                           if Session_Table_Status =
                             Terminal.App.Session_Table.Ok
                           then
                              Terminal.App.Renderer
                                .Release_Graphics_Stream
                                  (R, Closed_Stream);
                              Configure_Active_Core;
                              Scroll_Offset := 0;
                              Terminal.App.Selection.Clear (Selection);
                              Apply_Hovered_Link ((others => <>));
                           end if;
                        end;
                     when Terminal.App.Tabs.Next_Tab
                        | Terminal.App.Tabs.Previous_Tab =>
                        Terminal.App.Tabs.Apply
                          (Tabs, Tab_Command, Tab_Status);
                        if Tab_Status = Terminal.App.Tabs.Ok then
                           Terminal.App.Session_Table.Activate
                             (Sessions,
                              Terminal.App.Sessions.Session_Index
                                (Terminal.App.Tabs.Active (Tabs)),
                              Session_Table_Status);
                           if Session_Table_Status =
                             Terminal.App.Session_Table.Ok
                           then
                              Configure_Active_Core;
                              Scroll_Offset := 0;
                              Terminal.App.Selection.Clear (Selection);
                              Apply_Hovered_Link ((others => <>));
                           end if;
                        end if;
                     when Terminal.App.Tabs.No_Command =>
                        null;
                  end case;
                  Dirty := True;
                  Need_Redraw := True;
                  Local_Redraw := True;
                  Chunk := (others => <>);
               elsif Split_Command /=
                 Terminal.App.Splits.No_Command
               then
                  case Split_Command is
                     when Terminal.App.Splits.Split_Horizontal
                        | Terminal.App.Splits.Split_Vertical =>
                        Terminal.App.Session_Table.Split_Pane
                          (Sessions,
                           Tabs,
                           Splits,
                           Split_Command,
                           Last_Rows,
                           Last_Cols,
                           App_Config.Scrollback_Limit,
                           Session_Table_Status);
                        if Session_Table_Status =
                          Terminal.App.Session_Table.Ok
                        then
                           Configure_Active_Core;
                           Scroll_Offset := 0;
                           Terminal.App.Selection.Clear (Selection);
                           Apply_Hovered_Link ((others => <>));
                        end if;
                     when Terminal.App.Splits.Close_Pane =>
                        declare
                           Closed_Stream : constant
                             Terminal.Core.Graphics_Stream_ID :=
                               Terminal.App.Session_Runtime
                                 .Graphics_Stream_ID
                                   (Active_Runtime.all);
                        begin
                           Terminal.App.Session_Table.Close_Pane
                             (Sessions,
                              Splits,
                              Session_Table_Status);
                           if Session_Table_Status =
                             Terminal.App.Session_Table.Ok
                           then
                              Terminal.App.Renderer
                                .Release_Graphics_Stream
                                  (R, Closed_Stream);
                              Configure_Active_Core;
                              Scroll_Offset := 0;
                              Terminal.App.Selection.Clear (Selection);
                              Apply_Hovered_Link ((others => <>));
                           end if;
                        end;
                     when Terminal.App.Splits.Next_Pane =>
                        Terminal.App.Splits.Apply
                          (Splits, Split_Command, Split_Status);
                        if Split_Status = Terminal.App.Splits.Ok then
                           Terminal.App.Session_Table.Activate
                             (Sessions,
                              Terminal.App.Sessions.Session_Index
                                (Terminal.App.Splits.Active (Splits)),
                              Session_Table_Status);
                           if Session_Table_Status =
                             Terminal.App.Session_Table.Ok
                           then
                              Configure_Active_Core;
                              Scroll_Offset := 0;
                              Terminal.App.Selection.Clear (Selection);
                              Apply_Hovered_Link ((others => <>));
                           end if;
                        end if;
                     when Terminal.App.Splits.No_Command =>
                        null;
                  end case;
                  Dirty := True;
                  Need_Redraw := True;
                  Local_Redraw := True;
                  Chunk := (others => <>);
               elsif Is_Scrollback_Key (Event.Key_Event) then
                  if Terminal.App.Selection.Has_Selection (Selection) then
                     Terminal.App.Selection.Clear (Selection);
                  end if;
                  if Event.Key_Event.Key = GLFW_Vulkan.Input.Page_Up then
                    Scroll_Offset :=
                      Terminal.App.Scrollback_View.Clamp_Offset
                         (Active_Core.all, Scroll_Offset + Last_Rows);
                  elsif Scroll_Offset > Last_Rows then
                     Scroll_Offset := Scroll_Offset - Last_Rows;
                  else
                     Scroll_Offset := 0;
                  end if;
                  Dirty := True;
                  Need_Redraw := True;
                  Local_Redraw := True;
                  Chunk := (others => <>);
               elsif Terminal.App.Input_Map.Is_Paste_Shortcut
                 (Event.Key_Event)
               then
                  Scroll_Offset := 0;
                  if Modes.Keyboard_Locked then
                     Chunk := (others => <>);
                  else
                     if Terminal.App.Selection.Has_Selection (Selection) then
                        Terminal.App.Selection.Clear (Selection);
                        Dirty := True;
                        Local_Redraw := True;
                     end if;
                     Terminal.App.Input_Map.Encode_Paste_Text
                       (GLFW_Vulkan.Clipboard.Get_Text (W),
                        Modes,
                        Chunk);
                  end if;
               elsif Terminal.App.Input_Map.Is_Copy_Shortcut
                 (Event.Key_Event)
               then
                  if Terminal.App.Selection.Has_Selection (Selection) then
                     Copy_Selection;
                  end if;
                  Chunk := (others => <>);
               else
                  Scroll_Offset := 0;
                  if Modes.Keyboard_Locked then
                     Chunk := (others => <>);
                     Suppress_Character := Wide_Wide_Character'Val (0);
                  else
                     if Terminal.App.Selection.Has_Selection (Selection) then
                        Terminal.App.Selection.Clear (Selection);
                        Dirty := True;
                        Local_Redraw := True;
                     end if;
                     Terminal.App.Input_Map.Encode_Key
                       (Event.Key_Event, Modes, Chunk);
                     Suppress_Character :=
                       Terminal.App.Input_Map.Suppressed_Character
                         (Event.Key_Event, Modes);
                  end if;
               end if;
               end;
            when Terminal.App.Queues.Character =>
               Scroll_Offset := 0;
               if Suppress_Character /= Wide_Wide_Character'Val (0)
                 and then Event.Character_Event.Code_Point =
                   Suppress_Character
               then
                  Chunk := (others => <>);
                  Suppress_Character := Wide_Wide_Character'Val (0);
               elsif
                 Terminal.Core.Modes (Active_Core.all).Keyboard_Locked
               then
                  Chunk := (others => <>);
                  Suppress_Character := Wide_Wide_Character'Val (0);
               else
                  Suppress_Character := Wide_Wide_Character'Val (0);
                  if Terminal.App.Selection.Has_Selection (Selection) then
                     Terminal.App.Selection.Clear (Selection);
                     Dirty := True;
                     Local_Redraw := True;
                  end if;
                  Terminal.App.Input_Map.Encode_Character
                    (Event.Character_Event, Chunk);
               end if;
            when Terminal.App.Queues.Bytes =>
               Chunk := Event.Bytes;
            when Terminal.App.Queues.Mouse_Button =>
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
            when Terminal.App.Queues.Cursor_Position =>
               Chunk := (others => <>);
               declare
                  Pos : constant Terminal.App.Selection.Cell_Position :=
                    Active_Cell_From_Pixels
                      (Event.Cursor_Event.X, Event.Cursor_Event.Y);
                  Modes : constant Terminal.Core.Mode_Snapshot :=
                    Terminal.Core.Modes (Active_Core.all);
               begin
                  if Terminal.App.Selection.Is_Active (Selection) then
                     Terminal.App.Selection.Update_Selection
                       (Selection, Pos);
                     Dirty := True;
                     Need_Redraw := True;
                     Local_Redraw := True;
                  elsif Terminal.App.Input_Map.Mouse_Reporting_Enabled
                    (Modes)
                  then
                     Terminal.App.Input_Map.Encode_Mouse_Motion
                       (Event.Cursor_Event,
                        Modes,
                        Pos.Row,
                        Pos.Col,
                        Mouse_Button_Down,
                        Mouse_Button_Code_Value,
                        Mouse_Modifiers,
                        Chunk);
                  else
                     declare
                        Hover_Snap : Terminal.Core.Render_Snapshot :=
                          Terminal.App.Scrollback_View.Snapshot
                            (Active_Core.all, Scroll_Offset);
                        New_Link : constant Terminal.Core.Hyperlink :=
                          Supported_Link
                            (Terminal.App.Hyperlinks.Link_At
                               (Hover_Snap, Pos));
                     begin
                        Terminal.Core.Release (Hover_Snap);
                        if not Terminal.App.Hyperlinks.Same_Link
                          (Hovered_Link, New_Link)
                        then
                           Apply_Hovered_Link (New_Link);
                           Dirty := True;
                           Need_Redraw := True;
                           Local_Redraw := True;
                        end if;
                     end;
                  end if;
               end;
            when Terminal.App.Queues.Scroll =>
               Chunk := (others => <>);
               declare
                  Pos : constant Terminal.App.Selection.Cell_Position :=
                    Active_Cell_From_Pixels
                      (Event.Scroll_Event.X, Event.Scroll_Event.Y);
                  Modes : constant Terminal.Core.Mode_Snapshot :=
                    Terminal.Core.Modes (Active_Core.all);
               begin
                  if Terminal.App.Input_Map.Mouse_Reporting_Enabled
                    (Modes)
                  then
                     Terminal.App.Input_Map.Encode_Mouse_Wheel
                       (Event.Scroll_Event,
                        Modes,
                        Pos.Row,
                        Pos.Col,
                        Chunk);
                  elsif Event.Scroll_Event.Y_Offset > 0.0 then
                     Scroll_Offset :=
                       Terminal.App.Scrollback_View.Clamp_Offset
                         (Active_Core.all,
                          Scroll_Offset
                            + App_Config.Wheel_Scroll_Lines);
                     Dirty := True;
                     Need_Redraw := True;
                     Local_Redraw := True;
                  elsif Event.Scroll_Event.Y_Offset < 0.0 then
                     if Scroll_Offset > App_Config.Wheel_Scroll_Lines then
                        Scroll_Offset :=
                          Scroll_Offset
                            - App_Config.Wheel_Scroll_Lines;
                     else
                        Scroll_Offset := 0;
                     end if;
                     Dirty := True;
                     Need_Redraw := True;
                     Local_Redraw := True;
                  end if;
               end;
            when Terminal.App.Queues.Focus =>
               Terminal.App.Input_Map.Encode_Focus
                 (Event.Focus_Event,
                  Terminal.Core.Modes (Active_Core.all),
                  Chunk);
            when Terminal.App.Queues.Close_Request =>
               GLFW_Vulkan.Windows.Set_Should_Close (W, True);
               Chunk := (others => <>);
            when Terminal.App.Queues.Resize_Request =>
               Chunk := (others => <>);
         end case;
   
         if Chunk.Length > 0 then
            Terminal.App.Session_Runtime.Write
              (Active_Runtime.all, Chunk, Write_Stat);
            Last_Write_Status := Write_Stat;
            if Fatal_Write (Write_Stat) then
               if Terminal.App.Session_Table.Count (Sessions) = 1 then
                  GLFW_Vulkan.Windows.Set_Should_Close (W, True);
               end if;
            elsif Write_Stat = Terminal.App.PTY_Write.Incomplete then
               Stop := True;
               return;
            end if;
         end if;
      end Handle_Input_Event;

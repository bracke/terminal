separate (Terminal.App.Main_Loop.Run.Run_Frame.Handle_Input_Event)
procedure Handle_Key_Event is
begin
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
                  Configure_Visible_Cores;
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
                     Configure_Visible_Cores;
                     Scroll_Offset := 0;
                     Terminal.App.Selection.Clear (Selection);
                     Apply_Hovered_Link ((others => <>));
                  end if;
               end;
            when Terminal.App.Tabs.Next_Tab
               | Terminal.App.Tabs.Previous_Tab =>
               declare
                  Next_Tabs : Terminal.App.Tabs.Tab_State := Tabs;
               begin
               Terminal.App.Tabs.Apply
                 (Next_Tabs, Tab_Command, Tab_Status);
               if Tab_Status = Terminal.App.Tabs.Ok then
                  Terminal.App.Session_Table.Activate
                    (Sessions,
                     Terminal.App.Sessions.Session_Index
                       (Terminal.App.Tabs.Active (Next_Tabs)),
                     Session_Table_Status);
                  if Session_Table_Status =
                    Terminal.App.Session_Table.Ok
                  then
                     Tabs := Next_Tabs;
                     Configure_Visible_Cores;
                     Scroll_Offset := 0;
                     Terminal.App.Selection.Clear (Selection);
                     Apply_Hovered_Link ((others => <>));
                  end if;
               end if;
               end;
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
                  Configure_Visible_Cores;
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
                     Configure_Visible_Cores;
                     Scroll_Offset := 0;
                     Terminal.App.Selection.Clear (Selection);
                     Apply_Hovered_Link ((others => <>));
                  end if;
               end;
            when Terminal.App.Splits.Next_Pane =>
               declare
                  Next_Splits : Terminal.App.Splits.Split_State := Splits;
               begin
               Terminal.App.Splits.Apply
                 (Next_Splits, Split_Command, Split_Status);
               if Split_Status = Terminal.App.Splits.Ok then
                  Terminal.App.Session_Table.Activate
                    (Sessions,
                     Terminal.App.Sessions.Session_Index
                       (Terminal.App.Splits.Active (Next_Splits)),
                     Session_Table_Status);
                  if Session_Table_Status =
                    Terminal.App.Session_Table.Ok
                  then
                     Splits := Next_Splits;
                     Configure_Visible_Cores;
                     Scroll_Offset := 0;
                     Terminal.App.Selection.Clear (Selection);
                     Apply_Hovered_Link ((others => <>));
                  end if;
               end if;
               end;
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
end Handle_Key_Event;

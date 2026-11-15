separate (Terminal.App.Main_Loop.Run.Run_Frame.Handle_Input_Event)
procedure Handle_Key_Event is
   Modes : Terminal.Core.Mode_Snapshot;
   procedure Read_Modes (Core : in out Terminal.Core.Terminal) is
   begin
      Modes := Terminal.Core.Modes (Core);
   end Read_Modes;
   procedure Clamp_Page_Up (Core : in out Terminal.Core.Terminal) is
   begin
      Scroll_Offset :=
        Terminal.App.Scrollback_View.Clamp_Offset
          (Core, Scroll_Offset + Last_Rows);
   end Clamp_Page_Up;
   procedure Refresh_Copy_Selection
     (Extend : Boolean := False;
      Search : Boolean := False;
      Backward : Boolean := False;
      Restart : Boolean := False)
   is
      procedure Apply (Core : in out Terminal.Core.Terminal) is
      begin
         if Search then
            Terminal.App.Copy_Mode.Find
              (Copy_State, Core, Backward => Backward, Restart => Restart);
         end if;
         Scroll_Offset :=
           Terminal.App.Copy_Mode.Recommended_Offset (Copy_State, Core);
         if not Search
           or else Terminal.App.Copy_Mode.Match_Found (Copy_State)
         then
            Terminal.App.Copy_Mode.Select_Cursor
              (Copy_State, Core, Scroll_Offset, Selection, Extend);
         else
            Terminal.App.Selection.Clear (Selection);
         end if;
      end Apply;
   begin
      Terminal.App.Session_Runtime.With_Core (Active_Core, Apply'Access);
   end Refresh_Copy_Selection;

   procedure Enter_Copy_Mode (Search : Boolean) is
      procedure Apply (Core : in out Terminal.Core.Terminal) is
      begin
         if Search then
            Terminal.App.Copy_Mode.Enter_Search (Copy_State, Core);
         else
            Terminal.App.Copy_Mode.Enter_Copy (Copy_State, Core);
         end if;
         Scroll_Offset :=
           Terminal.App.Copy_Mode.Recommended_Offset (Copy_State, Core);
         Terminal.App.Copy_Mode.Select_Cursor
           (Copy_State, Core, Scroll_Offset, Selection);
      end Apply;
   begin
      Terminal.App.Session_Runtime.With_Core (Active_Core, Apply'Access);
   end Enter_Copy_Mode;

   procedure Move_Copy_Cursor (Rows, Cols : Integer; Extend : Boolean) is
      procedure Apply (Core : in out Terminal.Core.Terminal) is
      begin
         Terminal.App.Copy_Mode.Move (Copy_State, Core, Rows, Cols);
         Scroll_Offset :=
           Terminal.App.Copy_Mode.Recommended_Offset (Copy_State, Core);
         Terminal.App.Copy_Mode.Select_Cursor
           (Copy_State, Core, Scroll_Offset, Selection, Extend);
      end Apply;
   begin
      Terminal.App.Session_Runtime.With_Core (Active_Core, Apply'Access);
   end Move_Copy_Cursor;

   procedure Apply_Font_Size (Requested : Positive) is
      Old_Size : constant Positive := Active_Font_Size;
      Status : Terminal.App.Renderer.Font_Update_Status;
      Restore_Status : Terminal.App.Renderer.Font_Update_Status;
   begin
      if Requested = Active_Font_Size then
         return;
      end if;
      Terminal.App.Renderer.Set_Font
        (R,
         Unbounded.To_String (Active_Font_Path),
         Requested,
         Status);
      if Status = Terminal.App.Renderer.Font_Ok then
         Active_Font_Size := Requested;
      else
         Terminal.App.Renderer.Set_Font
           (R,
            Unbounded.To_String (Active_Font_Path),
            Old_Size,
            Restore_Status);
      end if;
   end Apply_Font_Size;

   procedure Refresh_Link_Hint_Selection is
   begin
      if Terminal.App.Hyperlinks.Hints_Active (Link_Hints) then
         Terminal.App.Selection.Begin_Selection
           (Selection,
            Terminal.App.Hyperlinks.Current_Hint_First (Link_Hints));
         Terminal.App.Selection.Finish_Selection
           (Selection,
            Terminal.App.Hyperlinks.Current_Hint_Last (Link_Hints));
      else
         Terminal.App.Selection.Clear (Selection);
      end if;
   end Refresh_Link_Hint_Selection;

   procedure Enter_Link_Hints is
      procedure Apply (Core : in out Terminal.Core.Terminal) is
         Snapshot : Terminal.Core.Render_Snapshot :=
           Terminal.App.Scrollback_View.Snapshot (Core, Scroll_Offset);
      begin
         Terminal.App.Hyperlinks.Begin_Hints (Link_Hints, Snapshot);
         Terminal.Core.Release (Snapshot);
         Refresh_Link_Hint_Selection;
      exception
         when others =>
            Terminal.Core.Release (Snapshot);
            raise;
      end Apply;
   begin
      Terminal.App.Session_Runtime.With_Core (Active_Core, Apply'Access);
   end Enter_Link_Hints;

   procedure Commit_Text_Composition is
      Code_Point : Wide_Wide_Character;
      Valid : Boolean;
   begin
      Terminal.App.Text_Composition.Commit
        (Text_Composition, Code_Point, Valid);
      if Valid and then not Modes.Keyboard_Locked then
         Terminal.App.Input_Map.Encode_Character
           ((Code_Point => Code_Point), Chunk);
      else
         Chunk := (others => <>);
      end if;
   end Commit_Text_Composition;
begin
   Terminal.App.Session_Runtime.With_Core (Active_Core, Read_Modes'Access);
   declare
      App_Action : constant Terminal.App.Key_Bindings.Action :=
        Resolve_Action (Event.Key_Event);
      Tab_Command : constant Terminal.App.Tabs.Tab_Command :=
        (case App_Action is
            when Terminal.App.Key_Bindings.New_Tab =>
              Terminal.App.Tabs.New_Tab,
            when Terminal.App.Key_Bindings.Close_Tab =>
              Terminal.App.Tabs.Close_Tab,
            when Terminal.App.Key_Bindings.Next_Tab =>
              Terminal.App.Tabs.Next_Tab,
            when Terminal.App.Key_Bindings.Previous_Tab =>
              Terminal.App.Tabs.Previous_Tab,
            when others => Terminal.App.Tabs.No_Command);
      Split_Command : constant
        Terminal.App.Splits.Split_Command :=
          (case App_Action is
              when Terminal.App.Key_Bindings.Split_Horizontal =>
                Terminal.App.Splits.Split_Horizontal,
              when Terminal.App.Key_Bindings.Split_Vertical =>
                Terminal.App.Splits.Split_Vertical,
              when Terminal.App.Key_Bindings.Close_Pane =>
                Terminal.App.Splits.Close_Pane,
              when Terminal.App.Key_Bindings.Next_Pane =>
                Terminal.App.Splits.Next_Pane,
              when others => Terminal.App.Splits.No_Command);
   begin
      if Event.Key_Event.Action = GLFW_Vulkan.Input.Release then
         Chunk := (others => <>);
      elsif App_Action in Terminal.App.Key_Bindings.New_Window
        | Terminal.App.Key_Bindings.Detach_Tab
      then
         Launch_Separate_Window
           (App_Action = Terminal.App.Key_Bindings.Detach_Tab);
         Chunk := (others => <>);
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      elsif App_Action = Terminal.App.Key_Bindings.Settings then
         Terminal.App.Command_Palette.Leave (Command_Palette);
         Terminal.App.Copy_Mode.Leave (Copy_State);
         Terminal.App.Selection.Clear (Selection);
         if Terminal.App.Settings.Active (Settings) then
            Terminal.App.Settings.Leave (Settings);
         else
            Terminal.App.Settings.Enter (Settings);
         end if;
         Chunk := (others => <>);
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      elsif App_Action = Terminal.App.Key_Bindings.Reload_Config then
         declare
            Candidate : Terminal.App.Config.Config;
            Applied : Boolean := False;
            Override_Accepted : Boolean := True;
         begin
            Terminal.App.Config.Load (Candidate);
            if Workspace_Override /= "" then
               Terminal.App.Config.Set_Workspace_Path
                 (Candidate, Workspace_Override, Override_Accepted);
            end if;
            if Candidate.Load_Status = Terminal.App.Config.Config_Loaded
              and then Override_Accepted
            then
               Apply_Runtime_Config (Candidate, Applied);
            end if;
            Terminal.App.Settings.Enter (Settings);
            Terminal.App.Settings.Set_Message
              (Settings,
               (if Applied then "configuration reloaded"
                else "reload rejected: "
                  & Terminal.App.Config.Status_Label (Candidate)));
         end;
         Chunk := (others => <>);
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      elsif Terminal.App.Settings.Active (Settings) then
         declare
            Key : constant GLFW_Vulkan.Input.Key := Event.Key_Event.Key;
            Candidate : Terminal.App.Config.Config := App_Config;
            Changed, Applied : Boolean := False;
         begin
            if Key = GLFW_Vulkan.Input.Escape then
               Terminal.App.Settings.Leave (Settings);
            elsif Terminal.App.Settings.Editing (Settings) then
               if Key = GLFW_Vulkan.Input.Backspace then
                  Terminal.App.Settings.Backspace (Settings);
               elsif Key = GLFW_Vulkan.Input.Enter then
                  Terminal.App.Settings.Apply_Edit
                    (Settings, Candidate, Changed);
                  if Changed then
                     Apply_Runtime_Config (Candidate, Applied);
                     Terminal.App.Settings.Set_Message
                       (Settings,
                        (if Applied then "applied" else "runtime rejected value"));
                  end if;
               end if;
            elsif Key in GLFW_Vulkan.Input.Up | GLFW_Vulkan.Input.Down then
               Terminal.App.Settings.Move
                 (Settings, (if Key = GLFW_Vulkan.Input.Up then -1 else 1));
            elsif Key in GLFW_Vulkan.Input.Left | GLFW_Vulkan.Input.Right then
               Terminal.App.Settings.Adjust
                 (Settings, Candidate,
                  (if Key = GLFW_Vulkan.Input.Left then -1 else 1), Changed);
               if Changed then
                  Apply_Runtime_Config (Candidate, Applied);
                  if not Applied then
                     Terminal.App.Settings.Set_Message
                       (Settings, "runtime rejected value");
                  end if;
               end if;
            elsif Key = GLFW_Vulkan.Input.Enter then
               Terminal.App.Settings.Begin_Edit (Settings);
            end if;
         end;
         Chunk := (others => <>);
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      elsif Terminal.App.Text_Composition.Active (Text_Composition) then
         Chunk := (others => <>);
         if Event.Key_Event.Key = GLFW_Vulkan.Input.Escape then
            Terminal.App.Text_Composition.Cancel (Text_Composition);
         elsif Event.Key_Event.Key = GLFW_Vulkan.Input.Backspace then
            Terminal.App.Text_Composition.Backspace (Text_Composition);
         elsif Event.Key_Event.Key in GLFW_Vulkan.Input.Enter | GLFW_Vulkan.Input.Space then
            Commit_Text_Composition;
         end if;
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      elsif Event.Key_Event.Key = GLFW_Vulkan.Input.U
        and then Event.Key_Event.Modifiers.Control
        and then Event.Key_Event.Modifiers.Shift
        and then not Event.Key_Event.Modifiers.Alt
        and then not Event.Key_Event.Modifiers.Super
      then
         Terminal.App.Command_Palette.Leave (Command_Palette);
         Terminal.App.Copy_Mode.Leave (Copy_State);
         Terminal.App.Hyperlinks.Leave_Hints (Link_Hints);
         Terminal.App.Selection.Clear (Selection);
         Terminal.App.Text_Composition.Begin_Composition (Text_Composition);
         Chunk := (others => <>);
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      elsif App_Action = Terminal.App.Key_Bindings.Command_Palette then
         Terminal.App.Copy_Mode.Leave (Copy_State);
         Terminal.App.Hyperlinks.Leave_Hints (Link_Hints);
         Terminal.App.Selection.Clear (Selection);
         Terminal.App.Command_Palette.Enter
           (Command_Palette, App_Config.Session_Profiles);
         Chunk := (others => <>);
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      elsif Terminal.App.Command_Palette.Active (Command_Palette) then
         declare
            Key : constant GLFW_Vulkan.Input.Key := Event.Key_Event.Key;
         begin
            if Key = GLFW_Vulkan.Input.Escape then
               Terminal.App.Command_Palette.Leave (Command_Palette);
            elsif Key = GLFW_Vulkan.Input.Backspace then
               Terminal.App.Command_Palette.Backspace (Command_Palette);
            elsif Key in GLFW_Vulkan.Input.Up | GLFW_Vulkan.Input.Left
              or else (Key = GLFW_Vulkan.Input.Tab
                and then Event.Key_Event.Modifiers.Shift)
            then
               Terminal.App.Command_Palette.Move (Command_Palette, -1);
            elsif Key in GLFW_Vulkan.Input.Down | GLFW_Vulkan.Input.Right
              or else Key = GLFW_Vulkan.Input.Tab
            then
               Terminal.App.Command_Palette.Move (Command_Palette, 1);
            elsif Key = GLFW_Vulkan.Input.Enter
              and then Terminal.App.Command_Palette.Match_Count
                (Command_Palette) > 0
            then
               declare
                  Choice : constant Terminal.App.Command_Palette.Choice :=
                    Terminal.App.Command_Palette.Selected (Command_Palette);
               begin
                  Terminal.App.Command_Palette.Leave (Command_Palette);
                  if Choice.Kind = Terminal.App.Command_Palette.Action_Choice then
                     Forced_Action := Choice.Action;
                     In_Q.Push
                       ((Kind => Terminal.App.Queues.Key,
                         Key_Event =>
                           (Key => GLFW_Vulkan.Input.Unknown,
                            Raw_Key => 0,
                            Scancode => 0,
                            Action => GLFW_Vulkan.Input.Press,
                            Modifiers => (others => False))));
                  else
                     Terminal.App.Session_Table.New_Tab
                       (Sessions, Last_Rows, Last_Cols,
                        App_Config.Scrollback_Limit, Session_Table_Status);
                     if Session_Table_Status = Terminal.App.Session_Table.Ok then
                        declare
                           Profile : constant Terminal.App.Session_Profiles.Profile :=
                             Terminal.App.Session_Profiles.Item
                               (App_Config.Session_Profiles, Choice.Profile_Index);
                           Index : constant Terminal.App.Sessions.Session_Index :=
                             Terminal.App.Session_Table.Active (Sessions);
                        begin
                           Apply_Profile (Index, Profile);
                           Terminal.App.Session_Table.Set_Active_Tab_Label
                             (Sessions,
                              Terminal.App.Session_Profiles.Name (Profile),
                              Session_Table_Status);
                        end;
                        Configure_Visible_Cores;
                        Scroll_Offset := 0;
                     end if;
                  end if;
               end;
            end if;
         end;
         Chunk := (others => <>);
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      elsif App_Action = Terminal.App.Key_Bindings.Search then
         Terminal.App.Hyperlinks.Leave_Hints (Link_Hints);
         Enter_Copy_Mode (Search => True);
         Chunk := (others => <>);
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      elsif App_Action = Terminal.App.Key_Bindings.Copy_Mode then
         Terminal.App.Hyperlinks.Leave_Hints (Link_Hints);
         if Terminal.App.Copy_Mode.Active (Copy_State) then
            Terminal.App.Copy_Mode.Leave (Copy_State);
            Terminal.App.Selection.Clear (Selection);
         else
            Enter_Copy_Mode (Search => False);
         end if;
         Chunk := (others => <>);
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      elsif App_Action = Terminal.App.Key_Bindings.Open_Links then
         Terminal.App.Copy_Mode.Leave (Copy_State);
         Enter_Link_Hints;
         if not Terminal.App.Hyperlinks.Hints_Active (Link_Hints) then
            Has_Link_Activation := True;
            Link_Activation := Terminal.App.Hyperlinks.No_Link;
         end if;
         Chunk := (others => <>);
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      elsif Terminal.App.Hyperlinks.Hints_Active (Link_Hints) then
         declare
            Key : constant GLFW_Vulkan.Input.Key := Event.Key_Event.Key;
         begin
            if Key = GLFW_Vulkan.Input.Escape then
               Terminal.App.Hyperlinks.Leave_Hints (Link_Hints);
               Terminal.App.Selection.Clear (Selection);
            elsif Key = GLFW_Vulkan.Input.Enter then
               Terminal.App.Hyperlinks.Activate
                 (Terminal.App.Hyperlinks.Current_Hint_Link (Link_Hints),
                  Link_Activation);
               Has_Link_Activation := True;
               Terminal.App.Hyperlinks.Leave_Hints (Link_Hints);
               Terminal.App.Selection.Clear (Selection);
            elsif Key in GLFW_Vulkan.Input.Left | GLFW_Vulkan.Input.Up
              or else
                (Key = GLFW_Vulkan.Input.Tab
                 and then Event.Key_Event.Modifiers.Shift)
            then
               Terminal.App.Hyperlinks.Move_Hint (Link_Hints, -1);
               Refresh_Link_Hint_Selection;
            elsif Key in GLFW_Vulkan.Input.Right | GLFW_Vulkan.Input.Down
              or else Key = GLFW_Vulkan.Input.Tab
            then
               Terminal.App.Hyperlinks.Move_Hint (Link_Hints, 1);
               Refresh_Link_Hint_Selection;
            end if;
         end;
         Chunk := (others => <>);
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      elsif Terminal.App.Copy_Mode.Active (Copy_State) then
         declare
            Extend : constant Boolean := Event.Key_Event.Modifiers.Shift;
            Key : constant GLFW_Vulkan.Input.Key := Event.Key_Event.Key;
            procedure Move_Page (Direction : Integer) is
               procedure Apply (Core : in out Terminal.Core.Terminal) is
               begin
                  Terminal.App.Copy_Mode.Move_Page
                    (Copy_State, Core, Direction);
                  Scroll_Offset :=
                    Terminal.App.Copy_Mode.Recommended_Offset
                      (Copy_State, Core);
                  Terminal.App.Copy_Mode.Select_Cursor
                    (Copy_State, Core, Scroll_Offset, Selection, Extend);
               end Apply;
            begin
               Terminal.App.Session_Runtime.With_Core
                 (Active_Core, Apply'Access);
            end Move_Page;
            procedure Move_Edge (Last : Boolean) is
               procedure Apply (Core : in out Terminal.Core.Terminal) is
               begin
                  Terminal.App.Copy_Mode.Move_Row_Edge
                    (Copy_State, Core, Last);
                  Terminal.App.Copy_Mode.Select_Cursor
                    (Copy_State, Core, Scroll_Offset, Selection, Extend);
               end Apply;
            begin
               Terminal.App.Session_Runtime.With_Core
                 (Active_Core, Apply'Access);
            end Move_Edge;
         begin
            if Key = GLFW_Vulkan.Input.Escape then
               Terminal.App.Copy_Mode.Leave (Copy_State);
               Terminal.App.Selection.Clear (Selection);
            elsif App_Action = Terminal.App.Key_Bindings.Copy then
               Copy_Selection;
               Terminal.App.Copy_Mode.Leave (Copy_State);
               Terminal.App.Selection.Clear (Selection);
            elsif Terminal.App.Copy_Mode.Searching (Copy_State) then
               if Event.Key_Event.Modifiers.Alt
                 and then Key = GLFW_Vulkan.Input.R
               then
                  Terminal.App.Copy_Mode.Toggle_Regex (Copy_State);
                  Refresh_Copy_Selection (Search => True, Restart => True);
               elsif Event.Key_Event.Modifiers.Alt
                 and then Key = GLFW_Vulkan.Input.C
               then
                  Terminal.App.Copy_Mode.Toggle_Case (Copy_State);
                  Refresh_Copy_Selection (Search => True, Restart => True);
               elsif Event.Key_Event.Modifiers.Alt
                 and then Key = GLFW_Vulkan.Input.W
               then
                  Terminal.App.Copy_Mode.Toggle_Whole_Word (Copy_State);
                  Refresh_Copy_Selection (Search => True, Restart => True);
               elsif Event.Key_Event.Modifiers.Control
                 and then Key in GLFW_Vulkan.Input.Up | GLFW_Vulkan.Input.Down
               then
                  Terminal.App.Copy_Mode.History_Move
                    (Copy_State,
                     (if Key = GLFW_Vulkan.Input.Up then -1 else 1));
                  Refresh_Copy_Selection (Search => True, Restart => True);
               elsif Key = GLFW_Vulkan.Input.Backspace then
                  Terminal.App.Copy_Mode.Backspace (Copy_State);
                  Refresh_Copy_Selection
                    (Search => True, Restart => True);
               elsif Key = GLFW_Vulkan.Input.Enter
                 or else Key = GLFW_Vulkan.Input.Down
               then
                  Terminal.App.Copy_Mode.Remember_Query (Copy_State);
                  Refresh_Copy_Selection (Search => True);
               elsif Key = GLFW_Vulkan.Input.Up then
                  Terminal.App.Copy_Mode.Remember_Query (Copy_State);
                  Refresh_Copy_Selection (Search => True, Backward => True);
               end if;
            elsif Key = GLFW_Vulkan.Input.Enter
              or else Key = GLFW_Vulkan.Input.Y
            then
               Copy_Selection;
               Terminal.App.Copy_Mode.Leave (Copy_State);
               Terminal.App.Selection.Clear (Selection);
            elsif Key = GLFW_Vulkan.Input.Up or else Key = GLFW_Vulkan.Input.K then
               Move_Copy_Cursor (-1, 0, Extend);
            elsif Key = GLFW_Vulkan.Input.Down or else Key = GLFW_Vulkan.Input.J then
               Move_Copy_Cursor (1, 0, Extend);
            elsif Key = GLFW_Vulkan.Input.Left or else Key = GLFW_Vulkan.Input.H then
               Move_Copy_Cursor (0, -1, Extend);
            elsif Key = GLFW_Vulkan.Input.Right or else Key = GLFW_Vulkan.Input.L then
               Move_Copy_Cursor (0, 1, Extend);
            elsif Key = GLFW_Vulkan.Input.Page_Up then
               Move_Page (-1);
            elsif Key = GLFW_Vulkan.Input.Page_Down then
               Move_Page (1);
            elsif Key = GLFW_Vulkan.Input.Home then
               Move_Edge (False);
            elsif Key = GLFW_Vulkan.Input.End_Key then
               Move_Edge (True);
            end if;
         end;
         Chunk := (others => <>);
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      elsif App_Action in Terminal.App.Key_Bindings.Font_Increase
        | Terminal.App.Key_Bindings.Font_Decrease
        | Terminal.App.Key_Bindings.Font_Reset
      then
         Apply_Font_Size
           ((case App_Action is
                when Terminal.App.Key_Bindings.Font_Increase =>
                  Positive'Min
                    (Terminal.App.Config.Max_Font_Pixel_Size,
                     Active_Font_Size + 1),
                when Terminal.App.Key_Bindings.Font_Decrease =>
                  Positive'Max
                    (Terminal.App.Config.Min_Font_Pixel_Size,
                     Active_Font_Size - Boolean'Pos
                       (Active_Font_Size > Terminal.App.Config.Min_Font_Pixel_Size)),
                when others => App_Config.Font_Pixel_Size));
         Chunk := (others => <>);
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      elsif App_Action in Terminal.App.Key_Bindings.Previous_Mark
        | Terminal.App.Key_Bindings.Next_Mark
      then
         declare
            procedure Jump (Core : in out Terminal.Core.Terminal) is
            begin
               Scroll_Offset :=
                 (if App_Action = Terminal.App.Key_Bindings.Previous_Mark
                  then Terminal.App.Scrollback_View.Previous_Mark_Offset
                    (Core, Scroll_Offset)
                  else Terminal.App.Scrollback_View.Next_Mark_Offset
                    (Core, Scroll_Offset));
            end Jump;
         begin
            Terminal.App.Session_Runtime.With_Core (Active_Core, Jump'Access);
         end;
         Chunk := (others => <>);
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      elsif App_Action in Terminal.App.Key_Bindings.Select_Command_Block
        | Terminal.App.Key_Bindings.Copy_Command_Block
        | Terminal.App.Key_Bindings.Rerun_Command_Block
      then
         declare
            Text : Unbounded.Unbounded_String;
            procedure Apply (Core : in out Terminal.Core.Terminal) is
               Block : constant Terminal.Core.Shell_Command_Block :=
                 Terminal.App.Shell_Blocks.Latest (Core);
               First, Last : Terminal.App.Selection.Cell_Position;
               Visible : Boolean;
            begin
               if App_Action = Terminal.App.Key_Bindings.Select_Command_Block then
                  Scroll_Offset := Terminal.App.Shell_Blocks.Recommended_Offset
                    (Core, Block);
                  Terminal.App.Shell_Blocks.Visible_Range
                    (Core, Block, Scroll_Offset, First, Last, Visible);
                  if Visible then
                     Terminal.App.Selection.Begin_Selection (Selection, First);
                     Terminal.App.Selection.Finish_Selection (Selection, Last);
                  else
                     Terminal.App.Selection.Clear (Selection);
                  end if;
               else
                  Text := Unbounded.To_Unbounded_String
                    (Terminal.App.Shell_Blocks.Command_Text (Core, Block));
               end if;
            end Apply;
         begin
            Terminal.App.Session_Runtime.With_Core (Active_Core, Apply'Access);
            if App_Action = Terminal.App.Key_Bindings.Copy_Command_Block
              and then Unbounded.Length (Text) > 0
            then
               GLFW_Vulkan.Clipboard.Set_Text (W, Unbounded.To_String (Text));
               Terminal.App.Clipboard_OSC52.Store_Local_Selection
                 (Clipboard_Targets, Unbounded.To_String (Text));
            elsif App_Action = Terminal.App.Key_Bindings.Rerun_Command_Block
              and then Unbounded.Length (Text) > 0
            then
               Send_Shell_Command
                 (Terminal.App.Session_Table.Active (Sessions),
                  Unbounded.To_String (Text));
               Scroll_Offset := 0;
            end if;
         end;
         Chunk := (others => <>);
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      elsif App_Action = Terminal.App.Key_Bindings.Toggle_Pane_Zoom then
         if Terminal.App.Splits.Count (Splits) > 1 then
            Pane_Zoomed := not Pane_Zoomed;
            Configure_Visible_Cores;
            Scroll_Offset := 0;
            Terminal.App.Selection.Clear (Selection);
         else
            Pane_Zoomed := False;
         end if;
         Chunk := (others => <>);
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      elsif App_Action = Terminal.App.Key_Bindings.Move_Pane then
         if Terminal.App.Splits.Count (Splits) > 1 then
            declare
               From : constant Terminal.App.Sessions.Session_Index :=
                 Terminal.App.Session_Table.Active (Sessions);
               To : constant Terminal.App.Sessions.Session_Index :=
                 (if From = Terminal.App.Splits.Count (Splits)
                  then 1 else From + 1);
            begin
               Terminal.App.Session_Table.Move_Active_Pane
                 (Sessions, Session_Table_Status);
               if Session_Table_Status = Terminal.App.Session_Table.Ok then
                  Move_Session_Command (From, To);
                  Configure_Visible_Cores;
                  Scroll_Offset := 0;
                  Terminal.App.Selection.Clear (Selection);
               end if;
            end;
         end if;
         Chunk := (others => <>);
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      elsif App_Action = Terminal.App.Key_Bindings.Broadcast_Input then
         Broadcast_Input :=
           Terminal.App.Splits.Count (Splits) > 1 and then not Broadcast_Input;
         Chunk := (others => <>);
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      elsif App_Action = Terminal.App.Key_Bindings.Toggle_Recording then
         declare
            Status : Terminal.App.Session_Recording.IO_Status;
         begin
            if Terminal.App.Session_Recording.Active (Recording) then
               Terminal.App.Session_Recording.Stop (Recording, Status);
            else
               Terminal.App.Session_Recording.Start
                 (Recording, Recording_Path, Last_Rows, Last_Cols, Status);
            end if;
            if Status /= Terminal.App.Session_Recording.Ok then
               Terminal.App.Settings.Enter (Settings);
               Terminal.App.Settings.Set_Message
                 (Settings, "recording operation failed");
            end if;
         end;
         Chunk := (others => <>);
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      elsif App_Action = Terminal.App.Key_Bindings.Replay_Recording then
         declare
            Status : Terminal.App.Session_Recording.IO_Status;
            procedure Feed_Replay
              (Stream : Terminal.Core.Graphics_Stream_ID;
               Replay_Chunk : Terminal.App.Queues.Byte_Chunk)
            is
               procedure Apply (Core : in out Terminal.Core.Terminal) is
                  Feed : Terminal.Core.Feed_Status;
               begin
                  if Replay_Chunk.Length > 0 then
                     Terminal.Core.Feed
                       (Core,
                        Replay_Chunk.Data (1 .. Replay_Chunk.Length),
                        Feed);
                     if Feed /= Terminal.Core.Ok then Last_Feed_Status := Feed; end if;
                  end if;
               end Apply;
            begin
               for I in 1 .. Terminal.App.Session_Table.Count (Sessions) loop
                  declare
                     Runtime : constant Terminal.App.Session_Table.Runtime_Borrow :=
                       Terminal.App.Session_Table.Runtime_At (Sessions, I);
                     Core : constant Terminal.App.Session_Runtime.Core_Borrow :=
                       Terminal.App.Session_Table.Core (Runtime);
                  begin
                     if Terminal.App.Session_Table.Graphics_Stream_ID (Runtime) =
                       Stream
                     then
                        Terminal.App.Session_Runtime.With_Core
                          (Core, Apply'Access);
                        exit;
                     end if;
                  end;
               end loop;
            end Feed_Replay;
         begin
            Terminal.App.Session_Recording.Replay
              (Recording_Path, Feed_Replay'Access, Status);
            if Status /= Terminal.App.Session_Recording.Ok then
               Terminal.App.Settings.Enter (Settings);
               Terminal.App.Settings.Set_Message
                 (Settings, "recording replay failed");
            end if;
         end;
         Scroll_Offset := 0;
         Chunk := (others => <>);
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      elsif App_Action = Terminal.App.Key_Bindings.Export_Transcript then
         declare
            Status : Terminal.App.Session_Recording.IO_Status;
            procedure Export (Core : in out Terminal.Core.Terminal) is
            begin
               Terminal.App.Session_Recording.Export_Transcript
                 (Core, Transcript_Path, Status);
            end Export;
         begin
            Terminal.App.Session_Runtime.With_Core
              (Active_Core, Export'Access);
            if Status /= Terminal.App.Session_Recording.Ok then
               Terminal.App.Settings.Enter (Settings);
               Terminal.App.Settings.Set_Message
                 (Settings, "transcript export failed");
            end if;
         end;
         Chunk := (others => <>);
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
      elsif Tab_Command /= Terminal.App.Tabs.No_Command then
         case Tab_Command is
            when Terminal.App.Tabs.New_Tab =>
               Terminal.App.Session_Table.New_Tab
                 (Sessions,
                  Last_Rows,
                  Last_Cols,
                  App_Config.Scrollback_Limit,
                  Session_Table_Status);
               if Session_Table_Status =
                 Terminal.App.Session_Table.Ok
               then
                  Start_Default_Or_Configured
                    (Terminal.App.Session_Table.Active (Sessions));
                  Configure_Visible_Cores;
                  Scroll_Offset := 0;
                  Terminal.App.Selection.Clear (Selection);
                  Apply_Hovered_Link ((others => <>));
               end if;
            when Terminal.App.Tabs.Close_Tab =>
               declare
                  Closed_Index : constant Terminal.App.Sessions.Session_Index :=
                    Terminal.App.Session_Table.Active (Sessions);
                  Closed_Stream : constant
                    Terminal.Core.Graphics_Stream_ID :=
                      Terminal.App.Session_Table.Graphics_Stream_ID
                        (Active_Runtime);
               begin
                  Terminal.App.Session_Table.Close_Tab
                    (Sessions, Session_Table_Status);
                  if Session_Table_Status =
                    Terminal.App.Session_Table.Ok
                  then
                     Forget_Session_Command (Closed_Index);
                     Terminal.App.Renderer.Graphics
                       .Release_Stream
                         (R, Closed_Stream);
                     if Terminal.App.Splits.Count (Splits) <= 1 then
                        Pane_Zoomed := False;
                        Broadcast_Input := False;
                     end if;
                     Configure_Visible_Cores;
                     Scroll_Offset := 0;
                     Terminal.App.Selection.Clear (Selection);
                     Apply_Hovered_Link ((others => <>));
                  end if;
               end;
            when Terminal.App.Tabs.Next_Tab
               | Terminal.App.Tabs.Previous_Tab =>
               Terminal.App.Session_Table.Apply_Tab_Navigation
                 (Sessions, Tab_Command, Session_Table_Status);
               if Session_Table_Status = Terminal.App.Session_Table.Ok then
                  Configure_Visible_Cores;
                  Scroll_Offset := 0;
                  Terminal.App.Selection.Clear (Selection);
                  Apply_Hovered_Link ((others => <>));
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
                  Split_Command,
                  Last_Rows,
                  Last_Cols,
                  App_Config.Scrollback_Limit,
                  Session_Table_Status);
               if Session_Table_Status =
                 Terminal.App.Session_Table.Ok
               then
                  Start_Default_Or_Configured
                    (Terminal.App.Session_Table.Active (Sessions));
                  Configure_Visible_Cores;
                  Scroll_Offset := 0;
                  Terminal.App.Selection.Clear (Selection);
                  Apply_Hovered_Link ((others => <>));
               end if;
            when Terminal.App.Splits.Close_Pane =>
               declare
                  Closed_Index : constant Terminal.App.Sessions.Session_Index :=
                    Terminal.App.Session_Table.Active (Sessions);
                  Closed_Stream : constant
                    Terminal.Core.Graphics_Stream_ID :=
                      Terminal.App.Session_Table.Graphics_Stream_ID
                        (Active_Runtime);
               begin
                  Terminal.App.Session_Table.Close_Pane
                    (Sessions,
                     Session_Table_Status);
                  if Session_Table_Status =
                    Terminal.App.Session_Table.Ok
                  then
                     Forget_Session_Command (Closed_Index);
                     Terminal.App.Renderer.Graphics
                       .Release_Stream
                         (R, Closed_Stream);
                     Configure_Visible_Cores;
                     Scroll_Offset := 0;
                     Terminal.App.Selection.Clear (Selection);
                     Apply_Hovered_Link ((others => <>));
                  end if;
               end;
            when Terminal.App.Splits.Next_Pane =>
               Terminal.App.Session_Table.Apply_Pane_Navigation
                 (Sessions, Split_Command, Session_Table_Status);
               if Session_Table_Status = Terminal.App.Session_Table.Ok then
                  Configure_Visible_Cores;
                  Scroll_Offset := 0;
                  Terminal.App.Selection.Clear (Selection);
                  Apply_Hovered_Link ((others => <>));
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
           Terminal.App.Session_Runtime.With_Core
             (Active_Core, Clamp_Page_Up'Access);
         elsif Scroll_Offset > Last_Rows then
            Scroll_Offset := Scroll_Offset - Last_Rows;
         else
            Scroll_Offset := 0;
         end if;
         Dirty := True;
         Need_Redraw := True;
         Local_Redraw := True;
         Chunk := (others => <>);
      elsif App_Action = Terminal.App.Key_Bindings.Paste
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
            if Broadcast_Input
              and then Terminal.App.Splits.Count (Splits) > 1
            then
               Write_Stat := Terminal.App.PTY_Write.Ok;
               for I in 1 .. Terminal.App.Splits.Count (Splits) loop
                  declare
                     One_Status : Terminal.App.PTY_Write.Write_All_Status;
                  begin
                     Terminal.App.Session_Table.Write_Paste
                       (Terminal.App.Session_Table.Runtime_At
                          (Sessions, Terminal.App.Sessions.Session_Index (I)),
                        GLFW_Vulkan.Clipboard.Get_Text (W),
                        Modes.Bracketed_Paste,
                        One_Status);
                     if One_Status /= Terminal.App.PTY_Write.Ok then
                        Write_Stat := One_Status;
                     end if;
                  end;
               end loop;
            else
               Terminal.App.Session_Table.Write_Paste
                 (Active_Runtime,
                  GLFW_Vulkan.Clipboard.Get_Text (W),
                  Modes.Bracketed_Paste,
                  Write_Stat);
            end if;
            Last_Write_Status := Write_Stat;
            if Fatal_Write (Write_Stat)
              and then Terminal.App.Session_Table.Count (Sessions) = 1
            then
               GLFW_Vulkan.Windows.Set_Should_Close (W, True);
            end if;
            Chunk := (others => <>);
         end if;
      elsif App_Action = Terminal.App.Key_Bindings.Copy
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

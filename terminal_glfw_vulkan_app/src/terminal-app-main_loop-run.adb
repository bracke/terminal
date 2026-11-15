with GLFW_Vulkan.Input.Scoped_Binding;

separate (Terminal.App.Main_Loop)
procedure Run (Workspace_Override : String := "") is
   use type Terminal.App.Renderer.Graphics.Resource_Limit_Update_Status;
   subtype Runtime_Snapshot_Array is Terminal.App.Renderer.Snapshot_Array
     (1 .. Terminal.App.Sessions.Max_Sessions);
   type Runtime_Owners is limited record
      GLFW_Context : GLFW_Vulkan.Context;
      Window       : aliased GLFW_Vulkan.Windows.Window;
      Renderer     : Terminal.App.Renderer.Renderer;
      Vulkan_Context : Terminal.App.Vulkan_Context.Context;
      Presenter    : Terminal.App.Vulkan_Presenter.Presenter;
      Sessions     : aliased Terminal.App.Session_Table.Runtime_Table;
      Snapshots : Runtime_Snapshot_Array;
      GLFW_Ready   : Boolean := False;
      Window_Ready : Boolean := False;
      Sessions_Ready : Boolean := False;
   end record;
   Owners : Runtime_Owners;
   Ctx : GLFW_Vulkan.Context renames Owners.GLFW_Context;
   W   : GLFW_Vulkan.Windows.Window renames Owners.Window;
   R   : Terminal.App.Renderer.Renderer renames Owners.Renderer;
   Vk_Ctx : Terminal.App.Vulkan_Context.Context renames Owners.Vulkan_Context;
   Presenter : Terminal.App.Vulkan_Presenter.Presenter renames Owners.Presenter;
   Sessions : Terminal.App.Session_Table.Runtime_Table renames Owners.Sessions;
   Snapshot_Cache : Runtime_Snapshot_Array renames Owners.Snapshots;
   GLFW_Ready : Boolean renames Owners.GLFW_Ready;
   Window_Ready : Boolean renames Owners.Window_Ready;
   Sessions_Ready : Boolean renames Owners.Sessions_Ready;
   Init_Status : GLFW_Vulkan.Init_Status;
   Window_Status : GLFW_Vulkan.Windows.Create_Status;
   Session_Table_Status : Terminal.App.Session_Table.Table_Status;
   In_Q  : aliased Terminal.App.Queues.Input_Event_Queue;
   Input_Grace : Natural := 0;
   Left_Press_Debounce : Terminal.App.Click_Debounce.State;
   Vk_Status : Terminal.App.Vulkan_Context.Init_Status;
   Presenter_Status : Terminal.App.Vulkan_Presenter.Init_Status;
   Vulkan_Recovery : Terminal.App.Vulkan_Recovery.Controller;
   Recovery_Tick : Natural := 0;
   Renderer_Status : Terminal.App.Renderer.Init_Status;
   Theme_Status : Terminal.App.Renderer.Theme_Update_Status;
   App_Config : Terminal.App.Config.Config;
   Active_Font_Path : Unbounded.Unbounded_String;
   Active_Font_Size : Positive := Terminal.App.Config.Default_Font_Pixel_Size;
   Runtime_Graphics : Terminal.App.Graphics_Profile.Runtime_Profile :=
     Terminal.App.Graphics_Profile.Default;
   FB_Width  : Natural := 0;
   FB_Height : Natural := 0;
   Initial_Rows : Positive := Terminal.App.Config.Default_Startup_Rows;
   Initial_Cols : Positive := Terminal.App.Config.Default_Startup_Cols;
   Last_Rows : Positive := Terminal.App.Config.Default_Startup_Rows;
   Last_Cols : Positive := Terminal.App.Config.Default_Startup_Cols;
   Need_Redraw : Boolean := True;
   Scroll_Offset : Natural := 0;
   Clipboard_Targets : Terminal.App.Clipboard_OSC52.Target_Store;
   Selection : Terminal.App.Selection.Selection_State;
   Copy_State : Terminal.App.Copy_Mode.State;
   Link_Hints : Terminal.App.Hyperlinks.Hint_State;
   Command_Palette : Terminal.App.Command_Palette.State;
   Settings : Terminal.App.Settings.State;
   Text_Composition : Terminal.App.Text_Composition.State;
   Accessibility : Terminal.App.Accessibility.State;
   Pane_Zoomed : Boolean := False;
   Broadcast_Input : Boolean := False;
   Recording : Terminal.App.Session_Recording.State;
   Forced_Action : Terminal.App.Key_Bindings.Action :=
     Terminal.App.Key_Bindings.No_Action;
   type Workspace_Command_Array is
     array (Terminal.App.Sessions.Session_Index) of
       Terminal.App.Workspace.Bounded_Command;
   Workspace_Commands : Workspace_Command_Array := (others => <>);
   Window_Handoff_Serial : Natural := 0;
   Hovered_Link : Terminal.Core.Hyperlink;
   Has_Link_Activation : Boolean := False;
   Link_Activation :
     Terminal.App.Hyperlinks.Activation_Status :=
       Terminal.App.Hyperlinks.No_Link;
   Mouse_Button_Down : Boolean := False;
   Mouse_Button_Code_Value : Natural := 0;
   Mouse_Modifiers : GLFW_Vulkan.Input.Modifier_Set;
   type Chrome_Drag_Kind is
     (No_Chrome_Drag, Tab_Chrome_Drag, Divider_Chrome_Drag,
      Scrollbar_Chrome_Drag);
   Chrome_Drag : Chrome_Drag_Kind := No_Chrome_Drag;
   Suppress_Chrome_Release : Boolean := False;
   Chrome_Press_Button : GLFW_Vulkan.Input.Mouse_Button :=
     GLFW_Vulkan.Input.Other;
   Drag_Tab : Terminal.App.Tabs.Tab_Index := 1;
   Drag_Divider : Terminal.App.Splits.Divider_Index := 1;
   Suppress_Character : Wide_Wide_Character :=
     Wide_Wide_Character'Val (0);
   Blink_Origin : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
   Last_Blink_Tick : Natural := 0;
   Visible_Blink_Activity : Terminal.App.Blink_Activity.Activity;
   Last_Feed_Status : Terminal.Core.Feed_Status := Terminal.Core.Ok;
   Last_Write_Status : Terminal.App.PTY_Write.Write_All_Status :=
     Terminal.App.PTY_Write.Ok;
   Last_Clipboard_Target : Terminal.Core.Clipboard_Target :=
     Terminal.Core.Clipboard_Clipboard;
   function Runtime_Font_Status return String is
     (Terminal.App.Fonts.Status_Label
        (Unbounded.To_String (Active_Font_Path),
         Terminal.App.Fonts.Fallback_Font_Paths'Length));
   function Interaction_Status return String is
     (if Terminal.App.Text_Composition.Active (Text_Composition)
      then Terminal.App.Text_Composition.Status_Label (Text_Composition)
      elsif Terminal.App.Command_Palette.Active (Command_Palette)
      then Terminal.App.Command_Palette.Status_Label (Command_Palette)
      elsif Terminal.App.Settings.Active (Settings)
      then Terminal.App.Settings.Status_Label (Settings, App_Config)
      elsif Terminal.App.Hyperlinks.Hints_Active (Link_Hints)
      then Terminal.App.Hyperlinks.Hint_Status_Label (Link_Hints)
      elsif Terminal.App.Copy_Mode.Active (Copy_State)
      then Terminal.App.Copy_Mode.Status_Label (Copy_State)
      elsif Terminal.App.Session_Recording.Active (Recording)
      then Terminal.App.Session_Recording.Status_Label (Recording)
      elsif Broadcast_Input then "BROADCAST INPUT"
      elsif Pane_Zoomed then "PANE ZOOM"
      else "");

   function Recording_Path return String is
      Workspace : constant String :=
        Terminal.App.Config.Workspace_Path_String (App_Config);
   begin
      return (if Workspace = "" then ".ada-terminal.recording"
              else Workspace & ".recording");
   end Recording_Path;

   function Transcript_Path return String is
      Workspace : constant String :=
        Terminal.App.Config.Workspace_Path_String (App_Config);
   begin
      return (if Workspace = "" then ".ada-terminal.txt"
              else Workspace & ".txt");
   end Transcript_Path;

   function Resolve_Action
     (Event : GLFW_Vulkan.Input.Key_Event)
      return Terminal.App.Key_Bindings.Action
   is
      Result : Terminal.App.Key_Bindings.Action;
   begin
      if Forced_Action /= Terminal.App.Key_Bindings.No_Action then
         Result := Forced_Action;
         Forced_Action := Terminal.App.Key_Bindings.No_Action;
         return Result;
      end if;
      return Terminal.App.Key_Bindings.Action_For (App_Config.Bindings, Event);
   end Resolve_Action;
   PTY_Capabilities : constant Terminal.PTY.Backend.Backend_Capabilities :=
     Terminal.PTY.Backend.Capabilities;
   Runtime_PTY_Backend_Status : constant String :=
     Terminal.PTY.Backend.Backend_Status_Label (PTY_Capabilities);
   Runtime_ConPTY_Status : constant String :=
     Terminal.PTY.Backend.ConPTY_Status_Label (PTY_Capabilities);
   Runtime_Multiplexer_Status : constant String :=
     Terminal.App.Multiplexer_Status_Label (Terminal.App.Profile);
   Last_Click_Time : Ada.Real_Time.Time := Blink_Origin;
   Last_Click_Pos  : Terminal.App.Selection.Cell_Position;
   Have_Last_Click : Boolean := False;
   Click_Count     : Natural := 0;

   procedure Send_Shell_Command
     (Index   : Terminal.App.Sessions.Session_Index;
      Command : String)
   is
      Chunk : Terminal.App.Queues.Byte_Chunk;
      Write_Status : Terminal.App.PTY_Write.Write_All_Status;
      Count : constant Natural := Command'Length;
   begin
      if Count = 0 or else Count >= Terminal.App.Queues.Max_Chunk_Length then
         return;
      end if;
      Chunk.Length := Count + 1;
      for I in 1 .. Count loop
         Chunk.Data (I) :=
           Terminal.Common.Bytes.Byte
             (Character'Pos (Command (Command'First + I - 1)));
      end loop;
      Chunk.Data (Chunk.Length) :=
        Terminal.Common.Bytes.Byte (Character'Pos (ASCII.CR));
      Terminal.App.Session_Table.Write
        (Terminal.App.Session_Table.Runtime_At (Sessions, Index),
         Chunk, Write_Status);
   end Send_Shell_Command;

   function Directory_Command (Path : String) return String is
      Command : String (1 .. Terminal.App.Queues.Max_Chunk_Length);
      Last : Natural := 0;
      procedure Append (Ch : Character) is
      begin
         if Last < Command'Last then
            Last := Last + 1;
            Command (Last) := Ch;
         end if;
      end Append;
      procedure Append (Text : String) is
      begin
         for Ch of Text loop Append (Ch); end loop;
      end Append;
   begin
      if Path = "" then return ""; end if;
      Append
        ((if PTY_Capabilities.POSIX_PTY then "cd -- """ else "cd /d """));
      for Ch of Path loop
         if PTY_Capabilities.POSIX_PTY and then Ch in '"' | '\' | '$' | '`' then
            Append ('\');
         elsif not PTY_Capabilities.POSIX_PTY and then Ch = '"' then
            Append ('"');
         end if;
         Append (Ch);
      end loop;
      Append ('"');
      return Command (1 .. Last);
   end Directory_Command;

   procedure Apply_Profile
     (Index : Terminal.App.Sessions.Session_Index;
      Value : Terminal.App.Session_Profiles.Profile)
   is
      Launch : constant String :=
        Terminal.App.Session_Profiles.Launch_Command (Value);
      Directory : constant String := Directory_Command
        (Terminal.App.Session_Profiles.Working_Directory (Value));
      Combined : constant String :=
        (if Directory = "" then Launch
         elsif Launch = "" then Directory
         else Directory & " && " & Launch);
      Name : Terminal.App.Theme.Theme_Name;
   begin
      if Terminal.App.Session_Profiles.Theme_Name (Value) /= ""
        and then Terminal.App.Theme.Parse_Name
          (Terminal.App.Session_Profiles.Theme_Name (Value), Name)
      then
         Terminal.App.Renderer.Set_Theme
           (R, Terminal.App.Theme.Built_In (Name), Theme_Status);
         if Theme_Status = Terminal.App.Renderer.Theme_Ok then
            App_Config.Color_Theme := Name;
         end if;
      end if;
      Terminal.App.Workspace.Set_Command (Workspace_Commands (Index), Launch);
      Send_Shell_Command (Index, Combined);
   end Apply_Profile;

   procedure Start_Configured_Command
     (Index : Terminal.App.Sessions.Session_Index)
   is
      Configured : constant String :=
        Terminal.App.Config.Startup_Command_String (App_Config);
   begin
      Terminal.App.Workspace.Set_Command
        (Workspace_Commands (Index), Configured);
      Send_Shell_Command (Index, Configured);
   end Start_Configured_Command;

   procedure Start_Default_Or_Configured
     (Index : Terminal.App.Sessions.Session_Index)
   is
      Default : constant Natural :=
        Terminal.App.Session_Profiles.Default_Index
          (App_Config.Session_Profiles);
   begin
      if Default > 0 then
         Apply_Profile
           (Index, Terminal.App.Session_Profiles.Item
             (App_Config.Session_Profiles, Default));
      else
         Start_Configured_Command (Index);
      end if;
   end Start_Default_Or_Configured;

   procedure Forget_Session_Command
     (Index : Terminal.App.Sessions.Session_Index)
   is
      Count : constant Natural := Terminal.App.Session_Table.Count (Sessions);
   begin
      for I in Index .. Terminal.App.Sessions.Session_Index (Count) loop
         if Natural (I) < Terminal.App.Sessions.Max_Sessions then
            Workspace_Commands (I) := Workspace_Commands (I + 1);
         end if;
      end loop;
      Workspace_Commands (Terminal.App.Sessions.Max_Sessions) := (others => <>);
   end Forget_Session_Command;

   procedure Move_Session_Command
     (From : Terminal.App.Sessions.Session_Index;
      To   : Terminal.App.Sessions.Session_Index)
   is
      Saved : constant Terminal.App.Workspace.Bounded_Command :=
        Workspace_Commands (From);
   begin
      if From < To then
         for I in From .. To - 1 loop
            Workspace_Commands (I) := Workspace_Commands (I + 1);
         end loop;
      elsif From > To then
         for I in reverse To + 1 .. From loop
            Workspace_Commands (I) := Workspace_Commands (I - 1);
         end loop;
      end if;
      Workspace_Commands (To) := Saved;
   end Move_Session_Command;

   procedure Restore_Workspace is
      Saved : Terminal.App.Workspace.State;
      IO : Terminal.App.Workspace.IO_Status;
      Status : Terminal.App.Session_Table.Table_Status;
      Loaded : Boolean := False;
      Default_Profile : constant Natural :=
        Terminal.App.Session_Profiles.Default_Index
          (App_Config.Session_Profiles);

   begin
      if App_Config.Restore_Workspace then
         Terminal.App.Workspace.Load
           (Terminal.App.Config.Workspace_Path_String (App_Config), Saved, IO);
         Loaded := IO = Terminal.App.Workspace.Loaded;
      end if;
      if Loaded then
         for I in 2 .. Saved.Count loop
            if Saved.Layout = Terminal.App.Workspace.Tabs then
               Terminal.App.Session_Table.New_Tab
                 (Sessions, Last_Rows, Last_Cols, App_Config.Scrollback_Limit, Status);
            elsif Saved.Layout = Terminal.App.Workspace.Panes then
               Terminal.App.Session_Table.Split_Pane
                 (Sessions,
                  (if Saved.Orientation = Terminal.App.Workspace.Horizontal
                   then Terminal.App.Splits.Split_Horizontal
                   else Terminal.App.Splits.Split_Vertical),
                  Last_Rows, Last_Cols, App_Config.Scrollback_Limit, Status);
            else
               exit;
            end if;
            exit when Status /= Terminal.App.Session_Table.Ok;
         end loop;
      end if;
      for I in 1 .. Terminal.App.Session_Table.Count (Sessions) loop
         Terminal.App.Session_Table.Activate (Sessions, I, Status);
         exit when Status /= Terminal.App.Session_Table.Ok;
         if Loaded then
            Workspace_Commands (I) := Saved.Entries (I).Startup_Command;
         elsif I = 1 and then Default_Profile > 0 then
            Apply_Profile
              (I, Terminal.App.Session_Profiles.Item
                (App_Config.Session_Profiles, Default_Profile));
         end if;
         if Loaded
           and then Saved.Layout = Terminal.App.Workspace.Tabs
           and then Saved.Entries (I).Label.Length > 0
         then
            Terminal.App.Session_Table.Set_Active_Tab_Label
              (Sessions,
               Terminal.App.Workspace.Label_Text (Saved.Entries (I).Label),
               Status);
         end if;
         if not (not Loaded and then I = 1 and then Default_Profile > 0)
           and then Workspace_Commands (I).Length = 0
         then
            Terminal.App.Workspace.Set_Command
              (Workspace_Commands (I),
               Terminal.App.Config.Startup_Command_String (App_Config));
         end if;
         if not (not Loaded and then I = 1 and then Default_Profile > 0) then
            declare
               Directory : constant String :=
                 (if Loaded then Directory_Command
                    (Terminal.App.Workspace.Path_Text
                      (Saved.Entries (I).Working_Directory)) else "");
               Startup : constant String :=
                 Terminal.App.Workspace.Command_Text (Workspace_Commands (I));
            begin
               Send_Shell_Command
                 (I,
                  (if Directory = "" then Startup
                   elsif Startup = "" then Directory
                   else Directory & " && " & Startup));
            end;
         end if;
      end loop;
      if Loaded
        and then Saved.Active <= Terminal.App.Session_Table.Count (Sessions)
      then
         Terminal.App.Session_Table.Activate (Sessions, Saved.Active, Status);
      end if;
   end Restore_Workspace;

   procedure Save_Workspace is
      Saved : Terminal.App.Workspace.State;
      IO : Terminal.App.Workspace.IO_Status;
      Tab_State : constant Terminal.App.Tabs.Tab_State :=
        Terminal.App.Session_Table.Tabs (Sessions);
      Split_State : constant Terminal.App.Splits.Split_State :=
        Terminal.App.Session_Table.Splits (Sessions);
   begin
      if not App_Config.Save_Workspace or else not Sessions_Ready then return; end if;
      Saved.Count := Terminal.App.Session_Table.Count (Sessions);
      Saved.Active := Terminal.App.Session_Table.Active (Sessions);
      if Terminal.App.Tabs.Count (Tab_State) > 1 then
         Saved.Layout := Terminal.App.Workspace.Tabs;
      elsif Terminal.App.Splits.Count (Split_State) > 1 then
         Saved.Layout := Terminal.App.Workspace.Panes;
         Saved.Orientation :=
           (if Terminal.App.Splits.Snapshot (Split_State).Orientation =
                 Terminal.App.Splits.Horizontal
            then Terminal.App.Workspace.Horizontal
            else Terminal.App.Workspace.Vertical);
      end if;
      for I in 1 .. Saved.Count loop
         declare
            Runtime : constant Terminal.App.Session_Table.Runtime_Borrow :=
              Terminal.App.Session_Table.Runtime_At (Sessions, I);
            Core : constant Terminal.App.Session_Runtime.Core_Borrow :=
              Terminal.App.Session_Table.Core (Runtime);
            procedure Capture (Item : in out Terminal.Core.Terminal) is
               Shell : constant Terminal.Core.Shell_Integration_Snapshot :=
                 Terminal.Core.Shell_Integration (Item);
            begin
               if Shell.Working_Directory.Length > 0 then
                  Terminal.App.Workspace.Set_Path
                    (Saved.Entries (I).Working_Directory,
                     Shell.Working_Directory.Text
                       (1 .. Shell.Working_Directory.Length));
               end if;
            end Capture;
         begin
            Terminal.App.Session_Runtime.With_Core (Core, Capture'Access);
         end;
         if Saved.Layout = Terminal.App.Workspace.Tabs then
            Terminal.App.Workspace.Set_Label
              (Saved.Entries (I).Label,
               Terminal.App.Tabs.Label_Text (Terminal.App.Tabs.Label (Tab_State, I)));
         end if;
         Saved.Entries (I).Startup_Command := Workspace_Commands (I);
      end loop;
      Terminal.App.Workspace.Save
        (Terminal.App.Config.Workspace_Path_String (App_Config), Saved, IO);
   end Save_Workspace;

   function Active_Runtime
     return Terminal.App.Session_Table.Runtime_Borrow;
   function Tabs return Terminal.App.Tabs.Tab_State;
   function Splits return Terminal.App.Splits.Split_State;
   procedure Configure_Visible_Cores;

   procedure Launch_Separate_Window (Detach_Active : Boolean) is
      PID : constant String := Ada.Strings.Fixed.Trim
        (GNAT.OS_Lib.Process_Id'Image (GNAT.OS_Lib.Current_Process_Id),
         Ada.Strings.Both);
      Base : constant String :=
        (if Terminal.App.Config.Workspace_Path_String (App_Config) = ""
         then ".ada-terminal" else
           Terminal.App.Config.Workspace_Path_String (App_Config));
      Path : constant String := Base & ".window-" & PID & "-"
        & Ada.Strings.Fixed.Trim
            (Natural'Image (Window_Handoff_Serial + 1), Ada.Strings.Both);
      Saved : Terminal.App.Workspace.State;
      IO : Terminal.App.Workspace.IO_Status;
      Launch : Terminal.App.Platform_Launcher.Launch_Status;
      Active : constant Terminal.App.Sessions.Session_Index :=
        Terminal.App.Session_Table.Active (Sessions);
   begin
      Window_Handoff_Serial := Window_Handoff_Serial + 1;
      if Path'Length > Terminal.App.Config.Max_Font_Path_Length then
         Terminal.App.Settings.Enter (Settings);
         Terminal.App.Settings.Set_Message
           (Settings, "workspace path is too long for a new window");
         return;
      end if;
      if Detach_Active
        and then Terminal.App.Session_Table.Count (Sessions) <= 1
      then
         Terminal.App.Settings.Enter (Settings);
         Terminal.App.Settings.Set_Message
           (Settings, "cannot detach the last session");
         return;
      end if;

      if Detach_Active then
         Saved.Count := 1;
         Saved.Active := 1;
         Saved.Entries (1).Startup_Command := Workspace_Commands (Active);
         declare
            Runtime : constant Terminal.App.Session_Table.Runtime_Borrow :=
              Terminal.App.Session_Table.Runtime_At (Sessions, Active);
            Core : constant Terminal.App.Session_Runtime.Core_Borrow :=
              Terminal.App.Session_Table.Core (Runtime);
            procedure Capture (Item : in out Terminal.Core.Terminal) is
               Shell : constant Terminal.Core.Shell_Integration_Snapshot :=
                 Terminal.Core.Shell_Integration (Item);
            begin
               if Shell.Working_Directory.Length > 0 then
                  Terminal.App.Workspace.Set_Path
                    (Saved.Entries (1).Working_Directory,
                     Shell.Working_Directory.Text
                       (1 .. Shell.Working_Directory.Length));
               end if;
            end Capture;
         begin
            Terminal.App.Session_Runtime.With_Core (Core, Capture'Access);
         end;
         if Terminal.App.Tabs.Count (Tabs) > 1 then
            Terminal.App.Workspace.Set_Label
              (Saved.Entries (1).Label,
               Terminal.App.Tabs.Label_Text
                 (Terminal.App.Tabs.Label (Tabs, Active)));
         end if;
         Terminal.App.Workspace.Save (Path, Saved, IO);
         if IO /= Terminal.App.Workspace.Saved then
            Terminal.App.Settings.Enter (Settings);
            Terminal.App.Settings.Set_Message
              (Settings, "could not create window handoff");
            return;
         end if;
      end if;

      Terminal.App.Platform_Launcher.Open_Window (Path, Launch);
      Terminal.App.Settings.Enter (Settings);
      if Launch /= Terminal.App.Platform_Launcher.Opened then
         Terminal.App.Settings.Set_Message (Settings, "new window launch failed");
         return;
      end if;
      Terminal.App.Settings.Set_Message
        (Settings,
         (if Detach_Active then "tab detached to new window"
          else "new window opened"));

      if Detach_Active then
         declare
            Closed_Stream : constant Terminal.Core.Graphics_Stream_ID :=
              Terminal.App.Session_Table.Graphics_Stream_ID (Active_Runtime);
         begin
            if Terminal.App.Tabs.Count (Tabs) > 1 then
               Terminal.App.Session_Table.Close_Tab
                 (Sessions, Session_Table_Status);
            else
               Terminal.App.Session_Table.Close_Pane
                 (Sessions, Session_Table_Status);
            end if;
            if Session_Table_Status = Terminal.App.Session_Table.Ok then
               Forget_Session_Command (Active);
               Terminal.App.Renderer.Graphics.Release_Stream (R, Closed_Stream);
               if Terminal.App.Splits.Count (Splits) <= 1 then
                  Pane_Zoomed := False;
                  Broadcast_Input := False;
               end if;
               Configure_Visible_Cores;
               Scroll_Offset := 0;
               Terminal.App.Selection.Clear (Selection);
            end if;
         end;
      end if;
   end Launch_Separate_Window;

   procedure On_Key (Event : GLFW_Vulkan.Input.Key_Event) is
   begin
      Input_Grace := Present_Grace_Frames;
      In_Q.Push
        ((Kind => Terminal.App.Queues.Key,
          Key_Event => Event));
   end On_Key;

   procedure On_Character (Event : GLFW_Vulkan.Input.Character_Event) is
   begin
      Input_Grace := Present_Grace_Frames;
      In_Q.Push
        ((Kind => Terminal.App.Queues.Character,
          Character_Event => Event));
   end On_Character;

   procedure On_Mouse_Button
     (Event : GLFW_Vulkan.Input.Mouse_Button_Event) is
   begin
      Input_Grace := Present_Grace_Frames;
      if Event.Action = GLFW_Vulkan.Input.Press
        and then Event.Button = GLFW_Vulkan.Input.Left
      then
         declare
            Now : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
         begin
            if not Terminal.App.Click_Debounce.Accept_Event
              (Left_Press_Debounce, Now, 0.040)
            then
               return;
            end if;
         end;
      end if;
      In_Q.Push
        ((Kind => Terminal.App.Queues.Mouse_Button,
          Button_Event => Event));
   end On_Mouse_Button;

   procedure On_Cursor_Position
     (Event : GLFW_Vulkan.Input.Cursor_Position_Event) is
   begin
      In_Q.Push
        ((Kind => Terminal.App.Queues.Cursor_Position,
          Cursor_Event => Event));
   end On_Cursor_Position;

   procedure On_Scroll (Event : GLFW_Vulkan.Input.Scroll_Event) is
   begin
      Input_Grace := Present_Grace_Frames;
      In_Q.Push
        ((Kind => Terminal.App.Queues.Scroll,
          Scroll_Event => Event));
   end On_Scroll;

   procedure On_Focus (Event : GLFW_Vulkan.Input.Focus_Event) is
   begin
      In_Q.Push
        ((Kind => Terminal.App.Queues.Focus,
          Focus_Event => Event));
   end On_Focus;

   package Scoped_Input is new GLFW_Vulkan.Input.Scoped_Binding
     (On_Key             => On_Key,
      On_Character       => On_Character,
      On_Mouse_Button    => On_Mouse_Button,
      On_Cursor_Position => On_Cursor_Position,
      On_Scroll          => On_Scroll,
      On_Focus           => On_Focus);
   Input_Binding : Scoped_Input.Binding (Owners.Window'Access);

   procedure Apply_Hovered_Link (Link : Terminal.Core.Hyperlink) is
      Cursor_Status : GLFW_Vulkan.Windows.Cursor_Status;
   begin
      if Terminal.App.Hyperlinks.Same_Link (Hovered_Link, Link) then
         return;
      end if;

      Hovered_Link := Link;
      Terminal.App.Renderer.Set_Hovered_Link (R, Hovered_Link);
      GLFW_Vulkan.Windows.Set_Standard_Cursor
        (W,
         (if Hovered_Link.Active
          then GLFW_Vulkan.Windows.Hand_Cursor
          else GLFW_Vulkan.Windows.Default_Cursor),
         Cursor_Status);
   end Apply_Hovered_Link;

   function Active_Runtime
     return Terminal.App.Session_Table.Runtime_Borrow is
   begin
      return Terminal.App.Session_Table.Active_Runtime (Owners.Sessions);
   end Active_Runtime;

   function Tabs return Terminal.App.Tabs.Tab_State is
     (Terminal.App.Session_Table.Tabs (Sessions));

   function Splits return Terminal.App.Splits.Split_State is
     (Terminal.App.Session_Table.Splits (Sessions));

   function Active_Core
     return Terminal.App.Session_Runtime.Core_Borrow is
   begin
      return Terminal.App.Session_Table.Core (Active_Runtime);
   end Active_Core;

   procedure Configure_Core
     (Runtime : Terminal.App.Session_Table.Runtime_Borrow;
      Rows    : Positive;
      Cols    : Positive)
   is
      Core : constant Terminal.App.Session_Runtime.Core_Borrow :=
        Terminal.App.Session_Table.Core (Runtime);
      Cell_Width : constant Positive := Terminal.App.Renderer.Cell_Width (R);
      Cell_Height : constant Positive := Terminal.App.Renderer.Cell_Height (R);
      Pixel_Width : constant Natural :=
        Natural'Min (Cols, Natural'Last / Cell_Width) * Cell_Width;
      Pixel_Height : constant Natural :=
        Natural'Min (Rows, Natural'Last / Cell_Height) * Cell_Height;
      procedure Apply (Item : in out Terminal.Core.Terminal) is
      begin
         Terminal.Core.Set_Graphics_Capabilities
           (Item,
            Terminal.App.Graphics_Profile.Core_Capabilities
              (Runtime_Graphics));
         Terminal.Core.Set_Graphics_Resource_Limits
           (Item,
            (Transaction_Length => App_Config.Graphics_Transaction_Bytes,
             Pending_Events => App_Config.Graphics_Pending_Events,
             Pending_Bytes => App_Config.Graphics_Pending_Bytes,
             Deferred_Input_Bytes =>
               App_Config.Graphics_Deferred_Input_Bytes,
             Pixel_Dimension => App_Config.Graphics_Pixel_Dimension));
         Terminal.Core.Set_Cell_Pixel_Size (Item, Cell_Width, Cell_Height);
         Terminal.Core.Set_Window_Pixel_Size
           (Item, Pixel_Width, Pixel_Height);
      end Apply;
   begin
      Terminal.App.Session_Runtime.With_Core (Core, Apply'Access);
   end Configure_Core;

   procedure Configure_Visible_Cores is
   begin
      if Pane_Zoomed or else Terminal.App.Splits.Count (Splits) <= 1 then
         Configure_Core
           (Active_Runtime, Last_Rows, Last_Cols);
      else
         declare
            Layout : constant Terminal.App.Splits.Pane_Layout :=
              Terminal.App.Splits.Layout (Splits, Last_Rows, Last_Cols);
         begin
            for I in 1 .. Layout.Count loop
               declare
                  Runtime_Borrow : constant
                    Terminal.App.Session_Table.Runtime_Borrow :=
                    Terminal.App.Session_Table.Runtime_At
                      (Owners.Sessions,
                       Terminal.App.Sessions.Session_Index (I));
               begin
                  if Layout.Rects (I).Rows > 0
                    and then Layout.Rects (I).Cols > 0
                  then
                     Configure_Core
                       (Runtime_Borrow,
                        Positive (Layout.Rects (I).Rows),
                        Positive (Layout.Rects (I).Cols));
                  end if;
               end;
            end loop;
         end;
      end if;
   end Configure_Visible_Cores;

   procedure Apply_Runtime_Config
     (Candidate : Terminal.App.Config.Config;
      Applied   : out Boolean)
   is
      Font_Status : Terminal.App.Renderer.Font_Update_Status;
      New_Font_Path : constant String :=
        (if Terminal.App.Config.Font_Path_String (Candidate)'Length = 0
         then Terminal.App.Fonts.Default_Font_Path
         else Terminal.App.Config.Font_Path_String (Candidate));
      Old_Font_Path : constant String := Unbounded.To_String (Active_Font_Path);
      Limit_Status :
        Terminal.App.Renderer.Graphics.Resource_Limit_Update_Status;
      procedure Set_Limits
        (Value : Terminal.App.Config.Config;
         Status : out Terminal.App.Renderer.Graphics.Resource_Limit_Update_Status)
      is
      begin
         Terminal.App.Renderer.Graphics.Set_Resource_Limits
           (R,
            (Image_Objects => Value.Graphics_Image_Objects,
             Image_Bytes => Value.Graphics_Image_Bytes,
             Placements => Value.Graphics_Placements,
             Animation_Frames => Value.Graphics_Animation_Frames,
             Per_Image_Bytes => Value.Graphics_Per_Image_Bytes,
             Theme_Transaction_Bytes => Value.Graphics_Image_Bytes * 4,
             Pixel_Dimension => Value.Graphics_Pixel_Dimension,
             GPU_Atlas_Bytes => Value.Graphics_GPU_Atlas_Bytes,
             GPU_Atlas_Dimension => Value.Graphics_GPU_Atlas_Dimension),
            Status);
      end Set_Limits;
      procedure Restore is
         Ignored : Terminal.App.Renderer.Graphics.Resource_Limit_Update_Status;
      begin
         Set_Limits (App_Config, Ignored);
         Terminal.App.Renderer.Set_Theme
           (R, Terminal.App.Config.Active_Theme (App_Config), Theme_Status);
         Terminal.App.Renderer.Set_Font
           (R, Old_Font_Path, Active_Font_Size, Font_Status);
      end Restore;
   begin
      Applied := False;
      Set_Limits (Candidate, Limit_Status);
      if Limit_Status /= Terminal.App.Renderer.Graphics.Limits_Applied then
         return;
      end if;
      Terminal.App.Renderer.Set_Theme
        (R, Terminal.App.Config.Active_Theme (Candidate), Theme_Status);
      if Theme_Status /= Terminal.App.Renderer.Theme_Ok then
         Restore;
         return;
      end if;
      Terminal.App.Renderer.Set_Font
        (R, New_Font_Path, Candidate.Font_Pixel_Size, Font_Status);
      if Font_Status /= Terminal.App.Renderer.Font_Ok then
         Restore;
         return;
      end if;

      App_Config := Candidate;
      Unbounded.Set_Unbounded_String (Active_Font_Path, New_Font_Path);
      Active_Font_Size := Candidate.Font_Pixel_Size;
      Runtime_Graphics := Terminal.App.Graphics_Profile.Create
        (Candidate.Kitty_File_Transfer,
         Candidate.Kitty_Temporary_Transfer,
         Candidate.Kitty_Shared_Memory,
         Candidate.ITerm2_File_Downloads);
      Terminal.App.Renderer.Graphics.Set_Access_Policy
        (R, Terminal.App.Graphics_Profile.Access_Policy (Runtime_Graphics));
      declare
         Policy : Terminal.App.ITerm2_Files.Download_Policy;
      begin
         Terminal.App.ITerm2_Files.Configure
           (Policy,
            Terminal.App.Graphics_Profile.Downloads_Enabled (Runtime_Graphics),
            Terminal.App.ITerm2_Files.Default_Download_Directory);
         Terminal.App.Renderer.Graphics.Set_ITerm2_Download_Policy (R, Policy);
      end;
      Configure_Visible_Cores;
      Applied := True;
   exception
      when others =>
         --  Restore presentation state if a backend rejects a live update.
         Restore;
         Applied := False;
   end Apply_Runtime_Config;

   function Active_PTY_Queue
     return Terminal.App.Session_Runtime.PTY_Queue_Borrow is
   begin
      return Terminal.App.Session_Table.PTY_Queue (Active_Runtime);
   end Active_PTY_Queue;

   procedure Resize_Visible_Runtimes
     (Target_Rows : Positive;
      Target_Cols : Positive;
      Success     : out Boolean)
   is
      procedure Resize_One
        (Runtime : Terminal.App.Session_Table.Runtime_Borrow;
         Rows    : Positive;
         Cols    : Positive)
      is
         Core_Resize : Terminal.Core.Resize_Status;
         PTY_Resize  : Terminal.PTY.Backend.Resize_Status;
         procedure Apply
           (Item : in out Terminal.App.Session_Runtime.Runtime) is
         begin
            Terminal.App.Session_Runtime.Resize
              (Item, Rows, Cols, Core_Resize, PTY_Resize);
         end Apply;
      begin
         Terminal.App.Session_Table.With_Runtime (Runtime, Apply'Access);
         if Core_Resize /= Terminal.Core.Ok
           or else PTY_Resize /= Terminal.PTY.Backend.Ok
         then
            Success := False;
            Need_Redraw := True;
         else
            Configure_Core (Runtime, Rows, Cols);
         end if;
      end Resize_One;
   begin
      Success := True;
      if Pane_Zoomed or else Terminal.App.Splits.Count (Splits) <= 1 then
         Resize_One (Active_Runtime, Target_Rows, Target_Cols);
      else
         declare
            Layout : constant Terminal.App.Splits.Pane_Layout :=
              Terminal.App.Splits.Layout
                (Splits, Target_Rows, Target_Cols);
         begin
            for I in 1 .. Layout.Count loop
               declare
                  Runtime_Borrow : constant
                    Terminal.App.Session_Table.Runtime_Borrow :=
                    Terminal.App.Session_Table.Runtime_At
                      (Owners.Sessions,
                       Terminal.App.Sessions.Session_Index (I));
               begin
                  if Layout.Rects (I).Rows > 0
                    and then Layout.Rects (I).Cols > 0
                  then
                     Resize_One
                       (Runtime_Borrow,
                        Positive (Layout.Rects (I).Rows),
                        Positive (Layout.Rects (I).Cols));
                  end if;
               end;
            end loop;
         end;
      end if;
   end Resize_Visible_Runtimes;

   procedure Resize_Visible_Runtimes is
      Success : Boolean;
   begin
      Resize_Visible_Runtimes (Last_Rows, Last_Cols, Success);
   end Resize_Visible_Runtimes;

   function Tab_Bar_Height return Natural is
     (if Terminal.App.Tabs.Count (Tabs) > 1
      then Terminal.App.Renderer.Cell_Height (R) + 2
      else 0);

   function Active_Pane_Origin_X return Natural is
   begin
      if Pane_Zoomed
        or else Terminal.App.Splits.Count (Splits) <= 1
        or else Terminal.App.Splits.Snapshot (Splits).Orientation =
          Terminal.App.Splits.Horizontal
      then
         return 0;
      else
         declare
            Layout : constant Terminal.App.Splits.Pane_Layout :=
              Terminal.App.Splits.Layout (Splits, Last_Rows, Last_Cols);
            Result : Natural := 0;
         begin
            for I in 1 .. Terminal.App.Splits.Active (Splits) - 1 loop
               Result :=
                 Result
                 + Layout.Rects (I).Cols
                   * Terminal.App.Renderer.Cell_Width (R)
                 + Terminal.App.Renderer.Content_Margin * 2;
            end loop;
            return Result;
         end;
      end if;
   end Active_Pane_Origin_X;

   function Active_Pane_Origin_Y return Natural is
   begin
      if Pane_Zoomed
        or else Terminal.App.Splits.Count (Splits) <= 1
        or else Terminal.App.Splits.Snapshot (Splits).Orientation =
          Terminal.App.Splits.Vertical
      then
         return Tab_Bar_Height;
      else
         declare
            Layout : constant Terminal.App.Splits.Pane_Layout :=
              Terminal.App.Splits.Layout (Splits, Last_Rows, Last_Cols);
            Result : Natural := Tab_Bar_Height;
         begin
            for I in 1 .. Terminal.App.Splits.Active (Splits) - 1 loop
               Result :=
                 Result
                 + Layout.Rects (I).Rows
                   * Terminal.App.Renderer.Cell_Height (R)
                 + Terminal.App.Renderer.Content_Margin * 2;
            end loop;
            return Result;
         end;
      end if;
   end Active_Pane_Origin_Y;

   function Active_Pane_Rows return Positive is
   begin
      if Pane_Zoomed or else Terminal.App.Splits.Count (Splits) <= 1 then
         return Last_Rows;
      else
         declare
            Layout : constant Terminal.App.Splits.Pane_Layout :=
              Terminal.App.Splits.Layout (Splits, Last_Rows, Last_Cols);
         begin
            return Positive (Layout.Rects (Terminal.App.Splits.Active (Splits)).Rows);
         end;
      end if;
   end Active_Pane_Rows;

   function Active_Pane_Cols return Positive is
   begin
      if Pane_Zoomed or else Terminal.App.Splits.Count (Splits) <= 1 then
         return Last_Cols;
      else
         declare
            Layout : constant Terminal.App.Splits.Pane_Layout :=
              Terminal.App.Splits.Layout (Splits, Last_Rows, Last_Cols);
         begin
            return Positive (Layout.Rects (Terminal.App.Splits.Active (Splits)).Cols);
         end;
      end if;
   end Active_Pane_Cols;

   function Active_Cell_From_Pixels
     (X : Float;
      Y : Float) return Terminal.App.Selection.Cell_Position is
   begin
      return Terminal.App.Selection.Cell_From_Pixels
        (X - Float (Active_Pane_Origin_X),
         Y - Float (Active_Pane_Origin_Y),
         Terminal.App.Renderer.Cell_Width (R),
         Terminal.App.Renderer.Cell_Height (R),
         Terminal.App.Renderer.Content_Margin,
         Active_Pane_Rows,
         Active_Pane_Cols);
   end Active_Cell_From_Pixels;

   function Tab_At_Pixels (X, Y : Float) return Terminal.App.Tabs.Tab_Count is
      State : constant Terminal.App.Tabs.Tab_State := Tabs;
      Count : constant Terminal.App.Tabs.Tab_Count :=
        Terminal.App.Tabs.Count (State);
      Base : Natural;
      Extra : Natural;
      Cursor : Natural := 0;
   begin
      if Count <= 1 or else X < 0.0 or else Y < 0.0
        or else Y >= Float (Tab_Bar_Height) or else FB_Width = 0
      then
         return 0;
      end if;
      Base := FB_Width / Positive (Count);
      Extra := FB_Width mod Positive (Count);
      for I in 1 .. Count loop
         declare
            Width : constant Natural :=
              Base + (if Natural (I) <= Extra then 1 else 0);
         begin
            if X >= Float (Cursor) and then X < Float (Cursor + Width) then
               return I;
            end if;
            Cursor := Cursor + Width;
         end;
      end loop;
      return 0;
   end Tab_At_Pixels;

   function Tab_Close_At_Pixels (Index : Terminal.App.Tabs.Tab_Index;
                                 X : Float) return Boolean is
      Count : constant Positive := Positive (Terminal.App.Tabs.Count (Tabs));
      Base : constant Natural := FB_Width / Count;
      Extra : constant Natural := FB_Width mod Count;
      First_X : Natural := 0;
      Width : Natural;
   begin
      for I in 1 .. Index - 1 loop
         First_X := First_X + Base + (if Natural (I) <= Extra then 1 else 0);
      end loop;
      Width := Base + (if Natural (Index) <= Extra then 1 else 0);
      return Width > Terminal.App.Renderer.Cell_Width (R) * 2
        and then X >= Float (First_X + Width - Terminal.App.Renderer.Cell_Width (R));
   end Tab_Close_At_Pixels;

   function Pane_At_Pixels (X, Y : Float) return Terminal.App.Splits.Pane_Count is
      State : constant Terminal.App.Splits.Split_State := Splits;
      Layout : constant Terminal.App.Splits.Pane_Layout :=
        Terminal.App.Splits.Layout (State, Last_Rows, Last_Cols);
      Cursor_X : Natural := 0;
      Cursor_Y : Natural := Tab_Bar_Height;
   begin
      if X < 0.0 or else Y < Float (Tab_Bar_Height) then
         return 0;
      elsif Pane_Zoomed then
         return Terminal.App.Splits.Pane_Count
           (Terminal.App.Splits.Active (Splits));
      end if;
      for I in 1 .. Layout.Count loop
         declare
            Width : constant Natural :=
              Layout.Rects (I).Cols * Terminal.App.Renderer.Cell_Width (R)
                + Terminal.App.Renderer.Content_Margin * 2;
            Height : constant Natural :=
              Layout.Rects (I).Rows * Terminal.App.Renderer.Cell_Height (R)
                + Terminal.App.Renderer.Content_Margin * 2;
         begin
            if X >= Float (Cursor_X) and then X < Float (Cursor_X + Width)
              and then Y >= Float (Cursor_Y) and then Y < Float (Cursor_Y + Height)
            then
               return I;
            end if;
            if Terminal.App.Splits.Snapshot (State).Orientation =
              Terminal.App.Splits.Vertical
            then
               Cursor_X := Cursor_X + Width;
            else
               Cursor_Y := Cursor_Y + Height;
            end if;
         end;
      end loop;
      return 0;
   end Pane_At_Pixels;

   function Divider_At_Pixels (X, Y : Float) return Natural is
      State : constant Terminal.App.Splits.Split_State := Splits;
      Layout : constant Terminal.App.Splits.Pane_Layout :=
        Terminal.App.Splits.Layout (State, Last_Rows, Last_Cols);
      Boundary : Natural :=
        (if Terminal.App.Splits.Snapshot (State).Orientation =
             Terminal.App.Splits.Horizontal
         then Tab_Bar_Height else 0);
      Tolerance : constant Float := 4.0;
   begin
      if Pane_Zoomed or else Layout.Count <= 1 then return 0; end if;
      for I in 1 .. Layout.Count - 1 loop
         Boundary := Boundary
           + (if Terminal.App.Splits.Snapshot (State).Orientation =
                   Terminal.App.Splits.Horizontal
              then Layout.Rects (I).Rows * Terminal.App.Renderer.Cell_Height (R)
                   + Terminal.App.Renderer.Content_Margin * 2
              else Layout.Rects (I).Cols * Terminal.App.Renderer.Cell_Width (R)
                   + Terminal.App.Renderer.Content_Margin * 2);
         if (Terminal.App.Splits.Snapshot (State).Orientation =
               Terminal.App.Splits.Horizontal
             and then abs (Y - Float (Boundary)) <= Tolerance)
           or else
             (Terminal.App.Splits.Snapshot (State).Orientation =
                Terminal.App.Splits.Vertical
              and then abs (X - Float (Boundary)) <= Tolerance)
         then
            return Natural (I);
         end if;
      end loop;
      return 0;
   end Divider_At_Pixels;

   function Scrollbar_At_Pixels (X, Y : Float) return Boolean is
      Left : constant Float :=
        Float
          (Active_Pane_Origin_X + Terminal.App.Renderer.Content_Margin
           + Active_Pane_Cols * Terminal.App.Renderer.Cell_Width (R) - 8);
      Top : constant Float :=
        Float (Active_Pane_Origin_Y + Terminal.App.Renderer.Content_Margin);
      Bottom : constant Float :=
        Top + Float (Active_Pane_Rows * Terminal.App.Renderer.Cell_Height (R));
   begin
      return X >= Left and then X <= Left + 10.0
        and then Y >= Top and then Y <= Bottom;
   end Scrollbar_At_Pixels;

   procedure Copy_Selection is
      procedure Process (Core : in out Terminal.Core.Terminal) is
         Copy_Snap : Terminal.Core.Render_Snapshot :=
           Terminal.App.Scrollback_View.Snapshot (Core, Scroll_Offset);
      begin
         declare
            Text : constant String :=
              Terminal.App.Selection.Selected_Text (Copy_Snap, Selection);
         begin
            if Text'Length > 0 then
               GLFW_Vulkan.Clipboard.Set_Text (W, Text);
               Terminal.App.Clipboard_OSC52.Store_Local_Selection
                 (Clipboard_Targets, Text);
            end if;
         end;
         Terminal.Core.Release (Copy_Snap);
      exception
         when others =>
            Terminal.Core.Release (Copy_Snap);
            raise;
      end Process;
   begin
      Terminal.App.Session_Runtime.With_Core (Active_Core, Process'Access);
   end Copy_Selection;

   procedure Release_Snapshot_Cache is
   begin
      for I in Snapshot_Cache'Range loop
         begin
            Terminal.Core.Release (Snapshot_Cache (I));
         exception
            when E : others =>
               Terminal.App.Cleanup_Diagnostics.Note_Failure
                 (Terminal.App.Cleanup_Diagnostics.Snapshot_Cache,
                  E,
                  "release cached render snapshot");
         end;
      end loop;
   end Release_Snapshot_Cache;

   procedure Shutdown is separate;
   function Start return Boolean is separate;

   procedure Run_Frame is separate;
begin
   if not Start then
      return;
   end if;

   Scoped_Input.Attach (Input_Binding);

   while not GLFW_Vulkan.Windows.Should_Close (W) loop
      Run_Frame;
   end loop;

   Shutdown;
exception
   when others =>
      Shutdown;
      raise;
end Run;

separate (Terminal.App.Main_Loop.Run.Run_Frame)
procedure Log_Frame_Diagnostics
  (Snaps                : Terminal.App.Renderer.Snapshot_Array;
   Active_Render_Index  : Positive;
   Render_Policy_Status : String;
   Framebuffer_Width    : Natural;
   Framebuffer_Height   : Natural;
   Renderer_State       : Terminal.App.Renderer.Renderer;
   Current_Core         : Terminal.Core.Terminal;
   Scrollback_Offset    : Natural;
   Selection_State      : Terminal.App.Selection.Selection_State;
   Hovered              : Terminal.Core.Hyperlink;
   Has_Activation       : Boolean;
   Activation           : Terminal.App.Hyperlinks.Activation_Status;
   Clipboard_Target     : Terminal.Core.Clipboard_Target;
   Tab_State            : Terminal.App.Tabs.Tab_State;
   Split_State          : Terminal.App.Splits.Split_State;
   Configuration        : Terminal.App.Config.Config;
   Blink_Tick           : Natural;
   Font_Status          : String;
   PTY_Backend_Status   : String;
   ConPTY_Status        : String;
   Multiplexer_Status   : String;
   PTY_Queue            : Terminal.App.Queues.PTY_Output_Queue;
   Input_Queue          : Terminal.App.Queues.Input_Event_Queue;
   Presenter_State      : Terminal.App.Vulkan_Presenter.Presenter;
   Feed_Status          : Terminal.Core.Feed_Status;
   Write_Status         : Terminal.App.PTY_Write.Write_All_Status)
is
   Statuses : Terminal.App.Diagnostics.Runtime_Statuses := (others => <>);

   procedure Set
     (Kind : Terminal.App.Diagnostics.Runtime_Status_Kind;
      Text : String) is
   begin
      Terminal.App.Diagnostics.Set (Statuses, Kind, Text);
   end Set;
begin
   Set
     (Terminal.App.Diagnostics.Grid_Status,
      Terminal.App.Resize.Grid_Status_Label
        (Framebuffer_Width,
         Framebuffer_Height,
         Terminal.App.Renderer.Cell_Width (Renderer_State),
         Terminal.App.Renderer.Cell_Height (Renderer_State),
         Terminal.App.Renderer.Content_Margin));
   Set (Terminal.App.Diagnostics.Policy_Status, Render_Policy_Status);
   Set
     (Terminal.App.Diagnostics.Scrollback_Status,
      Terminal.App.Scrollback_View.Status_Label
        (Current_Core, Scrollback_Offset));
   Set
     (Terminal.App.Diagnostics.Selection_Status,
      Terminal.App.Selection.Status_Label (Selection_State));
   Set
     (Terminal.App.Diagnostics.Link_Status,
      Terminal.App.Hyperlinks.Status_Label (Hovered));
   Set
     (Terminal.App.Diagnostics.Link_Activation_Status,
      Terminal.App.Hyperlinks.Activation_Status_Label
        (if Has_Activation
         then Activation
         else Terminal.App.Hyperlinks.No_Link));
   Set
     (Terminal.App.Diagnostics.Clipboard_Status,
      Terminal.App.Clipboard_OSC52.Status_Label (Clipboard_Target));
   Set
     (Terminal.App.Diagnostics.Tab_Status,
      Terminal.App.Tabs.Status_Label (Tab_State));
   Set
     (Terminal.App.Diagnostics.Split_Status,
      Terminal.App.Splits.Status_Label (Split_State));
   Set
     (Terminal.App.Diagnostics.Config_Status,
      Terminal.App.Config.Status_Label (Configuration));
   Set
     (Terminal.App.Diagnostics.Profile_Status,
      Terminal.App.Profile_Status_Label (Terminal.App.Profile));
   Set
     (Terminal.App.Diagnostics.Input_Status,
      Terminal.App.Input_Map.Input_Status_Label
        (Terminal.Core.Modes (Current_Core)));
   Set
     (Terminal.App.Diagnostics.Mouse_Status,
      Terminal.App.Input_Map.Mouse_Status_Label
        (Terminal.Core.Modes (Current_Core)));
   Set
     (Terminal.App.Diagnostics.Cursor_Status,
      Terminal.App.Cursor_Blink.Status_Label
        (Snaps (Active_Render_Index).Cursor, Blink_Tick));
   Set
     (Terminal.App.Diagnostics.Text_Blink_Status,
      Terminal.App.Text_Blink.Status_Label
        (Snaps (Active_Render_Index), Blink_Tick));
   Set
     (Terminal.App.Diagnostics.Theme_Status,
      Terminal.App.Theme.Status_Label (Configuration.Color_Theme));
   Set (Terminal.App.Diagnostics.Font_Status, Font_Status);
   Set
     (Terminal.App.Diagnostics.PTY_Backend_Status,
      PTY_Backend_Status);
   Set (Terminal.App.Diagnostics.ConPTY_Status, ConPTY_Status);
   Set
     (Terminal.App.Diagnostics.Multiplexer_Status,
      Multiplexer_Status);
   Set
     (Terminal.App.Diagnostics.Graphics_Header_Status,
      Terminal.App.Graphics.Header_Status_Label
        (Snaps (Active_Render_Index).Graphics));
   Set
     (Terminal.App.Diagnostics.Graphics_Data_Status,
      Terminal.App.Graphics.Data_Status_Label
        (Snaps (Active_Render_Index).Graphics));
   Terminal.App.Diagnostics.Log_If_Changed
     (Terminal.App.Diagnostics.Collect
        (Current_Core,
         PTY_Queue,
         Input_Queue,
         Renderer_State,
         Presenter_State,
         Feed_Status,
         Write_Status,
         Statuses));
end Log_Frame_Diagnostics;

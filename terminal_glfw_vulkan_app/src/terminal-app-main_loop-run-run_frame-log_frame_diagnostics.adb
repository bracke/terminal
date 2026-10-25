separate (Terminal.App.Main_Loop.Run.Run_Frame)
procedure Log_Frame_Diagnostics
  (Snaps                : Terminal.App.Renderer.Snapshot_Array;
   Active_Render_Index  : Positive;
   Render_Policy_Status : String)
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
        (FB_Width,
         FB_Height,
         Terminal.App.Renderer.Cell_Width (R),
         Terminal.App.Renderer.Cell_Height (R),
         Terminal.App.Renderer.Content_Margin));
   Set (Terminal.App.Diagnostics.Policy_Status, Render_Policy_Status);
   Set
     (Terminal.App.Diagnostics.Scrollback_Status,
      Terminal.App.Scrollback_View.Status_Label
        (Active_Core.all, Scroll_Offset));
   Set
     (Terminal.App.Diagnostics.Selection_Status,
      Terminal.App.Selection.Status_Label (Selection));
   Set
     (Terminal.App.Diagnostics.Link_Status,
      Terminal.App.Hyperlinks.Status_Label (Hovered_Link));
   Set
     (Terminal.App.Diagnostics.Link_Activation_Status,
      Terminal.App.Hyperlinks.Activation_Status_Label
        (if Has_Link_Activation
         then Link_Activation
         else Terminal.App.Hyperlinks.No_Link));
   Set
     (Terminal.App.Diagnostics.Clipboard_Status,
      Terminal.App.Clipboard_OSC52.Status_Label (Last_Clipboard_Target));
   Set
     (Terminal.App.Diagnostics.Tab_Status,
      Terminal.App.Tabs.Status_Label (Tabs));
   Set
     (Terminal.App.Diagnostics.Split_Status,
      Terminal.App.Splits.Status_Label (Splits));
   Set
     (Terminal.App.Diagnostics.Config_Status,
      Terminal.App.Config.Status_Label (App_Config));
   Set
     (Terminal.App.Diagnostics.Profile_Status,
      Terminal.App.Profile_Status_Label (Terminal.App.Profile));
   Set
     (Terminal.App.Diagnostics.Input_Status,
      Terminal.App.Input_Map.Input_Status_Label
        (Terminal.Core.Modes (Active_Core.all)));
   Set
     (Terminal.App.Diagnostics.Mouse_Status,
      Terminal.App.Input_Map.Mouse_Status_Label
        (Terminal.Core.Modes (Active_Core.all)));
   Set
     (Terminal.App.Diagnostics.Cursor_Status,
      Terminal.App.Cursor_Blink.Status_Label
        (Snaps (Active_Render_Index).Cursor, Current_Blink_Tick));
   Set
     (Terminal.App.Diagnostics.Text_Blink_Status,
      Terminal.App.Text_Blink.Status_Label
        (Snaps (Active_Render_Index), Current_Blink_Tick));
   Set
     (Terminal.App.Diagnostics.Theme_Status,
      Terminal.App.Theme.Status_Label (App_Config.Color_Theme));
   Set (Terminal.App.Diagnostics.Font_Status, Runtime_Font_Status);
   Set
     (Terminal.App.Diagnostics.PTY_Backend_Status,
      Runtime_PTY_Backend_Status);
   Set (Terminal.App.Diagnostics.ConPTY_Status, Runtime_ConPTY_Status);
   Set
     (Terminal.App.Diagnostics.Multiplexer_Status,
      Runtime_Multiplexer_Status);
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
        (Active_Core.all,
         Active_PTY_Queue.all,
         In_Q,
         R,
         Presenter,
         Last_Feed_Status,
         Last_Write_Status,
         Statuses));
end Log_Frame_Diagnostics;

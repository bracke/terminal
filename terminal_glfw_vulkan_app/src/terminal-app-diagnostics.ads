with Terminal.Core;
with Terminal.App.Clipboard_OSC52;
with Terminal.App.Config;
with Terminal.App.Cursor_Blink;
with Terminal.App.Fonts;
with Terminal.App.Graphics;
with Terminal.App.Hyperlinks;
with Terminal.App.Input_Map;
with Terminal.App.PTY_Write;
with Terminal.App.Queues;
with Terminal.App.Renderer;
with Terminal.App.Render_Policy;
with Terminal.App.Resize;
with Terminal.App.Scrollback_View;
with Terminal.App.Selection;
with Terminal.App.Splits;
with Terminal.App.Tabs;
with Terminal.App.Text_Blink;
with Terminal.App.Theme;
with Terminal.App.Vulkan_Presenter;
with Terminal.PTY.Backend;

package Terminal.App.Diagnostics is
   type Runtime_Status_Kind is
     (Grid_Status,
      Policy_Status,
      Scrollback_Status,
      Selection_Status,
      Link_Status,
      Link_Activation_Status,
      Clipboard_Status,
      Tab_Status,
      Split_Status,
      Config_Status,
      Profile_Status,
      Input_Status,
      Mouse_Status,
      Cursor_Status,
      Text_Blink_Status,
      Theme_Status,
      Font_Status,
      PTY_Backend_Status,
      ConPTY_Status,
      Multiplexer_Status,
      Graphics_Header_Status,
      Graphics_Data_Status);
   Max_Runtime_Status_Length : constant :=
     Terminal.App.Hyperlinks.Max_Status_Label_Length;
   type Runtime_Status_Value is record
      Length : Natural range 0 .. Max_Runtime_Status_Length := 0;
      Text   : String (1 .. Max_Runtime_Status_Length) := (others => ' ');
   end record;
   type Runtime_Statuses is
     array (Runtime_Status_Kind) of Runtime_Status_Value;
   procedure Set
     (Statuses : in out Runtime_Statuses;
      Kind     : Runtime_Status_Kind;
      Value    : String);

   type Snapshot is record
      Core          : Terminal.Core.Diagnostic_Snapshot;
      Last_Feed_Status : Terminal.Core.Feed_Status := Terminal.Core.Ok;
      Last_Write_Status : Terminal.App.PTY_Write.Write_All_Status :=
        Terminal.App.PTY_Write.Ok;
      Statuses       : Runtime_Statuses := (others => <>);
      PTY_Length    : Natural := 0;
      PTY_Overflows : Natural := 0;
      Input_Length  : Natural := 0;
      Input_Overflows : Natural := 0;
      Renderer      : Terminal.App.Renderer.Renderer_Diagnostics;
      Presenter     : Terminal.App.Vulkan_Presenter.Diagnostic_Snapshot;
   end record;

   function Collect
     (Core     : Terminal.Core.Terminal;
      PTY      : Terminal.App.Queues.PTY_Output_Queue;
      Input    : Terminal.App.Queues.Input_Event_Queue;
      Renderer : Terminal.App.Renderer.Renderer;
      Presenter : Terminal.App.Vulkan_Presenter.Presenter;
      Last_Feed_Status : Terminal.Core.Feed_Status := Terminal.Core.Ok;
      Last_Write_Status : Terminal.App.PTY_Write.Write_All_Status :=
        Terminal.App.PTY_Write.Ok;
      Statuses : Runtime_Statuses := (others => <>))
      return Snapshot;

   procedure Log_Startup_Failure
     (Stage  : String;
      Status : String);

   function Status_Line (S : Snapshot) return String;

   function Image_Texture_Pipeline_Status_Label (S : Snapshot) return String;

   procedure Log_If_Changed (S : Snapshot);
end Terminal.App.Diagnostics;

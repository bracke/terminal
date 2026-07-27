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
with Terminal.PTY.POSIX;

package Terminal.App.Diagnostics is
   subtype Grid_Status_Length_Range is
     Natural range 0 .. Terminal.App.Resize.Max_Status_Label_Length;
   subtype Policy_Status_Length_Range is
     Natural range 0 .. Terminal.App.Render_Policy.Max_Status_Label_Length;
   subtype Scrollback_Status_Length_Range is
     Natural range 0 .. Terminal.App.Scrollback_View.Max_Status_Label_Length;
   subtype Selection_Status_Length_Range is
     Natural range 0 .. Terminal.App.Selection.Max_Status_Label_Length;
   subtype Link_Status_Length_Range is
     Natural range 0 .. Terminal.App.Hyperlinks.Max_Status_Label_Length;
   subtype Clipboard_Status_Length_Range is
     Natural range 0 .. Terminal.App.Clipboard_OSC52.Max_Status_Label_Length;
   subtype Tab_Status_Length_Range is
     Natural range 0 .. Terminal.App.Tabs.Max_Status_Label_Length;
   subtype Split_Status_Length_Range is
     Natural range 0 .. Terminal.App.Splits.Max_Status_Label_Length;
   subtype Config_Status_Length_Range is
     Natural range 0 .. Terminal.App.Config.Max_Status_Label_Length;
   subtype Profile_Status_Length_Range is
     Natural range 0 .. Terminal.App.Max_Status_Label_Length;
   subtype Input_Status_Length_Range is
     Natural range 0 .. Terminal.App.Input_Map.Max_Input_Status_Label_Length;
   subtype Mouse_Status_Length_Range is
     Natural range 0 .. Terminal.App.Input_Map.Max_Mouse_Status_Label_Length;
   subtype Cursor_Status_Length_Range is
     Natural range 0 .. Terminal.App.Cursor_Blink.Max_Status_Label_Length;
   subtype Text_Blink_Status_Length_Range is
     Natural range 0 .. Terminal.App.Text_Blink.Max_Status_Label_Length;
   subtype Theme_Status_Length_Range is
     Natural range 0 .. Terminal.App.Theme.Max_Status_Label_Length;
   subtype Font_Status_Length_Range is
     Natural range 0 .. Terminal.App.Fonts.Max_Status_Label_Length;
   subtype PTY_Backend_Status_Length_Range is
     Natural range 0 .. Terminal.PTY.POSIX.Max_Status_Label_Length;
   subtype Multiplexer_Status_Length_Range is
     Natural range 0 .. Terminal.App.Max_Status_Label_Length;
   subtype Graphics_Header_Status_Length_Range is
     Natural range 0 .. Terminal.App.Graphics.Max_Status_Label_Length;
   subtype Graphics_Data_Status_Length_Range is
     Natural range 0 .. Terminal.App.Graphics.Max_Status_Label_Length;

   type Snapshot is record
      Core          : Terminal.Core.Diagnostic_Snapshot;
      Last_Feed_Status : Terminal.Core.Feed_Status := Terminal.Core.Ok;
      Last_Write_Status : Terminal.App.PTY_Write.Write_All_Status :=
        Terminal.App.PTY_Write.Ok;
      Grid_Status_Length : Grid_Status_Length_Range := 0;
      Grid_Status : String (1 .. Terminal.App.Resize.Max_Status_Label_Length) :=
        (others => ' ');
      Policy_Status_Length : Policy_Status_Length_Range := 0;
      Policy_Status :
        String (1 .. Terminal.App.Render_Policy.Max_Status_Label_Length) :=
          (others => ' ');
      Scrollback_Status_Length : Scrollback_Status_Length_Range := 0;
      Scrollback_Status :
        String (1 .. Terminal.App.Scrollback_View.Max_Status_Label_Length) :=
          (others => ' ');
      Selection_Status_Length : Selection_Status_Length_Range := 0;
      Selection_Status :
        String (1 .. Terminal.App.Selection.Max_Status_Label_Length) :=
          (others => ' ');
      Link_Status_Length : Link_Status_Length_Range := 0;
      Link_Status : String (1 .. Terminal.App.Hyperlinks.Max_Status_Label_Length) :=
        (others => ' ');
      Link_Activation_Status_Length : Link_Status_Length_Range := 0;
      Link_Activation_Status :
        String (1 .. Terminal.App.Hyperlinks.Max_Status_Label_Length) :=
          (others => ' ');
      Clipboard_Status_Length : Clipboard_Status_Length_Range := 0;
      Clipboard_Status :
        String (1 .. Terminal.App.Clipboard_OSC52.Max_Status_Label_Length) :=
          (others => ' ');
      Tab_Status_Length : Tab_Status_Length_Range := 0;
      Tab_Status : String (1 .. Terminal.App.Tabs.Max_Status_Label_Length) :=
        (others => ' ');
      Split_Status_Length : Split_Status_Length_Range := 0;
      Split_Status : String (1 .. Terminal.App.Splits.Max_Status_Label_Length) :=
        (others => ' ');
      Config_Status_Length : Config_Status_Length_Range := 0;
      Config_Status : String (1 .. Terminal.App.Config.Max_Status_Label_Length) :=
        (others => ' ');
      Profile_Status_Length : Profile_Status_Length_Range := 0;
      Profile_Status : String (1 .. Terminal.App.Max_Status_Label_Length) :=
        (others => ' ');
      Input_Status_Length : Input_Status_Length_Range := 0;
      Input_Status :
        String (1 .. Terminal.App.Input_Map.Max_Input_Status_Label_Length) :=
          (others => ' ');
      Mouse_Status_Length : Mouse_Status_Length_Range := 0;
      Mouse_Status :
        String (1 .. Terminal.App.Input_Map.Max_Mouse_Status_Label_Length) :=
          (others => ' ');
      Cursor_Status_Length : Cursor_Status_Length_Range := 0;
      Cursor_Status :
        String (1 .. Terminal.App.Cursor_Blink.Max_Status_Label_Length) :=
          (others => ' ');
      Text_Blink_Status_Length : Text_Blink_Status_Length_Range := 0;
      Text_Blink_Status :
        String (1 .. Terminal.App.Text_Blink.Max_Status_Label_Length) :=
          (others => ' ');
      Theme_Status_Length : Theme_Status_Length_Range := 0;
      Theme_Status :
        String (1 .. Terminal.App.Theme.Max_Status_Label_Length) :=
          (others => ' ');
      Font_Status_Length : Font_Status_Length_Range := 0;
      Font_Status :
        String (1 .. Terminal.App.Fonts.Max_Status_Label_Length) :=
          (others => ' ');
      PTY_Backend_Status_Length : PTY_Backend_Status_Length_Range := 0;
      PTY_Backend_Status :
        String (1 .. Terminal.PTY.POSIX.Max_Status_Label_Length) :=
          (others => ' ');
      ConPTY_Status_Length : PTY_Backend_Status_Length_Range := 0;
      ConPTY_Status :
        String (1 .. Terminal.PTY.POSIX.Max_Status_Label_Length) :=
          (others => ' ');
      Multiplexer_Status_Length : Multiplexer_Status_Length_Range := 0;
      Multiplexer_Status : String (1 .. Terminal.App.Max_Status_Label_Length) :=
        (others => ' ');
      Graphics_Header_Status_Length :
        Graphics_Header_Status_Length_Range := 0;
      Graphics_Header_Status :
        String (1 .. Terminal.App.Graphics.Max_Status_Label_Length) :=
          (others => ' ');
      Graphics_Data_Status_Length :
        Graphics_Data_Status_Length_Range := 0;
      Graphics_Data_Status :
        String (1 .. Terminal.App.Graphics.Max_Status_Label_Length) :=
          (others => ' ');
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
      Grid_Status : String := "";
      Policy_Status : String := "";
      Scrollback_Status : String := "";
      Selection_Status : String := "";
      Link_Status : String := "";
      Link_Activation_Status : String := "";
      Clipboard_Status : String := "";
      Tab_Status : String := "";
      Split_Status : String := "";
      Config_Status : String := "";
      Profile_Status : String := "";
      Input_Status : String := "";
      Mouse_Status : String := "";
      Cursor_Status : String := "";
      Text_Blink_Status : String := "";
      Theme_Status : String := "";
      Font_Status : String := "";
      PTY_Backend_Status : String := "";
      ConPTY_Status : String := "";
      Multiplexer_Status : String := "";
      Graphics_Header_Status : String := "";
      Graphics_Data_Status : String := "")
      return Snapshot;

   procedure Log_Startup_Failure
     (Stage  : String;
      Status : String);

   function Status_Line (S : Snapshot) return String;

   function Image_Texture_Pipeline_Status_Label (S : Snapshot) return String;

   procedure Log_If_Changed (S : Snapshot);
end Terminal.App.Diagnostics;

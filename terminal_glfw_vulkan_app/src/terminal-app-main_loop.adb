with Ada.Real_Time;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with GNAT.OS_Lib;

with GLFW_Vulkan;
with GLFW_Vulkan.Clipboard;
with GLFW_Vulkan.Events;
with GLFW_Vulkan.Input;
with GLFW_Vulkan.Windows;
with Terminal.Common;
with Terminal.Common.Bytes;
with Terminal.Core;
with Terminal.App.Accessibility;
with Terminal.App.Blink_Activity;
with Terminal.App.Clipboard_OSC52;
with Terminal.App.Click_Debounce;
with Terminal.App.Cleanup_Diagnostics;
with Terminal.App.Config;
with Terminal.App.Command_Palette;
with Terminal.App.Copy_Mode;
with Terminal.App.Cursor_Blink;
with Terminal.App.Diagnostics;
with Terminal.App.Fonts;
with Terminal.App.Frame_Completion;
with Terminal.App.Graphics;
with Terminal.App.Graphics_Profile;
with Terminal.App.Hyperlinks;
with Terminal.App.Input_Map;
with Terminal.App.ITerm2_Files;
with Terminal.App.Key_Bindings;
with Terminal.App.PTY_Write;
with Terminal.App.PTY_Cleanup_Lifecycle;
with Terminal.App.Platform_Launcher;
with Terminal.App.Queues;
with Terminal.App.Renderer;
with Terminal.App.Renderer.Graphics;
with Terminal.App.Renderer.Layout;
with Terminal.App.Renderer.Presentation;
with Terminal.App.Render_Policy;
with Terminal.App.Resize;
with Terminal.App.Scrollback_View;
with Terminal.App.Shell_Blocks;
with Terminal.App.Selection;
with Terminal.App.Settings;
with Terminal.App.Session_Runtime;
with Terminal.App.Session_Recording;
with Terminal.App.Session_Profiles;
with Terminal.App.Session_Graphics;
with Terminal.App.Session_Table;
with Terminal.App.Sessions;
with Terminal.App.Splits;
with Terminal.App.Tabs;
with Terminal.App.Text_Blink;
with Terminal.App.Text_Composition;
with Terminal.App.Theme;
with Terminal.App.Vulkan_Context;
with Terminal.App.Vulkan_Presenter;
with Terminal.App.Vulkan_Recovery;
with Terminal.App.Workspace;
with Terminal.PTY.Backend;

package body Terminal.App.Main_Loop is
   package Unbounded renames Ada.Strings.Unbounded;
   use type Ada.Real_Time.Time;
   use type GLFW_Vulkan.Init_Status;
   use type GLFW_Vulkan.Windows.Create_Status;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.App.Renderer.Theme_Update_Status;
   use type Terminal.App.Renderer.Font_Update_Status;
   use type Terminal.App.Vulkan_Context.Init_Status;
   use type Terminal.App.Vulkan_Presenter.Init_Status;
   use type Terminal.App.Vulkan_Presenter.Present_Status;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Resize_Status;
   use type Terminal.PTY.Backend.Resize_Status;
   use type Terminal.App.PTY_Write.Write_All_Status;
   use type Terminal.App.Splits.Split_Command;
   use type Terminal.App.Splits.Split_Orientation;
   use type Terminal.App.Splits.Split_Status;
   use type Terminal.App.Tabs.Tab_Command;
   use type Terminal.App.Tabs.Tab_Status;
   use type Terminal.App.Session_Table.Table_Status;
   use type Terminal.App.Session_Runtime.Runtime_Status;
   use type Terminal.App.Key_Bindings.Action;
   use type GLFW_Vulkan.Input.Key;
   use type Terminal.App.Command_Palette.Choice_Kind;
   use type Terminal.Core.Clipboard_Operation;
   use type Terminal.Core.Clipboard_Target;
   use type Terminal.Core.Notification_Kind;
   use type Terminal.Core.Graphics_Stream_ID;
   use type Terminal.App.Workspace.IO_Status;
   use type Terminal.App.Workspace.Layout_Kind;
   use type Terminal.App.Workspace.Pane_Orientation;
   use type Terminal.App.Platform_Launcher.Launch_Status;
   use type Terminal.App.Config.Config_Load_Status;
   use type Terminal.App.Session_Recording.IO_Status;
   use type GLFW_Vulkan.Input.Key;
   use type GLFW_Vulkan.Input.Key_Action;
   use type GLFW_Vulkan.Input.Mouse_Button;

   --  Present-grace window (frames). Refilled by input (in the On_* callbacks)
   --  and counted down one per loop iteration; while non-zero the loop keeps
   --  presenting every frame even when nothing changed, which keeps us on the
   --  compositor's frame clock so input stays paced to the display. Refilled by
   --  INPUT, not by the blink/redraw signal, so a blinking cursor still presents
   --  only on its own toggle and does not hold the window open. ~24 = ~0.4s.
   Present_Grace_Frames : constant := 24;
   Last_Tab_Title    : Unbounded.Unbounded_String;
   Last_Window_Title : Unbounded.Unbounded_String;

   function Fatal_Write
     (Status : Terminal.App.PTY_Write.Write_All_Status) return Boolean is
     (Status in
        Terminal.App.PTY_Write.Failed | Terminal.App.PTY_Write.Session_Closed);

   function Title_String (Title : Terminal.Core.Title_Text) return String is
   begin
      if Title.Length = 0 then
         return "Ada Terminal";
      else
         return Title.Text (1 .. Title.Length);
      end if;
   end Title_String;

   procedure Apply_Title
     (W          : GLFW_Vulkan.Windows.Window;
      New_Title  : Terminal.Core.Title_Text;
      Hover_Link : Terminal.Core.Hyperlink;
      Has_Link_Activation : Boolean;
      Link_Activation :
        Terminal.App.Hyperlinks.Activation_Status;
      Mode_Status : String;
      Sessions   : in out Terminal.App.Session_Table.Runtime_Table)
   is
      Status : Terminal.App.Session_Table.Table_Status;
      Tabs : constant Terminal.App.Tabs.Tab_State :=
        Terminal.App.Session_Table.Tabs (Sessions);
      Splits : constant Terminal.App.Splits.Split_State :=
        Terminal.App.Session_Table.Splits (Sessions);
      Base_Title : constant String :=
        Title_String (New_Title)
        & Terminal.App.Tabs.Title_Suffix (Tabs)
        & Terminal.App.Splits.Title_Suffix (Splits);
      Status_Title : constant String :=
        (if Has_Link_Activation
         then Base_Title
           & " - "
           & Terminal.App.Hyperlinks.Activation_Status_Label
               (Link_Activation)
         else Base_Title);
      Mode_Title : constant String :=
        (if Mode_Status'Length = 0
         then Status_Title
         else Status_Title & " - " & Mode_Status);
   begin
      if Unbounded.To_String (Last_Tab_Title) /= Title_String (New_Title) then
         Terminal.App.Session_Table.Set_Active_Tab_Label
           (Sessions, Title_String (New_Title), Status);
         if Status = Terminal.App.Session_Table.Ok then
            Unbounded.Set_Unbounded_String
              (Last_Tab_Title, Title_String (New_Title));
         end if;
      end if;
      declare
         Effective_Title : constant String :=
           Terminal.App.Hyperlinks.Hover_Title (Mode_Title, Hover_Link);
      begin
         if Unbounded.To_String (Last_Window_Title) /= Effective_Title then
            GLFW_Vulkan.Windows.Set_Title (W, Effective_Title);
            Unbounded.Set_Unbounded_String
              (Last_Window_Title, Effective_Title);
         end if;
      end;
   end Apply_Title;

   procedure Apply_Clipboard_Request
     (W : GLFW_Vulkan.Windows.Window;
      Runtime : in out Terminal.App.Session_Runtime.Runtime;
      Store : in out Terminal.App.Clipboard_OSC52.Target_Store;
      T : in out Terminal.Core.Terminal;
      Ok : out Boolean;
      Last_Write_Status : in out Terminal.App.PTY_Write.Write_All_Status;
      Last_Clipboard_Target : in out Terminal.Core.Clipboard_Target)
   is
      Request : constant Terminal.Core.Clipboard_Request :=
        Terminal.Core.Clipboard (T);
      Chunk : Terminal.App.Queues.Byte_Chunk;
      Write_Stat : Terminal.App.PTY_Write.Write_All_Status;
   begin
      Ok := True;
      if Request.Pending then
         Last_Clipboard_Target := Request.Target;
         if Request.Operation = Terminal.Core.Clipboard_Query then
            if Terminal.App.Session_Runtime.Has_Pending_Write (Runtime) then
               Last_Write_Status := Terminal.App.PTY_Write.Incomplete;
               return;
            end if;
            Terminal.App.Clipboard_OSC52.Build_Query_Response
              (Request.Target,
               (if Request.Target = Terminal.Core.Clipboard_Clipboard
                then GLFW_Vulkan.Clipboard.Get_Text (W)
                else Terminal.App.Clipboard_OSC52.Text (Store, Request.Target)),
               Chunk);
            Terminal.App.Session_Runtime.Write (Runtime, Chunk, Write_Stat);
            Last_Write_Status := Write_Stat;
            Ok := not Fatal_Write (Write_Stat);
         else
            if Request.Target = Terminal.Core.Clipboard_Clipboard then
               if Request.Length = 0 then
                  GLFW_Vulkan.Clipboard.Set_Text (W, "");
                  Terminal.App.Clipboard_OSC52.Store
                    (Store, Request.Target, "");
               else
                  GLFW_Vulkan.Clipboard.Set_Text
                    (W, Request.Text (1 .. Request.Length));
                  Terminal.App.Clipboard_OSC52.Store
                    (Store,
                     Request.Target,
                     Request.Text (1 .. Request.Length));
               end if;
            else
               Terminal.App.Clipboard_OSC52.Store
                 (Store,
                  Request.Target,
                  (if Request.Length = 0
                   then ""
                   else Request.Text (1 .. Request.Length)));
            end if;
         end if;
         Terminal.Core.Clear_Clipboard (T);
      end if;
   end Apply_Clipboard_Request;

   function Is_Scrollback_Key
     (Event : GLFW_Vulkan.Input.Key_Event) return Boolean
   is
   begin
      return Event.Action /= GLFW_Vulkan.Input.Release
        and then Event.Modifiers.Shift
        and then
          (Event.Key = GLFW_Vulkan.Input.Page_Up
           or else Event.Key = GLFW_Vulkan.Input.Page_Down);
   end Is_Scrollback_Key;

   function Mouse_Button_Code
     (Button : GLFW_Vulkan.Input.Mouse_Button) return Natural
   is
   begin
      case Button is
         when GLFW_Vulkan.Input.Left   => return 0;
         when GLFW_Vulkan.Input.Middle => return 1;
         when GLFW_Vulkan.Input.Right  => return 2;
         when others                   => return 0;
      end case;
   end Mouse_Button_Code;

   function Same_Position
     (Left  : Terminal.App.Selection.Cell_Position;
      Right : Terminal.App.Selection.Cell_Position) return Boolean is
     (Left.Row = Right.Row and then Left.Col = Right.Col);

   function Supported_Link
     (Link : Terminal.Core.Hyperlink) return Terminal.Core.Hyperlink
   is
      URI_Text : constant String :=
        (if Link.URI_Length = 0 then "" else Link.URI (1 .. Link.URI_Length));
   begin
      if Link.Active and then Terminal.App.Hyperlinks.Supported_URI (URI_Text) then
         return Link;
      else
         return (others => <>);
      end if;
   end Supported_Link;

   Double_Click_Interval : constant Duration := 0.5;

   procedure Run (Workspace_Override : String := "") is separate;
end Terminal.App.Main_Loop;

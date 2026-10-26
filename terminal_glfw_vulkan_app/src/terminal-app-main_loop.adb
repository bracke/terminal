with Ada.Real_Time;

with GLFW_Vulkan;
with GLFW_Vulkan.Clipboard;
with GLFW_Vulkan.Events;
with GLFW_Vulkan.Input;
with GLFW_Vulkan.Windows;
with Terminal.Core;
with Terminal.App.Clipboard_OSC52;
with Terminal.App.Cleanup_Diagnostics;
with Terminal.App.Config;
with Terminal.App.Cursor_Blink;
with Terminal.App.Diagnostics;
with Terminal.App.Fonts;
with Terminal.App.Graphics;
with Terminal.App.Hyperlinks;
with Terminal.App.Input_Map;
with Terminal.App.ITerm2_Files;
with Terminal.App.PTY_Write;
with Terminal.App.Queues;
with Terminal.App.Renderer;
with Terminal.App.Render_Policy;
with Terminal.App.Resize;
with Terminal.App.Scrollback_View;
with Terminal.App.Selection;
with Terminal.App.Session_Runtime;
with Terminal.App.Session_Graphics;
with Terminal.App.Session_Table;
with Terminal.App.Sessions;
with Terminal.App.Splits;
with Terminal.App.Tabs;
with Terminal.App.Text_Blink;
with Terminal.App.Theme;
with Terminal.App.Vulkan_Context;
with Terminal.App.Vulkan_Presenter;
with Terminal.App.Vulkan_Recovery;
with Terminal.PTY.Backend;

package body Terminal.App.Main_Loop is
   use type Ada.Real_Time.Time;
   use type GLFW_Vulkan.Init_Status;
   use type GLFW_Vulkan.Windows.Create_Status;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.App.Renderer.Theme_Update_Status;
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
   use type Terminal.Core.Clipboard_Operation;
   use type Terminal.Core.Clipboard_Target;
   use type GLFW_Vulkan.Input.Key;
   use type GLFW_Vulkan.Input.Key_Action;
   use type GLFW_Vulkan.Input.Mouse_Button;

   Input_Queue : access Terminal.App.Queues.Input_Event_Queue := null;

   --  Time of the last accepted left press, for bounce rejection: a failing mouse
   --  switch (or an un-debounced compositor) can emit a spurious second press
   --  microseconds after the real one, double-firing selection/paste.
   Last_Left_Press_Time : Ada.Real_Time.Time := Ada.Real_Time.Clock;

   --  Present-grace window (frames). Refilled by input (in the On_* callbacks)
   --  and counted down one per loop iteration; while non-zero the loop keeps
   --  presenting every frame even when nothing changed, which keeps us on the
   --  compositor's frame clock so input stays paced to the display. Refilled by
   --  INPUT, not by the blink/redraw signal, so a blinking cursor still presents
   --  only on its own toggle and does not hold the window open. ~24 = ~0.4s.
   Present_Grace_Frames : constant := 24;
   Input_Grace : Natural := 0;

   function Fatal_Write
     (Status : Terminal.App.PTY_Write.Write_All_Status) return Boolean is
     (Status in
        Terminal.App.PTY_Write.Failed | Terminal.App.PTY_Write.Session_Closed);

   procedure On_Key (Event : GLFW_Vulkan.Input.Key_Event) is
   begin
      Input_Grace := Present_Grace_Frames;
      if Input_Queue /= null then
         Input_Queue.Push
           ((Kind            => Terminal.App.Queues.Key,
             Width           => 0,
             Height          => 0,
             Bytes           => (others => <>),
             Key_Event       => Event,
             Character_Event => (others => <>),
             Button_Event    => (others => <>),
             Cursor_Event    => (others => <>),
             Scroll_Event    => (others => <>),
             Focus_Event     => (others => <>)));
      end if;
   end On_Key;

   procedure On_Character (Event : GLFW_Vulkan.Input.Character_Event) is
   begin
      Input_Grace := Present_Grace_Frames;
      if Input_Queue /= null then
         Input_Queue.Push
           ((Kind            => Terminal.App.Queues.Character,
             Width           => 0,
             Height          => 0,
             Bytes           => (others => <>),
             Key_Event       => (others => <>),
             Character_Event => Event,
             Button_Event    => (others => <>),
             Cursor_Event    => (others => <>),
             Scroll_Event    => (others => <>),
             Focus_Event     => (others => <>)));
      end if;
   end On_Character;

   procedure On_Mouse_Button (Event : GLFW_Vulkan.Input.Mouse_Button_Event) is
   begin
      Input_Grace := Present_Grace_Frames;
      if Event.Action = GLFW_Vulkan.Input.Press
        and then Event.Button = GLFW_Vulkan.Input.Left
      then
         declare
            Now : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
         begin
            --  Drop a left press that follows the previous accepted one too
            --  closely to be a real click -- a switch bounce that would otherwise
            --  double-fire selection or paste.
            if Ada.Real_Time.To_Duration (Now - Last_Left_Press_Time) < 0.040 then
               return;
            end if;
            Last_Left_Press_Time := Now;
         end;
      end if;

      if Input_Queue /= null then
         Input_Queue.Push
           ((Kind            => Terminal.App.Queues.Mouse_Button,
             Width           => 0,
             Height          => 0,
             Bytes           => (others => <>),
             Key_Event       => (others => <>),
             Character_Event => (others => <>),
             Button_Event    => Event,
             Cursor_Event    => (others => <>),
             Scroll_Event    => (others => <>),
             Focus_Event     => (others => <>)));
      end if;
   end On_Mouse_Button;

   procedure On_Cursor_Position
     (Event : GLFW_Vulkan.Input.Cursor_Position_Event)
   is
   begin
      if Input_Queue /= null then
         Input_Queue.Push
           ((Kind            => Terminal.App.Queues.Cursor_Position,
             Width           => 0,
             Height          => 0,
             Bytes           => (others => <>),
             Key_Event       => (others => <>),
             Character_Event => (others => <>),
             Button_Event    => (others => <>),
             Cursor_Event    => Event,
             Scroll_Event    => (others => <>),
             Focus_Event     => (others => <>)));
      end if;
   end On_Cursor_Position;

   procedure On_Scroll (Event : GLFW_Vulkan.Input.Scroll_Event) is
   begin
      Input_Grace := Present_Grace_Frames;
      if Input_Queue /= null then
         Input_Queue.Push
           ((Kind            => Terminal.App.Queues.Scroll,
             Width           => 0,
             Height          => 0,
             Bytes           => (others => <>),
             Key_Event       => (others => <>),
             Character_Event => (others => <>),
             Button_Event    => (others => <>),
             Cursor_Event    => (others => <>),
             Scroll_Event    => Event,
             Focus_Event     => (others => <>)));
      end if;
   end On_Scroll;

   procedure On_Focus (Event : GLFW_Vulkan.Input.Focus_Event) is
   begin
      if Input_Queue /= null then
         Input_Queue.Push
           ((Kind            => Terminal.App.Queues.Focus,
             Width           => 0,
             Height          => 0,
             Bytes           => (others => <>),
             Key_Event       => (others => <>),
             Character_Event => (others => <>),
             Button_Event    => (others => <>),
             Cursor_Event    => (others => <>),
             Scroll_Event    => (others => <>),
             Focus_Event     => Event));
      end if;
   end On_Focus;

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
      Tabs       : in out Terminal.App.Tabs.Tab_State;
      Splits     : Terminal.App.Splits.Split_State)
   is
      Status : Terminal.App.Tabs.Tab_Status;
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
   begin
      Terminal.App.Tabs.Set_Label
        (Tabs,
         Terminal.App.Tabs.Active (Tabs),
         Title_String (New_Title),
         Status);
      GLFW_Vulkan.Windows.Set_Title
        (W,
         Terminal.App.Hyperlinks.Hover_Title
           (Status_Title, Hover_Link));
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

   procedure Run is separate;
end Terminal.App.Main_Loop;

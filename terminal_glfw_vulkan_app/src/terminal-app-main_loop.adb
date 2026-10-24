with Ada.Real_Time;

with GLFW_Vulkan;
with GLFW_Vulkan.Clipboard;
with GLFW_Vulkan.Events;
with GLFW_Vulkan.Input;
with GLFW_Vulkan.Windows;
with Terminal.Core;
with Terminal.App.Clipboard_OSC52;
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
            Terminal.App.Clipboard_OSC52.Build_Query_Response
              (Request.Target,
               (if Request.Target = Terminal.Core.Clipboard_Clipboard
                then GLFW_Vulkan.Clipboard.Get_Text (W)
                else Terminal.App.Clipboard_OSC52.Text (Store, Request.Target)),
               Chunk);
            Terminal.App.Session_Runtime.Write (Runtime, Chunk, Write_Stat);
            Last_Write_Status := Write_Stat;
            Ok := Write_Stat = Terminal.App.PTY_Write.Ok;
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

   procedure Run is
      Ctx : GLFW_Vulkan.Context;
      W   : GLFW_Vulkan.Windows.Window;
      Init_Status : GLFW_Vulkan.Init_Status;
      Window_Status : GLFW_Vulkan.Windows.Create_Status;
      Session_Table_Status : Terminal.App.Session_Table.Table_Status;
      In_Q  : aliased Terminal.App.Queues.Input_Event_Queue;
      R     : Terminal.App.Renderer.Renderer;
      Vk_Ctx : Terminal.App.Vulkan_Context.Context;
      Vk_Status : Terminal.App.Vulkan_Context.Init_Status;
      Presenter : Terminal.App.Vulkan_Presenter.Presenter;
      Presenter_Status : Terminal.App.Vulkan_Presenter.Init_Status;
      Vulkan_Recovery : Terminal.App.Vulkan_Recovery.Controller;
      Recovery_Tick : Natural := 0;
      Renderer_Status : Terminal.App.Renderer.Init_Status;
      App_Config : Terminal.App.Config.Config;
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
      Splits : Terminal.App.Splits.Split_State;
      Tabs : Terminal.App.Tabs.Tab_State;
      Sessions : Terminal.App.Session_Table.Runtime_Table;
      Snapshot_Cache : Terminal.App.Renderer.Snapshot_Array
        (1 .. Terminal.App.Sessions.Max_Sessions);
      Hovered_Link : Terminal.Core.Hyperlink;
      Has_Link_Activation : Boolean := False;
      Link_Activation :
        Terminal.App.Hyperlinks.Activation_Status :=
          Terminal.App.Hyperlinks.No_Link;
      Mouse_Button_Down : Boolean := False;
      Mouse_Button_Code_Value : Natural := 0;
      Mouse_Modifiers : GLFW_Vulkan.Input.Modifier_Set;
      Suppress_Character : Wide_Wide_Character :=
        Wide_Wide_Character'Val (0);
      Blink_Origin : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Last_Blink_Tick : Natural := 0;
      Blinking_Text_Active : Boolean := False;
      Last_Feed_Status : Terminal.Core.Feed_Status := Terminal.Core.Ok;
      Last_Write_Status : Terminal.App.PTY_Write.Write_All_Status :=
        Terminal.App.PTY_Write.Ok;
      Last_Clipboard_Target : Terminal.Core.Clipboard_Target :=
        Terminal.Core.Clipboard_Clipboard;
      Runtime_Font_Status : constant String :=
        Terminal.App.Fonts.Status_Label
          (Terminal.App.Fonts.Default_Font_Path,
           Terminal.App.Fonts.Fallback_Font_Paths'Length);
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
        return access Terminal.App.Session_Runtime.Runtime is
      begin
         return Terminal.App.Session_Table.Active_Runtime (Sessions);
      end Active_Runtime;

      function Active_Core return access Terminal.Core.Terminal is
      begin
         return Terminal.App.Session_Runtime.Core (Active_Runtime.all);
      end Active_Core;

      procedure Configure_Active_Core is
      begin
         Terminal.Core.Set_Graphics_Capabilities
           (Active_Core.all,
            Terminal.App.Core_Graphics_Profile
              (App_Config.Kitty_File_Transfer,
               App_Config.Kitty_Temporary_Transfer,
               App_Config.Kitty_Shared_Memory,
               App_Config.ITerm2_File_Downloads));
         Terminal.Core.Set_Graphics_Resource_Limits
           (Active_Core.all,
            (Transaction_Length => App_Config.Graphics_Transaction_Bytes,
             Pending_Events => App_Config.Graphics_Pending_Events,
             Pending_Bytes => App_Config.Graphics_Pending_Bytes,
             Deferred_Input_Bytes =>
               App_Config.Graphics_Deferred_Input_Bytes,
             Pixel_Dimension => App_Config.Graphics_Pixel_Dimension));
         Terminal.Core.Set_Cell_Pixel_Size
           (Active_Core.all,
            Terminal.App.Renderer.Cell_Width (R),
            Terminal.App.Renderer.Cell_Height (R));
         Terminal.Core.Set_Window_Pixel_Size
           (Active_Core.all, FB_Width, FB_Height);
      end Configure_Active_Core;

      function Active_PTY_Queue
        return access Terminal.App.Queues.PTY_Output_Queue is
      begin
         return Terminal.App.Session_Runtime.PTY_Queue (Active_Runtime.all);
      end Active_PTY_Queue;

      procedure Resize_Visible_Runtimes is
      begin
         if Terminal.App.Splits.Count (Splits) <= 1 then
            declare
               Core_Resize : Terminal.Core.Resize_Status;
               PTY_Resize  : Terminal.PTY.Backend.Resize_Status;
            begin
               Terminal.App.Session_Runtime.Resize
                 (Active_Runtime.all,
                  Last_Rows,
                  Last_Cols,
                  Core_Resize,
                  PTY_Resize);
            end;
         else
            declare
               Layout : constant Terminal.App.Splits.Pane_Layout :=
                 Terminal.App.Splits.Layout (Splits, Last_Rows, Last_Cols);
            begin
               for I in 1 .. Layout.Count loop
                  declare
                     Runtime : constant access Terminal.App.Session_Runtime.Runtime :=
                       Terminal.App.Session_Table.Runtime_At
                         (Sessions,
                          Terminal.App.Sessions.Session_Index (I));
                     Core_Resize : Terminal.Core.Resize_Status;
                     PTY_Resize  : Terminal.PTY.Backend.Resize_Status;
                  begin
                     if Runtime /= null
                       and then Layout.Rects (I).Rows > 0
                       and then Layout.Rects (I).Cols > 0
                     then
                        Terminal.App.Session_Runtime.Resize
                          (Runtime.all,
                           Positive (Layout.Rects (I).Rows),
                           Positive (Layout.Rects (I).Cols),
                           Core_Resize,
                           PTY_Resize);
                     end if;
                  end;
               end loop;
            end;
         end if;
         Configure_Active_Core;
      end Resize_Visible_Runtimes;

      function Tab_Bar_Height return Natural is
        (if Terminal.App.Tabs.Count (Tabs) > 1
         then Terminal.App.Renderer.Cell_Height (R) + 2
         else 0);

      function Active_Pane_Origin_X return Natural is
      begin
         if Terminal.App.Splits.Count (Splits) <= 1
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
         if Terminal.App.Splits.Count (Splits) <= 1
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
         if Terminal.App.Splits.Count (Splits) <= 1 then
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
         if Terminal.App.Splits.Count (Splits) <= 1 then
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

      procedure Copy_Selection is
         Copy_Snap : Terminal.Core.Render_Snapshot :=
           Terminal.App.Scrollback_View.Snapshot (Active_Core.all, Scroll_Offset);
         Text : constant String :=
           Terminal.App.Selection.Selected_Text (Copy_Snap, Selection);
      begin
         if Text'Length > 0 then
            GLFW_Vulkan.Clipboard.Set_Text (W, Text);
            Terminal.App.Clipboard_OSC52.Store_Local_Selection
              (Clipboard_Targets, Text);
         end if;
         Terminal.Core.Release (Copy_Snap);
      end Copy_Selection;
   begin
      Terminal.App.Vulkan_Recovery.Initialize (Vulkan_Recovery);
      GLFW_Vulkan.Initialize (Ctx, Init_Status);
      if Init_Status /= GLFW_Vulkan.Ok then
         Terminal.App.Diagnostics.Log_Startup_Failure
           ("glfw", GLFW_Vulkan.Init_Status'Image (Init_Status));
         return;
      end if;

      Terminal.App.Config.Load (App_Config);

      GLFW_Vulkan.Windows.Create
        (Ctx,
         W,
         App_Config.Window_Width,
         App_Config.Window_Height,
         "Ada Terminal",
         Window_Status);
      if Window_Status /= GLFW_Vulkan.Windows.Ok then
         Terminal.App.Diagnostics.Log_Startup_Failure
           ("window", GLFW_Vulkan.Windows.Create_Status'Image (Window_Status));
         GLFW_Vulkan.Finalize (Ctx);
         return;
      end if;

      Terminal.App.Vulkan_Context.Initialize (Vk_Ctx, W, Vk_Status);
      if Vk_Status /= Terminal.App.Vulkan_Context.Ok then
         Terminal.App.Diagnostics.Log_Startup_Failure
           ("vulkan-context",
            Terminal.App.Vulkan_Context.Init_Status'Image (Vk_Status));
         GLFW_Vulkan.Windows.Destroy (W);
         GLFW_Vulkan.Finalize (Ctx);
         return;
      end if;

      GLFW_Vulkan.Windows.Framebuffer_Size (W, FB_Width, FB_Height);
      Terminal.App.Vulkan_Presenter.Initialize
        (P              => Presenter,
         Context        => Vk_Ctx,
         Status         => Presenter_Status,
         Desired_Width  => FB_Width,
         Desired_Height => FB_Height);
      if Presenter_Status /= Terminal.App.Vulkan_Presenter.Ok then
         Terminal.App.Diagnostics.Log_Startup_Failure
           ("vulkan-presenter",
            Terminal.App.Vulkan_Presenter.Init_Status'Image (Presenter_Status));
         Terminal.App.Vulkan_Context.Finalize (Vk_Ctx);
         GLFW_Vulkan.Windows.Destroy (W);
         GLFW_Vulkan.Finalize (Ctx);
         return;
      end if;

      Terminal.App.Renderer.Initialize (R, Vk_Ctx, Renderer_Status);
      if Renderer_Status /= Terminal.App.Renderer.Ok then
         Terminal.App.Diagnostics.Log_Startup_Failure
           ("renderer",
            Terminal.App.Renderer.Init_Status'Image (Renderer_Status));
         Terminal.App.Renderer.Finalize (R);
         Terminal.App.Vulkan_Presenter.Finalize (Presenter);
         Terminal.App.Vulkan_Context.Finalize (Vk_Ctx);
         GLFW_Vulkan.Windows.Destroy (W);
         GLFW_Vulkan.Finalize (Ctx);
         return;
      end if;
      Terminal.App.Renderer.Set_Theme
        (R, Terminal.App.Config.Active_Theme (App_Config));
      Terminal.App.Renderer.Set_Graphics_Access_Policy
        (R,
         (Allow_Regular_Files   => App_Config.Kitty_File_Transfer,
          Allow_Temporary_Files => App_Config.Kitty_Temporary_Transfer,
          Allow_Shared_Memory   => App_Config.Kitty_Shared_Memory));
      declare
         Policy : Terminal.App.ITerm2_Files.Download_Policy;
      begin
         Terminal.App.ITerm2_Files.Configure
           (Policy,
            App_Config.ITerm2_File_Downloads,
            Terminal.App.ITerm2_Files.Default_Download_Directory);
         Terminal.App.Renderer.Set_ITerm2_Download_Policy (R, Policy);
      end;
      Terminal.App.Renderer.Set_Graphics_Resource_Limits
        (R,
         (Image_Objects => App_Config.Graphics_Image_Objects,
          Image_Bytes => App_Config.Graphics_Image_Bytes,
          Placements => App_Config.Graphics_Placements,
          Animation_Frames => App_Config.Graphics_Animation_Frames,
          Per_Image_Bytes => App_Config.Graphics_Per_Image_Bytes,
          Pixel_Dimension => App_Config.Graphics_Pixel_Dimension,
          GPU_Atlas_Bytes => App_Config.Graphics_GPU_Atlas_Bytes,
          GPU_Atlas_Dimension => App_Config.Graphics_GPU_Atlas_Dimension));

      Terminal.App.Resize.Startup_Cells
        (Pixel_Width  => FB_Width,
         Pixel_Height => FB_Height,
         Cell_Width   => Terminal.App.Renderer.Cell_Width (R),
         Cell_Height  => Terminal.App.Renderer.Cell_Height (R),
         Margin       => Terminal.App.Renderer.Content_Margin,
         Default_Rows => App_Config.Startup_Rows,
         Default_Cols => App_Config.Startup_Cols,
         Rows         => Initial_Rows,
         Cols         => Initial_Cols);
      Last_Rows := Initial_Rows;
      Last_Cols := Initial_Cols;
      Terminal.App.Session_Table.Initialize
        (Sessions,
         Initial_Rows,
         Initial_Cols,
         App_Config.Scrollback_Limit,
         Session_Table_Status,
         Graphics_Profile =>
           Terminal.App.Core_Graphics_Profile
             (App_Config.Kitty_File_Transfer,
              App_Config.Kitty_Temporary_Transfer,
              App_Config.Kitty_Shared_Memory,
              App_Config.ITerm2_File_Downloads));
      if Session_Table_Status /= Terminal.App.Session_Table.Ok then
         Terminal.App.Diagnostics.Log_Startup_Failure
           ("session-table",
            Terminal.App.Session_Table.Table_Status'Image
              (Session_Table_Status));
         Terminal.App.Renderer.Finalize (R);
         Terminal.App.Vulkan_Presenter.Finalize (Presenter);
         Terminal.App.Vulkan_Context.Finalize (Vk_Ctx);
         GLFW_Vulkan.Windows.Destroy (W);
         GLFW_Vulkan.Finalize (Ctx);
         return;
      end if;

      Configure_Active_Core;

      Input_Queue := In_Q'Unchecked_Access;
      Terminal.App.Tabs.Initialize (Tabs);
      Terminal.App.Splits.Initialize (Splits);
      GLFW_Vulkan.Input.Set_Key_Callback (W, On_Key'Access);
      GLFW_Vulkan.Input.Set_Character_Callback (W, On_Character'Access);
      GLFW_Vulkan.Input.Set_Mouse_Button_Callback (W, On_Mouse_Button'Access);
      GLFW_Vulkan.Input.Set_Cursor_Position_Callback
        (W, On_Cursor_Position'Access);
      GLFW_Vulkan.Input.Set_Scroll_Callback (W, On_Scroll'Access);
      GLFW_Vulkan.Input.Set_Focus_Callback (W, On_Focus'Access);

      while not GLFW_Vulkan.Windows.Should_Close (W) loop
            declare
               Chunk      : Terminal.App.Queues.Byte_Chunk;
               Has_Chunk  : Boolean;
               Event      : Terminal.App.Queues.Input_Event;
               Has_Event  : Boolean;
               Feed       : Terminal.Core.Feed_Status;
               Write_Stat : Terminal.App.PTY_Write.Write_All_Status;
               Dirty      : Boolean := Need_Redraw;
               Local_Redraw : Boolean := False;
               Current_Blink_Tick : Natural := Last_Blink_Tick;
            begin
               if Recovery_Tick < Natural'Last then
                  Recovery_Tick := Recovery_Tick + 1;
               end if;
               --  Wait a frame's worth instead of spinning at ~60 fps. Present is
               --  already skipped for unchanged frames, so this timeout alone sets
               --  the idle rate and a short fixed wait keeps it cheap. Do not sleep
               --  longer when idle: once we stop presenting, nothing drives
               --  compositor wakeups, so a long block genuinely delays input. A
               --  frame's wait still catches each cursor/text blink edge within a
               --  frame (checked just below; present-skip drops the between frames),
               --  and input and PTY output (via Post_Empty_Event) wake it at once.
               GLFW_Vulkan.Events.Wait_Timeout (0.016);

               Current_Blink_Tick :=
                 Terminal.App.Cursor_Blink.Tick
                   (Ada.Real_Time.To_Duration
                      (Ada.Real_Time.Clock - Blink_Origin));
               if Current_Blink_Tick /= Last_Blink_Tick
                 and then
                   (Terminal.Core.Modes (Active_Core.all).Cursor_Blinking
                    or else Blinking_Text_Active)
               then
                  Dirty := True;
                  Need_Redraw := True;
                  Local_Redraw := True;
               end if;
               Last_Blink_Tick := Current_Blink_Tick;

               loop
                  Active_PTY_Queue.all.Pop (Chunk, Has_Chunk);
                  exit when not Has_Chunk;
                  if Chunk.Length > 0 then
                     Terminal.Core.Feed
                       (Active_Core.all, Chunk.Data (1 .. Chunk.Length), Feed);
                     Last_Feed_Status := Feed;
                     Scroll_Offset :=
                       Terminal.App.Scrollback_View.Clamp_Offset
                         (Active_Core.all, Scroll_Offset);
                     Dirty := True;
                  end if;
               end loop;
               Apply_Title
                 (W,
                  Terminal.Core.Title (Active_Core.all),
                  Hovered_Link,
                  Has_Link_Activation,
                  Link_Activation,
                  Tabs,
                  Splits);
               declare
                  Clipboard_Ok : Boolean;
               begin
                  Apply_Clipboard_Request
                    (W,
                     Active_Runtime.all,
                     Clipboard_Targets,
                     Active_Core.all,
                     Clipboard_Ok,
                     Last_Write_Status,
                     Last_Clipboard_Target);
                  if not Clipboard_Ok then
                     GLFW_Vulkan.Windows.Set_Should_Close (W, True);
                  end if;
               end;

               while
                 Terminal.Core.Pending_Response_Length (Active_Core.all) > 0
               loop
                  Chunk := (others => <>);
                  Terminal.Core.Read_Response
                    (Active_Core.all, Chunk.Data, Chunk.Length);
                  if Chunk.Length > 0 then
                     Terminal.App.Session_Runtime.Write
                       (Active_Runtime.all, Chunk, Write_Stat);
                     Last_Write_Status := Write_Stat;
                     if Write_Stat /= Terminal.App.PTY_Write.Ok then
                        GLFW_Vulkan.Windows.Set_Should_Close (W, True);
                        exit;
                     end if;
                  end if;
               end loop;

               loop
                  In_Q.Pop (Event, Has_Event);
                  exit when not Has_Event;
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
                     if Write_Stat /= Terminal.App.PTY_Write.Ok then
                        GLFW_Vulkan.Windows.Set_Should_Close (W, True);
                     end if;
                  end if;
               end loop;

               GLFW_Vulkan.Windows.Framebuffer_Size (W, FB_Width, FB_Height);
               Terminal.App.Renderer.Set_Framebuffer_Size
                 (R, FB_Width, FB_Height);
               Configure_Active_Core;
               if FB_Width > 0 and then FB_Height > 0 then
                  declare
                     New_Rows : Positive;
                     New_Cols : Positive;
                     Core_Resize : Terminal.Core.Resize_Status;
                     PTY_Resize  : Terminal.PTY.Backend.Resize_Status;
                  begin
                     Terminal.App.Resize.Pixels_To_Cells
                       (FB_Width,
                        FB_Height,
                        Terminal.App.Renderer.Cell_Width (R),
                        Terminal.App.Renderer.Cell_Height (R),
                        Terminal.App.Renderer.Content_Margin,
                        New_Rows,
                        New_Cols);
                     if New_Rows /= Last_Rows or else New_Cols /= Last_Cols then
                        Terminal.App.Session_Runtime.Resize
                          (Active_Runtime.all,
                           New_Rows,
                           New_Cols,
                           Core_Resize,
                           PTY_Resize);
                        if Core_Resize = Terminal.Core.Ok
                          and then PTY_Resize = Terminal.PTY.Backend.Ok
                        then
                           Last_Rows := New_Rows;
                           Last_Cols := New_Cols;
                           Scroll_Offset :=
                             Terminal.App.Scrollback_View.Clamp_Offset
                               (Active_Core.all, Scroll_Offset);
                           Terminal.App.Selection.Clear (Selection);
                           Apply_Hovered_Link ((others => <>));
                           Dirty := True;
                           Need_Redraw := True;
                           Local_Redraw := True;
                        end if;
                     end if;
                  end;
               end if;

               declare
                  Render_Policy_Status : constant String :=
                    Terminal.App.Render_Policy.Status_Label
                      (Modes                => Terminal.Core.Modes (Active_Core.all),
                       Scrollback_Offset    => Scroll_Offset,
                       Selection_Active     =>
                         Terminal.App.Selection.Has_Selection (Selection),
                       Local_Redraw_Request => Local_Redraw);
                  --  Whether the input grace window is still open this frame; while
                  --  it is we present unconditionally (bypassing the defer policy)
                  --  so the compositor keeps waking us and input stays responsive.
                  Grace_Active : constant Boolean := Input_Grace > 0;
               begin
               if Input_Grace > 0 then
                  Input_Grace := Input_Grace - 1;
               end if;
               if Dirty
                 and then not Grace_Active
                 and then Terminal.App.Render_Policy.Should_Defer_Render
                   (Modes                => Terminal.Core.Modes (Active_Core.all),
                    Scrollback_Offset    => Scroll_Offset,
                    Selection_Active     =>
                      Terminal.App.Selection.Has_Selection (Selection),
                    Local_Redraw_Request => Local_Redraw)
               then
                  Need_Redraw := True;
               elsif Grace_Active
                 and then not Dirty
                 and then
                   Terminal.App.Vulkan_Presenter.Is_Initialized (Presenter)
               then
                  --  Input grace exists to keep presenting on the compositor's
                  --  frame clock.  The terminal state has not changed, so reuse
                  --  the existing renderer batch instead of rebuilding terminal
                  --  snapshots, image tiles, and Vulkan vertices 24 times.
                  declare
                     Present_Status :
                       Terminal.App.Vulkan_Presenter.Present_Status;
                  begin
                     Terminal.App.Renderer.Present_Retained
                       (R, Vk_Ctx, Presenter, Present_Status);
                     if Present_Status in
                       Terminal.App.Vulkan_Presenter.Swapchain_Out_Of_Date
                         | Terminal.App.Vulkan_Presenter.Device_Lost
                     then
                        Terminal.App.Vulkan_Presenter.Finalize (Presenter);
                        Terminal.App.Vulkan_Recovery.Begin_Recovery
                          (Vulkan_Recovery,
                           (if Present_Status =
                                 Terminal.App.Vulkan_Presenter.Device_Lost
                            then Terminal.App.Vulkan_Recovery.Device_Lost
                            else Terminal.App.Vulkan_Recovery
                              .Swapchain_Invalid),
                           Recovery_Tick);
                        Need_Redraw := True;
                     elsif Present_Status =
                       Terminal.App.Vulkan_Presenter.Resources_In_Flight
                     then
                        Need_Redraw := True;
                     end if;
                  end;
               elsif Dirty or else Grace_Active then
                  declare
                     Visible_Count : constant Positive :=
                       (if Terminal.App.Splits.Count (Splits) > 1
                        then Positive (Terminal.App.Splits.Count (Splits))
                        else 1);
                     Active_Render_Index : constant Positive :=
                       (if Terminal.App.Splits.Count (Splits) > 1
                        then Positive (Terminal.App.Splits.Active (Splits))
                        else 1);
                     Snaps : Terminal.App.Renderer.Snapshot_Array renames
                       Snapshot_Cache (1 .. Visible_Count);
                     Render_Status : Terminal.App.Renderer.Render_Status;
                     Present_Status : Terminal.App.Vulkan_Presenter.Present_Status;
                     Can_Present : Boolean := True;
                  begin
                     Resize_Visible_Runtimes;
                     for I in Snaps'Range loop
                        declare
                           Runtime : constant access
                             Terminal.App.Session_Runtime.Runtime :=
                               (if Visible_Count = 1
                                then Active_Runtime
                                else Terminal.App.Session_Table.Runtime_At
                                  (Sessions,
                                   Terminal.App.Sessions.Session_Index (I)));
                           Core : constant access Terminal.Core.Terminal :=
                             (if Runtime = null
                              then Active_Core
                              else Terminal.App.Session_Runtime.Core
                                (Runtime.all));
                        begin
                           if Runtime = null then
                              Terminal.App.Scrollback_View.Snapshot
                                (Active_Core.all, 0, Snaps (I));
                           else
                              Terminal.App.Scrollback_View.Snapshot
                                (Terminal.App.Session_Runtime.Core
                                   (Runtime.all).all,
                                 (if I = Active_Render_Index
                                  then Scroll_Offset
                                  else 0),
                                 Snaps (I));
                           end if;

                           --  Render the oldest unconsumed graphics command.
                           --  It is acknowledged only after a successful
                           --  presentation, so swapchain retries cannot lose
                           --  protocol events.
                           if I /= Active_Render_Index
                             or else Scroll_Offset = 0
                           then
                              Terminal.Core.Peek_Graphics_Event
                                (Core.all, Snaps (I).Graphics);
                              if Snaps (I).Graphics.Pending
                                and then Snaps (I).Graphics.Payload_Length >
                                  Snaps (I).Graphics.Preview_Length
                              then
                                 Terminal.App.Renderer.Stage_Graphics_Event
                                   (R,
                                    Snaps (I).Graphics,
                                    Terminal.Core.Graphics_Event_Payload
                                      (Core.all, Snaps (I).Graphics));
                              end if;
                           else
                              Snaps (I).Graphics := (others => <>);
                           end if;
                        end;
                     end loop;

                     Terminal.App.Selection.Apply_To_Snapshot
                       (Snaps (Active_Render_Index), Selection);
                     Blinking_Text_Active :=
                       Terminal.App.Text_Blink.Contains_Blinking_Text
                         (Snaps (Active_Render_Index));
                     for I in Snaps'Range loop
                        Terminal.App.Text_Blink.Apply
                          (Snaps (I), Current_Blink_Tick);
                        Terminal.App.Cursor_Blink.Apply
                          (Snaps (I), Current_Blink_Tick);
                     end loop;
                     if not Terminal.App.Vulkan_Presenter.Is_Initialized
                       (Presenter)
                     then
                        GLFW_Vulkan.Windows.Framebuffer_Size
                          (W, FB_Width, FB_Height);
                        if FB_Width > 0 and then FB_Height > 0 then
                           if not Terminal.App.Vulkan_Recovery.Is_Pending
                             (Vulkan_Recovery)
                           then
                              Terminal.App.Vulkan_Recovery.Begin_Recovery
                                (Vulkan_Recovery,
                                 Terminal.App.Vulkan_Recovery
                                   .Swapchain_Invalid,
                                 Recovery_Tick);
                           end if;
                           if Terminal.App.Vulkan_Recovery.Attempt_Due
                             (Vulkan_Recovery, Recovery_Tick)
                           then
                              Terminal.App.Vulkan_Presenter.Initialize
                                (P              => Presenter,
                                 Context        => Vk_Ctx,
                                 Status         => Presenter_Status,
                                 Desired_Width  => FB_Width,
                                 Desired_Height => FB_Height);
                              Terminal.App.Vulkan_Recovery.Record_Attempt
                                (Vulkan_Recovery,
                                 Recovery_Tick,
                                 Presenter_Status =
                                   Terminal.App.Vulkan_Presenter.Ok);
                              if Presenter_Status /=
                                Terminal.App.Vulkan_Presenter.Ok
                              then
                                 --  Creation routines clean their own partial
                                 --  work; Finalize also makes that guarantee
                                 --  explicit before the next retry.
                                 Terminal.App.Vulkan_Presenter.Finalize
                                   (Presenter);
                                 Present_Status :=
                                   Terminal.App.Vulkan_Presenter
                                     .Not_Initialized;
                                 Can_Present := False;
                              end if;
                           else
                              Present_Status :=
                                Terminal.App.Vulkan_Presenter.Not_Initialized;
                              Can_Present := False;
                           end if;
                        else
                           Present_Status :=
                             Terminal.App.Vulkan_Presenter.Swapchain_Out_Of_Date;
                           Can_Present := False;
                        end if;
                     end if;

                     if Can_Present then
                        Terminal.App.Renderer.Render_App
                          (R,
                           Snaps,
                           Active_Render_Index,
                           Terminal.App.Tabs.Snapshot (Tabs),
                           Terminal.App.Splits.Snapshot (Splits),
                           Render_Status);
                        if Render_Status = Terminal.App.Renderer.Ok then
                           Terminal.App.Renderer.Present
                             (R, Vk_Ctx, Presenter, Present_Status);
                        else
                           Present_Status := Terminal.App.Vulkan_Presenter.Invalid_Batch;
                        end if;
                     else
                        Render_Status := Terminal.App.Renderer.Not_Initialized;
                     end if;
                     if Present_Status in
                       Terminal.App.Vulkan_Presenter.Swapchain_Out_Of_Date
                         | Terminal.App.Vulkan_Presenter.Device_Lost
                     then
                        Terminal.App.Vulkan_Presenter.Finalize (Presenter);
                        Terminal.App.Vulkan_Recovery.Begin_Recovery
                          (Vulkan_Recovery,
                           (if Present_Status =
                                 Terminal.App.Vulkan_Presenter.Device_Lost
                            then Terminal.App.Vulkan_Recovery.Device_Lost
                            else Terminal.App.Vulkan_Recovery
                              .Swapchain_Invalid),
                           Recovery_Tick);
                        --  Keep terminal, PTY, image objects and the window
                        --  alive.  Reconstruction is attempted on subsequent
                        --  loop ticks with bounded backoff.
                        Need_Redraw := True;
                     end if;
                     declare
                        Grid_Status : constant String :=
                          Terminal.App.Resize.Grid_Status_Label
                            (FB_Width,
                             FB_Height,
                             Terminal.App.Renderer.Cell_Width (R),
                             Terminal.App.Renderer.Cell_Height (R),
                             Terminal.App.Renderer.Content_Margin);
                        Scrollback_Status : constant String :=
                          Terminal.App.Scrollback_View.Status_Label
                            (Active_Core.all, Scroll_Offset);
                        Selection_Status : constant String :=
                          Terminal.App.Selection.Status_Label (Selection);
                        Link_Status : constant String :=
                          Terminal.App.Hyperlinks.Status_Label (Hovered_Link);
                        Link_Activation_Status : constant String :=
                          Terminal.App.Hyperlinks.Activation_Status_Label
                            (if Has_Link_Activation
                             then Link_Activation
                             else Terminal.App.Hyperlinks.No_Link);
                        Clipboard_Status : constant String :=
                          Terminal.App.Clipboard_OSC52.Status_Label
                            (Last_Clipboard_Target);
                        Tab_Status : constant String :=
                          Terminal.App.Tabs.Status_Label (Tabs);
                        Split_Status : constant String :=
                          Terminal.App.Splits.Status_Label (Splits);
                        Config_Status : constant String :=
                          Terminal.App.Config.Status_Label (App_Config);
                        Profile_Status : constant String :=
                          Terminal.App.Profile_Status_Label
                            (Terminal.App.Profile);
                        Input_Status : constant String :=
                          Terminal.App.Input_Map.Input_Status_Label
                            (Terminal.Core.Modes (Active_Core.all));
                        Mouse_Status : constant String :=
                          Terminal.App.Input_Map.Mouse_Status_Label
                            (Terminal.Core.Modes (Active_Core.all));
                        Cursor_Status : constant String :=
                          Terminal.App.Cursor_Blink.Status_Label
                            (Snaps (Active_Render_Index).Cursor,
                             Current_Blink_Tick);
                        Text_Blink_Status : constant String :=
                          Terminal.App.Text_Blink.Status_Label
                            (Snaps (Active_Render_Index), Current_Blink_Tick);
                        Theme_Status : constant String :=
                          Terminal.App.Theme.Status_Label
                            (App_Config.Color_Theme);
                        Graphics_Header_Status : constant String :=
                          Terminal.App.Graphics.Header_Status_Label
                            (Snaps (Active_Render_Index).Graphics);
                        Graphics_Data_Status : constant String :=
                          Terminal.App.Graphics.Data_Status_Label
                            (Snaps (Active_Render_Index).Graphics);
                        Diag : constant Terminal.App.Diagnostics.Snapshot :=
                          Terminal.App.Diagnostics.Collect
                            (Active_Core.all,
                             Active_PTY_Queue.all,
                             In_Q,
                             R,
                             Presenter,
                             Last_Feed_Status,
                             Last_Write_Status,
                             Grid_Status,
                             Render_Policy_Status,
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
                             Runtime_Font_Status,
                             Runtime_PTY_Backend_Status,
                             Runtime_ConPTY_Status,
                             Runtime_Multiplexer_Status,
                             Graphics_Header_Status,
                             Graphics_Data_Status);
                     begin
                        Terminal.App.Diagnostics.Log_If_Changed (Diag);
                     end;
                     if Render_Status = Terminal.App.Renderer.Ok
                       and then
                         (Present_Status = Terminal.App.Vulkan_Presenter.Ok
                          or else Present_Status =
                            Terminal.App.Vulkan_Presenter.Validated_Not_Presented)
                     then
                        declare
                           More_Graphics : Boolean := False;
                        begin
                           for I in Snaps'Range loop
                              declare
                                 Runtime : constant access
                                   Terminal.App.Session_Runtime.Runtime :=
                                     (if Visible_Count = 1
                                      then Active_Runtime
                                      else Terminal.App.Session_Table.Runtime_At
                                        (Sessions,
                                         Terminal.App.Sessions.Session_Index
                                           (I)));
                                 Core : constant access Terminal.Core.Terminal :=
                                   (if Runtime = null
                                    then Active_Core
                                    else Terminal.App.Session_Runtime.Core
                                      (Runtime.all));
                                 Response_Runtime : constant access
                                   Terminal.App.Session_Runtime.Runtime :=
                                     (if Runtime = null
                                      then Active_Runtime
                                      else Runtime);
                              begin
                                 if (I /= Active_Render_Index
                                     or else Scroll_Offset = 0)
                                 then
                                    Terminal.Core.Complete_Graphics_Event
                                      (Core.all,
                                       Snaps (I).Graphics,
                                       Terminal.App.Renderer.Graphics_Result
                                         (R, Snaps (I).Graphics));
                                    while Terminal.Core.Pending_Response_Length
                                      (Core.all) > 0
                                    loop
                                       Chunk := (others => <>);
                                       Terminal.Core.Read_Response
                                         (Core.all,
                                          Chunk.Data,
                                          Chunk.Length);
                                       exit when Chunk.Length = 0;
                                       Terminal.App.Session_Runtime.Write
                                         (Response_Runtime.all,
                                          Chunk,
                                          Write_Stat);
                                       Last_Write_Status := Write_Stat;
                                       if Write_Stat /=
                                         Terminal.App.PTY_Write.Ok
                                       then
                                          GLFW_Vulkan.Windows.Set_Should_Close
                                            (W, True);
                                          exit;
                                       end if;
                                    end loop;
                                 end if;
                                 --  The active pane's graphics queue is
                                 --  intentionally suspended while displaying
                                 --  scrollback.  Do not turn that suspended
                                 --  work into an immediate redraw request: it
                                 --  would spin continuously without consuming
                                 --  the event.  Returning to the live view is
                                 --  itself a redraw request and resumes it.
                                 if I /= Active_Render_Index
                                   or else Scroll_Offset = 0
                                 then
                                    More_Graphics := More_Graphics
                                      or else
                                        Terminal.Core
                                          .Pending_Graphics_Event_Count
                                            (Core.all) > 0;
                                 end if;
                              end;
                           end loop;
                           Terminal.App.Renderer.Commit_Graphics_Events (R);
                           Need_Redraw := More_Graphics;
                        end;
                        Terminal.Core.Clear_Damage (Active_Core.all);
                     elsif Present_Status not in
                       Terminal.App.Vulkan_Presenter.Swapchain_Out_Of_Date
                         | Terminal.App.Vulkan_Presenter.Device_Lost
                         | Terminal.App.Vulkan_Presenter.Resources_In_Flight
                     then
                        Need_Redraw :=
                          Terminal.App.Vulkan_Recovery.Is_Pending
                            (Vulkan_Recovery);
                     elsif Present_Status =
                       Terminal.App.Vulkan_Presenter.Resources_In_Flight
                     then
                        --  A submitted frame still owns the shared descriptor
                        --  or vertex resources. Retry after its fence signals.
                        Need_Redraw := True;
                     end if;
                  end;
               end if;
               end;
            end;
      end loop;

      Input_Queue := null;
      for I in Snapshot_Cache'Range loop
         Terminal.Core.Release (Snapshot_Cache (I));
      end loop;
      Terminal.App.Session_Table.Close_All (Sessions);
      Terminal.App.Renderer.Finalize (R);
      Terminal.App.Vulkan_Presenter.Finalize (Presenter);
      Terminal.App.Vulkan_Context.Finalize (Vk_Ctx);
      GLFW_Vulkan.Windows.Destroy (W);
      GLFW_Vulkan.Finalize (Ctx);
   end Run;
end Terminal.App.Main_Loop;

separate (Terminal.App.Main_Loop)
procedure Run is
   subtype Runtime_Snapshot_Array is Terminal.App.Renderer.Snapshot_Array
     (1 .. Terminal.App.Sessions.Max_Sessions);
   type Runtime_Owners is limited record
      GLFW_Context : GLFW_Vulkan.Context;
      Window       : GLFW_Vulkan.Windows.Window;
      Renderer     : Terminal.App.Renderer.Renderer;
      Vulkan_Context : Terminal.App.Vulkan_Context.Context;
      Presenter    : Terminal.App.Vulkan_Presenter.Presenter;
      Sessions     : Terminal.App.Session_Table.Runtime_Table;
      Snapshots    : Runtime_Snapshot_Array;
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
   Vk_Status : Terminal.App.Vulkan_Context.Init_Status;
   Presenter_Status : Terminal.App.Vulkan_Presenter.Init_Status;
   Vulkan_Recovery : Terminal.App.Vulkan_Recovery.Controller;
   Recovery_Tick : Natural := 0;
   Renderer_Status : Terminal.App.Renderer.Init_Status;
   Theme_Status : Terminal.App.Renderer.Theme_Update_Status;
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

   procedure Configure_Core
     (Runtime : not null access Terminal.App.Session_Runtime.Runtime;
      Rows    : Positive;
      Cols    : Positive)
   is
      Core : constant not null access Terminal.Core.Terminal :=
        Terminal.App.Session_Runtime.Core (Runtime.all);
      Cell_Width : constant Positive := Terminal.App.Renderer.Cell_Width (R);
      Cell_Height : constant Positive := Terminal.App.Renderer.Cell_Height (R);
      Pixel_Width : constant Natural :=
        Natural'Min (Cols, Natural'Last / Cell_Width) * Cell_Width;
      Pixel_Height : constant Natural :=
        Natural'Min (Rows, Natural'Last / Cell_Height) * Cell_Height;
   begin
      Terminal.Core.Set_Graphics_Capabilities
        (Core.all,
         Terminal.App.Core_Graphics_Profile
           (App_Config.Kitty_File_Transfer,
            App_Config.Kitty_Temporary_Transfer,
            App_Config.Kitty_Shared_Memory,
            App_Config.ITerm2_File_Downloads));
      Terminal.Core.Set_Graphics_Resource_Limits
        (Core.all,
         (Transaction_Length => App_Config.Graphics_Transaction_Bytes,
          Pending_Events => App_Config.Graphics_Pending_Events,
          Pending_Bytes => App_Config.Graphics_Pending_Bytes,
          Deferred_Input_Bytes =>
            App_Config.Graphics_Deferred_Input_Bytes,
          Pixel_Dimension => App_Config.Graphics_Pixel_Dimension));
      Terminal.Core.Set_Cell_Pixel_Size
        (Core.all, Cell_Width, Cell_Height);
      Terminal.Core.Set_Window_Pixel_Size
        (Core.all, Pixel_Width, Pixel_Height);
   end Configure_Core;

   procedure Configure_Visible_Cores is
   begin
      if Terminal.App.Splits.Count (Splits) <= 1 then
         Configure_Core (Active_Runtime, Last_Rows, Last_Cols);
      else
         declare
            Layout : constant Terminal.App.Splits.Pane_Layout :=
              Terminal.App.Splits.Layout (Splits, Last_Rows, Last_Cols);
         begin
            for I in 1 .. Layout.Count loop
               declare
                  Runtime : constant access Terminal.App.Session_Runtime.Runtime :=
                    Terminal.App.Session_Table.Runtime_At
                      (Sessions, Terminal.App.Sessions.Session_Index (I));
               begin
                  if Runtime /= null
                    and then Layout.Rects (I).Rows > 0
                    and then Layout.Rects (I).Cols > 0
                  then
                     Configure_Core
                       (Runtime,
                        Positive (Layout.Rects (I).Rows),
                        Positive (Layout.Rects (I).Cols));
                  end if;
               end;
            end loop;
         end;
      end if;
   end Configure_Visible_Cores;

   function Active_PTY_Queue
     return access Terminal.App.Queues.PTY_Output_Queue is
   begin
      return Terminal.App.Session_Runtime.PTY_Queue (Active_Runtime.all);
   end Active_PTY_Queue;

   procedure Resize_Visible_Runtimes
     (Target_Rows : Positive;
      Target_Cols : Positive;
      Success     : out Boolean)
   is
   begin
      Success := True;
      if Terminal.App.Splits.Count (Splits) <= 1 then
         declare
            Core_Resize : Terminal.Core.Resize_Status;
            PTY_Resize  : Terminal.PTY.Backend.Resize_Status;
         begin
            Terminal.App.Session_Runtime.Resize
              (Active_Runtime.all,
               Target_Rows,
               Target_Cols,
               Core_Resize,
               PTY_Resize);
            if Core_Resize /= Terminal.Core.Ok
              or else PTY_Resize /= Terminal.PTY.Backend.Ok
            then
               Success := False;
               Need_Redraw := True;
            else
               Configure_Core
                 (Active_Runtime, Target_Rows, Target_Cols);
            end if;
         end;
      else
         declare
            Layout : constant Terminal.App.Splits.Pane_Layout :=
              Terminal.App.Splits.Layout
                (Splits, Target_Rows, Target_Cols);
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
                     if Core_Resize /= Terminal.Core.Ok
                       or else PTY_Resize /= Terminal.PTY.Backend.Ok
                     then
                        Success := False;
                        Need_Redraw := True;
                     else
                        Configure_Core
                          (Runtime,
                           Positive (Layout.Rects (I).Rows),
                           Positive (Layout.Rects (I).Cols));
                     end if;
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
   end Copy_Selection;

   procedure Release_Snapshot_Cache is
   begin
      for I in Snapshot_Cache'Range loop
         begin
            Terminal.Core.Release (Snapshot_Cache (I));
         exception
            when others =>
               Terminal.App.Cleanup_Diagnostics.Note_Failure
                 (Terminal.App.Cleanup_Diagnostics.Snapshot_Cache);
         end;
      end loop;
   end Release_Snapshot_Cache;

   procedure Shutdown is
   begin
      Input_Queue := null;
      --  Cached snapshots borrow session-owned screen storage.  Release
      --  every cache entry before closing those sessions, and keep cleanup
      --  progressing if one damaged snapshot raises during unwinding.
      Release_Snapshot_Cache;
      if Sessions_Ready then
         begin
            Terminal.App.Session_Table.Close_All (Sessions);
            Sessions_Ready := False;
         exception
            when others =>
               Terminal.App.Cleanup_Diagnostics.Note_Failure
                 (Terminal.App.Cleanup_Diagnostics.Session_Table);
         end;
      end if;
      --  Preserve the native dependency order: renderer, device/swapchain,
      --  surface/instance, window, then GLFW.  Each owner is idempotent and
      --  controlled, but explicit cleanup here keeps the window alive until
      --  Vulkan has released the surface during exception propagation.
      Terminal.App.Renderer.Finalize (R);
      Terminal.App.Vulkan_Presenter.Finalize (Presenter);
      Terminal.App.Vulkan_Context.Finalize (Vk_Ctx);
      if Window_Ready then
         begin
            GLFW_Vulkan.Windows.Destroy (W);
            Window_Ready := False;
         exception
            when others =>
               Terminal.App.Cleanup_Diagnostics.Note_Failure
                 (Terminal.App.Cleanup_Diagnostics.GLFW_Window);
         end;
      end if;
      if GLFW_Ready and then not Window_Ready then
         begin
            GLFW_Vulkan.Finalize (Ctx);
            GLFW_Ready := False;
         exception
            when others =>
               Terminal.App.Cleanup_Diagnostics.Note_Failure
                 (Terminal.App.Cleanup_Diagnostics.GLFW_Context);
         end;
      end if;
   end Shutdown;

   procedure Run_Frame is separate;
begin
   Terminal.App.Vulkan_Recovery.Initialize (Vulkan_Recovery);
   GLFW_Vulkan.Initialize (Ctx, Init_Status);
   if Init_Status /= GLFW_Vulkan.Ok then
      Terminal.App.Diagnostics.Log_Startup_Failure
        ("glfw", GLFW_Vulkan.Init_Status'Image (Init_Status));
      return;
   end if;
   GLFW_Ready := True;

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
      Shutdown;
      return;
   end if;
   Window_Ready := True;

   Terminal.App.Vulkan_Context.Initialize (Vk_Ctx, W, Vk_Status);
   if Vk_Status /= Terminal.App.Vulkan_Context.Ok then
      Terminal.App.Diagnostics.Log_Startup_Failure
        ("vulkan-context",
         Terminal.App.Vulkan_Context.Init_Status'Image (Vk_Status));
      Shutdown;
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
      Shutdown;
      return;
   end if;

   Terminal.App.Renderer.Initialize (R, Vk_Ctx, Renderer_Status);
   if Renderer_Status /= Terminal.App.Renderer.Ok then
      Terminal.App.Diagnostics.Log_Startup_Failure
        ("renderer",
         Terminal.App.Renderer.Init_Status'Image (Renderer_Status));
      Shutdown;
      return;
   end if;
   Terminal.App.Renderer.Set_Theme
     (R, Terminal.App.Config.Active_Theme (App_Config), Theme_Status);
   if Theme_Status /= Terminal.App.Renderer.Theme_Ok then
      Terminal.App.Diagnostics.Log_Startup_Failure
        ("theme", Terminal.App.Renderer.Theme_Update_Status'Image
           (Theme_Status));
   end if;
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
       Theme_Transaction_Bytes => App_Config.Graphics_Image_Bytes * 4,
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
      Shutdown;
      return;
   end if;
   Sessions_Ready := True;

   Configure_Visible_Cores;

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
      Run_Frame;
   end loop;

   Shutdown;
exception
   when others =>
      Shutdown;
      raise;
end Run;

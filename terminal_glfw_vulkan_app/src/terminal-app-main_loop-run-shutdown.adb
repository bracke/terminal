separate (Terminal.App.Main_Loop.Run)
procedure Shutdown is
   Cleanup_Result : Terminal.App.PTY_Cleanup_Lifecycle.Shutdown_Result;
   Recording_Status : Terminal.App.Session_Recording.IO_Status;
begin
   Terminal.App.Control_Server.Stop (Control);
   Terminal.App.Global_Hotkey.Unregister;
   Terminal.App.Platform_IME.Finalize;
   if Window_Ready then
      Terminal.App.File_Drop.Finalize (GLFW_Vulkan.Windows.Native_Handle (W));
   end if;
   Terminal.App.Accessibility.Finalize (Accessibility);
   if Terminal.App.Session_Recording.Active (Recording) then
      Terminal.App.Session_Recording.Stop (Recording, Recording_Status);
      if Recording_Status /= Terminal.App.Session_Recording.Ok then
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Session_Table,
            "stop session recording");
      end if;
   end if;
   begin
      Save_Workspace;
   exception
      when E : others =>
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Session_Table,
            E,
            "save workspace");
   end;
   begin
      Scoped_Input.Detach (Input_Binding);
   exception
      when E : others =>
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.GLFW_Window,
            E,
            "detach GLFW input callbacks");
   end;
   --  Cached snapshots own their copied screen storage. Release every cache
   --  entry before sessions so shutdown sheds the large allocation early.
   Release_Snapshot_Cache;
   if Sessions_Ready then
      begin
         Terminal.App.Session_Table.Close_All (Sessions);
         Sessions_Ready := False;
      exception
         when E : others =>
            Terminal.App.Cleanup_Diagnostics.Note_Failure
              (Terminal.App.Cleanup_Diagnostics.Session_Table,
               E,
               "close session table");
      end;
   end if;
   --  Close_All deliberately retains partially closed runtimes. The lifecycle
   --  boundary records that state instead of claiming a global cleanup barrier.
   Terminal.App.PTY_Cleanup_Lifecycle.Shutdown
     (Timeout_Milliseconds => 5_000,
      Result               => Cleanup_Result);
   if not Terminal.App.PTY_Cleanup_Lifecycle.Complete (Cleanup_Result) then
      --  A finalizer may have published work at the first deadline. Give the
      --  application barrier and native queue one bounded follow-up pass before
      --  tearing down their remaining dependencies.
      Terminal.App.PTY_Cleanup_Lifecycle.Shutdown
        (Timeout_Milliseconds => 1_000,
         Result               => Cleanup_Result);
      if not Terminal.App.PTY_Cleanup_Lifecycle.Complete (Cleanup_Result) then
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Cleanup_Lifecycle,
            "cleanup lifecycle remained incomplete after bounded retry");
      end if;
   end if;
   --  Preserve native dependency order: renderer, device/swapchain,
   --  surface/instance, window, then GLFW.
   Terminal.App.Renderer.Finalize (R);
   Terminal.App.Vulkan_Presenter.Finalize (Presenter);
   Terminal.App.Vulkan_Context.Finalize (Vk_Ctx);
   if Window_Ready then
      begin
         GLFW_Vulkan.Windows.Destroy (W);
         Window_Ready := False;
      exception
         when E : others =>
            Terminal.App.Cleanup_Diagnostics.Note_Failure
              (Terminal.App.Cleanup_Diagnostics.GLFW_Window,
               E,
               "destroy GLFW window");
      end;
   end if;
   if GLFW_Ready and then not Window_Ready then
      begin
         GLFW_Vulkan.Finalize (Ctx);
         GLFW_Ready := False;
      exception
         when E : others =>
            Terminal.App.Cleanup_Diagnostics.Note_Failure
              (Terminal.App.Cleanup_Diagnostics.GLFW_Context,
               E,
               "finalize GLFW context");
      end;
   end if;
end Shutdown;

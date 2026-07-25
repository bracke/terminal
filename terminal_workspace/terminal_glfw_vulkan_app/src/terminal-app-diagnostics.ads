with Terminal.Core;
with Terminal.App.Queues;
with Terminal.App.Renderer;
with Terminal.App.Vulkan_Presenter;

package Terminal.App.Diagnostics is
   type Snapshot is record
      Core          : Terminal.Core.Diagnostic_Snapshot;
      PTY_Overflows : Natural := 0;
      Input_Overflows : Natural := 0;
      Renderer      : Terminal.App.Renderer.Renderer_Diagnostics;
      Presenter     : Terminal.App.Vulkan_Presenter.Diagnostic_Snapshot;
   end record;

   function Collect
     (Core     : Terminal.Core.Terminal;
      PTY      : Terminal.App.Queues.PTY_Output_Queue;
      Input    : Terminal.App.Queues.Input_Event_Queue;
      Renderer : Terminal.App.Renderer.Renderer;
      Presenter : Terminal.App.Vulkan_Presenter.Presenter)
      return Snapshot;

   procedure Log_Startup_Failure
     (Stage  : String;
      Status : String);

   procedure Log_If_Changed (S : Snapshot);
end Terminal.App.Diagnostics;

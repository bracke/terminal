separate (Terminal.App.Main_Loop.Run.Run_Frame)
procedure Log_Frame_Diagnostics
  (Current_Core    : Terminal.Core.Terminal;
   PTY_Queue       : Terminal.App.Queues.PTY_Output_Queue;
   Input_Queue     : Terminal.App.Queues.Input_Event_Queue;
   Renderer_State  : Terminal.App.Renderer.Renderer;
   Presenter_State : Terminal.App.Vulkan_Presenter.Presenter;
   Feed_Status     : Terminal.Core.Feed_Status;
   Write_Status    : Terminal.App.PTY_Write.Write_All_Status;
   Statuses        : Terminal.App.Diagnostics.Runtime_Statuses)
is
begin
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

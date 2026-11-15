separate (Terminal.App.Main_Loop.Run.Run_Frame)
procedure Log_Frame_Diagnostics
  (Current_Core    : Terminal.App.Session_Runtime.Core_Borrow;
   PTY_Queue       : Terminal.App.Session_Runtime.PTY_Queue_Borrow;
   Input_Queue     : Terminal.App.Queues.Input_Event_Queue;
   Renderer_State  : Terminal.App.Renderer.Renderer;
   Presenter_State : Terminal.App.Vulkan_Presenter.Presenter;
   Feed_Status     : Terminal.Core.Feed_Status;
   Write_Status    : Terminal.App.PTY_Write.Write_All_Status;
   Statuses        : Terminal.App.Diagnostics.Runtime_Statuses)
is
   procedure Read_Core (Core : in out Terminal.Core.Terminal) is
      procedure Read_Queue
        (Queue : in out Terminal.App.Queues.PTY_Output_Queue) is
      begin
         Terminal.App.Diagnostics.Log_If_Changed
           (Terminal.App.Diagnostics.Collect
              (Core,
               Queue,
               Input_Queue,
               Renderer_State,
               Presenter_State,
               Feed_Status,
               Write_Status,
               Statuses));
      end Read_Queue;
   begin
      Terminal.App.Session_Runtime.With_PTY_Queue
        (PTY_Queue, Read_Queue'Access);
   end Read_Core;
begin
   Terminal.App.Session_Runtime.With_Core (Current_Core, Read_Core'Access);
end Log_Frame_Diagnostics;

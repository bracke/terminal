separate (Terminal.App.Main_Loop.Run.Run_Frame)
procedure Complete_Frame_Graphics
  (Snaps               : Terminal.App.Renderer.Snapshot_Array;
   Active_Render_Index : Positive;
   Render_Status       : Terminal.App.Renderer.Render_Status;
   Present_Status      : Terminal.App.Vulkan_Presenter.Present_Status;
   Runtime_Table       : Terminal.App.Session_Table.Runtime_Table;
   Current_Runtime     : not null access
     Terminal.App.Session_Runtime.Runtime;
   Current_Core        : not null access Terminal.Core.Terminal;
   Scrollback_Offset   : Natural;
   Renderer_State      : in out Terminal.App.Renderer.Renderer;
   Window              : in out GLFW_Vulkan.Windows.Window;
   Last_Write          : in out Terminal.App.PTY_Write.Write_All_Status;
   Redraw              : in out Boolean;
   Recovery            : Terminal.App.Vulkan_Recovery.Controller)
is
begin
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
               Runtime : constant access Terminal.App.Session_Runtime.Runtime :=
                 (if Snaps'Length = 1
                  then Current_Runtime
                  else Terminal.App.Session_Table.Runtime_At
                    (Runtime_Table,
                     Terminal.App.Sessions.Session_Index (I)));
               Core : constant access Terminal.Core.Terminal :=
                 (if Runtime = null
                  then Current_Core
                  else Terminal.App.Session_Runtime.Core (Runtime.all));
               Response_Runtime : constant access
                 Terminal.App.Session_Runtime.Runtime :=
                   (if Runtime = null then Current_Runtime else Runtime);
               Chunk : Terminal.App.Queues.Byte_Chunk;
               Write_Status : Terminal.App.PTY_Write.Write_All_Status;
            begin
               if I /= Active_Render_Index or else Scrollback_Offset = 0 then
                  Terminal.Core.Complete_Graphics_Event
                    (Core.all,
                     Snaps (I).Graphics,
                     Terminal.App.Renderer.Graphics_Result
                       (Renderer_State, Snaps (I).Graphics));
                  while not Terminal.App.Session_Runtime.Has_Pending_Write
                    (Response_Runtime.all)
                    and then Terminal.Core.Pending_Response_Length (Core.all) > 0
                  loop
                     Chunk := (others => <>);
                     Terminal.Core.Read_Response
                       (Core.all, Chunk.Data, Chunk.Length);
                     exit when Chunk.Length = 0;
                     Terminal.App.Session_Runtime.Write
                       (Response_Runtime.all, Chunk, Write_Status);
                     Last_Write := Write_Status;
                     if Write_Status in
                       Terminal.App.PTY_Write.Failed
                         | Terminal.App.PTY_Write.Session_Closed
                     then
                        if Terminal.App.Session_Table.Count (Runtime_Table) = 1
                        then
                           GLFW_Vulkan.Windows.Set_Should_Close (Window, True);
                        end if;
                        exit;
                     elsif Write_Status = Terminal.App.PTY_Write.Incomplete then
                        exit;
                     end if;
                  end loop;
                  More_Graphics := More_Graphics
                    or else Terminal.Core.Pending_Graphics_Event_Count
                      (Core.all) > 0;
               end if;
            end;
         end loop;
         Terminal.App.Renderer.Commit_Graphics_Events (Renderer_State);
         Redraw := More_Graphics;
      end;
      Terminal.Core.Clear_Damage (Current_Core.all);
   elsif Present_Status not in
     Terminal.App.Vulkan_Presenter.Swapchain_Out_Of_Date
       | Terminal.App.Vulkan_Presenter.Device_Lost
       | Terminal.App.Vulkan_Presenter.Resources_In_Flight
   then
      Redraw := Terminal.App.Vulkan_Recovery.Is_Pending (Recovery);
   elsif Present_Status = Terminal.App.Vulkan_Presenter.Resources_In_Flight then
      Redraw := True;
   end if;
end Complete_Frame_Graphics;

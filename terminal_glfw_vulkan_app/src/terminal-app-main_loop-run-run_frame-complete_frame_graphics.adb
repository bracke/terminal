separate (Terminal.App.Main_Loop.Run.Run_Frame)
procedure Complete_Frame_Graphics
  (Snaps               : Terminal.App.Renderer.Snapshot_Array;
   Active_Render_Index : Positive;
   Render_Status       : Terminal.App.Renderer.Render_Status;
   Present_Status      : Terminal.App.Vulkan_Presenter.Present_Status)
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
                  then Active_Runtime
                  else Terminal.App.Session_Table.Runtime_At
                    (Sessions, Terminal.App.Sessions.Session_Index (I)));
               Core : constant access Terminal.Core.Terminal :=
                 (if Runtime = null
                  then Active_Core
                  else Terminal.App.Session_Runtime.Core (Runtime.all));
               Response_Runtime : constant access
                 Terminal.App.Session_Runtime.Runtime :=
                   (if Runtime = null then Active_Runtime else Runtime);
            begin
               if I /= Active_Render_Index or else Scroll_Offset = 0 then
                  Terminal.Core.Complete_Graphics_Event
                    (Core.all,
                     Snaps (I).Graphics,
                     Terminal.App.Renderer.Graphics_Result
                       (R, Snaps (I).Graphics));
                  while not Terminal.App.Session_Runtime.Has_Pending_Write
                    (Response_Runtime.all)
                    and then Terminal.Core.Pending_Response_Length (Core.all) > 0
                  loop
                     Chunk := (others => <>);
                     Terminal.Core.Read_Response
                       (Core.all, Chunk.Data, Chunk.Length);
                     exit when Chunk.Length = 0;
                     Terminal.App.Session_Runtime.Write
                       (Response_Runtime.all, Chunk, Write_Stat);
                     Last_Write_Status := Write_Stat;
                     if Fatal_Write (Write_Stat) then
                        if Terminal.App.Session_Table.Count (Sessions) = 1 then
                           GLFW_Vulkan.Windows.Set_Should_Close (W, True);
                        end if;
                        exit;
                     elsif Write_Stat = Terminal.App.PTY_Write.Incomplete then
                        exit;
                     end if;
                  end loop;
                  More_Graphics := More_Graphics
                    or else Terminal.Core.Pending_Graphics_Event_Count
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
        Terminal.App.Vulkan_Recovery.Is_Pending (Vulkan_Recovery);
   elsif Present_Status = Terminal.App.Vulkan_Presenter.Resources_In_Flight then
      Need_Redraw := True;
   end if;
end Complete_Frame_Graphics;

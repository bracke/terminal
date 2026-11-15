separate (Terminal.App.Main_Loop.Run.Run_Frame)
procedure Complete_Frame_Graphics
  (Snaps               : Terminal.App.Renderer.Snapshot_Array;
   Active_Render_Index : Positive;
   Runtime_Table       : aliased in out
     Terminal.App.Session_Table.Runtime_Table;
   Scrollback_Offset   : Natural;
   Renderer_State      : in out Terminal.App.Renderer.Renderer;
   Decision            : Terminal.App.Frame_Completion.Decision;
   Result              : in out Frame_Completion_Result)
is
begin
   if Decision.Accept_Graphics then
      declare
         More_Graphics : Boolean := False;
      begin
         for I in Snaps'Range loop
            declare
               Runtime_Borrow : constant
                 Terminal.App.Session_Table.Runtime_Borrow :=
                 (if Snaps'Length = 1
                  then Terminal.App.Session_Table.Active_Runtime (Runtime_Table)
                  else Terminal.App.Session_Table.Runtime_At
                    (Runtime_Table,
                     Terminal.App.Sessions.Session_Index (I)));
               Core : constant Terminal.App.Session_Runtime.Core_Borrow :=
                 Terminal.App.Session_Table.Core (Runtime_Borrow);
               procedure Process_Runtime
                 (Response_Runtime : in out
                    Terminal.App.Session_Runtime.Runtime) is
                  Chunk : Terminal.App.Queues.Byte_Chunk;
                  Write_Status : Terminal.App.PTY_Write.Write_All_Status;
                  procedure Process_Core
                    (Item : in out Terminal.Core.Terminal) is
                  begin
               if I /= Active_Render_Index or else Scrollback_Offset = 0 then
                  Terminal.Core.Complete_Graphics_Event
                    (Item, Snaps (I).Graphics,
                     Terminal.App.Renderer.Graphics.Result
                       (Renderer_State, Snaps (I).Graphics));
                  while not Terminal.App.Session_Runtime.Has_Pending_Write
                    (Response_Runtime)
                    and then Terminal.Core.Pending_Response_Length
                      (Item) > 0
                  loop
                     Chunk := (others => <>);
                     Terminal.Core.Read_Response
                       (Item, Chunk.Data, Chunk.Length);
                     exit when Chunk.Length = 0;
                     Terminal.App.Session_Runtime.Write
                       (Response_Runtime, Chunk, Write_Status);
                     Result.Write_Attempted := True;
                     Result.Write_Status := Write_Status;
                     if Write_Status in
                       Terminal.App.PTY_Write.Failed
                         | Terminal.App.PTY_Write.Session_Closed
                     then
                        if Terminal.App.Session_Table.Count (Runtime_Table) = 1
                        then
                           Result.Close_Window := True;
                        end if;
                        exit;
                     elsif Write_Status = Terminal.App.PTY_Write.Incomplete then
                        exit;
                     end if;
                  end loop;
                  More_Graphics := More_Graphics
                    or else Terminal.Core.Pending_Graphics_Event_Count
                      (Item) > 0;
               end if;
               Terminal.Core.Clear_Damage (Item);
                  end Process_Core;
               begin
                  Terminal.App.Session_Runtime.With_Core
                    (Core, Process_Core'Access);
               end Process_Runtime;
            begin
               Terminal.App.Session_Table.With_Runtime
                 (Runtime_Borrow, Process_Runtime'Access);
            end;
         end loop;
         Terminal.App.Renderer.Graphics.Commit_Visible_Events (Renderer_State);
         Result.Redraw := More_Graphics;
      end;
   else
      Result.Redraw := Decision.Redraw;
      Result.Close_Window := Result.Close_Window or Decision.Close_Window;
   end if;
end Complete_Frame_Graphics;

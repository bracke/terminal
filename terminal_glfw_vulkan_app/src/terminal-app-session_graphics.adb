with Terminal.App.Queues;
with Terminal.App.Session_Runtime;
with Terminal.App.Sessions;
with Terminal.App.Tabs;
with Terminal.Core;

package body Terminal.App.Session_Graphics is
   use type Terminal.App.PTY_Write.Write_All_Status;
   use type Terminal.App.Renderer.Render_Status;

   function Fatal
     (Status : Terminal.App.PTY_Write.Write_All_Status) return Boolean is
     (Status in
        Terminal.App.PTY_Write.Failed | Terminal.App.PTY_Write.Session_Closed);

   procedure Process_Hidden
     (Table         : in out Terminal.App.Session_Table.Runtime_Table;
      Splits        : Terminal.App.Splits.Split_State;
      Renderer      : in out Terminal.App.Renderer.Renderer;
      Processed     : out Boolean;
      Render_Status : out Terminal.App.Renderer.Render_Status;
      Write_Status  : out Terminal.App.PTY_Write.Write_All_Status)
   is
      Dummy_Tabs   : Terminal.App.Tabs.Tab_State;
      Dummy_Splits : Terminal.App.Splits.Split_State;
   begin
      Processed := False;
      Render_Status := Terminal.App.Renderer.Ok;
      Write_Status := Terminal.App.PTY_Write.Ok;
      Terminal.App.Tabs.Initialize (Dummy_Tabs);
      Terminal.App.Splits.Initialize (Dummy_Splits);

      for I in 1 .. Terminal.App.Session_Table.Count (Table) loop
         declare
            Index : constant Terminal.App.Sessions.Session_Index :=
              Terminal.App.Sessions.Session_Index (I);
            Visible : constant Boolean :=
              (if Terminal.App.Splits.Count (Splits) > 1
               then I <= Terminal.App.Splits.Count (Splits)
               else Index = Terminal.App.Session_Table.Active (Table));
            Runtime : constant access Terminal.App.Session_Runtime.Runtime :=
              Terminal.App.Session_Table.Runtime_At (Table, Index);
         begin
            if not Visible and then Runtime /= null then
               declare
                  Core : constant access Terminal.Core.Terminal :=
                    Terminal.App.Session_Runtime.Core (Runtime.all);
                  Snapshots : Terminal.App.Renderer.Snapshot_Array (1 .. 1);
                  Event : Terminal.Core.Graphics_Event;
                  Status : Terminal.App.Renderer.Render_Status;
                  Current_Write : Terminal.App.PTY_Write.Write_All_Status;
                  Chunk : Terminal.App.Queues.Byte_Chunk;
               begin
                  if Core /= null
                    and then Terminal.Core.Pending_Graphics_Event_Count
                      (Core.all) > 0
                  then
                     Snapshots (1) := Terminal.Core.Snapshot (Core.all);
                     Terminal.Core.Peek_Graphics_Event (Core.all, Event);
                     Snapshots (1).Graphics := Event;
                     if Event.Pending
                       and then Event.Payload_Length > Event.Preview_Length
                     then
                        Terminal.App.Renderer.Stage_Graphics_Event
                          (Renderer,
                           Event,
                           Terminal.Core.Graphics_Event_Payload
                             (Core.all, Event));
                     end if;
                     Terminal.App.Renderer.Render_App
                       (Renderer,
                        Snapshots,
                        1,
                        Terminal.App.Tabs.Snapshot (Dummy_Tabs),
                        Terminal.App.Splits.Snapshot (Dummy_Splits),
                        Status);
                     Terminal.Core.Release (Snapshots (1));

                     if Status = Terminal.App.Renderer.Ok
                       or else Terminal.App.Renderer.Graphics_Event_Processed
                         (Renderer, Event)
                     then
                        --  Batch allocation may fail after the protocol
                        --  operation has committed its object-store changes.
                        --  In that case the remembered result is authoritative
                        --  and prevents replaying the mutation.
                        Terminal.Core.Complete_Graphics_Event
                          (Core.all,
                           Event,
                           Terminal.App.Renderer.Graphics_Result
                             (Renderer, Event));
                        Terminal.App.Renderer.Commit_Offscreen_Graphics_Events
                          (Renderer);
                        Processed := True;
                     else
                        Terminal.App.Renderer.Commit_Offscreen_Graphics_Events
                          (Renderer);
                        Render_Status := Status;
                        return;
                     end if;

                     while not Terminal.App.Session_Runtime.Has_Pending_Write
                       (Runtime.all)
                       and then Terminal.Core.Pending_Response_Length
                         (Core.all) > 0
                     loop
                        Chunk := (others => <>);
                        Terminal.Core.Read_Response
                          (Core.all, Chunk.Data, Chunk.Length);
                        exit when Chunk.Length = 0;
                        Terminal.App.Session_Runtime.Write
                          (Runtime.all, Chunk, Current_Write);
                        if Fatal (Current_Write) then
                           Write_Status := Current_Write;
                           return;
                        elsif Current_Write = Terminal.App.PTY_Write.Incomplete
                        then
                           Write_Status := Current_Write;
                           exit;
                        end if;
                     end loop;
                  end if;
               exception
                  when others =>
                     Terminal.Core.Release (Snapshots (1));
                     raise;
               end;
            end if;
         end;
      end loop;
   end Process_Hidden;
end Terminal.App.Session_Graphics;

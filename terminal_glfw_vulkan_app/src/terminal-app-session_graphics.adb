with Terminal.Core.Snapshot_Editing;
with Terminal.App.Queues;
with Terminal.App.Renderer.Graphics;
with Terminal.App.Renderer.Layout;
with Terminal.App.Session_Runtime;
with Terminal.App.Sessions;
with Terminal.App.Splits;
with Terminal.App.Tabs;
with Terminal.Core;

package body Terminal.App.Session_Graphics is
   use type Terminal.App.PTY_Write.Write_All_Status;
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.App.Renderer.Graphics.Stage_Event_Status;

   function Fatal
     (Status : Terminal.App.PTY_Write.Write_All_Status) return Boolean is
     (Status in
        Terminal.App.PTY_Write.Failed | Terminal.App.PTY_Write.Session_Closed);

   procedure Process_Hidden
     (Table         : aliased in out
        Terminal.App.Session_Table.Runtime_Table;
      Renderer      : in out Terminal.App.Renderer.Renderer;
      Processed     : out Boolean;
      Render_Status : out Terminal.App.Renderer.Render_Status;
      Write_Status  : out Terminal.App.PTY_Write.Write_All_Status)
   is
      Dummy_Tabs   : Terminal.App.Tabs.Tab_State;
      Dummy_Splits : Terminal.App.Splits.Split_State;
      Splits : constant Terminal.App.Splits.Split_State :=
        Terminal.App.Session_Table.Splits (Table);
      Stop_Processing : Boolean := False;
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
            Runtime_Borrow : constant
              Terminal.App.Session_Table.Runtime_Borrow :=
              Terminal.App.Session_Table.Runtime_At (Table, Index);
            Core : constant Terminal.App.Session_Runtime.Core_Borrow :=
              Terminal.App.Session_Table.Core (Runtime_Borrow);
            procedure Process_Runtime
              (Runtime : in out Terminal.App.Session_Runtime.Runtime) is
               Snapshots : Terminal.App.Renderer.Snapshot_Array (1 .. 1);
               Event : Terminal.Core.Graphics_Event;
               Status : Terminal.App.Renderer.Render_Status;
               Current_Write : Terminal.App.PTY_Write.Write_All_Status;
               Chunk : Terminal.App.Queues.Byte_Chunk;
               Stage_Status :
                 Terminal.App.Renderer.Graphics.Stage_Event_Status;
               Completed_Before_Render : Boolean := False;
               procedure Process_Core (Item : in out Terminal.Core.Terminal) is
               begin
                  if Terminal.Core.Pending_Graphics_Event_Count
                      (Item) > 0
                  then
                     Terminal.Core.Snapshot (Item, Snapshots (1));
                     Terminal.Core.Peek_Graphics_Event (Item, Event);
                     Terminal.Core.Snapshot_Editing.Set_Graphics
                       (Snapshots (1), Event);
                     if Event.Pending
                       and then Event.Payload_Length > Event.Preview_Length
                     then
                        Stage_Status :=
                          Terminal.App.Renderer.Graphics.Stage_Event
                          (Renderer,
                           Item,
                           Event);
                        if Stage_Status =
                          Terminal.App.Renderer.Graphics.Stage_Allocation_Failed
                        then
                           Terminal.Core.Release (Snapshots (1));
                           Render_Status :=
                             Terminal.App.Renderer.Allocation_Failed;
                           Stop_Processing := True;
                           return;
                        elsif Stage_Status =
                          Terminal.App.Renderer.Graphics.Stage_Quota_Exceeded
                        then
                           --  This event cannot fit while the renderer keeps
                           --  other presentation-retry state.  Retire it as a
                           --  bounded-resource failure rather than retrying
                           --  the same impossible staging operation forever.
                           Terminal.Core.Complete_Graphics_Event
                             (Item, Event,
                              Terminal.App.Renderer.Graphics.Rejection_Result
                                (Event, Terminal.Core.Graphics_ENOSPC));
                           Terminal.Core.Snapshot_Editing.Set_Graphics
                             (Snapshots (1), (others => <>));
                           Completed_Before_Render := True;
                        elsif Stage_Status =
                          Terminal.App.Renderer.Graphics.Stage_Invalid_Event
                        then
                           Terminal.Core.Complete_Graphics_Event
                             (Item, Event,
                              Terminal.App.Renderer.Graphics.Rejection_Result
                                (Event, Terminal.Core.Graphics_EINVAL));
                           Terminal.Core.Snapshot_Editing.Set_Graphics
                             (Snapshots (1), (others => <>));
                           Completed_Before_Render := True;
                        end if;
                     end if;
                     Terminal.App.Renderer.Layout.Render_App
                       (Renderer,
                        Snapshots,
                        1,
                        Terminal.App.Tabs.Snapshot (Dummy_Tabs),
                        Terminal.App.Splits.Snapshot (Dummy_Splits),
                        Status);
                     Terminal.Core.Release (Snapshots (1));

                     if Status = Terminal.App.Renderer.Ok
                       or else Terminal.App.Renderer.Graphics.Event_Processed
                         (Renderer, Event)
                     then
                        --  Batch allocation may fail after the protocol
                        --  operation has committed its object-store changes.
                        --  In that case the remembered result is authoritative
                        --  and prevents replaying the mutation.
                        if not Completed_Before_Render then
                           Terminal.Core.Complete_Graphics_Event
                             (Item, Event,
                              Terminal.App.Renderer.Graphics.Result
                                (Renderer, Event));
                        end if;
                        Terminal.App.Renderer.Graphics.Commit_Offscreen_Event
                          (Renderer, Event);
                        Processed := True;
                     else
                        Terminal.App.Renderer.Graphics.Commit_Offscreen_Event
                          (Renderer, Event);
                        Render_Status := Status;
                        Stop_Processing := True;
                        return;
                     end if;

                     while not Terminal.App.Session_Runtime.Has_Pending_Write
                       (Runtime)
                       and then Terminal.Core.Pending_Response_Length
                         (Item) > 0
                     loop
                        Chunk := (others => <>);
                        Terminal.Core.Read_Response
                          (Item, Chunk.Data, Chunk.Length);
                        exit when Chunk.Length = 0;
                        Terminal.App.Session_Runtime.Write
                          (Runtime, Chunk, Current_Write);
                        if Fatal (Current_Write) then
                           Write_Status := Current_Write;
                           Stop_Processing := True;
                           return;
                        elsif Current_Write = Terminal.App.PTY_Write.Incomplete
                        then
                           Write_Status := Current_Write;
                           exit;
                        end if;
                     end loop;
                  end if;
               end Process_Core;
            begin
               Terminal.App.Session_Runtime.With_Core
                 (Core, Process_Core'Access);
            exception
               when others =>
                  Terminal.Core.Release (Snapshots (1));
                  raise;
            end Process_Runtime;
         begin
            if not Visible then
               Terminal.App.Session_Table.With_Runtime
                 (Runtime_Borrow, Process_Runtime'Access);
               if Stop_Processing then
                  return;
               end if;
            end if;
         end;
      end loop;
   end Process_Hidden;
end Terminal.App.Session_Graphics;

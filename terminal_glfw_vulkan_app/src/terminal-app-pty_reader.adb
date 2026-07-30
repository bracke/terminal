with Terminal.Common.Bytes;

with GLFW_Vulkan.Events;

package body Terminal.App.PTY_Reader is
   task body Reader is
      Chunk  : Terminal.App.Queues.Byte_Chunk;
      Last   : Natural;
      Status : Terminal.PTY.Backend.Read_Status;
      Done   : Boolean := False;
   begin
      while not Done loop
         select
            accept Stop do
               Done := True;
            end Stop;
         else
            null;
         end select;

         exit when Done;

         Terminal.PTY.Backend.Read (Session.all, Chunk.Data, Last, Status);
         case Status is
            when Terminal.PTY.Backend.Ok =>
               Chunk.Length := Last;
               Queue.Push (Chunk);
               --  Wake the main loop from its idle sleep so freshly read output
               --  is fed and drawn without waiting out the event timeout.
               GLFW_Vulkan.Events.Post_Empty_Event;
            when Terminal.PTY.Backend.End_Of_File | Terminal.PTY.Backend.Session_Closed =>
               exit;
            when others =>
               delay 0.01;
         end case;
      end loop;
   end Reader;
end Terminal.App.PTY_Reader;

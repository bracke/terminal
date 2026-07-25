with Terminal.Common.Bytes;

package body Terminal.App.PTY_Reader is
   task body Reader is
      Chunk  : Terminal.App.Queues.Byte_Chunk;
      Last   : Natural;
      Status : Terminal.PTY.POSIX.Read_Status;
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

         Terminal.PTY.POSIX.Read (Session.all, Chunk.Data, Last, Status);
         case Status is
            when Terminal.PTY.POSIX.Ok =>
               Chunk.Length := Last;
               Queue.Push (Chunk);
            when Terminal.PTY.POSIX.End_Of_File | Terminal.PTY.POSIX.Session_Closed =>
               exit;
            when others =>
               delay 0.01;
         end case;
      end loop;
   end Reader;
end Terminal.App.PTY_Reader;

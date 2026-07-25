with Terminal.App.Queues;
with Terminal.PTY.POSIX;

package Terminal.App.PTY_Write is
   Max_Write_Attempts : constant := 64;

   type Write_All_Status is
     (Ok,
      Incomplete,
      Failed,
      Session_Closed);

   procedure Write_All
     (S      : in out Terminal.PTY.POSIX.Session;
      Chunk  : Terminal.App.Queues.Byte_Chunk;
      Status : out Write_All_Status);
end Terminal.App.PTY_Write;

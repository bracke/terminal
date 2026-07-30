with Terminal.App.Queues;
with Terminal.PTY.Backend;

package Terminal.App.PTY_Write is
   Max_Write_Attempts : constant := 64;
   Max_Status_Label_Length : constant := 64;

   type Write_All_Status is
     (Ok,
      Incomplete,
      Failed,
      Session_Closed);

   function Status_Label (Status : Write_All_Status) return String;

   procedure Write_All
     (S      : in out Terminal.PTY.Backend.Session;
      Chunk  : Terminal.App.Queues.Byte_Chunk;
      Status : out Write_All_Status);
end Terminal.App.PTY_Write;

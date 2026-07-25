package body Terminal.App.PTY_Write is
   use type Terminal.PTY.POSIX.Write_Status;

   procedure Write_All
     (S      : in out Terminal.PTY.POSIX.Session;
      Chunk  : Terminal.App.Queues.Byte_Chunk;
      Status : out Write_All_Status)
   is
      Offset : Positive := 1;
      Last   : Natural := 0;
      W      : Terminal.PTY.POSIX.Write_Status;
   begin
      if Chunk.Length = 0 then
         Status := Ok;
         return;
      end if;

      for Attempt in 1 .. Max_Write_Attempts loop
         exit when Offset > Chunk.Length;

         Terminal.PTY.POSIX.Write
           (S, Chunk.Data (Offset .. Chunk.Length), Last, W);

         case W is
            when Terminal.PTY.POSIX.Ok | Terminal.PTY.POSIX.Partial =>
               if Last > 0 then
                  Offset := Offset + Last;
               else
                  delay 0.001;
               end if;
            when Terminal.PTY.POSIX.Interrupted =>
               null;
            when Terminal.PTY.POSIX.Session_Closed =>
               Status := Session_Closed;
               return;
            when Terminal.PTY.POSIX.Failed =>
               Status := Failed;
               return;
         end case;
      end loop;

      Status := (if Offset > Chunk.Length then Ok else Incomplete);
   end Write_All;
end Terminal.App.PTY_Write;

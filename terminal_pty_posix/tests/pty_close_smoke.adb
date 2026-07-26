with AUnit.Assertions;

with Terminal.Common.Bytes;
with Terminal.PTY.POSIX;

procedure PTY_Close_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.PTY.POSIX.Exit_State;
   use type Terminal.PTY.POSIX.Read_Status;
   use type Terminal.PTY.POSIX.Spawn_Status;

   S            : Terminal.PTY.POSIX.Session;
   Spawn_Status : Terminal.PTY.POSIX.Spawn_Status;
   Buffer       : Byte_Array (1 .. 16);
   Last         : Natural := 0;
   Read_Status  : Terminal.PTY.POSIX.Read_Status;
begin
   Terminal.PTY.POSIX.Spawn_Default_Shell (S, 24, 80, Spawn_Status);
   Assert (Spawn_Status = Terminal.PTY.POSIX.Ok, "pty spawn failed");
   Assert (Terminal.PTY.POSIX.Is_Alive (S), "spawned shell should be alive");

   Terminal.PTY.POSIX.Close (S);

   Assert
     (not Terminal.PTY.POSIX.Is_Alive (S),
      "close should leave child process non-alive");
   Assert
     (Terminal.PTY.POSIX.Child_State (S)
      in Terminal.PTY.POSIX.Exited | Terminal.PTY.POSIX.Signaled,
      "closed child should have a terminal exit state");

   Terminal.PTY.POSIX.Read (S, Buffer, Last, Read_Status);
   Assert (Read_Status = Terminal.PTY.POSIX.Session_Closed, "closed read");
   Assert (Last = 0, "closed read should return no bytes");
end PTY_Close_Smoke;

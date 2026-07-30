with AUnit.Assertions;

with Terminal.Common.Bytes;
with Terminal.PTY.Backend;

procedure PTY_Close_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.PTY.Backend.Exit_State;
   use type Terminal.PTY.Backend.Read_Status;
   use type Terminal.PTY.Backend.Spawn_Status;

   S            : Terminal.PTY.Backend.Session;
   Spawn_Status : Terminal.PTY.Backend.Spawn_Status;
   Buffer       : Byte_Array (1 .. 16);
   Last         : Natural := 0;
   Read_Status  : Terminal.PTY.Backend.Read_Status;
begin
   Terminal.PTY.Backend.Spawn_Default_Shell (S, 24, 80, Spawn_Status);
   Assert (Spawn_Status = Terminal.PTY.Backend.Ok, "pty spawn failed");
   Assert (Terminal.PTY.Backend.Is_Alive (S), "spawned shell should be alive");

   Terminal.PTY.Backend.Close (S);

   Assert
     (not Terminal.PTY.Backend.Is_Alive (S),
      "close should leave child process non-alive");
   Assert
     (Terminal.PTY.Backend.Child_State (S)
      in Terminal.PTY.Backend.Exited | Terminal.PTY.Backend.Signaled,
      "closed child should have a terminal exit state");

   Terminal.PTY.Backend.Read (S, Buffer, Last, Read_Status);
   Assert (Read_Status = Terminal.PTY.Backend.Session_Closed, "closed read");
   Assert (Last = 0, "closed read should return no bytes");
end PTY_Close_Smoke;

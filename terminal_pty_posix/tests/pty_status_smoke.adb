with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.PTY.POSIX;

procedure PTY_Status_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.PTY.POSIX.Read_Status;
   use type Terminal.PTY.POSIX.Resize_Status;
   use type Terminal.PTY.POSIX.Write_Status;

   S : Terminal.PTY.POSIX.Session;
   Buffer : Byte_Array (1 .. 16);
   Last : Natural;
   R_Status : Terminal.PTY.POSIX.Read_Status;
   W_Status : Terminal.PTY.POSIX.Write_Status;
   Z_Status : Terminal.PTY.POSIX.Resize_Status;
begin
   Terminal.PTY.POSIX.Read (S, Buffer, Last, R_Status);
   Assert (R_Status = Terminal.PTY.POSIX.Session_Closed, "closed read status");
   Assert (Last = 0, "closed read last");

   Terminal.PTY.POSIX.Write (S, (1 => 16#0D#), Last, W_Status);
   Assert (W_Status = Terminal.PTY.POSIX.Session_Closed, "closed write status");
   Assert (Last = 0, "closed write last");

   Terminal.PTY.POSIX.Resize (S, 24, 80, Z_Status);
   Assert (Z_Status = Terminal.PTY.POSIX.Session_Closed, "closed resize status");
end PTY_Status_Smoke;


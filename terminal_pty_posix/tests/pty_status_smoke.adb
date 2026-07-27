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
   Caps : constant Terminal.PTY.POSIX.Backend_Capabilities :=
     Terminal.PTY.POSIX.Capabilities;
begin
   Assert (Caps.POSIX_PTY, "POSIX PTY capability");
   Assert (not Caps.Windows_ConPTY, "ConPTY should not be provided by POSIX backend");
   Assert (Caps.Resize, "PTY resize capability");
   Assert (Caps.Terminal_Env, "terminal environment capability");
   Assert (Caps.Nonblocking_Read, "nonblocking read capability");
   Assert
     (Terminal.PTY.POSIX.Backend_Status_Label (Caps) =
      "POSIX PTY backend with resize, env, and nonblocking read",
      "PTY backend status label");
   Assert
     (Terminal.PTY.POSIX.Backend_Status_Label (Caps)'Length <=
      Terminal.PTY.POSIX.Max_Status_Label_Length,
      "PTY backend status label should be bounded");
   Assert
     (Terminal.PTY.POSIX.ConPTY_Status_Label (Caps) =
      "Windows ConPTY unsupported by POSIX PTY backend",
      "ConPTY status label");
   Assert
     (Terminal.PTY.POSIX.ConPTY_Status_Label (Caps)'Length <=
      Terminal.PTY.POSIX.Max_Status_Label_Length,
      "ConPTY status label should be bounded");

   Terminal.PTY.POSIX.Read (S, Buffer, Last, R_Status);
   Assert (R_Status = Terminal.PTY.POSIX.Session_Closed, "closed read status");
   Assert (Last = 0, "closed read last");

   Terminal.PTY.POSIX.Write (S, (1 => 16#0D#), Last, W_Status);
   Assert (W_Status = Terminal.PTY.POSIX.Session_Closed, "closed write status");
   Assert (Last = 0, "closed write last");

   Terminal.PTY.POSIX.Resize (S, 24, 80, Z_Status);
   Assert (Z_Status = Terminal.PTY.POSIX.Session_Closed, "closed resize status");
end PTY_Status_Smoke;

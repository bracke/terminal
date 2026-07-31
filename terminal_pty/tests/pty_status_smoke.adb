with Ada.Text_IO;
with AUnit.Assertions;
with Terminal.Common.Bytes;
with Terminal.PTY.Backend;

procedure PTY_Status_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.PTY.Backend.Read_Status;
   use type Terminal.PTY.Backend.Resize_Status;
   use type Terminal.PTY.Backend.Write_Status;

   S : Terminal.PTY.Backend.Session;
   Buffer : Byte_Array (1 .. 16);
   Last : Natural;
   R_Status : Terminal.PTY.Backend.Read_Status;
   W_Status : Terminal.PTY.Backend.Write_Status;
   Z_Status : Terminal.PTY.Backend.Resize_Status;
   Caps : constant Terminal.PTY.Backend.Backend_Capabilities :=
     Terminal.PTY.Backend.Capabilities;

   --  Exactly one of the two backends answers on any host, and which one is the
   --  first thing worth asserting: everything below reads differently depending
   --  on it.
   On_Windows : constant Boolean := Caps.Windows_ConPTY;

   Failures : Natural := 0;

   --  Every check is named and reported, rather than the first one raising:
   --  an assertion message is lost when AUnit's exception goes uncaught, so a
   --  failure would otherwise say only that something in here is wrong.
   procedure Check (Condition : Boolean; Label : String) is
   begin
      if not Condition then
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line ("pty_status_smoke: FAILED " & Label);
      end if;
   end Check;
begin
   Ada.Text_IO.Put_Line
     ("pty_status_smoke: posix=" & Boolean'Image (Caps.POSIX_PTY)
      & " conpty=" & Boolean'Image (Caps.Windows_ConPTY)
      & " resize=" & Boolean'Image (Caps.Resize)
      & " env=" & Boolean'Image (Caps.Terminal_Env)
      & " nonblocking=" & Boolean'Image (Caps.Nonblocking_Read));
   Ada.Text_IO.Put_Line
     ("pty_status_smoke: backend=[" &
      Terminal.PTY.Backend.Backend_Status_Label (Caps) & "] conpty=[" &
      Terminal.PTY.Backend.ConPTY_Status_Label (Caps) & "]");

   Check (Caps.POSIX_PTY xor Caps.Windows_ConPTY,
           "exactly one PTY backend should be in use");
   Check (Caps.Resize, "PTY resize capability");
   Check (Caps.Terminal_Env, "terminal environment capability");
   Check (Caps.Nonblocking_Read, "nonblocking read capability");
   Check
     (Terminal.PTY.Backend.Backend_Status_Label (Caps) =
      (if On_Windows
       then "Windows ConPTY backend with resize, env, and nonblocking read"
       else "POSIX PTY backend with resize, env, and nonblocking read"),
      "PTY backend status label");
   Check
     (Terminal.PTY.Backend.Backend_Status_Label (Caps)'Length <=
      Terminal.PTY.Backend.Max_Status_Label_Length,
      "PTY backend status label should be bounded");
   Check
     (Terminal.PTY.Backend.ConPTY_Status_Label (Caps) =
      (if On_Windows
       then "Windows ConPTY supported"
       else "Windows ConPTY unsupported by POSIX PTY backend"),
      "ConPTY status label");
   Check
     (Terminal.PTY.Backend.ConPTY_Status_Label (Caps)'Length <=
      Terminal.PTY.Backend.Max_Status_Label_Length,
      "ConPTY status label should be bounded");

   Terminal.PTY.Backend.Read (S, Buffer, Last, R_Status);
   Check (R_Status = Terminal.PTY.Backend.Session_Closed, "closed read status");
   Check (Last = 0, "closed read last");

   Terminal.PTY.Backend.Write (S, (1 => 16#0D#), Last, W_Status);
   Check (W_Status = Terminal.PTY.Backend.Session_Closed, "closed write status");
   Check (Last = 0, "closed write last");

   Terminal.PTY.Backend.Resize (S, 24, 80, Z_Status);
   Check (Z_Status = Terminal.PTY.Backend.Session_Closed, "closed resize status");
   Assert (Failures = 0,
           "capability smoke had" & Natural'Image (Failures) & " failures");
end PTY_Status_Smoke;

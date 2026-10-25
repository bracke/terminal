with Ada.Text_IO;
with AUnit.Assertions;

with Terminal.Common.Bytes;
with Terminal.PTY.Backend;

procedure PTY_Close_Smoke is
   use Terminal.Common.Bytes;
   use type Terminal.PTY.Backend.Exit_State;
   use type Terminal.PTY.Backend.Read_Status;
   use type Terminal.PTY.Backend.Spawn_Status;
   use type Terminal.PTY.Backend.Write_Status;

   --  AUnit's Assert outside a test case raises with no word of what
   --  failed; say it on standard error first, so a CI log names the check.
   procedure Assert (Condition : Boolean; Message : String);

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "FAILED: " & Message);
         AUnit.Assertions.Assert (False, Message);
      end if;
   end Assert;

   --  The backend spawns sh on POSIX and cmd.exe on Windows. A line ends in
   --  CR for both: cmd under a pseudo-console runs a line on CR alone, and
   --  the POSIX tty turns CR into the newline sh waits for.
   On_Windows : constant Boolean :=
     Terminal.PTY.Backend.Capabilities.Windows_ConPTY;

   S            : Terminal.PTY.Backend.Session;
   Spawn_Status : Terminal.PTY.Backend.Spawn_Status;
   Buffer       : Byte_Array (1 .. 16);
   Last         : Natural := 0;
   Read_Status  : Terminal.PTY.Backend.Read_Status;
   Write_Status : Terminal.PTY.Backend.Write_Status;

   procedure Send (Text : String) is
      Data : Byte_Array (1 .. Text'Length);
      Sent : Natural;
      Offset : Positive := 1;
   begin
      for I in Text'Range loop
         Data (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      while Offset <= Data'Last loop
         Terminal.PTY.Backend.Write
           (S, Data (Offset .. Data'Last), Sent, Write_Status);
         Assert
           (Write_Status in
              Terminal.PTY.Backend.Ok | Terminal.PTY.Backend.Partial
                | Terminal.PTY.Backend.Interrupted,
            "write command to child");
         if Sent > 0 then
            Offset := Offset + Sent;
         else
            delay 0.01;
         end if;
      end loop;
   end Send;

   --  A shell that sets up its line editor can throw away what was typed
   --  before it was ready, as zsh does on macOS; so wait for it to say
   --  something, its prompt or banner, and for that to settle.
   procedure Wait_For_Output is
      Quiet : Natural := 0;
      Heard : Boolean := False;
   begin
      for Attempt in 1 .. 1000 loop
         Terminal.PTY.Backend.Read (S, Buffer, Last, Read_Status);
         if Read_Status = Terminal.PTY.Backend.Ok and then Last >= Buffer'First then
            Heard := True;
            Quiet := 0;
         else
            exit when Read_Status not in
              Terminal.PTY.Backend.Would_Block | Terminal.PTY.Backend.Interrupted;
            Quiet := Quiet + 1;
            exit when Heard and then Quiet >= 20;
            delay 0.01;
         end if;
      end loop;
   end Wait_For_Output;
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

   Terminal.PTY.Backend.Spawn_Default_Shell (S, 24, 80, Spawn_Status);
   Assert (Spawn_Status = Terminal.PTY.Backend.Ok, "exit-status spawn failed");
   Wait_For_Output;
   Send ("exit 7" & ASCII.CR);
   --  Keep reading the echo while waiting: a BSD tty, as on macOS, holds
   --  a closing child until what it wrote has been drained.
   for Attempt in 1 .. 500 loop
      exit when not Terminal.PTY.Backend.Is_Alive (S);
      Terminal.PTY.Backend.Read (S, Buffer, Last, Read_Status);
      delay 0.01;
   end loop;
   Assert (not Terminal.PTY.Backend.Is_Alive (S), "exited shell is detected");
   Assert
     (Terminal.PTY.Backend.Child_State (S) = Terminal.PTY.Backend.Exited,
      "Is_Alive preserves the reaped child state");
   Assert
     (Terminal.PTY.Backend.Child_Status (S) /= 0,
      "Is_Alive preserves the reaped child status");
   --  A pseudo-console keeps its output pipe open until the console itself
   --  is closed, so only a POSIX slave reports the end of file on its own.
   if not On_Windows then
      for Attempt in 1 .. 100 loop
         Terminal.PTY.Backend.Read (S, Buffer, Last, Read_Status);
         exit when Read_Status = Terminal.PTY.Backend.End_Of_File;
         delay 0.01;
      end loop;
      Assert
        (Read_Status = Terminal.PTY.Backend.End_Of_File,
         "closed PTY slave reports end of file");
   end if;
   Terminal.PTY.Backend.Close (S);
   Assert
     (Terminal.PTY.Backend.Child_State (S) = Terminal.PTY.Backend.Exited,
      "close preserves an observed normal exit");

   Terminal.PTY.Backend.Spawn_Default_Shell (S, 24, 80, Spawn_Status);
   Assert (Spawn_Status = Terminal.PTY.Backend.Ok, "stubborn-shell spawn failed");
   --  cmd has no hangup to ignore; Close still has to end it.
   if not On_Windows then
      Wait_For_Output;
      Send ("trap '' HUP; while :; do sleep 1; done" & ASCII.CR);
   end if;
   delay 0.05;
   Terminal.PTY.Backend.Close (S);
   Assert
     (not Terminal.PTY.Backend.Is_Alive (S),
      "close must terminate a child that ignores hangup");
   Assert
     (Terminal.PTY.Backend.Child_State (S) in
        Terminal.PTY.Backend.Exited | Terminal.PTY.Backend.Signaled,
      "forced close records a terminal child state");
end PTY_Close_Smoke;

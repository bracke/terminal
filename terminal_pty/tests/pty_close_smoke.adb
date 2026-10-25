with Ada.Text_IO;
with AUnit.Assertions;

with Terminal.Common.Bytes;
with Terminal.PTY.Backend;

procedure PTY_Close_Smoke is
   use AUnit.Assertions;
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
   Send ("exit 7" & ASCII.LF);
   for Attempt in 1 .. 100 loop
      exit when not Terminal.PTY.Backend.Is_Alive (S);
      delay 0.01;
   end loop;
   Assert (not Terminal.PTY.Backend.Is_Alive (S), "exited shell is detected");
   Assert
     (Terminal.PTY.Backend.Child_State (S) = Terminal.PTY.Backend.Exited,
      "Is_Alive preserves the reaped child state");
   Assert
     (Terminal.PTY.Backend.Child_Status (S) /= 0,
      "Is_Alive preserves the reaped child status");
   for Attempt in 1 .. 100 loop
      Terminal.PTY.Backend.Read (S, Buffer, Last, Read_Status);
      exit when Read_Status = Terminal.PTY.Backend.End_Of_File;
      delay 0.01;
   end loop;
   Assert
     (Read_Status = Terminal.PTY.Backend.End_Of_File,
      "closed PTY slave reports end of file");
   Terminal.PTY.Backend.Close (S);
   Assert
     (Terminal.PTY.Backend.Child_State (S) = Terminal.PTY.Backend.Exited,
      "close preserves an observed normal exit");

   Terminal.PTY.Backend.Spawn_Default_Shell (S, 24, 80, Spawn_Status);
   Assert (Spawn_Status = Terminal.PTY.Backend.Ok, "stubborn-shell spawn failed");
   Send ("trap '' HUP; while :; do sleep 1; done" & ASCII.LF);
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

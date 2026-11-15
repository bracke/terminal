with Ada.Real_Time;
with AUnit.Assertions;

with Terminal.App.PTY_Write;
with Terminal.App.Cleanup_Diagnostics;
with Terminal.App.PTY_Cleanup_Lifecycle.Testing;
with Terminal.App.Queues;
with Terminal.App.Session_Runtime;
with Terminal.Common.Bytes;
with Terminal.PTY.Backend;

procedure Session_Shutdown_Smoke is
   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;
   use type Terminal.App.PTY_Write.Write_All_Status;
   use type Terminal.App.Session_Runtime.Runtime_Status;
   use type Terminal.App.Session_Runtime.Start_Status;

   package Runtime renames Terminal.App.Session_Runtime;

   R : aliased Runtime.Runtime;
   Start_Status : Runtime.Start_Status;
   Write_Status : Terminal.App.PTY_Write.Write_All_Status;
   On_Windows : constant Boolean :=
     Terminal.PTY.Backend.Capabilities.Windows_ConPTY;
   Command : constant String :=
     (if On_Windows
      then "for /L %i in (1,1,20000) do @echo 0123456789abcdef" & ASCII.CR
      else "i=0; while [ $i -lt 20000 ]; do echo 0123456789abcdef; "
           & "i=$((i+1)); done" & ASCII.CR);

   function Chunk_From_String
     (Text : String) return Terminal.App.Queues.Byte_Chunk
   is
      Result : Terminal.App.Queues.Byte_Chunk := (others => <>);
   begin
      Result.Length := Text'Length;
      for I in Text'Range loop
         Result.Data (I - Text'First + 1) :=
           Terminal.Common.Bytes.Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end Chunk_From_String;

   function Output_Queue_Full return Boolean is
      Full : Boolean := False;

      procedure Inspect
        (Item : in out Terminal.App.Queues.PTY_Output_Queue) is
      begin
         Full := Item.Length = Terminal.App.Queues.Max_Chunks;
      end Inspect;

      Borrow : Runtime.PTY_Queue_Borrow := Runtime.PTY_Queue (R);
   begin
      Runtime.With_PTY_Queue (Borrow, Inspect'Access);
      return Full;
   end Output_Queue_Full;
begin
   Runtime.Start (R, 24, 80, 100, Start_Status);
   AUnit.Assertions.Assert
     (Start_Status = Runtime.Ok, "shutdown fixture must start");

   --  Let the shell initialize, then produce more than the bounded output
   --  queue can retain.
   delay 0.20;
   Runtime.Write (R, Chunk_From_String (Command), Write_Status);
   AUnit.Assertions.Assert
     (Write_Status = Terminal.App.PTY_Write.Ok,
      "shutdown fixture command must be written");

   declare
      Deadline : constant Ada.Real_Time.Time :=
        Ada.Real_Time.Clock + Ada.Real_Time.Seconds (10);
   begin
      loop
         exit when Output_Queue_Full or else Ada.Real_Time.Clock >= Deadline;
         delay 0.01;
      end loop;
      AUnit.Assertions.Assert
        (Output_Queue_Full,
         "shutdown fixture must block the reader on a full output queue");
   end;

   declare
      Started : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
   begin
      Runtime.Close (R);
      AUnit.Assertions.Assert
        (Ada.Real_Time.Clock - Started < Ada.Real_Time.Seconds (5),
         "session shutdown must not wait on a blocked reader or ConPTY drain");
   end;
   AUnit.Assertions.Assert
     (Runtime.State (R) = Runtime.Closed,
      "session shutdown must release reader and backend resources");

   declare
      Before : constant Natural :=
        Terminal.App.Cleanup_Diagnostics.Capture.Counts
          (Terminal.App.Cleanup_Diagnostics.PTY_Backend);
      After : Natural;
   begin
      Terminal.App.PTY_Cleanup_Lifecycle.Testing
        .Verify_Backend_After_App_Failure;
      Terminal.App.PTY_Cleanup_Lifecycle.Testing
        .Exercise_Incomplete_Shutdown;
      After := Terminal.App.Cleanup_Diagnostics.Capture.Counts
        (Terminal.App.Cleanup_Diagnostics.PTY_Backend);
      AUnit.Assertions.Assert
        (After > Before or else Before = Natural'Last,
         "incomplete PTY cleanup must enter application diagnostics");
   end;
exception
   when others =>
      Runtime.Close (R);
      raise;
end Session_Shutdown_Smoke;

with Ada.Text_IO;

with AUnit.Assertions;
with Interfaces;

with Terminal.Common.Bytes;
with Terminal.PTY.Backend.Testing;

procedure PTY_Windows_Lifecycle_Smoke is
   package Testing renames Terminal.PTY.Backend.Testing;
   use type Terminal.PTY.Backend.Exit_State;
   use type Terminal.PTY.Backend.Spawn_Status;
   use type Terminal.PTY.Backend.Write_Status;

   Baseline_Failures : Natural;
   Cleanup_Complete  : Boolean;

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "FAILED: " & Message);
         AUnit.Assertions.Assert (False, Message);
      end if;
   end Assert;
begin
   Assert
     (Testing.Signed_Exit_Status (16#C000_013A#) = -1_073_741_510,
      "high-bit Windows exit status must be reinterpreted as signed");
   Assert
     (Testing.Signed_Exit_Status (Interfaces.Unsigned_32'Last) = -1,
      "all-one-bits Windows exit status must be -1");
   Assert
     (not Testing.Needs_Deletion (Testing.Not_Allocated),
      "an absent attribute list must not be deleted");
   Assert
     (not Testing.Needs_Deletion (Testing.Allocated),
      "an uninitialized attribute buffer must not be deleted");
   Assert
     (Testing.Needs_Deletion (Testing.Initialized),
      "an initialized attribute list must be deleted");

   if Terminal.PTY.Backend.Capabilities.Windows_ConPTY then
      Baseline_Failures := Testing.Cleanup_Failure_Count;
      Assert
        (Testing.Exercise_Failed_Reaper,
         "failed process termination must be handed to the bounded reaper");
      Assert
        (Testing.Exercise_Reader_Handoff,
         "reader context and output pipe must transfer as one owner");
      Terminal.PTY.Backend.Drain_Deferred_Cleanup
        (Timeout_Milliseconds => 10_000,
         Complete             => Cleanup_Complete);
      Assert (Cleanup_Complete,
              "bounded deferred cleanup must drain after transient failure");
      Assert
        (Terminal.PTY.Backend.Deferred_Cleanup_Pending = 0,
         "drained cleanup must have no pending owners");
      Assert
        (Terminal.PTY.Backend.Deferred_Cleanup_Quarantined = 0,
         "drained cleanup must have no quarantined owners");
      Assert
        (Testing.Active_Cleanup_Workers = 0,
         "drained cleanup must have no active workers");
      Assert
        (Testing.Cleanup_Failure_Count = Baseline_Failures,
         "transient cleanup retries must not count as terminal failures");
      Assert
        (Testing.Exercise_Cleanup_Fault_Injection,
         "allocation and queue failures must preserve cleanup ownership");
      Assert
        (Testing.Cleanup_Failure_Count > Baseline_Failures,
         "exhausted cleanup allocation must increment diagnostics");
      Baseline_Failures := Testing.Cleanup_Failure_Count;
      Assert
        (Testing.Enter_Quarantine_Batch,
         "persistent cleanup failures must enter quarantine");
      Assert
        (Terminal.PTY.Backend.Deferred_Cleanup_Quarantined > 0,
         "quarantine count must expose its retained owner");
      Terminal.PTY.Backend.Drain_Deferred_Cleanup
        (Timeout_Milliseconds => 0,
         Complete             => Cleanup_Complete);
      Assert
        (not Cleanup_Complete,
         "zero-timeout drain must report retained cleanup work");
      Testing.Reset_Drain_Worker_High_Water;
      Assert
        (Testing.Release_Quarantine,
         "quarantined cleanup fixtures must become releasable");
      Terminal.PTY.Backend.Drain_Deferred_Cleanup
        (Timeout_Milliseconds => 10_000,
         Complete             => Cleanup_Complete);
      Assert (Cleanup_Complete,
              "released quarantine must drain completely");
      Assert
        (Terminal.PTY.Backend.Deferred_Cleanup_Pending = 0
         and then Terminal.PTY.Backend.Deferred_Cleanup_Quarantined = 0,
         "released quarantine must relinquish every owner");
      Assert
        (Testing.Active_Cleanup_Workers = 0,
         "quarantine drain must wait for every worker to exit");
      Assert
        (Testing.Drain_Worker_High_Water in 1 .. 4,
         "quarantine drain must admit at most four retry workers");
      Assert
        (Testing.Cleanup_Failure_Count > Baseline_Failures,
         "quarantine must count one terminal cleanup failure");

      declare
         use Terminal.Common.Bytes;

         Command : constant String := "exit 259" & Character'Val (13);
         Data    : Byte_Array (1 .. Command'Length);
         S       : Terminal.PTY.Backend.Session;
         Spawn   : Terminal.PTY.Backend.Spawn_Status;
         Written : Natural := 0;
         Status  : Terminal.PTY.Backend.Write_Status;
         State   : Terminal.PTY.Backend.Exit_State :=
           Terminal.PTY.Backend.Still_Running;

         procedure Write_All is
            First : Positive := Data'First;
         begin
            while First <= Data'Last loop
               Terminal.PTY.Backend.Write
                 (S, Data (First .. Data'Last), Written, Status);
               case Status is
                  when Terminal.PTY.Backend.Ok
                     | Terminal.PTY.Backend.Partial =>
                     Assert (Written > 0,
                             "Windows lifecycle write should make progress");
                     First := First + Written;
                  when Terminal.PTY.Backend.Interrupted =>
                     null;
                  when Terminal.PTY.Backend.Failed
                     | Terminal.PTY.Backend.Session_Closed =>
                     Assert (False,
                             "Windows lifecycle exit command should be written");
               end case;
            end loop;
         end Write_All;
      begin
         for I in Command'Range loop
            Data (I - Command'First + 1) :=
              Byte (Character'Pos (Command (I)));
         end loop;

         Terminal.PTY.Backend.Spawn_Default_Shell (S, 24, 80, Spawn);
         Assert (Spawn = Terminal.PTY.Backend.Ok,
                 "Windows lifecycle shell should spawn");
         Write_All;

         for Attempt in 1 .. 300 loop
            State := Terminal.PTY.Backend.Child_State (S);
            exit when State /= Terminal.PTY.Backend.Still_Running;
            delay 0.01;
         end loop;

         Assert (State = Terminal.PTY.Backend.Exited,
                 "exit code 259 must not be reported as STILL_ACTIVE");
         Assert (Terminal.PTY.Backend.Child_Status (S) = 259,
                 "exit code 259 must be preserved");
         Terminal.PTY.Backend.Close (S);
      end;

      Terminal.PTY.Backend.Shutdown_Deferred_Cleanup
        (Timeout_Milliseconds => 10_000,
         Complete             => Cleanup_Complete);
      Assert (Cleanup_Complete,
              "cleanup shutdown barrier must finish without pending owners");
      Assert
        (Testing.Exercise_Rejected_Handoff,
         "post-shutdown handoff rejection must retain caller ownership");
      declare
         Rejected_Session : Terminal.PTY.Backend.Session;
         Rejected_Status  : Terminal.PTY.Backend.Spawn_Status;
      begin
         Terminal.PTY.Backend.Spawn_Default_Shell
           (Rejected_Session, 24, 80, Rejected_Status);
         Assert
           (Rejected_Status = Terminal.PTY.Backend.Cleanup_Shutdown,
            "post-shutdown session spawn must fail explicitly");
      end;
      Baseline_Failures := Testing.Cleanup_Failure_Count;
      Assert
        (Testing.Exercise_Close_Failure,
         "failed handle close must consume its unsafe numeric marker");
      Assert
        (Testing.Cleanup_Failure_Count > Baseline_Failures,
         "non-retryable close failure must increment cleanup diagnostics");
      Assert
        (Terminal.PTY.Backend.Deferred_Cleanup_Abandoned_Count > 0,
         "abandoned owner count must remain visible after terminal failure");
      Assert
        (Testing.Exercise_Permanent_Release_Failures,
         "permanent wait and LocalFree failures must consume their markers");
      Terminal.PTY.Backend.Drain_Deferred_Cleanup
        (Timeout_Milliseconds => 0,
         Complete             => Cleanup_Complete);
      Assert
        (not Cleanup_Complete,
         "abandoned terminal resources must prevent complete drain status");
   end if;
end PTY_Windows_Lifecycle_Smoke;

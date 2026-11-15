with Interfaces.C;

package body Terminal.PTY.Backend.Testing is
   use type Interfaces.C.int;
   use type Interfaces.C.long;
   function C_Test_Close_Failure return Interfaces.C.int
     with Import, Convention => C,
          External_Name => "terminal_pty_test_close_failure";
   function C_Test_POSIX_Deferred_Cleanup return Interfaces.C.int
     with Import, Convention => C,
          External_Name => "terminal_pty_test_posix_deferred_cleanup";
   function C_Test_Failed_Reaper return Interfaces.C.int
     with Import, Convention => C,
          External_Name => "terminal_pty_test_failed_reaper";
   function C_Test_Reader_Handoff return Interfaces.C.int
     with Import, Convention => C,
          External_Name => "terminal_pty_test_reader_handoff";
   function C_Test_Enter_Quarantine return Interfaces.C.int
     with Import, Convention => C,
          External_Name => "terminal_pty_test_enter_quarantine";
   function C_Test_Enter_Quarantine_Batch return Interfaces.C.int
     with Import, Convention => C,
          External_Name => "terminal_pty_test_enter_quarantine_batch";
   function C_Test_Release_Quarantine return Interfaces.C.int
     with Import, Convention => C,
          External_Name => "terminal_pty_test_release_quarantine";
   procedure C_Reset_Drain_Worker_High_Water
     with Import, Convention => C,
          External_Name =>
            "terminal_pty_cleanup_test_reset_drain_worker_high_water";
   function C_Drain_Worker_High_Water return Interfaces.C.long
     with Import, Convention => C,
          External_Name =>
            "terminal_pty_cleanup_test_drain_worker_high_water";
   function C_Active_Cleanup_Workers return Interfaces.C.long
     with Import, Convention => C,
          External_Name => "terminal_pty_cleanup_test_active_workers";
   function C_Test_Cleanup_Fault_Injection return Interfaces.C.int
     with Import, Convention => C,
          External_Name => "terminal_pty_test_cleanup_fault_injection";
   function C_Test_Rejected_Handoff return Interfaces.C.int
     with Import, Convention => C,
          External_Name => "terminal_pty_test_rejected_handoff";
   function C_Test_Permanent_Release_Failures return Interfaces.C.int
     with Import, Convention => C,
          External_Name => "terminal_pty_test_permanent_release_failures";
   function Needs_Deletion (State : Attribute_List_State) return Boolean is
      Backend_State : constant Native_Allocation_State :=
        (case State is
            when Not_Allocated => Terminal.PTY.Backend.Not_Allocated,
            when Allocated     => Terminal.PTY.Backend.Allocated,
            when Initialized   => Terminal.PTY.Backend.Initialized);
   begin
      return Native_Needs_Deletion (Backend_State);
   end Needs_Deletion;

   function Signed_Exit_Status
     (Code : Interfaces.Unsigned_32) return Integer is
     (Windows_Signed_Exit_Status (Code));

   function Spawn_Diagnostics (S : Session) return Spawn_Trace is
     (Pipes_Made      => S.Spawn_Debug.Pipes_Made,
      Console_Made    => S.Spawn_Debug.Console_Made,
      Attributes_Made => S.Spawn_Debug.Attributes_Made,
      Process_Made    => S.Spawn_Debug.Process_Made,
      Last_Error      => S.Spawn_Debug.Last_Error,
      Startup_Size    => S.Spawn_Debug.Startup_Size,
      Attribute_Size  => S.Spawn_Debug.Attribute_Size);

   function Read_Diagnostics (S : Session) return Read_Trace is
     (Polls       => S.Read_Debug.Polls,
      Poll_Failed => S.Read_Debug.Poll_Failed,
      Poll_Error  => S.Read_Debug.Poll_Error,
      Bytes_Seen  => S.Read_Debug.Bytes_Seen);

   function Cleanup_Failure_Count return Natural is
     (Terminal.PTY.Backend.Cleanup_Failure_Count);

   function Exercise_POSIX_Cleanup_Diagnostic return Boolean is
      Baseline_Failures  : constant Natural := Cleanup_Failure_Count;
      Baseline_Abandoned : constant Natural :=
        Terminal.PTY.Backend.Deferred_Cleanup_Abandoned_Count;
      S : Session;
   begin
      if Capabilities.Windows_ConPTY then
         return True;
      end if;
      S.Master_FD := Integer (Interfaces.C.int'Last);
      S.Child_PID := -1;
      S.Closed := False;
      Close (S);
      return Cleanup_Failure_Count > Baseline_Failures
        and then Terminal.PTY.Backend.Deferred_Cleanup_Abandoned_Count >
          Baseline_Abandoned;
   end Exercise_POSIX_Cleanup_Diagnostic;

   function Exercise_POSIX_Deferred_Cleanup return Boolean is
     (C_Test_POSIX_Deferred_Cleanup /= 0);

   function Exercise_Close_Failure return Boolean is
     (C_Test_Close_Failure /= 0);

   function Exercise_Failed_Reaper return Boolean is
     (C_Test_Failed_Reaper /= 0);

   function Exercise_Reader_Handoff return Boolean is
     (C_Test_Reader_Handoff /= 0);

   function Enter_Quarantine return Boolean is
     (C_Test_Enter_Quarantine /= 0);

   function Enter_Quarantine_Batch return Boolean is
     (C_Test_Enter_Quarantine_Batch /= 0);

   function Release_Quarantine return Boolean is
     (C_Test_Release_Quarantine /= 0);

   procedure Reset_Drain_Worker_High_Water is
   begin
      C_Reset_Drain_Worker_High_Water;
   end Reset_Drain_Worker_High_Water;

   function Drain_Worker_High_Water return Natural is
      Value : constant Interfaces.C.long := C_Drain_Worker_High_Water;
   begin
      return
        (if Value <= 0 then 0
         elsif Value >= Interfaces.C.long (Natural'Last) then Natural'Last
         else Natural (Value));
   end Drain_Worker_High_Water;

   function Active_Cleanup_Workers return Natural is
      Value : constant Interfaces.C.long := C_Active_Cleanup_Workers;
   begin
      return
        (if Value <= 0 then 0
         elsif Value >= Interfaces.C.long (Natural'Last) then Natural'Last
         else Natural (Value));
   end Active_Cleanup_Workers;

   function Exercise_Cleanup_Fault_Injection return Boolean is
     (C_Test_Cleanup_Fault_Injection /= 0);

   function Exercise_Rejected_Handoff return Boolean is
     (C_Test_Rejected_Handoff /= 0);

   function Exercise_Permanent_Release_Failures return Boolean is
     (C_Test_Permanent_Release_Failures /= 0);
end Terminal.PTY.Backend.Testing;

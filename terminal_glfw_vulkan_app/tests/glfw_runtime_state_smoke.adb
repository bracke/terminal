with GLFW_Vulkan.Runtime_State;
with GLFW_Vulkan.Runtime_State.Testing;
with Interfaces;

procedure GLFW_Runtime_State_Smoke is
   package State renames GLFW_Vulkan.Runtime_State;
   package State_Testing renames GLFW_Vulkan.Runtime_State.Testing;
   use type State.Runtime_Phase;
   use type Interfaces.Unsigned_64;

   procedure Acquire_First
     (Manager     : in out State.Manager;
      Lease       : in out GLFW_Vulkan.Runtime_Lease) is
   begin
      State.Acquire (Manager, Lease);
      pragma Assert
        (State_Testing.Acquired (Lease)
         and then State_Testing.Needs_Start (Lease));
   end Acquire_First;

   Start_Failure : State.Manager;
   Normal        : State.Manager;
   Cancelled     : State.Manager;
   Cleanup_Error : State.Manager;
   Stale         : State.Manager;
   Concurrent    : State.Manager;
   Concurrent_Stop : State.Manager;
   Concurrent_Failure : State.Manager;
   Start_Failure_Lease : GLFW_Vulkan.Runtime_Lease;
   Normal_Lease : GLFW_Vulkan.Runtime_Lease;
   Normal_Extra_Lease : GLFW_Vulkan.Runtime_Lease;
   Cancelled_Lease : GLFW_Vulkan.Runtime_Lease;
   Cleanup_Error_Lease : GLFW_Vulkan.Runtime_Lease;
   Stale_Lease : GLFW_Vulkan.Runtime_Lease;
   Concurrent_Lease : GLFW_Vulkan.Runtime_Lease;
   Concurrent_Stop_Lease : GLFW_Vulkan.Runtime_Lease;
   Concurrent_Stop_Waiter_Lease : GLFW_Vulkan.Runtime_Lease;
   Concurrent_Failure_Lease : GLFW_Vulkan.Runtime_Lease;
   Generation    : Interfaces.Unsigned_64;
   Stop_Generation : Interfaces.Unsigned_64;

   protected type Concurrent_Result_Box is
      procedure Mark_Started;
      entry Wait_Until_Started;
      procedure Record_Result (Was_Acquired, Needed_Start : Boolean);
      function Completed return Boolean;
      function Was_Acquired return Boolean;
      function Needed_Start return Boolean;
   private
      Started : Boolean := False;
      Done : Boolean := False;
      Acquired_Value : Boolean := False;
      Needed_Start_Value : Boolean := False;
   end Concurrent_Result_Box;

   protected body Concurrent_Result_Box is
      procedure Mark_Started is
      begin
         Started := True;
      end Mark_Started;
      entry Wait_Until_Started when Started is
      begin
         null;
      end Wait_Until_Started;
      procedure Record_Result (Was_Acquired, Needed_Start : Boolean) is
      begin
         Done := True;
         Acquired_Value := Was_Acquired;
         Needed_Start_Value := Needed_Start;
      end Record_Result;
      function Completed return Boolean is (Done);
      function Was_Acquired return Boolean is (Acquired_Value);
      function Needed_Start return Boolean is (Needed_Start_Value);
   end Concurrent_Result_Box;

   Start_Result : Concurrent_Result_Box;
   Stop_Result : Concurrent_Result_Box;
   Failure_Result : Concurrent_Result_Box;
begin
   pragma Assert (GLFW_Vulkan.Runtime_Transition_Failure_Count = 0);

   Acquire_First (Start_Failure, Start_Failure_Lease);
   State.Complete_Start (Start_Failure, Start_Failure_Lease, False);
   pragma Assert (State.Phase (Start_Failure) = State.Stopped);

   Acquire_First (Normal, Normal_Lease);
   State.Complete_Start (Normal, Normal_Lease, True);
   pragma Assert (State.Phase (Normal) = State.Started);
   State.Retain (Normal, Normal_Extra_Lease);
   State.Release (Normal, Normal_Extra_Lease);
   pragma Assert
     (not State_Testing.Needs_Stop (Normal_Extra_Lease)
      and then State.Phase (Normal) = State.Started);
   State.Release (Normal, Normal_Lease);
   Stop_Generation := State_Testing.Generation (Normal_Lease);
   pragma Assert
     (State_Testing.Needs_Stop (Normal_Lease)
      and then State.Phase (Normal) = State.Stopping);
   --  This is the state published by the C shim if cancellation becomes
   --  visible immediately after glfwTerminate returns.
   State_Testing.Mark_Raw_Stopped (Normal_Lease);
   State.Complete_Stop (Normal, Normal_Lease, True);
   pragma Assert
     (State.Phase (Normal) = State.Stopped
      and then State.Stop_Completed (Normal, Stop_Generation)
      and then not State_Testing.Raw_Stopped (Normal_Lease));

   Acquire_First (Cancelled, Cancelled_Lease);
   Generation := State_Testing.Generation (Cancelled_Lease);
   State_Testing.Set_Generation (Cancelled_Lease, Generation + 1);
   State.Cancel_Start (Cancelled, Cancelled_Lease);
   pragma Assert
     (not State_Testing.Needs_Stop (Cancelled_Lease)
      and then State.Phase (Cancelled) = State.Starting);
   State_Testing.Set_Generation (Cancelled_Lease, Generation);
   State.Cancel_Start (Cancelled, Cancelled_Lease);
   pragma Assert
     (State_Testing.Needs_Stop (Cancelled_Lease)
      and then State.Phase (Cancelled) = State.Stopping);
   State.Complete_Stop (Cancelled, Cancelled_Lease, True);
   pragma Assert (State.Phase (Cancelled) = State.Stopped);

   Acquire_First (Cleanup_Error, Cleanup_Error_Lease);
   State.Cancel_Start (Cleanup_Error, Cleanup_Error_Lease);
   State.Complete_Stop (Cleanup_Error, Cleanup_Error_Lease, False);
   pragma Assert (State.Phase (Cleanup_Error) = State.Failed);
   State.Acquire (Cleanup_Error, Cleanup_Error_Lease);
   pragma Assert
     (not State_Testing.Acquired (Cleanup_Error_Lease)
      and then not State_Testing.Needs_Start (Cleanup_Error_Lease));

   Acquire_First (Stale, Stale_Lease);
   State.Cancel_Start (Stale, Stale_Lease);
   Stop_Generation := State_Testing.Generation (Stale_Lease);
   State.Complete_Stop (Stale, Stale_Lease, True);
   declare
      Old_Generation : constant Interfaces.Unsigned_64 := Stop_Generation;
      Rejected : Boolean := False;
   begin
      Acquire_First (Stale, Stale_Lease);
      Generation := State_Testing.Generation (Stale_Lease);
      pragma Assert
        (State.Stop_Completed (Stale, Old_Generation));
      begin
         State_Testing.Set_Generation (Stale_Lease, Old_Generation);
         State.Complete_Start (Stale, Stale_Lease, True);
      exception
         when Program_Error => Rejected := True;
      end;
      pragma Assert (Rejected and then State.Phase (Stale) = State.Starting);
      State_Testing.Set_Generation (Stale_Lease, Generation);
      State.Complete_Start (Stale, Stale_Lease, True);
      State.Release (Stale, Stale_Lease);
      Stop_Generation := State_Testing.Generation (Stale_Lease);
      Rejected := False;
      begin
         State_Testing.Set_Generation (Stale_Lease, Old_Generation);
         State.Complete_Stop (Stale, Stale_Lease, True);
      exception
         when Program_Error => Rejected := True;
      end;
      pragma Assert (Rejected and then State.Phase (Stale) = State.Stopping);
      State_Testing.Set_Generation (Stale_Lease, Stop_Generation);
      State.Complete_Stop (Stale, Stale_Lease, True);
   end;

   Acquire_First (Concurrent, Concurrent_Lease);
   declare
      task Waiting_Acquire;
      task body Waiting_Acquire is
         Local_Lease : GLFW_Vulkan.Runtime_Lease;
      begin
         Start_Result.Mark_Started;
         State.Acquire (Concurrent, Local_Lease);
         Start_Result.Record_Result
           (State_Testing.Acquired (Local_Lease),
            State_Testing.Needs_Start (Local_Lease));
         State.Release (Concurrent, Local_Lease);
      end Waiting_Acquire;
   begin
      Start_Result.Wait_Until_Started;
      for Attempt in 1 .. 5_000 loop
         exit when State_Testing.Waiting_Acquire_Count (Concurrent) = 1;
         delay 0.001;
      end loop;
      pragma Assert
        (State_Testing.Waiting_Acquire_Count (Concurrent) = 1
         and then not Start_Result.Completed);
      State.Complete_Start (Concurrent, Concurrent_Lease, True);
   end;
   pragma Assert
     (Start_Result.Completed
      and then Start_Result.Was_Acquired
      and then not Start_Result.Needed_Start);
   State.Release (Concurrent, Concurrent_Lease);
   pragma Assert (State_Testing.Needs_Stop (Concurrent_Lease));
   State.Complete_Stop (Concurrent, Concurrent_Lease, True);

   --  An acquire queued behind a stop starts the next generation only after
   --  the previous generation has completed.
   Acquire_First (Concurrent_Stop, Concurrent_Stop_Lease);
   State.Complete_Start (Concurrent_Stop, Concurrent_Stop_Lease, True);
   State.Release (Concurrent_Stop, Concurrent_Stop_Lease);
   pragma Assert (State_Testing.Needs_Stop (Concurrent_Stop_Lease));
   declare
      task Waiting_Acquire;
      task body Waiting_Acquire is
         Was_Acquired : Boolean;
         Needed_Start : Boolean;
      begin
         Stop_Result.Mark_Started;
         State.Acquire
           (Concurrent_Stop, Concurrent_Stop_Waiter_Lease);
         Was_Acquired :=
           State_Testing.Acquired (Concurrent_Stop_Waiter_Lease);
         Needed_Start :=
           State_Testing.Needs_Start (Concurrent_Stop_Waiter_Lease);
         if Was_Acquired and then Needed_Start
         then
            State.Complete_Start
              (Concurrent_Stop, Concurrent_Stop_Waiter_Lease, True);
         end if;
         Stop_Result.Record_Result
           (Was_Acquired, Needed_Start);
      end Waiting_Acquire;
   begin
      Stop_Result.Wait_Until_Started;
      for Attempt in 1 .. 5_000 loop
         exit when State_Testing.Waiting_Acquire_Count (Concurrent_Stop) = 1;
         delay 0.001;
      end loop;
      pragma Assert
        (State_Testing.Waiting_Acquire_Count (Concurrent_Stop) = 1
         and then not Stop_Result.Completed);
      State.Complete_Stop (Concurrent_Stop, Concurrent_Stop_Lease, True);
   end;
   pragma Assert
     (Stop_Result.Completed
      and then Stop_Result.Was_Acquired
      and then Stop_Result.Needed_Start
      and then State.Phase (Concurrent_Stop) = State.Started);
   State.Release (Concurrent_Stop, Concurrent_Stop_Waiter_Lease);
   pragma Assert
     (State_Testing.Needs_Stop (Concurrent_Stop_Waiter_Lease));
   State.Complete_Stop
     (Concurrent_Stop, Concurrent_Stop_Waiter_Lease, True);
   --  A failed transition opens the barrier and rejects queued acquirers.
   Acquire_First (Concurrent_Failure, Concurrent_Failure_Lease);
   State.Complete_Start
     (Concurrent_Failure, Concurrent_Failure_Lease, True);
   State.Release (Concurrent_Failure, Concurrent_Failure_Lease);
   declare
      task Waiting_Acquire;
      task body Waiting_Acquire is
         Local_Lease : GLFW_Vulkan.Runtime_Lease;
      begin
         Failure_Result.Mark_Started;
         State.Acquire (Concurrent_Failure, Local_Lease);
         Failure_Result.Record_Result
           (State_Testing.Acquired (Local_Lease),
            State_Testing.Needs_Start (Local_Lease));
      end Waiting_Acquire;
   begin
      Failure_Result.Wait_Until_Started;
      for Attempt in 1 .. 5_000 loop
         exit when State_Testing.Waiting_Acquire_Count (Concurrent_Failure) = 1;
         delay 0.001;
      end loop;
      pragma Assert
        (State_Testing.Waiting_Acquire_Count (Concurrent_Failure) = 1
         and then not Failure_Result.Completed);
      State.Quarantine (Concurrent_Failure);
   end;
   pragma Assert
     (Failure_Result.Completed
      and then not Failure_Result.Was_Acquired
      and then not Failure_Result.Needed_Start);

   State.Quarantine (Concurrent);
   pragma Assert
     (State.Phase (Concurrent) = State.Failed
      and then State.Transition_Failure_Count (Concurrent) = 1);
end GLFW_Runtime_State_Smoke;

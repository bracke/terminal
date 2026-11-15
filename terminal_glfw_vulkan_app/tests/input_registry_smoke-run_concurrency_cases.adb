separate (Input_Registry_Smoke)
procedure Run_Concurrency_Cases is
   function Wait_Until
     (Condition : not null access function return Boolean) return Boolean is
   begin
      for Attempt in 1 .. 5_000 loop
         if Condition.all then
            return True;
         end if;
         delay 0.001;
      end loop;
      return False;
   end Wait_Until;

   function Retirement_Started return Boolean is
     (Testing.Retirement_In_Progress (Third_Handle));

   function Dispatch_Is_Waiting return Boolean is
     (Testing.Waiting_Dispatch_Count (Third_Handle) > 0);

   function Dispatch_Stopped_Waiting return Boolean is
     (Testing.Waiting_Dispatch_Count (Third_Handle) = 0);
begin
   --  Forced retirement must not return while another task can still invoke
   --  a callback copied from the retiring registry entry.
   Dispatch_Synchronization.Reset;
   Mutation_Completion.Reset;
   Testing.Set_Key_Callback
     (Third_Handle, Block_Third_Window'Unrestricted_Access);
   declare
      task Dispatch_Third_Window;
      task Retire_Third_Window;
      task body Dispatch_Third_Window is
      begin
         Testing.Dispatch_Key (Third_Handle);
      end Dispatch_Third_Window;
      task body Retire_Third_Window is
      begin
         Dispatch_Synchronization.Wait_Until_Entered;
         Testing.Retire (Third_Handle);
         Mutation_Completion.Mark_Completed;
      end Retire_Third_Window;
   begin
      Dispatch_Synchronization.Wait_Until_Entered;
      if not Wait_Until (Retirement_Started'Access) then
         raise Program_Error with "retirement did not start";
      end if;
      Assert
        (Testing.Retirement_In_Progress (Third_Handle)
         and then not Mutation_Completion.Is_Completed,
         "retirement waits for in-flight callback dispatch");
      Dispatch_Synchronization.Release;
   end;
   Assert
     (Mutation_Completion.Is_Completed,
      "retirement completes after callback dispatch exits");

   --  Cancellation while retirement is waiting must release its private hold;
   --  the in-flight dispatch token remains the sole owner until it exits.
   Dispatch_Synchronization.Reset;
   Testing.Set_Key_Callback
     (Third_Handle, Block_Third_Window'Unrestricted_Access);
   declare
      task Dispatch_Third_Window;
      task Retire_Third_Window;
      function Retirement_Terminated return Boolean is
        (Retire_Third_Window'Terminated);
      task body Dispatch_Third_Window is
      begin
         Testing.Dispatch_Key (Third_Handle);
      end Dispatch_Third_Window;
      task body Retire_Third_Window is
      begin
         Dispatch_Synchronization.Wait_Until_Entered;
         Testing.Retire (Third_Handle);
      end Retire_Third_Window;
   begin
      Dispatch_Synchronization.Wait_Until_Entered;
      if not Wait_Until (Retirement_Started'Access) then
         raise Program_Error with
           "cancelled retirement did not acquire its node hold";
      end if;
      abort Retire_Third_Window;
      --  Suspend_Until_True is abort-deferred by the runtime.  Let the active
      --  dispatch leave so cancellation can reach the controlled guard.
      Dispatch_Synchronization.Release;
      if not Wait_Until (Retirement_Terminated'Access) then
         raise Program_Error with "cancelled retirement task did not terminate";
      elsif Testing.Retirement_In_Progress (Third_Handle) then
         raise Program_Error with
           "cancelled retirement retained its node hold";
      end if;
   exception
      when others =>
         Dispatch_Synchronization.Release;
         raise;
   end;
   Testing.Set_Key_Callback
     (Third_Handle, Count_Cancelled_Retirement'Unrestricted_Access);
   Testing.Dispatch_Key (Third_Handle);
   if Cancelled_Retirement_Count /= 1 then
      raise Program_Error with
        "callback identity could not be reused after cancelled retirement";
   end if;
   Testing.Clear_Callbacks (Third_Handle);

   Testing.Set_Key_Callback (Third_Handle, Count_First'Unrestricted_Access);
   declare
      task Replace_Third_Window;
      task Dispatch_During_Mutation;
      task body Replace_Third_Window is
      begin
         Testing.Set_Key_Callback_Paused
           (Third_Handle, Count_Waiting'Unrestricted_Access);
      end Replace_Third_Window;
      task body Dispatch_During_Mutation is
      begin
         Testing.Wait_Until_Mutation_Paused;
         Testing.Dispatch_Key (Third_Handle);
         Waiting_Dispatch_Completion.Mark_Completed;
      end Dispatch_During_Mutation;
      Dispatch_Waited : Boolean := False;
   begin
      Testing.Wait_Until_Mutation_Paused;
      Dispatch_Waited := Wait_Until (Dispatch_Is_Waiting'Access);
      Testing.Release_Paused_Mutation;
      Assert
        (Dispatch_Waited,
         "same-window dispatch reached the mutation wait queue");
      select
         Waiting_Dispatch_Completion.Wait_Until_Completed;
      or
         delay 5.0;
         abort Dispatch_During_Mutation;
         Assert (False, "same-window dispatch was discarded by mutation");
      end select;
   end;
   Assert
     (Waiting_Count = 1,
      "same-window dispatch observes the replacement callback");
   Testing.Clear_Callbacks (Third_Handle);

   --  Exercise the pause fixture a second time.  A stale Released flag would
   --  let this mutation pass without waiting and make later race tests lie.
   Testing.Set_Key_Callback (Third_Handle, Count_First'Unrestricted_Access);
   declare
      task Replace_Third_Window_Again;
      task body Replace_Third_Window_Again is
      begin
         Testing.Set_Key_Callback_Paused
           (Third_Handle, Count_Waiting'Unrestricted_Access);
      end Replace_Third_Window_Again;
   begin
      Testing.Wait_Until_Mutation_Paused;
      Testing.Release_Paused_Mutation;
   end;
   Testing.Dispatch_Key (Third_Handle);
   Assert
     (Waiting_Count = 2,
      "mutation pause fixture is reusable across registrations");
   Testing.Clear_Callbacks (Third_Handle);

   --  Cancellation while a dispatch is queued behind a mutation must release
   --  its waiter hold.  Otherwise the retired callback generation can never
   --  be reclaimed.
   Testing.Set_Key_Callback (Third_Handle, Count_First'Unrestricted_Access);
   declare
      task Paused_Mutation;
      task Cancelled_Waiter;
      task body Paused_Mutation is
      begin
         Testing.Set_Key_Callback_Paused
           (Third_Handle, Count_Waiting'Unrestricted_Access);
      end Paused_Mutation;
      task body Cancelled_Waiter is
      begin
         Testing.Wait_Until_Mutation_Paused;
         Testing.Dispatch_Key (Third_Handle);
      end Cancelled_Waiter;
      Reached_Wait_Queue : Boolean := False;
      Cancellation_Completed : Boolean := False;
      Waiter_Hold_Released : Boolean := False;
   begin
      Testing.Wait_Until_Mutation_Paused;
      Reached_Wait_Queue := Wait_Until (Dispatch_Is_Waiting'Access);
      abort Cancelled_Waiter;
      --  Suspend_Until_True defers abort while blocked.  Releasing the
      --  mutation lets the pending cancellation land either immediately
      --  before promotion or immediately after the protected handoff.
      Testing.Release_Paused_Mutation;
      declare
         function Waiter_Terminated return Boolean is
           (Cancelled_Waiter'Terminated);
      begin
         Cancellation_Completed := Wait_Until (Waiter_Terminated'Access);
      end;
      Waiter_Hold_Released := Wait_Until (Dispatch_Stopped_Waiting'Access);
      Assert
        (Reached_Wait_Queue,
         "cancelled dispatch reached the mutation wait queue");
      Assert
        (Cancellation_Completed,
         "queued dispatch responds to cancellation");
      Assert
        (Waiter_Hold_Released,
         "cancelled dispatch releases its registry waiter hold");
   end;
   Testing.Clear_Callbacks (Third_Handle);

   --  Finalizer retirement can race a mutation that already owns its guard.
   --  Retirement must retain the native-window generation until that mutation
   --  has left the region in which it may call native callback setters.
   Testing.Set_Key_Callback (Third_Handle, Count_First'Unrestricted_Access);
   Mutation_Completion.Reset;
   declare
      task Interrupted_Mutation;
      task Retire_Mutating_Window;
      task body Interrupted_Mutation is
      begin
         Testing.Set_Key_Callback_Paused
           (Third_Handle, Count_Waiting'Unrestricted_Access);
      exception
         when Program_Error => null;
      end Interrupted_Mutation;
      task body Retire_Mutating_Window is
      begin
         Testing.Wait_Until_Mutation_Paused;
         Testing.Retire (Third_Handle);
         Mutation_Completion.Mark_Completed;
      end Retire_Mutating_Window;
   begin
      Testing.Wait_Until_Mutation_Paused;
      if not Wait_Until (Retirement_Started'Access) then
         raise Program_Error with
           "retirement did not start while callback mutation was paused";
      end if;
      Assert
        (not Mutation_Completion.Is_Completed,
         "retirement retains the window until callback mutation exits");
      Testing.Release_Paused_Mutation;
   end;
   Assert
     (Mutation_Completion.Is_Completed,
      "retirement completes after callback mutation exits");
   Testing.Dispatch_Key (Third_Handle);
   Testing.Set_Key_Callback
     (Third_Handle, Count_Reused'Unrestricted_Access);
   Testing.Dispatch_Key (Third_Handle);
   Assert
     (Reused_Count = 2,
      "retirement during mutation permits clean address reuse");
   Testing.Clear_Callbacks (Third_Handle);

   --  A dispatch already waiting on an old window generation must not be
   --  delivered to a replacement window that reuses the native address.
   Testing.Set_Key_Callback (Third_Handle, Count_First'Unrestricted_Access);
   Mutation_Completion.Reset;
   declare
      task Interrupted_Mutation;
      task Waiting_Dispatch;
      task body Interrupted_Mutation is
      begin
         Testing.Set_Key_Callback_Paused
           (Third_Handle, Count_Waiting'Unrestricted_Access);
      exception
         when Program_Error => null;
      end Interrupted_Mutation;
      task body Waiting_Dispatch is
      begin
         Testing.Wait_Until_Mutation_Paused;
         Testing.Dispatch_Key (Third_Handle);
         Retired_Dispatch_Completion.Mark_Completed;
      end Waiting_Dispatch;
      Dispatch_Waited : Boolean := False;
      First_Before : constant Natural := First_Count;
      Waiting_Before : constant Natural := Waiting_Count;
      Reused_Before : constant Natural := Reused_Count;
   begin
      Testing.Wait_Until_Mutation_Paused;
      Dispatch_Waited := Wait_Until (Dispatch_Is_Waiting'Access);
      Assert (Dispatch_Waited, "retired dispatch reached the wait queue");
      declare
         task Retire_Mutating_Window;
         task body Retire_Mutating_Window is
         begin
            Testing.Retire (Third_Handle);
            Mutation_Completion.Mark_Completed;
         end Retire_Mutating_Window;
      begin
         if not Wait_Until (Retirement_Started'Access) then
            raise Program_Error with
              "retirement did not start with a queued dispatch";
         end if;
         Testing.Release_Paused_Mutation;
         select
            Mutation_Completion.Wait_Until_Completed;
         or
            delay 5.0;
            abort Retire_Mutating_Window;
            raise Program_Error with
              "retirement did not complete after callback mutation release";
         end select;
      end;
      Testing.Set_Key_Callback
        (Third_Handle, Count_Reused'Unrestricted_Access);
      select
         Retired_Dispatch_Completion.Wait_Until_Completed;
      or
         delay 5.0;
         abort Waiting_Dispatch;
         raise Program_Error with "retired dispatch did not complete";
      end select;
      Assert
        (First_Count = First_Before
         and then Waiting_Count = Waiting_Before
         and then Reused_Count = Reused_Before,
         "a retired-generation event is discarded before address reuse");
   end;
   Testing.Dispatch_Key (Third_Handle);
   Assert (Reused_Count = 3, "replacement callback remains dispatchable");
   Testing.Clear_Callbacks (Third_Handle);
end Run_Concurrency_Cases;

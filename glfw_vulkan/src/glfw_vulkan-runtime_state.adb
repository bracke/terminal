package body GLFW_Vulkan.Runtime_State is
   use type Interfaces.Unsigned_64;

   protected body Lease_State is
      entry Acquire_Lease
        (Lease : in out GLFW_Vulkan.Runtime_Lease)
        when Current_Phase /= Starting and then Current_Phase /= Stopping
      is
      begin
         if Lease.Acquired or else Lease.Needs_Start or else Lease.Needs_Stop then
            raise Program_Error with "GLFW runtime lease is already active";
         end if;
         Lease.Generation := 0;
         case Current_Phase is
            when Started =>
               if References = Natural'Last then
                  raise Storage_Error with
                    "GLFW runtime reference count exhausted";
               end if;
               References := References + 1;
               Lease.Acquired := True;
            when Stopped =>
               Current_Phase := Starting;
               Lease.Needs_Start := True;
               Lease.Acquired := True;
               Lease.Generation := Next_Generation;
               Active_Generation := Lease.Generation;
               if Last_Stop_Generation = Lease.Generation then
                  Last_Stop_Generation := 0;
               end if;
               Next_Generation := Next_Generation + 1;
               if Next_Generation = 0 then
                  Next_Generation := 1;
               end if;
            when Failed =>
               null;
            when Starting | Stopping =>
               raise Program_Error with "invalid GLFW transition barrier";
         end case;
      end Acquire_Lease;

      procedure Complete_Start
        (Lease      : in out GLFW_Vulkan.Runtime_Lease;
         Succeeded  : Boolean) is
      begin
         if Current_Phase /= Starting
           or else not Lease.Acquired
           or else not Lease.Needs_Start
           or else Lease.Generation = 0
           or else Lease.Generation /= Active_Generation
         then
            raise Program_Error with "stale GLFW start completion";
         end if;
         if Succeeded then
            Current_Phase := Started;
            References := 1;
            Lease.Needs_Start := False;
            Lease.Raw_Stopped := 0;
         else
            Current_Phase := Stopped;
            References := 0;
            Active_Generation := 0;
            Lease.Acquired := False;
            Lease.Needs_Start := False;
            Lease.Raw_Started := False;
            Lease.Raw_Stopped := 0;
            Lease.Generation := 0;
         end if;
      end Complete_Start;

      procedure Cancel_Start
        (Lease : in out GLFW_Vulkan.Runtime_Lease) is
      begin
         Lease.Needs_Stop :=
           Lease.Generation /= 0
           and then Lease.Acquired
           and then Lease.Needs_Start
           and then Current_Phase = Starting
           and then Active_Generation = Lease.Generation;
         if Lease.Needs_Stop then
            Current_Phase := Stopping;
            References := 0;
            Lease.Acquired := False;
            Lease.Needs_Start := False;
         end if;
      end Cancel_Start;

      procedure Retain (Lease : in out GLFW_Vulkan.Runtime_Lease) is
      begin
         if Lease.Acquired or else Lease.Needs_Start or else Lease.Needs_Stop then
            raise Program_Error with "GLFW runtime lease is already active";
         elsif Current_Phase /= Started or else References = 0 then
            raise Program_Error with "GLFW runtime is not initialized";
         elsif References = Natural'Last then
            raise Storage_Error with
              "GLFW runtime reference count exhausted";
         end if;
         References := References + 1;
         Lease.Acquired := True;
         Lease.Generation := Active_Generation;
      end Retain;

      procedure Release (Lease : in out GLFW_Vulkan.Runtime_Lease) is
      begin
         if not Lease.Acquired or else Lease.Needs_Start or else Lease.Needs_Stop
         then
            raise Program_Error with "GLFW runtime lease is not active";
         elsif Current_Phase /= Started or else References = 0 then
            raise Program_Error with "GLFW runtime lease is not held";
         end if;
         References := References - 1;
         Lease.Acquired := False;
         Lease.Generation := 0;
         if References = 0 then
            Current_Phase := Stopping;
            Lease.Needs_Stop := True;
            Lease.Generation := Active_Generation;
         end if;
      end Release;

      procedure Complete_Stop
        (Lease      : in out GLFW_Vulkan.Runtime_Lease;
         Succeeded  : Boolean) is
      begin
         if Current_Phase /= Stopping
           or else not Lease.Needs_Stop
           or else Lease.Generation = 0
           or else Lease.Generation /= Active_Generation
         then
            raise Program_Error with "stale GLFW stop completion";
         end if;
         Current_Phase := (if Succeeded then Stopped else Failed);
         References := 0;
         Last_Stop_Generation := Lease.Generation;
         Active_Generation := 0;
         Lease.Needs_Stop := False;
         Lease.Raw_Stopped := 0;
         Lease.Generation := 0;
      end Complete_Stop;

      procedure Quarantine is
      begin
         Current_Phase := Failed;
         References := 0;
         Active_Generation := 0;
         if Transition_Failures < Natural'Last then
            Transition_Failures := Transition_Failures + 1;
         end if;
      end Quarantine;

      function Phase return Runtime_Phase is (Current_Phase);
      function Stop_Completed
        (Generation : Interfaces.Unsigned_64) return Boolean is
        (Generation /= 0 and then Generation = Last_Stop_Generation);
      function Transition_Failure_Count return Natural is
        (Transition_Failures);
      function Waiting_Acquire_Count return Natural is (Acquire_Lease'Count);
   end Lease_State;

   procedure Acquire
     (State : in out Manager;
      Lease : in out GLFW_Vulkan.Runtime_Lease) is
   begin
      State.Leases.Acquire_Lease (Lease);
   end Acquire;

   procedure Complete_Start
     (State     : in out Manager;
      Lease     : in out GLFW_Vulkan.Runtime_Lease;
      Succeeded : Boolean) is
   begin
      State.Leases.Complete_Start (Lease, Succeeded);
   end Complete_Start;

   procedure Cancel_Start
     (State : in out Manager;
      Lease : in out GLFW_Vulkan.Runtime_Lease) is
   begin
      State.Leases.Cancel_Start (Lease);
   end Cancel_Start;

   procedure Retain
     (State : in out Manager;
      Lease : in out GLFW_Vulkan.Runtime_Lease) is
   begin
      State.Leases.Retain (Lease);
   end Retain;

   procedure Release
     (State : in out Manager;
      Lease : in out GLFW_Vulkan.Runtime_Lease) is
   begin
      State.Leases.Release (Lease);
   end Release;

   procedure Complete_Stop
     (State     : in out Manager;
      Lease     : in out GLFW_Vulkan.Runtime_Lease;
      Succeeded : Boolean) is
   begin
      State.Leases.Complete_Stop (Lease, Succeeded);
   end Complete_Stop;

   procedure Quarantine (State : in out Manager) is
   begin
      State.Leases.Quarantine;
   end Quarantine;

   function Phase (State : Manager) return Runtime_Phase is
     (State.Leases.Phase);

   function Stop_Completed
     (State      : Manager;
      Generation : Interfaces.Unsigned_64) return Boolean is
     (State.Leases.Stop_Completed (Generation));

   function Transition_Failure_Count (State : Manager) return Natural is
     (State.Leases.Transition_Failure_Count);

end GLFW_Vulkan.Runtime_State;

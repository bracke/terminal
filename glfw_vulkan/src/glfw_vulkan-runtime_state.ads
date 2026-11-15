with GLFW_Vulkan;
with Interfaces;

package GLFW_Vulkan.Runtime_State is
   type Runtime_Phase is (Stopped, Starting, Started, Stopping, Failed);
   type Manager is limited private;

   procedure Acquire
     (State : in out Manager;
      Lease : in out GLFW_Vulkan.Runtime_Lease);
   procedure Complete_Start
     (State     : in out Manager;
      Lease     : in out GLFW_Vulkan.Runtime_Lease;
      Succeeded : Boolean);
   procedure Cancel_Start
     (State : in out Manager;
      Lease : in out GLFW_Vulkan.Runtime_Lease);
   procedure Retain
     (State : in out Manager;
      Lease : in out GLFW_Vulkan.Runtime_Lease);
   procedure Release
     (State : in out Manager;
      Lease : in out GLFW_Vulkan.Runtime_Lease);
   procedure Complete_Stop
     (State     : in out Manager;
      Lease     : in out GLFW_Vulkan.Runtime_Lease;
      Succeeded : Boolean);
   procedure Quarantine (State : in out Manager);
   function Phase (State : Manager) return Runtime_Phase;
   function Stop_Completed
     (State      : Manager;
      Generation : Interfaces.Unsigned_64) return Boolean;
   function Transition_Failure_Count (State : Manager) return Natural;

private
   protected type Lease_State is
      entry Acquire_Lease
        (Lease : in out GLFW_Vulkan.Runtime_Lease);
      procedure Complete_Start
        (Lease      : in out GLFW_Vulkan.Runtime_Lease;
         Succeeded  : Boolean);
      procedure Cancel_Start
        (Lease : in out GLFW_Vulkan.Runtime_Lease);
      procedure Retain
        (Lease : in out GLFW_Vulkan.Runtime_Lease);
      procedure Release
        (Lease : in out GLFW_Vulkan.Runtime_Lease);
      procedure Complete_Stop
        (Lease      : in out GLFW_Vulkan.Runtime_Lease;
         Succeeded  : Boolean);
      procedure Quarantine;
      function Phase return Runtime_Phase;
      function Stop_Completed
        (Generation : Interfaces.Unsigned_64) return Boolean;
      function Transition_Failure_Count return Natural;
      function Waiting_Acquire_Count return Natural;
   private
      Current_Phase : Runtime_Phase := Stopped;
      References : Natural := 0;
      Active_Generation : Interfaces.Unsigned_64 := 0;
      Next_Generation : Interfaces.Unsigned_64 := 1;
      Last_Stop_Generation : Interfaces.Unsigned_64 := 0;
      Transition_Failures : Natural := 0;
   end Lease_State;

   type Manager is limited record
      Leases : Lease_State;
   end record;
end GLFW_Vulkan.Runtime_State;

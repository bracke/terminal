with Interfaces.C;

package body GLFW_Vulkan.Runtime_State.Testing is
   use type Interfaces.C.int;
   function Waiting_Acquire_Count (Value : Manager) return Natural is
     (Value.Leases.Waiting_Acquire_Count);
   function Acquired (Lease : GLFW_Vulkan.Runtime_Lease) return Boolean is
     (Lease.Acquired);
   function Needs_Start (Lease : GLFW_Vulkan.Runtime_Lease) return Boolean is
     (Lease.Needs_Start);
   function Needs_Stop (Lease : GLFW_Vulkan.Runtime_Lease) return Boolean is
     (Lease.Needs_Stop);
   function Raw_Stopped (Lease : GLFW_Vulkan.Runtime_Lease) return Boolean is
     (Lease.Raw_Stopped /= 0);
   procedure Mark_Raw_Stopped (Lease : in out GLFW_Vulkan.Runtime_Lease) is
   begin
      Lease.Raw_Stopped := 1;
   end Mark_Raw_Stopped;
   function Generation
     (Lease : GLFW_Vulkan.Runtime_Lease) return Interfaces.Unsigned_64 is
     (Lease.Generation);
   procedure Set_Generation
     (Lease : in out GLFW_Vulkan.Runtime_Lease;
      Value : Interfaces.Unsigned_64) is
   begin
      Lease.Generation := Value;
   end Set_Generation;
end GLFW_Vulkan.Runtime_State.Testing;

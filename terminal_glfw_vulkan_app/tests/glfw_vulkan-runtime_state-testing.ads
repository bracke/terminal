with GLFW_Vulkan;
with Interfaces;

package GLFW_Vulkan.Runtime_State.Testing is
   function Waiting_Acquire_Count (Value : Manager) return Natural;
   function Acquired (Lease : GLFW_Vulkan.Runtime_Lease) return Boolean;
   function Needs_Start (Lease : GLFW_Vulkan.Runtime_Lease) return Boolean;
   function Needs_Stop (Lease : GLFW_Vulkan.Runtime_Lease) return Boolean;
   function Raw_Stopped (Lease : GLFW_Vulkan.Runtime_Lease) return Boolean;
   procedure Mark_Raw_Stopped (Lease : in out GLFW_Vulkan.Runtime_Lease);
   function Generation
     (Lease : GLFW_Vulkan.Runtime_Lease) return Interfaces.Unsigned_64;
   procedure Set_Generation
     (Lease : in out GLFW_Vulkan.Runtime_Lease;
      Value : Interfaces.Unsigned_64);
end GLFW_Vulkan.Runtime_State.Testing;

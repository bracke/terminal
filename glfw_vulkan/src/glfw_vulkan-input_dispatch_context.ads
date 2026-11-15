with GLFW_Vulkan.Raw;

private package GLFW_Vulkan.Input_Dispatch_Context is
   Max_Nesting : constant := 64;

   procedure Enter (Window : GLFW_Vulkan.Raw.GLFW_Window_Handle);
   procedure Leave;
   function Depth_For
     (Window : GLFW_Vulkan.Raw.GLFW_Window_Handle) return Natural;
   function Active return Boolean;
end GLFW_Vulkan.Input_Dispatch_Context;

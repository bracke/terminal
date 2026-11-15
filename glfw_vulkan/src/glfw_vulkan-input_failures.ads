with GLFW_Vulkan.Input;

private package GLFW_Vulkan.Input_Failures is
   procedure Note_Callback
     (Source         : GLFW_Vulkan.Input.Failure_Source;
      Exception_Name : String);
   procedure Note_Infrastructure
     (Source         : GLFW_Vulkan.Input.Failure_Source;
      Exception_Name : String);
   procedure Reset_Callbacks;
   procedure Reset_Infrastructure;
   function Snapshot return GLFW_Vulkan.Input.Failure_Snapshot;
end GLFW_Vulkan.Input_Failures;

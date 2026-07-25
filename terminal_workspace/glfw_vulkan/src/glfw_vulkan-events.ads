package GLFW_Vulkan.Events is
   procedure Poll;
   procedure Wait;
   procedure Wait_Timeout (Seconds : Duration);
   procedure Post_Empty_Event;
end GLFW_Vulkan.Events;


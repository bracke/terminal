package body GLFW_Vulkan.Windows.Internal is
   function Handle (W : Window) return Raw.GLFW_Window_Handle is
     (W.Handle);
end GLFW_Vulkan.Windows.Internal;

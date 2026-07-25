with GLFW_Vulkan.Windows;

package GLFW_Vulkan.Clipboard is
   function Get_Text (W : GLFW_Vulkan.Windows.Window) return String;

   procedure Set_Text
     (W    : GLFW_Vulkan.Windows.Window;
      Text : String);
end GLFW_Vulkan.Clipboard;


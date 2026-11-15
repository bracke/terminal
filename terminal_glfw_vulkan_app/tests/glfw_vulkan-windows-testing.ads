with System;

package GLFW_Vulkan.Windows.Testing is
   procedure Set_Fake_Handle (W : in out Window; Handle : System.Address);
   procedure Clear_Fake_Handle (W : in out Window);
end GLFW_Vulkan.Windows.Testing;

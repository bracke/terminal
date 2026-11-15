with GLFW_Vulkan.Raw;

package body GLFW_Vulkan.Windows.Testing is
   use type GLFW_Vulkan.Raw.GLFW_Window_Handle;
   procedure Set_Fake_Handle (W : in out Window; Handle : System.Address) is
   begin
      if W.Handle /= GLFW_Vulkan.Raw.Null_Window then
         raise Program_Error with "test window already has a handle";
      end if;
      W.Handle := GLFW_Vulkan.Raw.GLFW_Window_Handle (Handle);
   end Set_Fake_Handle;

   procedure Clear_Fake_Handle (W : in out Window) is
   begin
      W.Handle := GLFW_Vulkan.Raw.Null_Window;
   end Clear_Fake_Handle;
end GLFW_Vulkan.Windows.Testing;

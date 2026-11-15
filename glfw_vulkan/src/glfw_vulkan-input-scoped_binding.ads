with Ada.Finalization;
with GLFW_Vulkan.Windows;

generic
   with procedure On_Key (Event : GLFW_Vulkan.Input.Key_Event);
   with procedure On_Character (Event : GLFW_Vulkan.Input.Character_Event);
   with procedure On_Mouse_Button
     (Event : GLFW_Vulkan.Input.Mouse_Button_Event);
   with procedure On_Cursor_Position
     (Event : GLFW_Vulkan.Input.Cursor_Position_Event);
   with procedure On_Scroll (Event : GLFW_Vulkan.Input.Scroll_Event);
   with procedure On_Focus (Event : GLFW_Vulkan.Input.Focus_Event);
package GLFW_Vulkan.Input.Scoped_Binding is
   --  The access discriminant makes the window outlive the binding by Ada's
   --  normal accessibility rules.  Callback cleanup therefore never depends
   --  on an unchecked pointer to an object that may already have finalized.
   type Binding
     (Window : not null access GLFW_Vulkan.Windows.Window) is
     new Ada.Finalization.Limited_Controlled with private;
   procedure Attach (Object : in out Binding);
   procedure Detach (Object : in out Binding);

private
   type Binding
     (Window : not null access GLFW_Vulkan.Windows.Window) is
     new Ada.Finalization.Limited_Controlled with record
      Token : GLFW_Vulkan.Input.Callback_Binding_Token;
   end record;
   overriding procedure Finalize (Object : in out Binding);
end GLFW_Vulkan.Input.Scoped_Binding;

with Ada.Exceptions;
with GLFW_Vulkan.Input_Registry;

package body GLFW_Vulkan.Input.Scoped_Binding is
   procedure Dispatch_Key (Event : GLFW_Vulkan.Input.Key_Event) is
   begin
      On_Key (Event);
   end Dispatch_Key;

   procedure Dispatch_Character
     (Event : GLFW_Vulkan.Input.Character_Event) is
   begin
      On_Character (Event);
   end Dispatch_Character;

   procedure Dispatch_Mouse_Button
     (Event : GLFW_Vulkan.Input.Mouse_Button_Event) is
   begin
      On_Mouse_Button (Event);
   end Dispatch_Mouse_Button;

   procedure Dispatch_Cursor_Position
     (Event : GLFW_Vulkan.Input.Cursor_Position_Event) is
   begin
      On_Cursor_Position (Event);
   end Dispatch_Cursor_Position;

   procedure Dispatch_Scroll (Event : GLFW_Vulkan.Input.Scroll_Event) is
   begin
      On_Scroll (Event);
   end Dispatch_Scroll;

   procedure Dispatch_Focus (Event : GLFW_Vulkan.Input.Focus_Event) is
   begin
      On_Focus (Event);
   end Dispatch_Focus;

   procedure Attach (Object : in out Binding) is
   begin
      if Object.Token.Active then
         raise Program_Error with "GLFW input binding is already attached";
      end if;
      GLFW_Vulkan.Input.Attach_Callbacks
        (Object.Window.all,
         (Key             => Dispatch_Key'Unrestricted_Access,
          Character       => Dispatch_Character'Unrestricted_Access,
          Mouse_Button    => Dispatch_Mouse_Button'Unrestricted_Access,
          Cursor_Position => Dispatch_Cursor_Position'Unrestricted_Access,
          Scroll          => Dispatch_Scroll'Unrestricted_Access,
          Focus           => Dispatch_Focus'Unrestricted_Access),
         Object.Token);
   end Attach;

   procedure Detach (Object : in out Binding) is
   begin
      if Object.Token.Active then
         GLFW_Vulkan.Input.Detach_Callbacks
           (Object.Window.all, Object.Token);
      end if;
   end Detach;

   overriding procedure Finalize (Object : in out Binding) is
   begin
      Detach (Object);
   exception
      when E : others =>
         --  A controlled finalizer must not replace the exception that caused
         --  its enclosing scope to unwind.  Explicit Detach still reports a
         --  failure to callers that can retry while the window remains alive.
         --  Retire the Ada callbacks before diagnostics so no secondary
         --  reporting failure can leave an Unrestricted_Access value live.
         GLFW_Vulkan.Input.Abandon_Callbacks (Object.Token);
         GLFW_Vulkan.Input_Registry.Note_Infrastructure_Failure
           (GLFW_Vulkan.Input.Registry_Infrastructure_Failure,
            Ada.Exceptions.Exception_Name (E));
   end Finalize;
end GLFW_Vulkan.Input.Scoped_Binding;

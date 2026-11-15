with C_String_Ownership;
with Interfaces.C.Strings;
with GLFW_Vulkan.Raw;
with GLFW_Vulkan.Windows.Internal;

package body GLFW_Vulkan.Clipboard is
   use type Interfaces.C.Strings.chars_ptr;

   function Get_Text (W : GLFW_Vulkan.Windows.Window) return String is
      Ptr : constant Interfaces.C.Strings.chars_ptr :=
        Raw.Get_Clipboard_String (GLFW_Vulkan.Windows.Internal.Handle (W));
   begin
      if Ptr = Interfaces.C.Strings.Null_Ptr then
         return "";
      else
         return Interfaces.C.Strings.Value (Ptr);
      end if;
   end Get_Text;

   procedure Set_Text
     (W    : GLFW_Vulkan.Windows.Window;
      Text : String)
   is
      C_Text : C_String_Ownership.Owner;
   begin
      C_String_Ownership.Set (C_Text, Text);
      Raw.Set_Clipboard_String
        (GLFW_Vulkan.Windows.Internal.Handle (W),
         C_String_Ownership.Unsafe_Pointer (C_Text));
   end Set_Text;
end GLFW_Vulkan.Clipboard;

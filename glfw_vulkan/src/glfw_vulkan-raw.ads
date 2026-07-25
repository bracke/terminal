with Interfaces.C;
with Interfaces.C.Strings;
with System;

package GLFW_Vulkan.Raw is
   type GLFW_Window_Handle is new System.Address;
   Null_Window : constant GLFW_Window_Handle := GLFW_Window_Handle (System.Null_Address);

   GLFW_CLIENT_API : constant Interfaces.C.int := 16#00022001#;
   GLFW_NO_API     : constant Interfaces.C.int := 0;

   GLFW_PRESS   : constant Interfaces.C.int := 1;
   GLFW_RELEASE : constant Interfaces.C.int := 0;
   GLFW_REPEAT  : constant Interfaces.C.int := 2;

   GLFW_MOD_SHIFT   : constant Interfaces.C.int := 16#0001#;
   GLFW_MOD_CONTROL : constant Interfaces.C.int := 16#0002#;
   GLFW_MOD_ALT     : constant Interfaces.C.int := 16#0004#;
   GLFW_MOD_SUPER   : constant Interfaces.C.int := 16#0008#;

   function Init return Interfaces.C.int
     with Import, Convention => C, External_Name => "glfwInit";

   procedure Terminate_GLFW
     with Import, Convention => C, External_Name => "glfwTerminate";

   function Vulkan_Supported return Interfaces.C.int
     with Import, Convention => C, External_Name => "glfwVulkanSupported";

   type Extension_Pointer_Array is
     array (Interfaces.C.unsigned range 0 .. 31) of Interfaces.C.Strings.chars_ptr
     with Convention => C;
   type Extension_Pointer_Array_Access is access all Extension_Pointer_Array;

   function Get_Required_Instance_Extensions
     (Count : access Interfaces.C.unsigned) return Extension_Pointer_Array_Access
     with Import, Convention => C, External_Name => "glfwGetRequiredInstanceExtensions";

   procedure Window_Hint
     (Hint  : Interfaces.C.int;
      Value : Interfaces.C.int)
     with Import, Convention => C, External_Name => "glfwWindowHint";

   function Create_Window
     (Width   : Interfaces.C.int;
      Height  : Interfaces.C.int;
      Title   : Interfaces.C.Strings.chars_ptr;
      Monitor : System.Address;
      Share   : System.Address) return GLFW_Window_Handle
     with Import, Convention => C, External_Name => "glfwCreateWindow";

   procedure Destroy_Window (Window : GLFW_Window_Handle)
     with Import, Convention => C, External_Name => "glfwDestroyWindow";

   function Window_Should_Close (Window : GLFW_Window_Handle) return Interfaces.C.int
     with Import, Convention => C, External_Name => "glfwWindowShouldClose";

   procedure Set_Window_Should_Close
     (Window : GLFW_Window_Handle;
      Value  : Interfaces.C.int)
     with Import, Convention => C, External_Name => "glfwSetWindowShouldClose";

   procedure Set_Window_Title
     (Window : GLFW_Window_Handle;
      Title  : Interfaces.C.Strings.chars_ptr)
     with Import, Convention => C, External_Name => "glfwSetWindowTitle";

   procedure Get_Framebuffer_Size
     (Window : GLFW_Window_Handle;
      Width  : out Interfaces.C.int;
      Height : out Interfaces.C.int)
     with Import, Convention => C, External_Name => "glfwGetFramebufferSize";

   procedure Poll_Events
     with Import, Convention => C, External_Name => "glfwPollEvents";

   procedure Wait_Events
     with Import, Convention => C, External_Name => "glfwWaitEvents";

   procedure Wait_Events_Timeout (Seconds : Interfaces.C.double)
     with Import, Convention => C, External_Name => "glfwWaitEventsTimeout";

   procedure Post_Empty_Event
     with Import, Convention => C, External_Name => "glfwPostEmptyEvent";

   function Get_Clipboard_String
     (Window : GLFW_Window_Handle) return Interfaces.C.Strings.chars_ptr
     with Import, Convention => C, External_Name => "glfwGetClipboardString";

   procedure Set_Clipboard_String
     (Window : GLFW_Window_Handle;
      Text   : Interfaces.C.Strings.chars_ptr)
     with Import, Convention => C, External_Name => "glfwSetClipboardString";

   type Key_Callback_Access is access procedure
     (Window   : GLFW_Window_Handle;
      Key      : Interfaces.C.int;
      Scancode : Interfaces.C.int;
      Action   : Interfaces.C.int;
      Mods     : Interfaces.C.int)
     with Convention => C;

   type Char_Callback_Access is access procedure
     (Window     : GLFW_Window_Handle;
      Code_Point : Interfaces.C.unsigned)
     with Convention => C;

   function Set_Key_Callback
     (Window   : GLFW_Window_Handle;
      Callback : Key_Callback_Access) return Key_Callback_Access
     with Import, Convention => C, External_Name => "glfwSetKeyCallback";

   function Set_Char_Callback
     (Window   : GLFW_Window_Handle;
      Callback : Char_Callback_Access) return Char_Callback_Access
     with Import, Convention => C, External_Name => "glfwSetCharCallback";

   function Create_Window_Surface
     (Instance : System.Address;
      Window   : GLFW_Window_Handle;
      Surface  : System.Address) return Interfaces.C.int
     with Import, Convention => C, External_Name => "glfw_vulkan_create_window_surface";
end GLFW_Vulkan.Raw;

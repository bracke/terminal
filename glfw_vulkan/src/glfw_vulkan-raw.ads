with Interfaces.C;
with Interfaces.C.Strings;
with System;

package GLFW_Vulkan.Raw is
   type GLFW_Window_Handle is new System.Address;
   Null_Window : constant GLFW_Window_Handle := GLFW_Window_Handle (System.Null_Address);
   type GLFW_Cursor_Handle is new System.Address;
   Null_Cursor : constant GLFW_Cursor_Handle := GLFW_Cursor_Handle (System.Null_Address);

   GLFW_CLIENT_API : constant Interfaces.C.int := 16#00022001#;
   GLFW_NO_API     : constant Interfaces.C.int := 0;

   GLFW_PRESS   : constant Interfaces.C.int := 1;
   GLFW_RELEASE : constant Interfaces.C.int := 0;
   GLFW_REPEAT  : constant Interfaces.C.int := 2;

   GLFW_MOUSE_BUTTON_LEFT   : constant Interfaces.C.int := 0;
   GLFW_MOUSE_BUTTON_RIGHT  : constant Interfaces.C.int := 1;
   GLFW_MOUSE_BUTTON_MIDDLE : constant Interfaces.C.int := 2;

   GLFW_ARROW_CURSOR : constant Interfaces.C.int := 16#00036001#;
   GLFW_IBEAM_CURSOR : constant Interfaces.C.int := 16#00036002#;
   GLFW_HAND_CURSOR  : constant Interfaces.C.int := 16#00036004#;

   GLFW_MOD_SHIFT   : constant Interfaces.C.int := 16#0001#;
   GLFW_MOD_CONTROL : constant Interfaces.C.int := 16#0002#;
   GLFW_MOD_ALT     : constant Interfaces.C.int := 16#0004#;
   GLFW_MOD_SUPER   : constant Interfaces.C.int := 16#0008#;

   function Init return Interfaces.C.int
     with Import, Convention => C, External_Name => "glfwInit";

   procedure Terminate_Tracked (Completed : access Interfaces.C.int)
     with Import, Convention => C,
          External_Name => "terminal_glfw_terminate";

   function Vulkan_Supported return Interfaces.C.int
     with Import, Convention => C, External_Name => "glfwVulkanSupported";

   function Get_Required_Instance_Extensions
     (Count : access Interfaces.C.unsigned) return System.Address
     with Import, Convention => C, External_Name => "glfwGetRequiredInstanceExtensions";

   procedure Window_Hint
     (Hint  : Interfaces.C.int;
      Value : Interfaces.C.int)
     with Import, Convention => C, External_Name => "glfwWindowHint";

   procedure Create_Window_Owned
     (Target  : access GLFW_Window_Handle;
      Width   : Interfaces.C.int;
      Height  : Interfaces.C.int;
      Title   : Interfaces.C.Strings.chars_ptr;
      Monitor : System.Address;
      Share   : System.Address)
     with Import, Convention => C,
          External_Name => "terminal_glfw_create_window";

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

   procedure Create_Standard_Cursor_Owned
     (Target : access GLFW_Cursor_Handle;
      Shape  : Interfaces.C.int)
     with Import, Convention => C,
          External_Name => "terminal_glfw_create_standard_cursor";

   procedure Destroy_Cursor (Cursor : GLFW_Cursor_Handle)
     with Import, Convention => C, External_Name => "glfwDestroyCursor";

   procedure Set_Cursor
     (Window : GLFW_Window_Handle;
      Cursor : GLFW_Cursor_Handle)
     with Import, Convention => C, External_Name => "glfwSetCursor";

   procedure Set_Cursor_Tracked
     (Window    : GLFW_Window_Handle;
      Cursor    : GLFW_Cursor_Handle;
      Installed : access Interfaces.C.int)
     with Import, Convention => C,
          External_Name => "terminal_glfw_set_cursor";

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

   type Mouse_Button_Callback_Access is access procedure
     (Window : GLFW_Window_Handle;
      Button : Interfaces.C.int;
      Action : Interfaces.C.int;
      Mods   : Interfaces.C.int)
     with Convention => C;

   type Cursor_Pos_Callback_Access is access procedure
     (Window : GLFW_Window_Handle;
      X_Pos  : Interfaces.C.double;
      Y_Pos  : Interfaces.C.double)
     with Convention => C;

   type Scroll_Callback_Access is access procedure
     (Window   : GLFW_Window_Handle;
      X_Offset : Interfaces.C.double;
      Y_Offset : Interfaces.C.double)
     with Convention => C;

   type Window_Focus_Callback_Access is access procedure
     (Window  : GLFW_Window_Handle;
      Focused : Interfaces.C.int)
     with Convention => C;

   function Set_Key_Callback
     (Window   : GLFW_Window_Handle;
      Callback : Key_Callback_Access) return Key_Callback_Access
     with Import, Convention => C, External_Name => "glfwSetKeyCallback";

   function Set_Char_Callback
     (Window   : GLFW_Window_Handle;
      Callback : Char_Callback_Access) return Char_Callback_Access
     with Import, Convention => C, External_Name => "glfwSetCharCallback";

   function Set_Mouse_Button_Callback
     (Window   : GLFW_Window_Handle;
      Callback : Mouse_Button_Callback_Access)
      return Mouse_Button_Callback_Access
     with Import, Convention => C, External_Name => "glfwSetMouseButtonCallback";

   function Set_Cursor_Pos_Callback
     (Window   : GLFW_Window_Handle;
      Callback : Cursor_Pos_Callback_Access) return Cursor_Pos_Callback_Access
     with Import, Convention => C, External_Name => "glfwSetCursorPosCallback";

   function Set_Scroll_Callback
     (Window   : GLFW_Window_Handle;
      Callback : Scroll_Callback_Access) return Scroll_Callback_Access
     with Import, Convention => C, External_Name => "glfwSetScrollCallback";

   function Set_Window_Focus_Callback
     (Window   : GLFW_Window_Handle;
      Callback : Window_Focus_Callback_Access)
      return Window_Focus_Callback_Access
     with Import, Convention => C, External_Name => "glfwSetWindowFocusCallback";

   procedure Set_Key_Callback_Owned
     (Window    : GLFW_Window_Handle;
      Callback  : Key_Callback_Access;
      Previous  : access Key_Callback_Access;
      Installed : access Interfaces.C.int)
     with Import, Convention => C,
          External_Name => "terminal_glfw_set_key_callback_owned";
   procedure Set_Char_Callback_Owned
     (Window    : GLFW_Window_Handle;
      Callback  : Char_Callback_Access;
      Previous  : access Char_Callback_Access;
      Installed : access Interfaces.C.int)
     with Import, Convention => C,
          External_Name => "terminal_glfw_set_char_callback_owned";
   procedure Set_Mouse_Button_Callback_Owned
     (Window    : GLFW_Window_Handle;
      Callback  : Mouse_Button_Callback_Access;
      Previous  : access Mouse_Button_Callback_Access;
      Installed : access Interfaces.C.int)
     with Import, Convention => C,
          External_Name => "terminal_glfw_set_mouse_button_callback_owned";
   procedure Set_Cursor_Pos_Callback_Owned
     (Window    : GLFW_Window_Handle;
      Callback  : Cursor_Pos_Callback_Access;
      Previous  : access Cursor_Pos_Callback_Access;
      Installed : access Interfaces.C.int)
     with Import, Convention => C,
          External_Name => "terminal_glfw_set_cursor_pos_callback_owned";
   procedure Set_Scroll_Callback_Owned
     (Window    : GLFW_Window_Handle;
      Callback  : Scroll_Callback_Access;
      Previous  : access Scroll_Callback_Access;
      Installed : access Interfaces.C.int)
     with Import, Convention => C,
          External_Name => "terminal_glfw_set_scroll_callback_owned";
   procedure Set_Window_Focus_Callback_Owned
     (Window    : GLFW_Window_Handle;
      Callback  : Window_Focus_Callback_Access;
      Previous  : access Window_Focus_Callback_Access;
      Installed : access Interfaces.C.int)
     with Import, Convention => C,
          External_Name => "terminal_glfw_set_window_focus_callback_owned";

   procedure Get_Cursor_Pos
     (Window : GLFW_Window_Handle;
      X_Pos  : out Interfaces.C.double;
      Y_Pos  : out Interfaces.C.double)
     with Import, Convention => C, External_Name => "glfwGetCursorPos";

   function Create_Window_Surface
     (Instance : System.Address;
      Window   : GLFW_Window_Handle;
      Allocator : System.Address;
      Surface  : System.Address) return Interfaces.C.int
     with Import, Convention => C, External_Name => "glfwCreateWindowSurface";
end GLFW_Vulkan.Raw;

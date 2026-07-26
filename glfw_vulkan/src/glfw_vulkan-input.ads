with GLFW_Vulkan.Windows;

package GLFW_Vulkan.Input is
   type Key_Action is (Press, Release, Repeat);

   type Modifier_Set is record
      Shift   : Boolean := False;
      Control : Boolean := False;
      Alt     : Boolean := False;
      Super   : Boolean := False;
   end record;

   type Key is
     (Unknown,
      Enter, Tab, Backspace, Escape,
      Up, Down, Left, Right, Home, End_Key, Page_Up, Page_Down, Insert, Delete,
      Space,
      Apostrophe, Comma, Minus, Period, Slash,
      Semicolon, Equal, Left_Bracket, Backslash, Right_Bracket, Grave_Accent,
      F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12,
      A, B, C, D, E, F, G, H, I, J, K, L, M,
      N, O, P, Q, R, S, T, U, V, W, X, Y, Z,
      Num_0, Num_1, Num_2, Num_3, Num_4, Num_5, Num_6, Num_7, Num_8, Num_9,
      Kp_0, Kp_1, Kp_2, Kp_3, Kp_4, Kp_5, Kp_6, Kp_7, Kp_8, Kp_9,
      Kp_Decimal, Kp_Divide, Kp_Multiply, Kp_Subtract, Kp_Add,
      Kp_Enter, Kp_Equal);

   type Key_Event is record
      Key       : GLFW_Vulkan.Input.Key := Unknown;
      Raw_Key   : Integer := 0;
      Scancode  : Integer := 0;
      Action    : Key_Action := Release;
      Modifiers : Modifier_Set;
   end record;

   type Character_Event is record
      Code_Point : Wide_Wide_Character := Wide_Wide_Character'Val (0);
   end record;

   type Mouse_Button is (Left, Right, Middle, Other);

   type Mouse_Button_Event is record
      Button     : Mouse_Button := Other;
      Raw_Button : Integer := 0;
      Action     : Key_Action := Release;
      Modifiers  : Modifier_Set;
      X          : Float := 0.0;
      Y          : Float := 0.0;
   end record;

   type Cursor_Position_Event is record
      X : Float := 0.0;
      Y : Float := 0.0;
   end record;

   type Scroll_Event is record
      X_Offset : Float := 0.0;
      Y_Offset : Float := 0.0;
      X        : Float := 0.0;
      Y        : Float := 0.0;
   end record;

   type Focus_Event is record
      Focused : Boolean := False;
   end record;

   type Key_Callback is access procedure (Event : Key_Event);
   type Character_Callback is access procedure (Event : Character_Event);
   type Mouse_Button_Callback is access procedure (Event : Mouse_Button_Event);
   type Cursor_Position_Callback is access procedure
     (Event : Cursor_Position_Event);
   type Scroll_Callback is access procedure (Event : Scroll_Event);
   type Focus_Callback is access procedure (Event : Focus_Event);

   procedure Set_Key_Callback
     (W        : in out GLFW_Vulkan.Windows.Window;
      Callback : Key_Callback);

   procedure Set_Character_Callback
     (W        : in out GLFW_Vulkan.Windows.Window;
      Callback : Character_Callback);

   procedure Set_Mouse_Button_Callback
     (W        : in out GLFW_Vulkan.Windows.Window;
      Callback : Mouse_Button_Callback);

   procedure Set_Cursor_Position_Callback
     (W        : in out GLFW_Vulkan.Windows.Window;
      Callback : Cursor_Position_Callback);

   procedure Set_Scroll_Callback
     (W        : in out GLFW_Vulkan.Windows.Window;
      Callback : Scroll_Callback);

   procedure Set_Focus_Callback
     (W        : in out GLFW_Vulkan.Windows.Window;
      Callback : Focus_Callback);
end GLFW_Vulkan.Input;

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
      F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12,
      A, B, C, D, E, F, G, H, I, J, K, L, M,
      N, O, P, Q, R, S, T, U, V, W, X, Y, Z,
      Num_0, Num_1, Num_2, Num_3, Num_4, Num_5, Num_6, Num_7, Num_8, Num_9);

   type Key_Event is record
      Key       : GLFW_Vulkan.Input.Key;
      Raw_Key   : Integer;
      Scancode  : Integer;
      Action    : Key_Action;
      Modifiers : Modifier_Set;
   end record;

   type Character_Event is record
      Code_Point : Wide_Wide_Character;
   end record;

   type Key_Callback is access procedure (Event : Key_Event);
   type Character_Callback is access procedure (Event : Character_Event);

   procedure Set_Key_Callback
     (W        : in out GLFW_Vulkan.Windows.Window;
      Callback : Key_Callback);

   procedure Set_Character_Callback
     (W        : in out GLFW_Vulkan.Windows.Window;
      Callback : Character_Callback);
end GLFW_Vulkan.Input;

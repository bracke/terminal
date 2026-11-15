with Interfaces;
with GLFW_Vulkan.Raw;
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

   type Callback_Set is record
      Key             : Key_Callback := null;
      Character       : Character_Callback := null;
      Mouse_Button    : Mouse_Button_Callback := null;
      Cursor_Position : Cursor_Position_Callback := null;
      Scroll          : Scroll_Callback := null;
      Focus           : Focus_Callback := null;
   end record;

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

   --  Remove every callback associated with W.  Window destruction calls this
   --  automatically so nested Ada callbacks cannot outlive their scope.
   procedure Clear_Callbacks (W : in out GLFW_Vulkan.Windows.Window);

   --  Exceptions cannot cross GLFW's C callback boundary. This counter makes
   --  callback failures observable to diagnostics and tests.
   type Failure_Source is
     (No_Failure,
      Key_Callback_Failure,
      Character_Callback_Failure,
      Mouse_Button_Callback_Failure,
      Cursor_Position_Callback_Failure,
      Scroll_Callback_Failure,
      Focus_Callback_Failure,
      Registry_Infrastructure_Failure);
   Max_Exception_Name_Length : constant := 128;
   subtype Exception_Name_Length is
     Natural range 0 .. Max_Exception_Name_Length;
   type Failure_Detail is record
      Source : Failure_Source := No_Failure;
      Exception_Name : String (1 .. Max_Exception_Name_Length) :=
        (others => ASCII.NUL);
      Name_Length : Exception_Name_Length := 0;
   end record;
   type Failure_Snapshot is record
      Callback_Count       : Natural := 0;
      Callback_Detail      : Failure_Detail;
      Infrastructure_Count : Natural := 0;
      Infrastructure_Detail : Failure_Detail;
   end record;

   function Failure_Diagnostics return Failure_Snapshot;

private
   type Raw_Callback_Set is record
      Key        : aliased GLFW_Vulkan.Raw.Key_Callback_Access := null;
      Character  : aliased GLFW_Vulkan.Raw.Char_Callback_Access := null;
      Mouse      : aliased GLFW_Vulkan.Raw.Mouse_Button_Callback_Access := null;
      Cursor     : aliased GLFW_Vulkan.Raw.Cursor_Pos_Callback_Access := null;
      Scroll     : aliased GLFW_Vulkan.Raw.Scroll_Callback_Access := null;
      Focus      : aliased GLFW_Vulkan.Raw.Window_Focus_Callback_Access := null;
   end record;
   type Callback_Channel is
     (Key_Channel,
      Character_Channel,
      Mouse_Channel,
      Cursor_Channel,
      Scroll_Channel,
      Focus_Channel);
   type Callback_Channel_Set is
     array (Callback_Channel) of aliased Interfaces.C.int;

   type Set_Key_Operation is access procedure
     (Window   : GLFW_Vulkan.Raw.GLFW_Window_Handle;
      Callback : GLFW_Vulkan.Raw.Key_Callback_Access;
      Previous : access GLFW_Vulkan.Raw.Key_Callback_Access;
      Installed : access Interfaces.C.int)
     with Convention => C;
   type Set_Character_Operation is access procedure
     (Window   : GLFW_Vulkan.Raw.GLFW_Window_Handle;
      Callback : GLFW_Vulkan.Raw.Char_Callback_Access;
      Previous : access GLFW_Vulkan.Raw.Char_Callback_Access;
      Installed : access Interfaces.C.int)
     with Convention => C;
   type Set_Mouse_Operation is access procedure
     (Window   : GLFW_Vulkan.Raw.GLFW_Window_Handle;
      Callback : GLFW_Vulkan.Raw.Mouse_Button_Callback_Access;
      Previous : access GLFW_Vulkan.Raw.Mouse_Button_Callback_Access;
      Installed : access Interfaces.C.int)
     with Convention => C;
   type Set_Cursor_Operation is access procedure
     (Window   : GLFW_Vulkan.Raw.GLFW_Window_Handle;
      Callback : GLFW_Vulkan.Raw.Cursor_Pos_Callback_Access;
      Previous : access GLFW_Vulkan.Raw.Cursor_Pos_Callback_Access;
      Installed : access Interfaces.C.int)
     with Convention => C;
   type Set_Scroll_Operation is access procedure
     (Window   : GLFW_Vulkan.Raw.GLFW_Window_Handle;
      Callback : GLFW_Vulkan.Raw.Scroll_Callback_Access;
      Previous : access GLFW_Vulkan.Raw.Scroll_Callback_Access;
      Installed : access Interfaces.C.int)
     with Convention => C;
   type Set_Focus_Operation is access procedure
     (Window   : GLFW_Vulkan.Raw.GLFW_Window_Handle;
      Callback : GLFW_Vulkan.Raw.Window_Focus_Callback_Access;
      Previous : access GLFW_Vulkan.Raw.Window_Focus_Callback_Access;
      Installed : access Interfaces.C.int)
     with Convention => C;
   type Callback_Backend is record
      Set_Key       : not null Set_Key_Operation;
      Set_Character : not null Set_Character_Operation;
      Set_Mouse     : not null Set_Mouse_Operation;
      Set_Cursor    : not null Set_Cursor_Operation;
      Set_Scroll    : not null Set_Scroll_Operation;
      Set_Focus     : not null Set_Focus_Operation;
   end record;
   procedure Configure_Callback_Backend (Value : Callback_Backend);
   procedure Reset_Callback_Backend;

   type Callback_Binding_Token is record
      Window : GLFW_Vulkan.Raw.GLFW_Window_Handle :=
        GLFW_Vulkan.Raw.Null_Window;
      Owner : Interfaces.Unsigned_64 := 0;
      Previous : Callback_Set;
      Previous_Raw : aliased Raw_Callback_Set;
      Installed : aliased Callback_Channel_Set := (others => 0);
      Active : Boolean := False;
   end record;

   procedure Attach_Callbacks
     (W         : in out GLFW_Vulkan.Windows.Window;
      Callbacks : Callback_Set;
      Token     : in out Callback_Binding_Token);
   procedure Detach_Callbacks
     (W     : in out GLFW_Vulkan.Windows.Window;
      Token : in out Callback_Binding_Token);
   procedure Abandon_Callbacks (Token : in out Callback_Binding_Token);
end GLFW_Vulkan.Input;

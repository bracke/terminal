with Interfaces;
with System;

package GLFW_Vulkan.Input.Testing is
   subtype Binding_Owner is Interfaces.Unsigned_64;
   procedure Claim_Binding
     (Handle       : System.Address;
      Owner        : out Binding_Owner;
      Previous_Key : out Key_Callback);
   procedure Set_Bound_Key
     (Handle   : System.Address;
      Owner    : Binding_Owner;
      Callback : Key_Callback);
   procedure Restore_Binding
     (Handle       : System.Address;
      Owner        : Binding_Owner;
      Previous_Key : Key_Callback);
   procedure Use_Fake_Callback_Backend;
   procedure Restore_Native_Callback_Backend;
   procedure Reset_Fake_Callback_Backend;
   procedure Fail_Fake_Callback_Install_At (Call : Natural);
   procedure Fail_Fake_Callback_Installs_At
     (First_Call, Second_Call : Natural);
   function Fake_Callback_Call_Count return Natural;
   function Fake_Callbacks_Are_Restored return Boolean;
   function Fake_Callbacks_Are_Cleared return Boolean;
   procedure Set_Key_Callback
     (Handle : System.Address; Callback : Key_Callback);
   procedure Set_Key_Callback_Paused
     (Handle : System.Address; Callback : Key_Callback);
   procedure Wait_Until_Mutation_Paused;
   procedure Release_Paused_Mutation;
   function Waiting_Dispatch_Count (Handle : System.Address) return Natural;
   function Retirement_In_Progress (Handle : System.Address) return Boolean;
   procedure Set_Character_Callback
     (Handle : System.Address; Callback : Character_Callback);
   procedure Set_Mouse_Button_Callback
     (Handle : System.Address; Callback : Mouse_Button_Callback);
   procedure Set_Cursor_Position_Callback
     (Handle : System.Address; Callback : Cursor_Position_Callback);
   procedure Set_Scroll_Callback
     (Handle : System.Address; Callback : Scroll_Callback);
   procedure Set_Focus_Callback
     (Handle : System.Address; Callback : Focus_Callback);
   procedure Clear_Callbacks (Handle : System.Address);
   procedure Abandon_Clear (Handle : System.Address);
   procedure Retire (Handle : System.Address);
   procedure Dispatch_Key
     (Handle : System.Address; Raw_Key : Integer := 65);
   procedure Dispatch_Character (Handle : System.Address);
   procedure Dispatch_Mouse_Button (Handle : System.Address);
   procedure Dispatch_Cursor_Position (Handle : System.Address);
   procedure Dispatch_Scroll (Handle : System.Address);
   procedure Dispatch_Focus (Handle : System.Address);
   procedure Reset_Cursor_Read_Count;
   function Cursor_Read_Count return Natural;
   procedure Reset_Callback_Failures;
   procedure Reset_Infrastructure_Failures;
end GLFW_Vulkan.Input.Testing;

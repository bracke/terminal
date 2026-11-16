with GLFW_Vulkan.Input;
with System;

package Terminal.App.Platform_IME is
   Max_Preedit_Bytes : constant := 512;
   type Install_Status is (Installed, Unsupported, Install_Failed);

   procedure Initialize (Window : System.Address; Status : out Install_Status);
   procedure Finalize;
   function Active return Boolean;
   function Process_Key (Event : GLFW_Vulkan.Input.Key_Event) return Boolean;
   --  XIM produces the committed text itself, while GLFW subsequently emits
   --  the same character callback for the original key event.  This consumes
   --  exactly those duplicate callbacks.  Other backends leave it false.
   function Suppress_Next_GLFW_Character return Boolean;
   procedure Set_Focused (Focused : Boolean);
   procedure Set_Cursor_Rectangle (X, Y, Width, Height : Natural);

   function Preedit_Active return Boolean;
   function Preedit_Text return String;
   function Status_Label return String;
   procedure Poll_Commit
     (Code_Point : out Wide_Wide_Character;
      Available  : out Boolean);
end Terminal.App.Platform_IME;

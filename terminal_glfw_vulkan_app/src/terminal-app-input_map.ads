with GLFW_Vulkan.Input;
with Terminal.Core;
with Terminal.App.Queues;
with Terminal.App.Splits;
with Terminal.App.Tabs;

package Terminal.App.Input_Map is
   Max_Input_Status_Label_Length : constant := 96;
   Max_Mouse_Status_Label_Length : constant := 96;

   function Is_Paste_Shortcut
     (Event : GLFW_Vulkan.Input.Key_Event) return Boolean;

   function Is_Copy_Shortcut
     (Event : GLFW_Vulkan.Input.Key_Event) return Boolean;

   function Tab_Command
     (Event : GLFW_Vulkan.Input.Key_Event) return Terminal.App.Tabs.Tab_Command;

   function Split_Command
     (Event : GLFW_Vulkan.Input.Key_Event)
      return Terminal.App.Splits.Split_Command;

   function Is_Primary_Paste_Button
     (Event : GLFW_Vulkan.Input.Mouse_Button_Event) return Boolean;

   function Local_Mouse_Selection_Override
     (Event : GLFW_Vulkan.Input.Mouse_Button_Event) return Boolean;

   function Suppressed_Character
     (Event : GLFW_Vulkan.Input.Key_Event;
      Modes : Terminal.Core.Mode_Snapshot) return Wide_Wide_Character;

   procedure Encode_Key
     (Event : GLFW_Vulkan.Input.Key_Event;
      Modes : Terminal.Core.Mode_Snapshot;
      Chunk : out Terminal.App.Queues.Byte_Chunk);

   procedure Encode_Character
     (Event : GLFW_Vulkan.Input.Character_Event;
      Chunk : out Terminal.App.Queues.Byte_Chunk);

   procedure Encode_Paste_Text
     (Text  : String;
      Modes : Terminal.Core.Mode_Snapshot;
      Chunk : out Terminal.App.Queues.Byte_Chunk);

   function Paste_Status_Label
     (Modes : Terminal.Core.Mode_Snapshot) return String;

   function Focus_Status_Label
     (Modes : Terminal.Core.Mode_Snapshot) return String;

   function Keyboard_Status_Label
     (Modes : Terminal.Core.Mode_Snapshot) return String;

   function Key_Mode_Status_Label
     (Modes : Terminal.Core.Mode_Snapshot) return String;

   function Input_Status_Label
     (Modes : Terminal.Core.Mode_Snapshot) return String;

   function Mouse_Reporting_Enabled
     (Modes : Terminal.Core.Mode_Snapshot) return Boolean;
   function Mouse_Status_Label
     (Modes : Terminal.Core.Mode_Snapshot) return String;

   procedure Encode_Mouse_Button
     (Event : GLFW_Vulkan.Input.Mouse_Button_Event;
      Modes : Terminal.Core.Mode_Snapshot;
      Row   : Positive;
      Col   : Positive;
      Chunk : out Terminal.App.Queues.Byte_Chunk);

   procedure Encode_Mouse_Motion
     (Event       : GLFW_Vulkan.Input.Cursor_Position_Event;
      Modes       : Terminal.Core.Mode_Snapshot;
      Row         : Positive;
      Col         : Positive;
      Button_Down : Boolean;
      Button_Code : Natural;
      Modifiers   : GLFW_Vulkan.Input.Modifier_Set;
      Chunk       : out Terminal.App.Queues.Byte_Chunk);

   procedure Encode_Mouse_Wheel
     (Event : GLFW_Vulkan.Input.Scroll_Event;
      Modes : Terminal.Core.Mode_Snapshot;
      Row   : Positive;
      Col   : Positive;
      Chunk : out Terminal.App.Queues.Byte_Chunk);

   procedure Encode_Focus
     (Event : GLFW_Vulkan.Input.Focus_Event;
      Modes : Terminal.Core.Mode_Snapshot;
      Chunk : out Terminal.App.Queues.Byte_Chunk);
end Terminal.App.Input_Map;

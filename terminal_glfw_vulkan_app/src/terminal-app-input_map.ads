with GLFW_Vulkan.Input;
with Terminal.Core;
with Terminal.App.Queues;

package Terminal.App.Input_Map is
   function Is_Paste_Shortcut
     (Event : GLFW_Vulkan.Input.Key_Event) return Boolean;

   function Is_Copy_Shortcut
     (Event : GLFW_Vulkan.Input.Key_Event) return Boolean;

   function Is_Primary_Paste_Button
     (Event : GLFW_Vulkan.Input.Mouse_Button_Event) return Boolean;

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

   function Mouse_Reporting_Enabled
     (Modes : Terminal.Core.Mode_Snapshot) return Boolean;

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

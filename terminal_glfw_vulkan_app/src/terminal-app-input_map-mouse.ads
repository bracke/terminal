with GLFW_Vulkan.Input;
with Terminal.App.Queues;
with Terminal.Core;

private package Terminal.App.Input_Map.Mouse is
   procedure Encode_Button
     (Event : GLFW_Vulkan.Input.Mouse_Button_Event;
      Modes : Terminal.Core.Mode_Snapshot;
      Row   : Positive;
      Col   : Positive;
      Chunk : out Terminal.App.Queues.Byte_Chunk);

   procedure Encode_Motion
     (Event       : GLFW_Vulkan.Input.Cursor_Position_Event;
      Modes       : Terminal.Core.Mode_Snapshot;
      Row         : Positive;
      Col         : Positive;
      Button_Down : Boolean;
      Button_Code : Natural;
      Modifiers   : GLFW_Vulkan.Input.Modifier_Set;
      Chunk       : out Terminal.App.Queues.Byte_Chunk);

   procedure Encode_Wheel
     (Event : GLFW_Vulkan.Input.Scroll_Event;
      Modes : Terminal.Core.Mode_Snapshot;
      Row   : Positive;
      Col   : Positive;
      Chunk : out Terminal.App.Queues.Byte_Chunk);

end Terminal.App.Input_Map.Mouse;

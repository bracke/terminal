with GLFW_Vulkan.Input;
with Terminal.Core;
with Terminal.App.Queues;

package Terminal.App.Input_Map is
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
end Terminal.App.Input_Map;

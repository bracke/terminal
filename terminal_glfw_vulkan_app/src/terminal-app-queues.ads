with Terminal.Common.Bytes;
with GLFW_Vulkan.Input;

package Terminal.App.Queues is
   Max_Chunk_Length : constant := 4096;
   Max_Chunks       : constant := 64;
   Max_Input_Events : constant := 256;

   subtype Chunk_Index is Positive range 1 .. Max_Chunk_Length;
   subtype Queue_Index is Positive range 1 .. Max_Chunks;

   type Byte_Chunk is record
      Length : Natural range 0 .. Max_Chunk_Length := 0;
      Data   : Terminal.Common.Bytes.Byte_Array (Chunk_Index) := (others => 0);
   end record;
   type Byte_Chunk_Ring is array (Queue_Index) of Byte_Chunk;

   protected type PTY_Output_Queue is
      procedure Push (Chunk : Byte_Chunk);
      procedure Pop (Chunk : out Byte_Chunk; Available : out Boolean);
      function Overflow_Count return Natural;
      function Length return Natural;
   private
      Items     : Byte_Chunk_Ring;
      Head      : Queue_Index := Queue_Index'First;
      Tail      : Queue_Index := Queue_Index'First;
      Count     : Natural range 0 .. Max_Chunks := 0;
      Overflows : Natural := 0;
   end PTY_Output_Queue;

   type Input_Event_Kind is
     (Bytes,
      Key,
      Character,
      Mouse_Button,
      Cursor_Position,
      Scroll,
      Focus,
      Close_Request,
      Resize_Request);

   type Input_Event is record
      Kind   : Input_Event_Kind := Bytes;
      Width  : Natural := 0;
      Height : Natural := 0;
      Bytes  : Byte_Chunk;
      Key_Event       : GLFW_Vulkan.Input.Key_Event;
      Character_Event : GLFW_Vulkan.Input.Character_Event;
      Button_Event    : GLFW_Vulkan.Input.Mouse_Button_Event;
      Cursor_Event    : GLFW_Vulkan.Input.Cursor_Position_Event;
      Scroll_Event    : GLFW_Vulkan.Input.Scroll_Event;
      Focus_Event     : GLFW_Vulkan.Input.Focus_Event;
   end record;
   type Input_Event_Ring is array (Positive range 1 .. Max_Input_Events) of Input_Event;

   protected type Input_Event_Queue is
      procedure Push (Event : Input_Event);
      procedure Pop (Event : out Input_Event; Available : out Boolean);
      function Overflow_Count return Natural;
      function Length return Natural;
   private
      Items     : Input_Event_Ring;
      Head      : Positive range 1 .. Max_Input_Events := 1;
      Tail      : Positive range 1 .. Max_Input_Events := 1;
      Count     : Natural range 0 .. Max_Input_Events := 0;
      Overflows : Natural := 0;
   end Input_Event_Queue;
end Terminal.App.Queues;

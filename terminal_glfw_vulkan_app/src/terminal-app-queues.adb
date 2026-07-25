with GLFW_Vulkan.Input;

package body Terminal.App.Queues is
   function Next_Chunk (I : Queue_Index) return Queue_Index is
     (if I = Queue_Index'Last then Queue_Index'First else I + 1);

   protected body PTY_Output_Queue is
      procedure Push (Chunk : Byte_Chunk) is
      begin
         if Count = Max_Chunks then
            Overflows := Overflows + 1;
            return;
         end if;
         Items (Tail) := Chunk;
         Tail := Next_Chunk (Tail);
         Count := Count + 1;
      end Push;

      procedure Pop (Chunk : out Byte_Chunk; Available : out Boolean) is
      begin
         if Count = 0 then
            Chunk := (others => <>);
            Available := False;
            return;
         end if;
         Chunk := Items (Head);
         Head := Next_Chunk (Head);
         Count := Count - 1;
         Available := True;
      end Pop;

      function Overflow_Count return Natural is (Overflows);
      function Length return Natural is (Count);
   end PTY_Output_Queue;

   function Next_Input (I : Positive) return Positive is
     (if I = Max_Input_Events then 1 else I + 1);

   protected body Input_Event_Queue is
      procedure Push (Event : Input_Event) is
      begin
         if Count = Max_Input_Events then
            Overflows := Overflows + 1;
            return;
         end if;
         Items (Tail) := Event;
         Tail := Next_Input (Tail);
         Count := Count + 1;
      end Push;

      procedure Pop (Event : out Input_Event; Available : out Boolean) is
      begin
         if Count = 0 then
            Event :=
              (Kind            => Bytes,
               Width           => 0,
               Height          => 0,
               Bytes           => (others => <>),
               Key_Event       =>
                 (Key       => GLFW_Vulkan.Input.Unknown,
                  Raw_Key   => 0,
                  Scancode  => 0,
                  Action    => GLFW_Vulkan.Input.Release,
                  Modifiers => (others => False)),
               Character_Event =>
                 (Code_Point => Wide_Wide_Character'Val (0)),
               Button_Event    => (others => <>),
               Cursor_Event    => (others => <>));
            Available := False;
            return;
         end if;
         Event := Items (Head);
         Head := Next_Input (Head);
         Count := Count - 1;
         Available := True;
      end Pop;

      function Overflow_Count return Natural is (Overflows);
      function Length return Natural is (Count);
   end Input_Event_Queue;
end Terminal.App.Queues;

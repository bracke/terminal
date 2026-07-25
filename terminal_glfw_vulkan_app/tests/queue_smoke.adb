with AUnit.Assertions;

with GLFW_Vulkan.Input;
with Terminal.App.Queues;
with Terminal.Common.Bytes;

procedure Queue_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.App.Queues.Input_Event_Kind;

   package Q renames Terminal.App.Queues;

   PTY : Q.PTY_Output_Queue;
   Input : Q.Input_Event_Queue;

   procedure Push_PTY_Byte (Value : Byte) is
      Chunk : Q.Byte_Chunk;
   begin
      Chunk := (others => <>);
      Chunk.Length := 1;
      Chunk.Data (1) := Value;
      PTY.Push (Chunk);
   end Push_PTY_Byte;

   procedure Push_Input_Byte (Value : Byte) is
      Chunk : Q.Byte_Chunk;
      Event : Q.Input_Event;
   begin
      Chunk := (others => <>);
      Chunk.Length := 1;
      Chunk.Data (1) := Value;
      Event :=
        (Kind => Q.Bytes,
         Width => 0,
         Height => 0,
         Bytes => Chunk,
         Key_Event =>
           (Key => GLFW_Vulkan.Input.Unknown,
            Raw_Key => 0,
            Scancode => 0,
            Action => GLFW_Vulkan.Input.Release,
            Modifiers => (others => False)),
         Character_Event =>
           (Code_Point => Wide_Wide_Character'Val (0)),
         Button_Event => (others => <>),
         Cursor_Event => (others => <>),
         Scroll_Event => (others => <>),
         Focus_Event => (others => <>));
      Input.Push (Event);
   end Push_Input_Byte;

   procedure Assert_PTY_Byte (Expected : Byte; Message : String) is
      Chunk : Q.Byte_Chunk;
      Available : Boolean;
   begin
      PTY.Pop (Chunk, Available);
      Assert (Available, Message & " available");
      Assert (Chunk.Length = 1, Message & " length");
      Assert (Chunk.Data (1) = Expected, Message & " value");
   end Assert_PTY_Byte;

   procedure Assert_Input_Byte (Expected : Byte; Message : String) is
      Event : Q.Input_Event;
      Available : Boolean;
   begin
      Input.Pop (Event, Available);
      Assert (Available, Message & " available");
      Assert (Event.Kind = Q.Bytes, Message & " kind");
      Assert (Event.Bytes.Length = 1, Message & " length");
      Assert (Event.Bytes.Data (1) = Expected, Message & " value");
   end Assert_Input_Byte;

   Empty_Chunk : Q.Byte_Chunk;
   Empty_Event : Q.Input_Event;
   Available : Boolean;
begin
   for I in 1 .. Q.Max_Chunks loop
      Push_PTY_Byte (Byte (I));
   end loop;
   Assert (PTY.Length = Q.Max_Chunks, "pty queue full length");
   Push_PTY_Byte (16#FF#);
   Assert (PTY.Overflow_Count = 1, "pty overflow count");
   Assert (PTY.Length = Q.Max_Chunks, "pty drop-newest length");

   Assert_PTY_Byte (1, "pty first");
   Assert_PTY_Byte (2, "pty second");
   for I in 3 .. Q.Max_Chunks loop
      Assert_PTY_Byte (Byte (I), "pty ordered");
   end loop;
   PTY.Pop (Empty_Chunk, Available);
   Assert (not Available, "pty empty");

   for I in 1 .. Q.Max_Input_Events loop
      Push_Input_Byte (Byte (I mod 256));
   end loop;
   Assert (Input.Length = Q.Max_Input_Events, "input queue full length");
   Push_Input_Byte (16#EE#);
   Assert (Input.Overflow_Count = 1, "input overflow count");
   Assert (Input.Length = Q.Max_Input_Events, "input drop-newest length");

   Assert_Input_Byte (1, "input first");
   Assert_Input_Byte (2, "input second");
   for I in 3 .. Q.Max_Input_Events loop
      Assert_Input_Byte (Byte (I mod 256), "input ordered");
   end loop;
   Input.Pop (Empty_Event, Available);
   Assert (not Available, "input empty");
end Queue_Smoke;

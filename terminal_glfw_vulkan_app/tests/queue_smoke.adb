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
      Accepted : Boolean;
   begin
      Chunk := (others => <>);
      Chunk.Length := 1;
      Chunk.Data (1) := Value;
      PTY.Push (Chunk, Accepted);
      Assert (Accepted, "pty queue accepts lossless input");
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
   Assert
     (Q.Queue_Status_Label ("pty", PTY.Length, Q.Max_Chunks, PTY.Overflow_Count) =
      "pty queue 0/64",
      "empty pty queue status label");
   Assert
     (Q.Queue_Status_Label
        ("pty", PTY.Length, Q.Max_Chunks, PTY.Overflow_Count)'Length <=
      Q.Max_Status_Label_Length,
      "pty queue status label should be bounded");

   for I in 1 .. Q.Max_Chunks loop
      Push_PTY_Byte (Byte (I));
   end loop;
   Assert (PTY.Length = Q.Max_Chunks, "pty queue full length");
   Assert
     (Q.Queue_Status_Label ("pty", PTY.Length, Q.Max_Chunks, PTY.Overflow_Count) =
      "pty queue 64/64",
      "full pty queue status label");
   Assert (PTY.Overflow_Count = 0, "pty queue never drops bytes");
   Assert (PTY.Length = Q.Max_Chunks, "pty full length remains bounded");
   Assert
     (Q.Queue_Status_Label ("pty", PTY.Length, Q.Max_Chunks, PTY.Overflow_Count) =
      "pty queue 64/64",
      "lossless full pty queue status label");

   declare
      protected Completion is
         procedure Mark (Accepted : Boolean);
         function Done return Boolean;
         function Was_Accepted return Boolean;
      private
         Finished : Boolean := False;
         Accepted : Boolean := False;
      end Completion;

      protected body Completion is
         procedure Mark (Accepted : Boolean) is
         begin
            Completion.Accepted := Accepted;
            Finished := True;
         end Mark;
         function Done return Boolean is (Finished);
         function Was_Accepted return Boolean is (Accepted);
      end Completion;

      task Producer;
      task body Producer is
         Chunk : Q.Byte_Chunk := (others => <>);
         Accepted : Boolean;
      begin
         Chunk.Length := 1;
         Chunk.Data (1) := 16#EE#;
         PTY.Push (Chunk, Accepted);
         Completion.Mark (Accepted);
      end Producer;
   begin
      delay 0.01;
      Assert (not Completion.Done, "full pty queue blocks its producer");
      Assert_PTY_Byte (1, "pty first");
      for Attempt in 1 .. 100 loop
         exit when Completion.Done;
         delay 0.001;
      end loop;
      if not Completion.Done then
         abort Producer;
      end if;
      Assert (Completion.Done, "pty producer resumes after space is available");
      Assert (Completion.Was_Accepted, "resumed pty push is accepted");
   end;
   for I in 2 .. Q.Max_Chunks loop
      Assert_PTY_Byte (Byte (I), "pty ordered");
   end loop;
   Assert_PTY_Byte (16#EE#, "pty blocked producer order");
   PTY.Pop (Empty_Chunk, Available);
   Assert (not Available, "pty empty");

   for I in 1 .. Q.Max_Chunks / 2 loop
      Push_PTY_Byte (Byte (I));
   end loop;
   for I in 1 .. Q.Max_Chunks / 4 loop
      Assert_PTY_Byte (Byte (I), "pty wrap pre-drain");
   end loop;
   for I in Q.Max_Chunks / 2 + 1 .. Q.Max_Chunks / 2 + Q.Max_Chunks / 4 loop
      Push_PTY_Byte (Byte (I));
   end loop;
   Assert (PTY.Length = Q.Max_Chunks / 2, "pty wrapped length");
   for I in Q.Max_Chunks / 4 + 1 .. Q.Max_Chunks / 2 + Q.Max_Chunks / 4 loop
      Assert_PTY_Byte (Byte (I), "pty wrapped order");
   end loop;
   PTY.Pop (Empty_Chunk, Available);
   Assert (not Available, "pty wrapped empty");

   for I in 1 .. Q.Max_Chunks / 2 loop
      Push_PTY_Byte (Byte (I));
   end loop;
   for I in 1 .. Q.Max_Chunks / 4 loop
      Assert_PTY_Byte (Byte (I), "pty overflow wrap pre-drain");
   end loop;
   for I in Q.Max_Chunks / 2 + 1 .. Q.Max_Chunks + Q.Max_Chunks / 4 loop
      Push_PTY_Byte (Byte (I));
   end loop;
   Assert (PTY.Length = Q.Max_Chunks, "pty full wrapped length");
   Assert (PTY.Overflow_Count = 0, "pty wrapped queue remains lossless");
   for I in Q.Max_Chunks / 4 + 1 .. Q.Max_Chunks + Q.Max_Chunks / 4 loop
      Assert_PTY_Byte (Byte (I), "pty overflow wrapped order");
   end loop;
   PTY.Pop (Empty_Chunk, Available);
   Assert (not Available, "pty wrapped empty");

   PTY.Shut_Down;
   declare
      Chunk : Q.Byte_Chunk := (others => <>);
      Accepted : Boolean;
   begin
      Chunk.Length := 1;
      PTY.Push (Chunk, Accepted);
      Assert (not Accepted, "shutdown wakes and rejects pty producers");
   end;

   for I in 1 .. Q.Max_Input_Events loop
      Push_Input_Byte (Byte (I mod 256));
   end loop;
   Assert (Input.Length = Q.Max_Input_Events, "input queue full length");
   Assert
     (Q.Queue_Status_Label
        ("input", Input.Length, Q.Max_Input_Events, Input.Overflow_Count) =
      "input queue 256/256",
      "full input queue status label");
   Push_Input_Byte (16#EE#);
   Assert (Input.Overflow_Count = 1, "input overflow count");
   Assert (Input.Length = Q.Max_Input_Events, "input drop-newest length");
   Assert
     (Q.Queue_Status_Label
        ("input", Input.Length, Q.Max_Input_Events, Input.Overflow_Count) =
      "input queue 256/256; overflows=1",
      "overflow input queue status label");
   Assert
     (Q.Queue_Status_Label
        ("input", Input.Length, Q.Max_Input_Events, Input.Overflow_Count)'Length <=
      Q.Max_Status_Label_Length,
      "input queue status label should be bounded");

   Assert_Input_Byte (1, "input first");
   Assert_Input_Byte (2, "input second");
   for I in 3 .. Q.Max_Input_Events loop
      Assert_Input_Byte (Byte (I mod 256), "input ordered");
   end loop;
   Input.Pop (Empty_Event, Available);
   Assert (not Available, "input empty");

   for I in 1 .. Q.Max_Input_Events / 2 loop
      Push_Input_Byte (Byte (I mod 256));
   end loop;
   for I in 1 .. Q.Max_Input_Events / 4 loop
      Assert_Input_Byte (Byte (I mod 256), "input wrap pre-drain");
   end loop;
   for I in Q.Max_Input_Events / 2 + 1 ..
     Q.Max_Input_Events / 2 + Q.Max_Input_Events / 4
   loop
      Push_Input_Byte (Byte (I mod 256));
   end loop;
   Assert (Input.Length = Q.Max_Input_Events / 2, "input wrapped length");
   for I in Q.Max_Input_Events / 4 + 1 ..
     Q.Max_Input_Events / 2 + Q.Max_Input_Events / 4
   loop
      Assert_Input_Byte (Byte (I mod 256), "input wrapped order");
   end loop;
   Input.Pop (Empty_Event, Available);
   Assert (not Available, "input wrapped empty");

   for I in 1 .. Q.Max_Input_Events / 2 loop
      Push_Input_Byte (Byte (I mod 256));
   end loop;
   for I in 1 .. Q.Max_Input_Events / 4 loop
      Assert_Input_Byte (Byte (I mod 256), "input overflow wrap pre-drain");
   end loop;
   for I in Q.Max_Input_Events / 2 + 1 ..
     Q.Max_Input_Events + Q.Max_Input_Events / 4 + 1
   loop
      Push_Input_Byte (Byte (I mod 256));
   end loop;
   Assert (Input.Length = Q.Max_Input_Events, "input overflow wrapped length");
   Assert (Input.Overflow_Count = 2, "input overflow wrapped count");
   for I in Q.Max_Input_Events / 4 + 1 ..
     Q.Max_Input_Events + Q.Max_Input_Events / 4
   loop
      Assert_Input_Byte (Byte (I mod 256), "input overflow wrapped order");
   end loop;
   Input.Pop (Empty_Event, Available);
   Assert (not Available, "input overflow wrapped empty");

   declare
      Motion : Q.Input_Event :=
        (Kind => Q.Cursor_Position, others => <>);
   begin
      Input.Push (Motion);
      Input.Push (Motion);
      Assert (Input.Length = 1, "adjacent cursor positions coalesce");
      for I in 1 .. Q.Max_Input_Events - 1 loop
         Push_Input_Byte (Byte (I mod 256));
      end loop;
      Push_Input_Byte (16#EE#);
      Assert
        (Input.Length = Q.Max_Input_Events,
         "discrete input replaces queued cursor motion");
      Assert
        (Input.Overflow_Count = 3,
         "discarded cursor motion is counted");
      for I in 1 .. Q.Max_Input_Events - 1 loop
         Assert_Input_Byte
           (Byte (I mod 256), "cursor eviction preserves discrete order");
      end loop;
      Assert_Input_Byte (16#EE#, "new discrete event is retained");
   end;
end Queue_Smoke;

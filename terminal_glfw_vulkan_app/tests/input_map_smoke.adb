with AUnit.Assertions;

with GLFW_Vulkan.Input;
with Terminal.App.Input_Map;
with Terminal.App.Queues;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Input_Map_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type GLFW_Vulkan.Input.Key_Action;

   package GI renames GLFW_Vulkan.Input;
   package IM renames Terminal.App.Input_Map;
   package Q renames Terminal.App.Queues;

   Modes : Terminal.Core.Mode_Snapshot;
   Chunk : Q.Byte_Chunk;

   function Key_Event
     (Key     : GI.Key;
      Action  : GI.Key_Action := GI.Press;
      Shift   : Boolean := False;
      Control : Boolean := False;
      Alt     : Boolean := False) return GI.Key_Event
   is
   begin
      return
        (Key       => Key,
         Raw_Key   => 0,
         Scancode  => 0,
         Action    => Action,
         Modifiers =>
           (Shift => Shift, Control => Control, Alt => Alt, Super => False));
   end Key_Event;

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   procedure Assert_Bytes
     (Actual  : Q.Byte_Chunk;
      Expect  : Byte_Array;
      Message : String)
   is
   begin
      Assert (Actual.Length = Expect'Length, Message & " length");
      for I in Expect'Range loop
         Assert
           (Actual.Data (I - Expect'First + 1) = Expect (I),
            Message & " byte" & Natural'Image (I - Expect'First + 1));
      end loop;
   end Assert_Bytes;
begin
   IM.Encode_Key (Key_Event (GI.Enter), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#0D#), "enter");

   IM.Encode_Key (Key_Event (GI.Backspace), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#7F#), "backspace");

   IM.Encode_Key (Key_Event (GI.C, Control => True), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#03#), "ctrl-c");

   IM.Encode_Key (Key_Event (GI.D, Control => True), Modes, Chunk);
   Assert_Bytes (Chunk, (1 => 16#04#), "ctrl-d");

   IM.Encode_Key (Key_Event (GI.X, Alt => True), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "x"), "alt-x");

   IM.Encode_Key (Key_Event (GI.X, Shift => True, Alt => True), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "X"), "alt-shift-x");

   IM.Encode_Key (Key_Event (GI.Up), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "[A"), "normal up");

   Modes.Application_Cursor := True;
   IM.Encode_Key (Key_Event (GI.Up), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "OA"), "application up");
   Modes.Application_Cursor := False;

   IM.Encode_Key (Key_Event (GI.F5), Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes (ASCII.ESC & "[15~"), "f5");

   IM.Encode_Key (Key_Event (GI.A, Action => GI.Release), Modes, Chunk);
   Assert (Chunk.Length = 0, "release should not encode");

   IM.Encode_Character ((Code_Point => Wide_Wide_Character'Val (16#00E9#)), Chunk);
   Assert_Bytes (Chunk, (1 => 16#C3#, 2 => 16#A9#), "utf8 e-acute");

   IM.Encode_Character ((Code_Point => Wide_Wide_Character'Val (16#1F642#)), Chunk);
   Assert_Bytes
     (Chunk,
      (1 => 16#F0#, 2 => 16#9F#, 3 => 16#99#, 4 => 16#82#),
      "utf8 smile");

   IM.Encode_Paste_Text ("abc", Modes, Chunk);
   Assert_Bytes (Chunk, To_Bytes ("abc"), "plain paste");

   Modes.Bracketed_Paste := True;
   IM.Encode_Paste_Text ("abc", Modes, Chunk);
   Assert_Bytes
     (Chunk,
      To_Bytes (ASCII.ESC & "[200~abc" & ASCII.ESC & "[201~"),
      "bracketed paste");
end Input_Map_Smoke;

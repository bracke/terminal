with Terminal.Common.Bytes;

package body Terminal.App.Input_Map is
   use Terminal.Common.Bytes;
   use GLFW_Vulkan.Input;

   procedure Append (Chunk : in out Terminal.App.Queues.Byte_Chunk; B : Byte) is
   begin
      if Chunk.Length < Terminal.App.Queues.Max_Chunk_Length then
         Chunk.Length := Chunk.Length + 1;
         Chunk.Data (Chunk.Length) := B;
      end if;
   end Append;

   procedure Append_String (Chunk : in out Terminal.App.Queues.Byte_Chunk; S : String) is
   begin
      for Ch of S loop
         Append (Chunk, Byte (Character'Pos (Ch)));
      end loop;
   end Append_String;

   procedure Encode_UTF8 (CP : Natural; Chunk : in out Terminal.App.Queues.Byte_Chunk) is
   begin
      if CP <= 16#7F# then
         Append (Chunk, Byte (CP));
      elsif CP <= 16#7FF# then
         Append (Chunk, Byte (16#C0# + CP / 64));
         Append (Chunk, Byte (16#80# + CP mod 64));
      elsif CP <= 16#FFFF# then
         Append (Chunk, Byte (16#E0# + CP / 4096));
         Append (Chunk, Byte (16#80# + (CP / 64) mod 64));
         Append (Chunk, Byte (16#80# + CP mod 64));
      else
         Append (Chunk, Byte (16#F0# + CP / 262144));
         Append (Chunk, Byte (16#80# + (CP / 4096) mod 64));
         Append (Chunk, Byte (16#80# + (CP / 64) mod 64));
         Append (Chunk, Byte (16#80# + CP mod 64));
      end if;
   end Encode_UTF8;

   function Alt_Printable (Event : GLFW_Vulkan.Input.Key_Event) return Character is
   begin
      case Event.Key is
         when A => return (if Event.Modifiers.Shift then 'A' else 'a');
         when B => return (if Event.Modifiers.Shift then 'B' else 'b');
         when C => return (if Event.Modifiers.Shift then 'C' else 'c');
         when D => return (if Event.Modifiers.Shift then 'D' else 'd');
         when E => return (if Event.Modifiers.Shift then 'E' else 'e');
         when F => return (if Event.Modifiers.Shift then 'F' else 'f');
         when G => return (if Event.Modifiers.Shift then 'G' else 'g');
         when H => return (if Event.Modifiers.Shift then 'H' else 'h');
         when I => return (if Event.Modifiers.Shift then 'I' else 'i');
         when J => return (if Event.Modifiers.Shift then 'J' else 'j');
         when K => return (if Event.Modifiers.Shift then 'K' else 'k');
         when L => return (if Event.Modifiers.Shift then 'L' else 'l');
         when M => return (if Event.Modifiers.Shift then 'M' else 'm');
         when N => return (if Event.Modifiers.Shift then 'N' else 'n');
         when O => return (if Event.Modifiers.Shift then 'O' else 'o');
         when P => return (if Event.Modifiers.Shift then 'P' else 'p');
         when Q => return (if Event.Modifiers.Shift then 'Q' else 'q');
         when R => return (if Event.Modifiers.Shift then 'R' else 'r');
         when S => return (if Event.Modifiers.Shift then 'S' else 's');
         when T => return (if Event.Modifiers.Shift then 'T' else 't');
         when U => return (if Event.Modifiers.Shift then 'U' else 'u');
         when V => return (if Event.Modifiers.Shift then 'V' else 'v');
         when W => return (if Event.Modifiers.Shift then 'W' else 'w');
         when X => return (if Event.Modifiers.Shift then 'X' else 'x');
         when Y => return (if Event.Modifiers.Shift then 'Y' else 'y');
         when Z => return (if Event.Modifiers.Shift then 'Z' else 'z');
         when Num_0 => return '0';
         when Num_1 => return '1';
         when Num_2 => return '2';
         when Num_3 => return '3';
         when Num_4 => return '4';
         when Num_5 => return '5';
         when Num_6 => return '6';
         when Num_7 => return '7';
         when Num_8 => return '8';
         when Num_9 => return '9';
         when others => return ASCII.NUL;
      end case;
   end Alt_Printable;

   procedure Encode_Key
     (Event : GLFW_Vulkan.Input.Key_Event;
      Modes : Terminal.Core.Mode_Snapshot;
      Chunk : out Terminal.App.Queues.Byte_Chunk)
   is
      Alt_Char : Character;
   begin
      Chunk := (others => <>);
      if Event.Action = Release then
         return;
      end if;

      if Event.Modifiers.Control then
         case Event.Key is
            when C => Append (Chunk, 16#03#);
            when D => Append (Chunk, 16#04#);
            when Z => Append (Chunk, 16#1A#);
            when others => null;
         end case;
         if Chunk.Length > 0 then
            return;
         end if;
      end if;

      if Event.Modifiers.Alt then
         Alt_Char := Alt_Printable (Event);
         if Alt_Char /= ASCII.NUL then
            Append (Chunk, 16#1B#);
            Append (Chunk, Byte (Character'Pos (Alt_Char)));
            return;
         end if;
      end if;

      case Event.Key is
         when Enter      => Append (Chunk, 16#0D#);
         when Tab        => Append (Chunk, 16#09#);
         when Backspace  => Append (Chunk, 16#7F#);
         when Escape     => Append (Chunk, 16#1B#);
         when Up         => Append_String (Chunk, (if Modes.Application_Cursor then ASCII.ESC & "OA" else ASCII.ESC & "[A"));
         when Down       => Append_String (Chunk, (if Modes.Application_Cursor then ASCII.ESC & "OB" else ASCII.ESC & "[B"));
         when Right      => Append_String (Chunk, (if Modes.Application_Cursor then ASCII.ESC & "OC" else ASCII.ESC & "[C"));
         when Left       => Append_String (Chunk, (if Modes.Application_Cursor then ASCII.ESC & "OD" else ASCII.ESC & "[D"));
         when Home       => Append_String (Chunk, ASCII.ESC & "[H");
         when End_Key    => Append_String (Chunk, ASCII.ESC & "[F");
         when Page_Up    => Append_String (Chunk, ASCII.ESC & "[5~");
         when Page_Down  => Append_String (Chunk, ASCII.ESC & "[6~");
         when Insert     => Append_String (Chunk, ASCII.ESC & "[2~");
         when Delete     => Append_String (Chunk, ASCII.ESC & "[3~");
         when F1         => Append_String (Chunk, ASCII.ESC & "OP");
         when F2         => Append_String (Chunk, ASCII.ESC & "OQ");
         when F3         => Append_String (Chunk, ASCII.ESC & "OR");
         when F4         => Append_String (Chunk, ASCII.ESC & "OS");
         when F5         => Append_String (Chunk, ASCII.ESC & "[15~");
         when F6         => Append_String (Chunk, ASCII.ESC & "[17~");
         when F7         => Append_String (Chunk, ASCII.ESC & "[18~");
         when F8         => Append_String (Chunk, ASCII.ESC & "[19~");
         when F9         => Append_String (Chunk, ASCII.ESC & "[20~");
         when F10        => Append_String (Chunk, ASCII.ESC & "[21~");
         when F11        => Append_String (Chunk, ASCII.ESC & "[23~");
         when F12        => Append_String (Chunk, ASCII.ESC & "[24~");
         when others     => null;
      end case;
   end Encode_Key;

   procedure Encode_Character
     (Event : GLFW_Vulkan.Input.Character_Event;
      Chunk : out Terminal.App.Queues.Byte_Chunk)
   is
   begin
      Chunk := (others => <>);
      Encode_UTF8 (Wide_Wide_Character'Pos (Event.Code_Point), Chunk);
   end Encode_Character;

   procedure Encode_Paste_Text
     (Text  : String;
      Modes : Terminal.Core.Mode_Snapshot;
      Chunk : out Terminal.App.Queues.Byte_Chunk)
   is
   begin
      Chunk := (others => <>);
      if Modes.Bracketed_Paste then
         Append_String (Chunk, ASCII.ESC & "[200~");
      end if;

      Append_String (Chunk, Text);

      if Modes.Bracketed_Paste then
         Append_String (Chunk, ASCII.ESC & "[201~");
      end if;
   end Encode_Paste_Text;
end Terminal.App.Input_Map;

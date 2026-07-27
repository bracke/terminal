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

   function Modifier_Code
     (Modifiers : GLFW_Vulkan.Input.Modifier_Set) return Natural
   is
      Code : Natural := 1;
   begin
      if Modifiers.Shift then
         Code := Code + 1;
      end if;
      if Modifiers.Alt then
         Code := Code + 2;
      end if;
      if Modifiers.Control then
         Code := Code + 4;
      end if;
      return Code;
   end Modifier_Code;

   procedure Append_Natural
     (Chunk : in out Terminal.App.Queues.Byte_Chunk;
      Value : Natural)
   is
      Text : constant String := Natural'Image (Value);
   begin
      for Ch of Text loop
         if Ch /= ' ' then
            Append (Chunk, Byte (Character'Pos (Ch)));
         end if;
      end loop;
   end Append_Natural;

   procedure Append_CSI_Final
     (Chunk     : in out Terminal.App.Queues.Byte_Chunk;
      Event     : GLFW_Vulkan.Input.Key_Event;
      Final     : Character;
      Unmodified : String)
   is
      Modifier : constant Natural := Modifier_Code (Event.Modifiers);
   begin
      if Modifier = 1 then
         Append_String (Chunk, Unmodified);
      else
         Append_String (Chunk, ASCII.ESC & "[1;");
         Append_Natural (Chunk, Modifier);
         Append (Chunk, Byte (Character'Pos (Final)));
      end if;
   end Append_CSI_Final;

   procedure Append_CSI_Tilde
     (Chunk     : in out Terminal.App.Queues.Byte_Chunk;
      Event     : GLFW_Vulkan.Input.Key_Event;
      Number    : Natural;
      Unmodified : String)
   is
      Modifier : constant Natural := Modifier_Code (Event.Modifiers);
   begin
      if Modifier = 1 then
         Append_String (Chunk, Unmodified);
      else
         Append (Chunk, 16#1B#);
         Append (Chunk, Byte (Character'Pos ('[')));
         Append_Natural (Chunk, Number);
         Append (Chunk, Byte (Character'Pos (';')));
         Append_Natural (Chunk, Modifier);
         Append (Chunk, Byte (Character'Pos ('~')));
      end if;
   end Append_CSI_Tilde;

   function Keypad_Application_Final
     (Key : GLFW_Vulkan.Input.Key) return Character is
   begin
      case Key is
         when Kp_0        => return 'p';
         when Kp_1        => return 'q';
         when Kp_2        => return 'r';
         when Kp_3        => return 's';
         when Kp_4        => return 't';
         when Kp_5        => return 'u';
         when Kp_6        => return 'v';
         when Kp_7        => return 'w';
         when Kp_8        => return 'x';
         when Kp_9        => return 'y';
         when Kp_Decimal  => return 'n';
         when Kp_Divide   => return 'o';
         when Kp_Multiply => return 'j';
         when Kp_Subtract => return 'm';
         when Kp_Add      => return 'k';
         when Kp_Enter    => return 'M';
         when Kp_Equal    => return 'X';
         when others      => return ASCII.NUL;
      end case;
   end Keypad_Application_Final;

   function Keypad_Printable
     (Key : GLFW_Vulkan.Input.Key) return Wide_Wide_Character is
   begin
      case Key is
         when Kp_0        => return '0';
         when Kp_1        => return '1';
         when Kp_2        => return '2';
         when Kp_3        => return '3';
         when Kp_4        => return '4';
         when Kp_5        => return '5';
         when Kp_6        => return '6';
         when Kp_7        => return '7';
         when Kp_8        => return '8';
         when Kp_9        => return '9';
         when Kp_Decimal  => return '.';
         when Kp_Divide   => return '/';
         when Kp_Multiply => return '*';
         when Kp_Subtract => return '-';
         when Kp_Add      => return '+';
         when Kp_Equal    => return '=';
         when others      => return Wide_Wide_Character'Val (0);
      end case;
   end Keypad_Printable;

   procedure Append_Keypad_Application
     (Chunk : in out Terminal.App.Queues.Byte_Chunk;
      Event : GLFW_Vulkan.Input.Key_Event)
   is
      Final : constant Character := Keypad_Application_Final (Event.Key);
   begin
      if Final /= ASCII.NUL then
         if Event.Modifiers.Alt then
            Append (Chunk, 16#1B#);
         end if;
         Append_String (Chunk, ASCII.ESC & "O");
         Append (Chunk, Byte (Character'Pos (Final)));
      end if;
   end Append_Keypad_Application;

   procedure Append_Return
     (Chunk : in out Terminal.App.Queues.Byte_Chunk;
      Modes : Terminal.Core.Mode_Snapshot)
   is
   begin
      Append (Chunk, 16#0D#);
      if Modes.Linefeed_New_Line then
         Append (Chunk, 16#0A#);
      end if;
   end Append_Return;

   function Mouse_Button_Code
     (Button : GLFW_Vulkan.Input.Mouse_Button) return Natural
   is
   begin
      case Button is
         when Left   => return 0;
         when Middle => return 1;
         when Right  => return 2;
         when others => return 0;
      end case;
   end Mouse_Button_Code;

   function Mouse_Modifier_Code
     (Modifiers : GLFW_Vulkan.Input.Modifier_Set) return Natural
   is
      Code : Natural := 0;
   begin
      if Modifiers.Shift then
         Code := Code + 4;
      end if;
      if Modifiers.Alt then
         Code := Code + 8;
      end if;
      if Modifiers.Control then
         Code := Code + 16;
      end if;
      return Code;
   end Mouse_Modifier_Code;

   procedure Append_Mouse
     (Chunk     : in out Terminal.App.Queues.Byte_Chunk;
      Modes     : Terminal.Core.Mode_Snapshot;
      Code      : Natural;
      Row       : Positive;
      Col       : Positive;
      Release   : Boolean)
   is
   begin
      if Modes.Mouse_SGR then
         Append_String (Chunk, ASCII.ESC & "[<");
         Append_Natural (Chunk, Code);
         Append (Chunk, Byte (Character'Pos (';')));
         Append_Natural (Chunk, Col);
         Append (Chunk, Byte (Character'Pos (';')));
         Append_Natural (Chunk, Row);
         Append (Chunk, Byte (Character'Pos ((if Release then 'm' else 'M'))));
      elsif Col <= 223 and then Row <= 223 and then Code <= 223 then
         Append_String (Chunk, ASCII.ESC & "[M");
         Append (Chunk, Byte (Code + 32));
         Append (Chunk, Byte (Col + 32));
         Append (Chunk, Byte (Row + 32));
      end if;
   end Append_Mouse;

   procedure Encode_UTF8 (CP : Natural; Chunk : in out Terminal.App.Queues.Byte_Chunk) is
   begin
      if CP in 16#D800# .. 16#DFFF# or else CP > 16#10FFFF# then
         return;
      elsif CP <= 16#7F# then
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
         when Kp_0 => return '0';
         when Kp_1 => return '1';
         when Kp_2 => return '2';
         when Kp_3 => return '3';
         when Kp_4 => return '4';
         when Kp_5 => return '5';
         when Kp_6 => return '6';
         when Kp_7 => return '7';
         when Kp_8 => return '8';
         when Kp_9 => return '9';
         when Kp_Decimal => return '.';
         when Kp_Divide => return '/';
         when Kp_Multiply => return '*';
         when Kp_Subtract => return '-';
         when Kp_Add => return '+';
         when Kp_Equal => return '=';
         when Space => return ' ';
         when Apostrophe => return (if Event.Modifiers.Shift then '"' else ''');
         when Comma => return (if Event.Modifiers.Shift then '<' else ',');
         when Minus => return (if Event.Modifiers.Shift then '_' else '-');
         when Period => return (if Event.Modifiers.Shift then '>' else '.');
         when Slash => return (if Event.Modifiers.Shift then '?' else '/');
         when Semicolon => return (if Event.Modifiers.Shift then ':' else ';');
         when Equal => return (if Event.Modifiers.Shift then '+' else '=');
         when Left_Bracket => return (if Event.Modifiers.Shift then '{' else '[');
         when Backslash => return (if Event.Modifiers.Shift then '|' else '\');
         when Right_Bracket => return (if Event.Modifiers.Shift then '}' else ']');
         when Grave_Accent => return (if Event.Modifiers.Shift then '~' else '`');
         when others => return ASCII.NUL;
      end case;
   end Alt_Printable;

   function Control_Byte (Key : GLFW_Vulkan.Input.Key) return Byte is
   begin
      case Key is
         when A => return 16#01#;
         when B => return 16#02#;
         when C => return 16#03#;
         when D => return 16#04#;
         when E => return 16#05#;
         when F => return 16#06#;
         when G => return 16#07#;
         when H => return 16#08#;
         when I => return 16#09#;
         when J => return 16#0A#;
         when K => return 16#0B#;
         when L => return 16#0C#;
         when M => return 16#0D#;
         when N => return 16#0E#;
         when O => return 16#0F#;
         when P => return 16#10#;
         when Q => return 16#11#;
         when R => return 16#12#;
         when S => return 16#13#;
         when T => return 16#14#;
         when U => return 16#15#;
         when V => return 16#16#;
         when W => return 16#17#;
         when X => return 16#18#;
         when Y => return 16#19#;
         when Z => return 16#1A#;
         when Space => return 16#00#;
         when Left_Bracket => return 16#1B#;
         when Backslash => return 16#1C#;
         when Right_Bracket => return 16#1D#;
         when Num_6 => return 16#1E#;
         when Minus => return 16#1F#;
         when Slash => return 16#7F#;
         when others => return 0;
      end case;
   end Control_Byte;

   function Is_Paste_Shortcut
     (Event : GLFW_Vulkan.Input.Key_Event) return Boolean is
   begin
      return Event.Action /= Release
        and then
          ((Event.Key = V
            and then
              ((Event.Modifiers.Control and then Event.Modifiers.Shift)
               or else Event.Modifiers.Super))
           or else
             (Event.Key = Insert
              and then Event.Modifiers.Shift
              and then not Event.Modifiers.Control
              and then not Event.Modifiers.Alt
              and then not Event.Modifiers.Super));
   end Is_Paste_Shortcut;

   function Is_Copy_Shortcut
     (Event : GLFW_Vulkan.Input.Key_Event) return Boolean is
   begin
      return Event.Action /= Release
        and then
          ((Event.Key = C
            and then
              ((Event.Modifiers.Control and then Event.Modifiers.Shift)
               or else Event.Modifiers.Super))
           or else
             (Event.Key = Insert
              and then Event.Modifiers.Control
              and then not Event.Modifiers.Shift
              and then not Event.Modifiers.Alt
              and then not Event.Modifiers.Super));
   end Is_Copy_Shortcut;

   function Tab_Command
     (Event : GLFW_Vulkan.Input.Key_Event) return Terminal.App.Tabs.Tab_Command
   is
   begin
      if Event.Action = Release or else not Event.Modifiers.Control then
         return Terminal.App.Tabs.No_Command;
      elsif Event.Modifiers.Shift
        and then not Event.Modifiers.Alt
        and then not Event.Modifiers.Super
        and then Event.Key = T
      then
         return Terminal.App.Tabs.New_Tab;
      elsif Event.Modifiers.Shift
        and then not Event.Modifiers.Alt
        and then not Event.Modifiers.Super
        and then Event.Key = W
      then
         return Terminal.App.Tabs.Close_Tab;
      elsif not Event.Modifiers.Shift
        and then not Event.Modifiers.Alt
        and then not Event.Modifiers.Super
        and then Event.Key = Page_Down
      then
         return Terminal.App.Tabs.Next_Tab;
      elsif not Event.Modifiers.Shift
        and then not Event.Modifiers.Alt
        and then not Event.Modifiers.Super
        and then Event.Key = Page_Up
      then
         return Terminal.App.Tabs.Previous_Tab;
      else
         return Terminal.App.Tabs.No_Command;
      end if;
   end Tab_Command;

   function Split_Command
     (Event : GLFW_Vulkan.Input.Key_Event)
      return Terminal.App.Splits.Split_Command
   is
   begin
      if Event.Action = Release
        or else not Event.Modifiers.Control
        or else not Event.Modifiers.Shift
        or else Event.Modifiers.Alt
        or else Event.Modifiers.Super
      then
         return Terminal.App.Splits.No_Command;
      elsif Event.Key = H then
         return Terminal.App.Splits.Split_Horizontal;
      elsif Event.Key = V then
         return Terminal.App.Splits.Split_Vertical;
      elsif Event.Key = X then
         return Terminal.App.Splits.Close_Pane;
      elsif Event.Key = L then
         return Terminal.App.Splits.Next_Pane;
      else
         return Terminal.App.Splits.No_Command;
      end if;
   end Split_Command;

   function Is_Primary_Paste_Button
     (Event : GLFW_Vulkan.Input.Mouse_Button_Event) return Boolean is
   begin
      return Event.Action = Press
        and then Event.Button = Middle
        and then not Event.Modifiers.Shift
        and then not Event.Modifiers.Control
        and then not Event.Modifiers.Alt
        and then not Event.Modifiers.Super;
   end Is_Primary_Paste_Button;

   function Local_Mouse_Selection_Override
     (Event : GLFW_Vulkan.Input.Mouse_Button_Event) return Boolean is
   begin
      return Event.Button = Left
        and then Event.Modifiers.Shift
        and then not Event.Modifiers.Control
        and then not Event.Modifiers.Super;
   end Local_Mouse_Selection_Override;

   function Suppressed_Character
     (Event : GLFW_Vulkan.Input.Key_Event;
      Modes : Terminal.Core.Mode_Snapshot) return Wide_Wide_Character is
   begin
      if Event.Action /= Release
        and then Modes.Application_Keypad
        and then not Event.Modifiers.Control
        and then not Event.Modifiers.Super
      then
         return Keypad_Printable (Event.Key);
      else
         return Wide_Wide_Character'Val (0);
      end if;
   end Suppressed_Character;

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

      if Modes.Application_Keypad
        and then Keypad_Application_Final (Event.Key) /= ASCII.NUL
        and then not Event.Modifiers.Control
        and then not Event.Modifiers.Super
      then
         Append_Keypad_Application (Chunk, Event);
         return;
      end if;

      if Event.Key = Backspace
        and then (Event.Modifiers.Control or else Event.Modifiers.Alt)
      then
         if Event.Modifiers.Alt then
            Append (Chunk, 16#1B#);
         end if;
         Append
           (Chunk,
            (if Event.Modifiers.Control
             or else Modes.Backarrow_Key_Backspace
             then 16#08#
             else 16#7F#));
         return;
      end if;

      if Event.Modifiers.Control then
         if Event.Key = Space then
            if Event.Modifiers.Alt then
               Append (Chunk, 16#1B#);
            end if;
            Append (Chunk, 16#00#);
            return;
         end if;

         declare
            Ctrl : constant Byte := Control_Byte (Event.Key);
         begin
            if Ctrl /= 0 then
               if Event.Modifiers.Alt then
                  Append (Chunk, 16#1B#);
               end if;
               Append (Chunk, Ctrl);
               return;
            end if;
         end;
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
         when Enter      => Append_Return (Chunk, Modes);
         when Tab        =>
            if Event.Modifiers.Shift then
               Append_String (Chunk, ASCII.ESC & "[Z");
            else
               Append (Chunk, 16#09#);
            end if;
         when Kp_Enter   =>
            if Event.Modifiers.Alt then
               Append (Chunk, 16#1B#);
            end if;
            Append_Return (Chunk, Modes);
         when Backspace  =>
            Append
              (Chunk,
               (if Modes.Backarrow_Key_Backspace then 16#08# else 16#7F#));
         when Space      =>
            if Event.Modifiers.Alt then
               Append (Chunk, 16#1B#);
               Append (Chunk, Byte (Character'Pos (' ')));
            end if;
         when Escape     => Append (Chunk, 16#1B#);
         when Up         =>
            Append_CSI_Final
              (Chunk, Event, 'A',
               (if Modes.Application_Cursor then ASCII.ESC & "OA" else ASCII.ESC & "[A"));
         when Down       =>
            Append_CSI_Final
              (Chunk, Event, 'B',
               (if Modes.Application_Cursor then ASCII.ESC & "OB" else ASCII.ESC & "[B"));
         when Right      =>
            Append_CSI_Final
              (Chunk, Event, 'C',
               (if Modes.Application_Cursor then ASCII.ESC & "OC" else ASCII.ESC & "[C"));
         when Left       =>
            Append_CSI_Final
              (Chunk, Event, 'D',
               (if Modes.Application_Cursor then ASCII.ESC & "OD" else ASCII.ESC & "[D"));
         when Home       => Append_CSI_Final (Chunk, Event, 'H', ASCII.ESC & "[H");
         when End_Key    => Append_CSI_Final (Chunk, Event, 'F', ASCII.ESC & "[F");
         when Page_Up    => Append_CSI_Tilde (Chunk, Event, 5, ASCII.ESC & "[5~");
         when Page_Down  => Append_CSI_Tilde (Chunk, Event, 6, ASCII.ESC & "[6~");
         when Insert     => Append_CSI_Tilde (Chunk, Event, 2, ASCII.ESC & "[2~");
         when Delete     => Append_CSI_Tilde (Chunk, Event, 3, ASCII.ESC & "[3~");
         when F1         => Append_CSI_Final (Chunk, Event, 'P', ASCII.ESC & "OP");
         when F2         => Append_CSI_Final (Chunk, Event, 'Q', ASCII.ESC & "OQ");
         when F3         => Append_CSI_Final (Chunk, Event, 'R', ASCII.ESC & "OR");
         when F4         => Append_CSI_Final (Chunk, Event, 'S', ASCII.ESC & "OS");
         when F5         => Append_CSI_Tilde (Chunk, Event, 15, ASCII.ESC & "[15~");
         when F6         => Append_CSI_Tilde (Chunk, Event, 17, ASCII.ESC & "[17~");
         when F7         => Append_CSI_Tilde (Chunk, Event, 18, ASCII.ESC & "[18~");
         when F8         => Append_CSI_Tilde (Chunk, Event, 19, ASCII.ESC & "[19~");
         when F9         => Append_CSI_Tilde (Chunk, Event, 20, ASCII.ESC & "[20~");
         when F10        => Append_CSI_Tilde (Chunk, Event, 21, ASCII.ESC & "[21~");
         when F11        => Append_CSI_Tilde (Chunk, Event, 23, ASCII.ESC & "[23~");
         when F12        => Append_CSI_Tilde (Chunk, Event, 24, ASCII.ESC & "[24~");
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

   function Paste_Status_Label
     (Modes : Terminal.Core.Mode_Snapshot) return String is
   begin
      if Modes.Bracketed_Paste then
         return "Bracketed paste active";
      else
         return "Plain paste active";
      end if;
   end Paste_Status_Label;

   function Focus_Status_Label
     (Modes : Terminal.Core.Mode_Snapshot) return String is
   begin
      if Modes.Focus_Reporting then
         return "Focus reporting active";
      else
         return "Focus reporting inactive";
      end if;
   end Focus_Status_Label;

   function Keyboard_Status_Label
     (Modes : Terminal.Core.Mode_Snapshot) return String is
   begin
      if Modes.Keyboard_Locked then
         return "Keyboard input locked";
      else
         return "Keyboard input active";
      end if;
   end Keyboard_Status_Label;

   function Key_Mode_Status_Label
     (Modes : Terminal.Core.Mode_Snapshot) return String
   is
      Result : String (1 .. Max_Input_Status_Label_Length);
      Last   : Natural := 0;

      procedure Append (Text : String) is
      begin
         for Ch of Text loop
            exit when Last = Result'Last;
            Last := Last + 1;
            Result (Last) := Ch;
         end loop;
      end Append;
   begin
      Append ("Keys: ");
      Append
        (if Modes.Application_Cursor
         then "app cursor"
         else "normal cursor");
      Append (", ");
      Append
        (if Modes.Application_Keypad
         then "app keypad"
         else "numeric keypad");
      Append (", ");
      Append
        (if Modes.Backarrow_Key_Backspace
         then "Backspace=BS"
         else "Backspace=DEL");
      Append (", ");
      Append
        (if Modes.Linefeed_New_Line
         then "LF sends CRLF"
         else "LF sends LF");

      return Result (1 .. Last);
   end Key_Mode_Status_Label;

   function Input_Status_Label
     (Modes : Terminal.Core.Mode_Snapshot) return String is
      Keyboard : constant String :=
        (if Modes.Keyboard_Locked then "keyboard locked" else "keyboard active");
      Paste : constant String :=
        (if Modes.Bracketed_Paste then "bracketed paste" else "plain paste");
      Focus : constant String :=
        (if Modes.Focus_Reporting then "focus reporting" else "focus local");
      Mouse : constant String :=
        (if Mouse_Reporting_Enabled (Modes)
         then "mouse reporting"
         else "local mouse");
   begin
      return
        "Input: " & Keyboard & ", " & Paste & ", " & Focus & ", " & Mouse;
   end Input_Status_Label;

   function Mouse_Reporting_Enabled
     (Modes : Terminal.Core.Mode_Snapshot) return Boolean is
   begin
      return Modes.Mouse_Button
        or else Modes.Mouse_Drag
        or else Modes.Mouse_Any_Event;
   end Mouse_Reporting_Enabled;

   function Mouse_Status_Label
     (Modes : Terminal.Core.Mode_Snapshot) return String is
   begin
      if Mouse_Reporting_Enabled (Modes) then
         return "Mouse reporting active; Shift+Left keeps local selection";
      else
         return "Local selection active; wheel scrolls scrollback";
      end if;
   end Mouse_Status_Label;

   procedure Encode_Mouse_Button
     (Event : GLFW_Vulkan.Input.Mouse_Button_Event;
      Modes : Terminal.Core.Mode_Snapshot;
      Row   : Positive;
      Col   : Positive;
      Chunk : out Terminal.App.Queues.Byte_Chunk)
   is
      Release : constant Boolean := Event.Action = GLFW_Vulkan.Input.Release;
      Code    : Natural;
   begin
      Chunk := (others => <>);
      if not Mouse_Reporting_Enabled (Modes)
        or else Event.Action = GLFW_Vulkan.Input.Repeat
        or else Event.Button = GLFW_Vulkan.Input.Other
      then
         return;
      end if;

      Code :=
        (if Release
         then 3
         else Mouse_Button_Code (Event.Button))
        + Mouse_Modifier_Code (Event.Modifiers);
      Append_Mouse (Chunk, Modes, Code, Row, Col, Release);
   end Encode_Mouse_Button;

   procedure Encode_Mouse_Motion
     (Event       : GLFW_Vulkan.Input.Cursor_Position_Event;
      Modes       : Terminal.Core.Mode_Snapshot;
      Row         : Positive;
      Col         : Positive;
      Button_Down : Boolean;
      Button_Code : Natural;
      Modifiers   : GLFW_Vulkan.Input.Modifier_Set;
      Chunk       : out Terminal.App.Queues.Byte_Chunk)
   is
      Code : Natural;
   begin
      Chunk := (others => <>);
      if Modes.Mouse_Any_Event then
         Code := (if Button_Down then Button_Code else 3);
      elsif Modes.Mouse_Drag and then Button_Down then
         Code := Button_Code;
      else
         return;
      end if;

      Code := Code + 32 + Mouse_Modifier_Code (Modifiers);
      Append_Mouse (Chunk, Modes, Code, Row, Col, False);
   end Encode_Mouse_Motion;

   procedure Encode_Mouse_Wheel
     (Event : GLFW_Vulkan.Input.Scroll_Event;
      Modes : Terminal.Core.Mode_Snapshot;
      Row   : Positive;
      Col   : Positive;
      Chunk : out Terminal.App.Queues.Byte_Chunk)
   is
      Code : Natural;
   begin
      Chunk := (others => <>);
      if not Mouse_Reporting_Enabled (Modes)
        or else (Event.X_Offset = 0.0 and then Event.Y_Offset = 0.0)
      then
         return;
      end if;

      if Event.X_Offset > 0.0 then
         Code := 66;
      elsif Event.X_Offset < 0.0 then
         Code := 67;
      else
         Code := (if Event.Y_Offset > 0.0 then 64 else 65);
      end if;
      Append_Mouse (Chunk, Modes, Code, Row, Col, False);
   end Encode_Mouse_Wheel;

   procedure Encode_Focus
     (Event : GLFW_Vulkan.Input.Focus_Event;
      Modes : Terminal.Core.Mode_Snapshot;
      Chunk : out Terminal.App.Queues.Byte_Chunk)
   is
   begin
      Chunk := (others => <>);
      if Modes.Focus_Reporting then
         Append_String
           (Chunk,
            ASCII.ESC & "["
            & (if Event.Focused then "I" else "O"));
      end if;
   end Encode_Focus;
end Terminal.App.Input_Map;

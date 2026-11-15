with Terminal.Common.Bytes;
with Terminal.Common.Status;
with Terminal.App.Input_Map.Status;

package body Terminal.App.Input_Map.Mouse is
   use Terminal.Common.Bytes;
   use GLFW_Vulkan.Input;

   procedure Append (Chunk : in out Terminal.App.Queues.Byte_Chunk; B : Byte) is
   begin
      if Chunk.Length < Terminal.App.Queues.Max_Chunk_Length then
         Chunk.Length := Chunk.Length + 1;
         Chunk.Data (Chunk.Length) := B;
      end if;
   end Append;

   procedure Append_String
     (Chunk : in out Terminal.App.Queues.Byte_Chunk;
      S     : String)
   is
   begin
      for Ch of S loop
         Append (Chunk, Byte (Character'Pos (Ch)));
      end loop;
   end Append_String;

   procedure Append_Natural
     (Chunk : in out Terminal.App.Queues.Byte_Chunk;
      Value : Natural)
   is
      Text : constant String := Terminal.Common.Status.Trimmed_Natural (Value);
   begin
      Append_String (Chunk, Text);
   end Append_Natural;

   function Button_Code (Button : Mouse_Button) return Natural is
   begin
      case Button is
         when Left   => return 0;
         when Middle => return 1;
         when Right  => return 2;
         when others => return 0;
      end case;
   end Button_Code;

   function Modifier_Code (Modifiers : Modifier_Set) return Natural is
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
   end Modifier_Code;

   procedure Append_Mouse
     (Chunk   : in out Terminal.App.Queues.Byte_Chunk;
      Modes   : Terminal.Core.Mode_Snapshot;
      Code    : Natural;
      Row     : Positive;
      Col     : Positive;
      Release : Boolean)
   is
      procedure Append_UTF8_Value (Value : Natural) is
         Encoded : constant Natural := Value + 32;
      begin
         if Encoded <= 16#7F# then
            Append (Chunk, Byte (Encoded));
         elsif Encoded <= 16#7FF# then
            Append (Chunk, Byte (16#C0# + Encoded / 64));
            Append (Chunk, Byte (16#80# + Encoded mod 64));
         elsif Encoded <= 16#FFFF# then
            Append (Chunk, Byte (16#E0# + Encoded / 4096));
            Append (Chunk, Byte (16#80# + (Encoded / 64) mod 64));
            Append (Chunk, Byte (16#80# + Encoded mod 64));
         end if;
      end Append_UTF8_Value;
   begin
      if Modes.Mouse_SGR then
         Append_String (Chunk, ASCII.ESC & "[<");
         Append_Natural (Chunk, Code);
         Append (Chunk, Byte (Character'Pos (';')));
         Append_Natural (Chunk, Col);
         Append (Chunk, Byte (Character'Pos (';')));
         Append_Natural (Chunk, Row);
         Append (Chunk, Byte (Character'Pos ((if Release then 'm' else 'M'))));
      elsif Modes.Mouse_URXVT then
         Append_String (Chunk, ASCII.ESC & "[");
         Append_Natural (Chunk, Code + 32);
         Append (Chunk, Byte (Character'Pos (';')));
         Append_Natural (Chunk, Col);
         Append (Chunk, Byte (Character'Pos (';')));
         Append_Natural (Chunk, Row);
         Append (Chunk, Byte (Character'Pos ('M')));
      elsif Modes.Mouse_UTF8 then
         Append_String (Chunk, ASCII.ESC & "[M");
         Append_UTF8_Value (Code);
         Append_UTF8_Value (Col);
         Append_UTF8_Value (Row);
      elsif Col <= 223 and then Row <= 223 and then Code <= 223 then
         Append_String (Chunk, ASCII.ESC & "[M");
         Append (Chunk, Byte (Code + 32));
         Append (Chunk, Byte (Col + 32));
         Append (Chunk, Byte (Row + 32));
      end if;
   end Append_Mouse;

   procedure Encode_Button
     (Event : Mouse_Button_Event;
      Modes : Terminal.Core.Mode_Snapshot;
      Row   : Positive;
      Col   : Positive;
      Chunk : out Terminal.App.Queues.Byte_Chunk)
   is
      Is_Release : constant Boolean := Event.Action = Release;
      Code       : Natural;
   begin
      Chunk := (others => <>);
      if not Terminal.App.Input_Map.Status.Mouse_Reporting_Enabled (Modes)
        or else Event.Action = Repeat
        or else Event.Button = Other
      then
         return;
      end if;

      Code :=
        (if Is_Release then 3 else Button_Code (Event.Button))
        + Modifier_Code (Event.Modifiers);
      Append_Mouse (Chunk, Modes, Code, Row, Col, Is_Release);
   end Encode_Button;

   procedure Encode_Motion
     (Event       : Cursor_Position_Event;
      Modes       : Terminal.Core.Mode_Snapshot;
      Row         : Positive;
      Col         : Positive;
      Button_Down : Boolean;
      Button_Code : Natural;
      Modifiers   : Modifier_Set;
      Chunk       : out Terminal.App.Queues.Byte_Chunk)
   is
      pragma Unreferenced (Event);
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

      Code := Code + 32 + Modifier_Code (Modifiers);
      Append_Mouse (Chunk, Modes, Code, Row, Col, False);
   end Encode_Motion;

   procedure Encode_Wheel
     (Event : Scroll_Event;
      Modes : Terminal.Core.Mode_Snapshot;
      Row   : Positive;
      Col   : Positive;
      Chunk : out Terminal.App.Queues.Byte_Chunk)
   is
      Code : Natural;
   begin
      Chunk := (others => <>);
      if not Terminal.App.Input_Map.Status.Mouse_Reporting_Enabled (Modes)
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
   end Encode_Wheel;

end Terminal.App.Input_Map.Mouse;

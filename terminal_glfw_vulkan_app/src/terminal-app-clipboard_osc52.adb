with Ada.Characters.Latin_1;
with Terminal.Common.Bytes;

package body Terminal.App.Clipboard_OSC52 is
   use Terminal.Common.Bytes;
   use type Terminal.Core.Clipboard_Target;

   Alphabet : constant String :=
     "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

   procedure Append
     (Chunk : in out Terminal.App.Queues.Byte_Chunk;
      Ch    : Character)
   is
   begin
      if Chunk.Length < Terminal.App.Queues.Max_Chunk_Length then
         Chunk.Length := Chunk.Length + 1;
         Chunk.Data (Chunk.Length) := Byte (Character'Pos (Ch));
      end if;
   end Append;

   procedure Append_Base64_Quartet
     (Chunk : in out Terminal.App.Queues.Byte_Chunk;
      A     : Natural;
      B     : Natural;
      C     : Natural;
      Count : Positive)
   is
      N0 : constant Natural := A / 4;
      N1 : constant Natural := (A mod 4) * 16 + B / 16;
      N2 : constant Natural := (B mod 16) * 4 + C / 64;
      N3 : constant Natural := C mod 64;
   begin
      Append (Chunk, Alphabet (Alphabet'First + N0));
      Append (Chunk, Alphabet (Alphabet'First + N1));
      if Count >= 2 then
         Append (Chunk, Alphabet (Alphabet'First + N2));
      else
         Append (Chunk, '=');
      end if;
      if Count = 3 then
         Append (Chunk, Alphabet (Alphabet'First + N3));
      else
         Append (Chunk, '=');
      end if;
   end Append_Base64_Quartet;

   procedure Store
     (State  : in out Target_Store;
      Target : Terminal.Core.Clipboard_Target;
      Text   : String)
   is
      Count : constant Natural :=
        Natural'Min (Text'Length, Terminal.Core.Max_Clipboard_Length);

      procedure Copy (Slot : in out Stored_Text) is
      begin
         Slot := (others => <>);
         Slot.Length := Count;
         for I in 1 .. Count loop
            Slot.Data (I) := Text (Text'First + I - 1);
         end loop;
      end Copy;
   begin
      if Target = Terminal.Core.Clipboard_Primary then
         Copy (State.Primary);
      elsif Target = Terminal.Core.Clipboard_Selection then
         Copy (State.Selection);
      end if;
   end Store;

   procedure Store_Local_Selection
     (State : in out Target_Store;
      Text  : String)
   is
   begin
      Store (State, Terminal.Core.Clipboard_Primary, Text);
      Store (State, Terminal.Core.Clipboard_Selection, Text);
   end Store_Local_Selection;

   function Text
     (State  : Target_Store;
      Target : Terminal.Core.Clipboard_Target) return String
   is
   begin
      if Target = Terminal.Core.Clipboard_Primary then
         return State.Primary.Data (1 .. State.Primary.Length);
      elsif Target = Terminal.Core.Clipboard_Selection then
         return State.Selection.Data (1 .. State.Selection.Length);
      else
         return "";
      end if;
   end Text;

   procedure Build_Query_Response
     (Target : Terminal.Core.Clipboard_Target;
      Text   : String;
      Chunk  : out Terminal.App.Queues.Byte_Chunk)
   is
      Last_Input : constant Natural :=
        Natural'Min (Text'Length, Max_Query_Text_Bytes);
      Offset     : Natural := 0;
      Target_Char : constant Character :=
        (if Target = Terminal.Core.Clipboard_Primary then 'p'
         elsif Target = Terminal.Core.Clipboard_Selection then 's'
         else 'c');
   begin
      Chunk := (others => <>);
      Append (Chunk, Ada.Characters.Latin_1.ESC);
      Append (Chunk, ']');
      Append (Chunk, '5');
      Append (Chunk, '2');
      Append (Chunk, ';');
      Append (Chunk, Target_Char);
      Append (Chunk, ';');

      while Offset < Last_Input loop
         declare
            Remaining : constant Natural := Last_Input - Offset;
            Count     : constant Positive :=
              (if Remaining >= 3 then 3 else Positive (Remaining));
            A         : constant Natural :=
              Character'Pos (Text (Text'First + Offset));
            B         : constant Natural :=
              (if Count >= 2
               then Character'Pos (Text (Text'First + Offset + 1))
               else 0);
            C         : constant Natural :=
              (if Count = 3
               then Character'Pos (Text (Text'First + Offset + 2))
               else 0);
         begin
            Append_Base64_Quartet (Chunk, A, B, C, Count);
            Offset := Offset + Count;
         end;
      end loop;

      Append (Chunk, Ada.Characters.Latin_1.ESC);
      Append (Chunk, '\');
   end Build_Query_Response;

   procedure Build_Query_Response
     (Text  : String;
      Chunk : out Terminal.App.Queues.Byte_Chunk)
   is
   begin
      Build_Query_Response (Terminal.Core.Clipboard_Clipboard, Text, Chunk);
   end Build_Query_Response;
end Terminal.App.Clipboard_OSC52;

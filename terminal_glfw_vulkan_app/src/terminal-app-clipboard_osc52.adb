with Ada.Characters.Latin_1;
with Terminal.Common.Bytes;

package body Terminal.App.Clipboard_OSC52 is
   use Terminal.Common.Bytes;

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

   procedure Build_Query_Response
     (Text  : String;
      Chunk : out Terminal.App.Queues.Byte_Chunk)
   is
      Last_Input : constant Natural :=
        Natural'Min (Text'Length, Max_Query_Text_Bytes);
      Offset     : Natural := 0;
   begin
      Chunk := (others => <>);
      Append (Chunk, Ada.Characters.Latin_1.ESC);
      Append (Chunk, ']');
      Append (Chunk, '5');
      Append (Chunk, '2');
      Append (Chunk, ';');
      Append (Chunk, 'c');
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
end Terminal.App.Clipboard_OSC52;

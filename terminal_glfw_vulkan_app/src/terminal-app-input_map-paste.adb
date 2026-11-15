with Terminal.Common.Bytes;

package body Terminal.App.Input_Map.Paste is
   use Terminal.Common.Bytes;

   procedure Append
     (Chunk : in out Terminal.App.Queues.Byte_Chunk;
      Text  : String) is
   begin
      for Ch of Text loop
         Chunk.Length := Chunk.Length + 1;
         Chunk.Data (Chunk.Length) := Byte (Character'Pos (Ch));
      end loop;
   end Append;

   procedure Encode
     (Text  : String;
      Modes : Terminal.Core.Mode_Snapshot;
      Chunk : out Terminal.App.Queues.Byte_Chunk)
   is
      Opening : constant String := ASCII.ESC & "[200~";
      Closing : constant String := ASCII.ESC & "[201~";
      Framing_Length : constant Natural :=
        (if Modes.Bracketed_Paste then Opening'Length + Closing'Length else 0);
   begin
      if Text'Length > Terminal.App.Queues.Max_Chunk_Length - Framing_Length
      then
         raise Constraint_Error with
           "paste text requires the streaming write interface";
      end if;
      Chunk := (others => <>);
      if Modes.Bracketed_Paste then
         Append (Chunk, Opening);
      end if;
      Append (Chunk, Text);
      if Modes.Bracketed_Paste then
         Append (Chunk, Closing);
      end if;
   end Encode;
end Terminal.App.Input_Map.Paste;

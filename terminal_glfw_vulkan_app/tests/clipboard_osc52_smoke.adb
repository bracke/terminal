with AUnit.Assertions;

with Terminal.App.Clipboard_OSC52;
with Terminal.App.Queues;
with Terminal.Common.Bytes;

procedure Clipboard_OSC52_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;

   function Text_Of (Chunk : Terminal.App.Queues.Byte_Chunk) return String is
      Result : String (1 .. Chunk.Length);
   begin
      for I in Result'Range loop
         Result (I) := Character'Val (Chunk.Data (I));
      end loop;
      return Result;
   end Text_Of;

   Chunk : Terminal.App.Queues.Byte_Chunk;
   Long_Text : String
     (1 .. Terminal.App.Clipboard_OSC52.Max_Query_Text_Bytes + 20) :=
       (others => 'x');
begin
   Terminal.App.Clipboard_OSC52.Build_Query_Response ("hello", Chunk);
   Assert
     (Text_Of (Chunk) = Character'Val (16#1B#) & "]52;c;aGVsbG8=" &
        Character'Val (16#1B#) & "\",
      "OSC 52 query response should base64 encode clipboard text");

   Terminal.App.Clipboard_OSC52.Build_Query_Response ("", Chunk);
   Assert
     (Text_Of (Chunk) = Character'Val (16#1B#) & "]52;c;" &
        Character'Val (16#1B#) & "\",
      "empty OSC 52 query response");

   Terminal.App.Clipboard_OSC52.Build_Query_Response (Long_Text, Chunk);
   Assert
     (Chunk.Length = 4_093,
      "long OSC 52 query response should be bounded");
   Assert
     (Chunk.Data (1) = 16#1B#
      and then Chunk.Data (2) = Byte (Character'Pos (']'))
      and then Chunk.Data (Chunk.Length - 1) = 16#1B#
      and then Chunk.Data (Chunk.Length) = Byte (Character'Pos ('\')),
      "bounded OSC 52 response framing");
end Clipboard_OSC52_Smoke;

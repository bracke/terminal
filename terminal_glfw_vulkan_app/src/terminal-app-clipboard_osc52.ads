with Terminal.App.Queues;

package Terminal.App.Clipboard_OSC52 is
   Max_Query_Text_Bytes : constant := 3_063;

   procedure Build_Query_Response
     (Text  : String;
      Chunk : out Terminal.App.Queues.Byte_Chunk);
end Terminal.App.Clipboard_OSC52;

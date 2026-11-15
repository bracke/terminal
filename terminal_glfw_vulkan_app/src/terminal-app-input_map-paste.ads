with Terminal.App.Queues;
with Terminal.Core;

private package Terminal.App.Input_Map.Paste is
   procedure Encode
     (Text  : String;
      Modes : Terminal.Core.Mode_Snapshot;
      Chunk : out Terminal.App.Queues.Byte_Chunk);
end Terminal.App.Input_Map.Paste;

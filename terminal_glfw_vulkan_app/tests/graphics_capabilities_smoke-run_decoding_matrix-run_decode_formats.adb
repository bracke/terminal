separate (Graphics_Capabilities_Smoke.Run_Decoding_Matrix)
procedure Run_Decode_Formats is
   procedure Run_Sixel_Semantics is separate;
   procedure Run_Streaming_Decoders is separate;
   procedure Run_Protocol_Formats is separate;
begin
      Reset_And_Initialize_Fixtures;
      Run_Sixel_Semantics;
      Run_Streaming_Decoders;
      Run_Protocol_Formats;
end Run_Decode_Formats;

separate (Graphics_Capabilities_Smoke.Run_Decoding_Matrix)
procedure Run_Decode_Core is
   procedure Run_Core_Group_1 is separate;
   procedure Run_Core_Group_2 is separate;
   procedure Run_Core_Group_3 is separate;
   procedure Run_Core_Group_4 is separate;
begin
   Run_Core_Group_1;
   Run_Core_Group_2;
   Run_Core_Group_3;
   Run_Core_Group_4;
end Run_Decode_Core;

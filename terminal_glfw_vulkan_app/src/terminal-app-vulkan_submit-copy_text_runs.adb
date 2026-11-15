separate (Terminal.App.Vulkan_Submit)
procedure Copy_Text_Runs
  (Frame : RM.Frame_Commands; Batch : in out Submission_Batch) is
begin
   if Frame.Text_Run_Count = 0 then return; end if;
   if Batch.Text_Runs = null or else Batch.Text_Runs'Length < Frame.Text_Run_Count
   then
      declare
         Replacement : RM.Text_Run_Array_Access := new RM.Text_Run_Array
           (1 .. Grown_Capacity
             ((if Batch.Text_Runs = null then 0 else Batch.Text_Runs'Length),
              Positive (Frame.Text_Run_Count)));
      begin
         if Batch.Text_Runs /= null then Free_Text_Runs (Batch.Text_Runs); end if;
         Batch.Text_Runs := Replacement;
      end;
   end if;
   for I in 1 .. Frame.Text_Run_Count loop
      Batch.Text_Runs (I) := Frame.Text_Runs (I);
      Batch.Shaped_Glyph_Total := Batch.Shaped_Glyph_Total
        + Natural (Frame.Text_Runs (I).Shaped_Glyph_Count);
   end loop;
   Batch.Text_Run_Total := Frame.Text_Run_Count;
end Copy_Text_Runs;

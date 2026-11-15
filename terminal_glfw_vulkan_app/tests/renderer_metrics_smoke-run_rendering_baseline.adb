separate (Renderer_Metrics_Smoke)
procedure Run_Rendering_Baseline (Context : in out Suite_Context) is
begin
   Run_Hyperlink_And_Diagnostic_Cases (Context);
   Run_Placement_And_Cropping_Cases (Context);
   Run_Deletion_Scope_Cases (Context);
   Run_Image_Number_Cases (Context);
   Run_Relative_Placement_Cases (Context);
   Run_Virtual_Parent_And_RGB_Cases (Context);
   Run_Chunked_Raw_Cases (Context);
end Run_Rendering_Baseline;

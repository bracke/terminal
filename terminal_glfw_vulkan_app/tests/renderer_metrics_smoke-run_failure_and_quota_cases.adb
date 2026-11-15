separate (Renderer_Metrics_Smoke)
procedure Run_Failure_And_Quota_Cases (Context : in out Suite_Context) is
begin
   Run_Failure_And_Colour_Cases (Context);
   Run_Decoration_Cases (Context);
   Run_Cluster_Shaping_Cases (Context);
   Run_Emoji_Cluster_Cases (Context);
   Run_Shaping_Fallback_Cases (Context);
   Run_Image_Quota_Cases (Context);
end Run_Failure_And_Quota_Cases;

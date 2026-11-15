separate (Renderer_Metrics_Smoke)
procedure Run_Composition_And_Lifetime_Cases (Context : in out Suite_Context) is
begin
   Run_Lifecycle_And_Multi_View_Cases (Context);
   Run_Scrollback_Placement_Cases (Context);
end Run_Composition_And_Lifetime_Cases;

with Terminal.App.Renderer.Testing.Placement_Invariants;

procedure Image_Placements_Smoke is
begin
   Terminal.App.Renderer.Testing.Placement_Invariants
     .Verify_Image_Placement_Invariants;
   Terminal.App.Renderer.Testing.Placement_Invariants
     .Verify_Placement_Update_Invalidation;
end Image_Placements_Smoke;

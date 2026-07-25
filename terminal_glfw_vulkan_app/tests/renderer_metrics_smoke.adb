with AUnit.Assertions;

with Terminal.App.Renderer;

procedure Renderer_Metrics_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Renderer.Init_Status;

   R      : Terminal.App.Renderer.Renderer;
   Status : Terminal.App.Renderer.Init_Status;
begin
   Terminal.App.Renderer.Initialize_Headless (R, Status);
   Assert (Status = Terminal.App.Renderer.Ok, "renderer initialize failed");
   Assert
     (Terminal.App.Renderer.Cell_Height (R) >= 16,
      "cell height should keep at least the requested pixel size");
   Assert
     (Terminal.App.Renderer.Cell_Width (R) = 8,
      "cell width should keep the fixed monospace grid width");
   Terminal.App.Renderer.Finalize (R);
end Renderer_Metrics_Smoke;

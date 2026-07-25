with AUnit.Assertions;

with Terminal.App.Vulkan_Context;
with Terminal.App.Vulkan_Presenter;
with Terminal.App.Vulkan_Submit;

procedure Vulkan_Presenter_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Vulkan_Presenter.Init_Status;
   use type Terminal.App.Vulkan_Presenter.Present_Status;

   package VC renames Terminal.App.Vulkan_Context;
   package VP renames Terminal.App.Vulkan_Presenter;
   package VS renames Terminal.App.Vulkan_Submit;

   Context : VC.Context;
   Presenter : VP.Presenter;
   Batch : VS.Submission_Batch;
   Init_Status : VP.Init_Status;
   Present_Status : VP.Present_Status;
begin
   VP.Initialize (Presenter, Context, Init_Status);
   Assert
     (Init_Status = VP.Context_Not_Initialized,
      "uninitialized Vulkan context must be rejected");

   VP.Present (Presenter, Context, Batch, Present_Status);
   Assert
     (Present_Status = VP.Not_Initialized,
      "present before initialize must be rejected");

   declare
      Diag : constant VP.Diagnostic_Snapshot := VP.Diagnostics (Presenter);
   begin
      Assert (not Diag.Initialized, "presenter should remain uninitialized");
      Assert (Diag.Rejected_Frames = 1, "rejected frame counter");
      Assert
        (Diag.Last_Status = VP.Not_Initialized,
         "last present status should be retained");
      Assert
        (Diag.Last_Text_Run_Count = 0,
         "rejected present should clear text run count");
      Assert
        (Diag.Last_Shaped_Glyph_Count = 0,
         "rejected present should clear shaped glyph count");
   end;
end Vulkan_Presenter_Smoke;

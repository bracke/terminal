with AUnit.Assertions;

with Terminal.App.Vulkan_Recovery;

procedure Vulkan_Recovery_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Vulkan_Recovery.Recovery_Reason;

   package VR renames Terminal.App.Vulkan_Recovery;

   State : VR.Controller;
   D     : VR.Diagnostic_Snapshot;
begin
   VR.Initialize (State);
   Assert (not VR.Is_Pending (State), "recovery starts ready");

   VR.Begin_Recovery (State, VR.Device_Lost, 10);
   Assert (VR.Attempt_Due (State, 10), "first retry is immediate");
   VR.Record_Attempt (State, 10, False);
   Assert (not VR.Attempt_Due (State, 10), "failed retry is delayed");
   Assert (VR.Attempt_Due (State, 11), "first backoff is one tick");

   VR.Record_Attempt (State, 11, False);
   Assert (not VR.Attempt_Due (State, 12), "second backoff is two ticks");
   Assert (VR.Attempt_Due (State, 13), "second retry becomes due");

   VR.Record_Attempt (State, 13, True);
   Assert (not VR.Is_Pending (State), "successful reconstruction is ready");
   D := VR.Diagnostics (State);
   Assert (D.Incidents = 1, "one loss incident");
   Assert (D.Attempts = 3, "all reconstruction attempts counted");
   Assert (D.Failed_Attempts = 2, "failed reconstruction attempts counted");
   Assert (D.Successful_Recoveries = 1, "successful recovery counted");
   Assert (D.Reason = VR.No_Recovery, "successful recovery clears reason");

   VR.Begin_Recovery (State, VR.Swapchain_Invalid, 20);
   VR.Begin_Recovery (State, VR.Device_Lost, 20);
   D := VR.Diagnostics (State);
   Assert (D.Incidents = 2, "pending loss is one incident");
   Assert (D.Reason = VR.Device_Lost, "stronger current reason retained");

   for Attempt in 1 .. 12 loop
      declare
         At_Tick : constant Natural := VR.Diagnostics (State).Next_Attempt_Tick;
      begin
         Assert (VR.Attempt_Due (State, At_Tick), "scheduled retry is due");
         VR.Record_Attempt (State, At_Tick, False);
      end;
   end loop;
   D := VR.Diagnostics (State);
   Assert
     (D.Next_Attempt_Tick <= 20 + 12 * 128,
      "recovery delay remains bounded");
end Vulkan_Recovery_Smoke;

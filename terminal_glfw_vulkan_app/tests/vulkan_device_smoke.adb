with AUnit.Assertions;
with System;

with Terminal.App.Vulkan_Context;
with Terminal.App.Vulkan_Device;

procedure Vulkan_Device_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Vulkan_Device.Create_Status;
   use type Terminal.App.Vulkan_Device.Render_Status;
   use type Terminal.App.Vulkan_Device.Select_Status;

   package VC renames Terminal.App.Vulkan_Context;
   package VD renames Terminal.App.Vulkan_Device;

   Context : VC.Context;
   Choice : VD.Selection;
   Device : VD.Logical_Device;
   Select_Status : VD.Select_Status;
   Create_Status : VD.Create_Status;
   Render_Status : VD.Render_Status;
begin
   VD.Select_Physical_Device (Context, Choice, Select_Status);
   Assert
     (Select_Status = VD.Context_Not_Initialized,
      "uninitialized context must reject physical-device selection");
   Assert (not VD.Is_Selected (Choice), "choice should not be selected");

   VD.Create_Logical_Device
     (Choice         => Choice,
      Surface        => System.Null_Address,
      Desired_Width  => 0,
      Desired_Height => 0,
      Device         => Device,
      Status         => Create_Status);
   Assert
     (Create_Status = VD.Selection_Not_Ready,
      "unselected physical device must reject logical-device creation");
   Assert (not VD.Is_Initialized (Device), "logical device should not be live");

   VD.Render (Device, Render_Status);
   Assert
     (Render_Status = VD.Not_Initialized,
      "uninitialized logical device must reject render");

   declare
      Diag : constant VD.Device_Diagnostic_Snapshot := VD.Diagnostics (Device);
   begin
      Assert
        (Diag.Last_Status = VD.Selection_Not_Ready,
         "device diagnostic should retain failure status");
      Assert
        (Diag.Color_Sample_Count = 1,
         "uninitialized device should report 1x color sampling");
      Assert
        (not Diag.Color_MSAA_Created,
         "uninitialized device should not report an MSAA target");
   end;
end Vulkan_Device_Smoke;

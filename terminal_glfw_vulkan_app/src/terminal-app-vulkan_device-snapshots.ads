private package Terminal.App.Vulkan_Device.Snapshots is
   function Capture
     (Device                : Logical_Device;
      Include_Image_Preview : Boolean) return Device_Diagnostic_Snapshot;
end Terminal.App.Vulkan_Device.Snapshots;

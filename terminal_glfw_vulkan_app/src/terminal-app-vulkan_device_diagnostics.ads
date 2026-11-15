with Terminal.App.Vulkan_Device;

package Terminal.App.Vulkan_Device_Diagnostics is
   function Select_Status_Label
     (Status : Vulkan_Device.Select_Status) return String;
   function Create_Status_Label
     (Status : Vulkan_Device.Create_Status) return String;
   function Render_Status_Label
     (Status : Vulkan_Device.Render_Status) return String;
   function Operationally_Equivalent
     (Left, Right : Vulkan_Device.Device_Diagnostic_Snapshot) return Boolean;
   function Image_Status_Label
     (Diagnostics : Vulkan_Device.Device_Diagnostic_Snapshot) return String;
   function Image_Texture_Status_Label
     (Diagnostics : Vulkan_Device.Device_Diagnostic_Snapshot) return String;
   function Image_Texture_Resource_Status_Label
     (Diagnostics : Vulkan_Device.Device_Diagnostic_Snapshot) return String;
end Terminal.App.Vulkan_Device_Diagnostics;

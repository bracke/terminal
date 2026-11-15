private package Terminal.App.Vulkan_Device.Selection_Logic is
   type Capability_Query_Result is
     (Capability_Available, Capability_Unavailable, Capability_Query_Failed);

   procedure Select_Physical_Device
     (Context : Terminal.App.Vulkan_Context.Context;
      Choice  : out Selection;
      Status  : out Select_Status);

   function Is_Selected (Choice : Selection) return Boolean;
   function Physical_Device (Choice : Selection) return Vk.Physical_Device_T;
   function Queue_Family_Index (Choice : Selection) return Natural;
   function Present_Queue_Family_Index (Choice : Selection) return Natural;
   function Diagnostics (Choice : Selection) return Diagnostic_Snapshot;

   function Swapchain_Support
     (Device  : Vk.Physical_Device_T;
      Checked : out Natural) return Capability_Query_Result;
end Terminal.App.Vulkan_Device.Selection_Logic;

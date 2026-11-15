with Vk;

private package Terminal.App.Vulkan_Device.Resource_Lifecycle is
   procedure Destroy_Vertex_Buffer (Device : in out Logical_Device);
   procedure Destroy_Atlas_Image (Device : in out Logical_Device);
   procedure Destroy_Image_Texture (Device : in out Logical_Device);
   procedure Destroy_Colour_Sheet (Device : in out Logical_Device);
   procedure Destroy_Readback_Buffer
     (Device  : in out Logical_Device;
      Success : out Boolean);
   procedure Destroy_Deferred_Upload
     (Device  : in out Logical_Device;
      Success : out Boolean);
   procedure Defer_Upload_Resources
     (Device         : in out Logical_Device;
      Staging_Buffer : in out Vk.Buffer_T;
      Staging_Memory : in out Vk.Device_Memory_T;
      Image          : in out Vk.Image_T;
      Image_Memory   : in out Vk.Device_Memory_T;
      Image_View     : in out Vk.Image_View_T);
   procedure Reap_Deferred_Upload
     (Device : in out Logical_Device;
      Ready  : out Boolean;
      Status : out Create_Status);
   procedure Restore_Upload_Fence
     (Device : in out Logical_Device;
      Status : out Create_Status);
end Terminal.App.Vulkan_Device.Resource_Lifecycle;

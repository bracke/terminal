with Ada.Exceptions;
with System;
with Terminal.App.Cleanup_Diagnostics;
with Terminal.App.Vulkan_Destroy_Pair;
with Terminal.App.Vulkan_Destroy_Once;
with Terminal.App.Vulkan_Destroy_Triple;
with Terminal.App.Vulkan_Retirement;

package body Terminal.App.Vulkan_Device.Resource_Lifecycle is
   use type Vk.Buffer_T;
   use type Vk.Device_Memory_T;
   use type Vk.Fence_T;
   use type Vk.Image_T;
   use type Vk.Image_View_T;
   use type Vk.Result_T;

   procedure Destroy_Vertex_Buffer (Device : in out Logical_Device) is
      Cleanup_Ok : Boolean;
      procedure Destroy_Buffer (Handle : Vk.Buffer_T) is
      begin
         Vk.Destroy_Buffer (Device.Device, Handle, System.Null_Address);
      end Destroy_Buffer;
      procedure Free_Memory (Handle : Vk.Device_Memory_T) is
      begin
         Vk.Free_Memory (Device.Device, Handle, System.Null_Address);
      end Free_Memory;
      procedure Destroy_Chain is new Terminal.App.Vulkan_Destroy_Pair
        (Vk.Buffer_T, System.Null_Address, "destroy Vulkan vertex buffer",
         Destroy_Buffer,
         Vk.Device_Memory_T, System.Null_Address,
         "free Vulkan vertex-buffer memory", Free_Memory);
   begin
      Destroy_Chain (Device.Vertex_Buffer, Device.Vertex_Memory, Cleanup_Ok);
      Device.Vertex_Buffer_Bytes := 0;
      Device.Uploaded_Vertex_Count := 0;
      Device.Uploaded_Text_Run_Count := 0;
      Device.Uploaded_Shaped_Glyph_Count := 0;
      if not Cleanup_Ok then
         Device.Cleanup_Quarantined := True;
         raise Program_Error with "Vulkan vertex-buffer cleanup failed";
      end if;
   end Destroy_Vertex_Buffer;

   procedure Destroy_Atlas_Image (Device : in out Logical_Device) is
      Cleanup_Ok : Boolean;
      procedure Destroy_View (Handle : Vk.Image_View_T) is
      begin
         Vk.Destroy_Image_View (Device.Device, Handle, System.Null_Address);
      end Destroy_View;
      procedure Destroy_Image (Handle : Vk.Image_T) is
      begin
         Vk.Destroy_Image (Device.Device, Handle, System.Null_Address);
      end Destroy_Image;
      procedure Free_Memory (Handle : Vk.Device_Memory_T) is
      begin
         Vk.Free_Memory (Device.Device, Handle, System.Null_Address);
      end Free_Memory;
      procedure Destroy_Chain is new Terminal.App.Vulkan_Destroy_Triple
        (Vk.Image_View_T, System.Null_Address, "destroy Vulkan atlas view",
         Destroy_View,
         Vk.Image_T, System.Null_Address, "destroy Vulkan atlas image",
         Destroy_Image,
         Vk.Device_Memory_T, System.Null_Address, "free Vulkan atlas memory",
         Free_Memory);
   begin
      Destroy_Chain
        (Device.Atlas_View, Device.Atlas_Image, Device.Atlas_Memory,
         Cleanup_Ok);
      Device.Atlas_Width := 0;
      Device.Atlas_Height := 0;
      Device.Atlas_Bytes := 0;
      if not Cleanup_Ok then
         Device.Cleanup_Quarantined := True;
         raise Program_Error with "Vulkan atlas cleanup failed";
      end if;
   end Destroy_Atlas_Image;

   procedure Destroy_Colour_Sheet (Device : in out Logical_Device) is
      Cleanup_Ok : Boolean;
      procedure Destroy_View (Handle : Vk.Image_View_T) is
      begin
         Vk.Destroy_Image_View (Device.Device, Handle, System.Null_Address);
      end Destroy_View;
      procedure Destroy_Image (Handle : Vk.Image_T) is
      begin
         Vk.Destroy_Image (Device.Device, Handle, System.Null_Address);
      end Destroy_Image;
      procedure Free_Memory (Handle : Vk.Device_Memory_T) is
      begin
         Vk.Free_Memory (Device.Device, Handle, System.Null_Address);
      end Free_Memory;
      procedure Destroy_Chain is new Terminal.App.Vulkan_Destroy_Triple
        (Vk.Image_View_T, System.Null_Address,
         "destroy Vulkan colour-sheet view", Destroy_View,
         Vk.Image_T, System.Null_Address,
         "destroy Vulkan colour-sheet image", Destroy_Image,
         Vk.Device_Memory_T, System.Null_Address,
         "free Vulkan colour-sheet memory", Free_Memory);
   begin
      Destroy_Chain
        (Device.Colour_Sheet_View, Device.Colour_Sheet_Image,
         Device.Colour_Sheet_Memory, Cleanup_Ok);
      Device.Colour_Sheet_Width := 0;
      Device.Colour_Sheet_Height := 0;
      if not Cleanup_Ok then
         Device.Cleanup_Quarantined := True;
         raise Program_Error with "Vulkan colour-sheet cleanup failed";
      end if;
   end Destroy_Colour_Sheet;

   procedure Destroy_Image_Texture (Device : in out Logical_Device) is
      Cleanup_Ok : Boolean;
      procedure Destroy_View (Handle : Vk.Image_View_T) is
      begin
         Vk.Destroy_Image_View (Device.Device, Handle, System.Null_Address);
      end Destroy_View;
      procedure Destroy_Image (Handle : Vk.Image_T) is
      begin
         Vk.Destroy_Image (Device.Device, Handle, System.Null_Address);
      end Destroy_Image;
      procedure Free_Memory (Handle : Vk.Device_Memory_T) is
      begin
         Vk.Free_Memory (Device.Device, Handle, System.Null_Address);
      end Free_Memory;
      procedure Destroy_Chain is new Terminal.App.Vulkan_Destroy_Triple
        (Vk.Image_View_T, System.Null_Address,
         "destroy Vulkan image-texture view", Destroy_View,
         Vk.Image_T, System.Null_Address,
         "destroy Vulkan image texture", Destroy_Image,
         Vk.Device_Memory_T, System.Null_Address,
         "free Vulkan image-texture memory", Free_Memory);
   begin
      Destroy_Chain
        (Device.Image_Texture_View, Device.Image_Texture_Image,
         Device.Image_Texture_Memory, Cleanup_Ok);
      Device.Image_Texture_Width := 0;
      Device.Image_Texture_Height := 0;
      Device.Image_Texture_Bytes := 0;
      Device.Image_Texture_Content_Signature := 0;
      if Device.Image_Texture_Descriptor_Bound_Count > 1 then
         Device.Image_Texture_Descriptor_Bound_Count := 1;
      end if;
      if not Cleanup_Ok then
         Device.Cleanup_Quarantined := True;
         raise Program_Error with "Vulkan image-texture cleanup failed";
      end if;
   end Destroy_Image_Texture;

   procedure Destroy_Readback_Buffer
     (Device  : in out Logical_Device;
      Success : out Boolean)
   is
      procedure Destroy_Buffer (Handle : Vk.Buffer_T) is
      begin
         Vk.Destroy_Buffer (Device.Device, Handle, System.Null_Address);
      end Destroy_Buffer;
      procedure Free_Memory (Handle : Vk.Device_Memory_T) is
      begin
         Vk.Free_Memory (Device.Device, Handle, System.Null_Address);
      end Free_Memory;
      procedure Destroy_Chain is new Terminal.App.Vulkan_Destroy_Pair
        (Vk.Buffer_T, System.Null_Address, "destroy Vulkan readback buffer",
         Destroy_Buffer,
         Vk.Device_Memory_T, System.Null_Address,
         "free Vulkan readback memory", Free_Memory);
   begin
      Destroy_Chain
        (Device.Readback_Buffer, Device.Readback_Memory, Success);
      Device.Readback_Enabled := False;
      Device.Readback_Pending := False;
      Device.Readback_Bytes := 0;
      Device.Readback_Frame := 0;
      if not Success then
         Device.Cleanup_Quarantined := True;
      end if;
   end Destroy_Readback_Buffer;

   procedure Destroy_Deferred_Upload
     (Device  : in out Logical_Device;
      Success : out Boolean)
   is
      procedure Destroy_View_Call (Handle : Vk.Image_View_T) is
      begin
         Vk.Destroy_Image_View
           (Device.Device, Handle, System.Null_Address);
      end Destroy_View_Call;

      procedure Destroy_Image_Call (Handle : Vk.Image_T) is
      begin
         Vk.Destroy_Image (Device.Device, Handle, System.Null_Address);
      end Destroy_Image_Call;

      procedure Free_Memory_Call (Handle : Vk.Device_Memory_T) is
      begin
         Vk.Free_Memory (Device.Device, Handle, System.Null_Address);
      end Free_Memory_Call;

      procedure Destroy_Buffer_Call (Handle : Vk.Buffer_T) is
      begin
         Vk.Destroy_Buffer (Device.Device, Handle, System.Null_Address);
      end Destroy_Buffer_Call;

      procedure Destroy_Image_Chain is new Terminal.App.Vulkan_Destroy_Triple
        (Vk.Image_View_T, System.Null_Address,
         "destroy deferred Vulkan image view", Destroy_View_Call,
         Vk.Image_T, System.Null_Address,
         "destroy deferred Vulkan image", Destroy_Image_Call,
         Vk.Device_Memory_T, System.Null_Address,
         "free deferred Vulkan image memory", Free_Memory_Call);
      procedure Destroy_Buffer_Chain is new Terminal.App.Vulkan_Destroy_Pair
        (Vk.Buffer_T, System.Null_Address,
         "destroy deferred Vulkan staging buffer", Destroy_Buffer_Call,
         Vk.Device_Memory_T, System.Null_Address,
         "free deferred Vulkan staging memory", Free_Memory_Call);
      Image_Ok : Boolean;
      Buffer_Ok : Boolean;
   begin
      Destroy_Image_Chain
        (Device.Deferred_Upload_View,
         Device.Deferred_Upload_Image,
         Device.Deferred_Upload_Image_Memory,
         Image_Ok);
      Destroy_Buffer_Chain
        (Device.Deferred_Upload_Buffer,
         Device.Deferred_Upload_Memory,
         Buffer_Ok);
      Success := Image_Ok and Buffer_Ok;
      Device.Deferred_Upload_Pending := False;
      if not Success then
         Device.Cleanup_Quarantined := True;
      end if;
   end Destroy_Deferred_Upload;

   procedure Defer_Upload_Resources
     (Device         : in out Logical_Device;
      Staging_Buffer : in out Vk.Buffer_T;
      Staging_Memory : in out Vk.Device_Memory_T;
      Image          : in out Vk.Image_T;
      Image_Memory   : in out Vk.Device_Memory_T;
      Image_View     : in out Vk.Image_View_T) is
   begin
      if Device.Deferred_Upload_Pending then
         raise Program_Error with "an upload retirement is already pending";
      end if;
      Device.Deferred_Upload_Buffer := Staging_Buffer;
      Device.Deferred_Upload_Memory := Staging_Memory;
      Device.Deferred_Upload_Image := Image;
      Device.Deferred_Upload_Image_Memory := Image_Memory;
      Device.Deferred_Upload_View := Image_View;
      Device.Deferred_Upload_Pending := True;
      Staging_Buffer := System.Null_Address;
      Staging_Memory := System.Null_Address;
      Image := System.Null_Address;
      Image_Memory := System.Null_Address;
      Image_View := System.Null_Address;
   end Defer_Upload_Resources;

   procedure Reap_Deferred_Upload
     (Device : in out Logical_Device;
      Ready  : out Boolean;
      Status : out Create_Status)
   is
      Cleanup_Succeeded : Boolean := True;
      Fence : Terminal.App.Vulkan_Retirement.Fence_Outcome;
      Outcome : Terminal.App.Vulkan_Retirement.Retirement_Outcome;
      Result : Vk.Result_T;
   begin
      Ready := True;
      Status := Ok;
      if not Device.Deferred_Upload_Pending then
         return;
      elsif Device.Upload_Fence = System.Null_Address then
         Ready := False;
         Status := Copy_Atlas_Failed;
         return;
      end if;
      Result := Vk.Get_Fence_Status (Device.Device, Device.Upload_Fence);
      if Result = Vk.SUCCESS then
         Fence := Terminal.App.Vulkan_Retirement.Fence_Ready;
         Destroy_Deferred_Upload (Device, Cleanup_Succeeded);
      elsif Result = Vk.ERROR_DEVICE_LOST then
         Fence := Terminal.App.Vulkan_Retirement.Fence_Device_Lost;
         Destroy_Deferred_Upload (Device, Cleanup_Succeeded);
      elsif Result = Vk.NOT_READY then
         Fence := Terminal.App.Vulkan_Retirement.Fence_In_Flight;
      else
         Fence := Terminal.App.Vulkan_Retirement.Fence_Failed;
      end if;
      Outcome := Terminal.App.Vulkan_Retirement.Evaluate
        (Fence, Cleanup_Succeeded);
      case Outcome is
         when Terminal.App.Vulkan_Retirement.Retired => null;
         when Terminal.App.Vulkan_Retirement.Still_In_Flight =>
            Ready := False;
            Status := Resources_In_Flight;
         when Terminal.App.Vulkan_Retirement.Device_Lost =>
            Ready := False;
            Status := Device_Lost;
         when Terminal.App.Vulkan_Retirement.Cleanup_Failed
            | Terminal.App.Vulkan_Retirement.Fence_Failed =>
            Ready := False;
            Status := Copy_Atlas_Failed;
      end case;
   end Reap_Deferred_Upload;

   procedure Restore_Upload_Fence
     (Device : in out Logical_Device;
      Status : out Create_Status)
   is
      Fence_Info : aliased Vk.Fence_Create_Info_T :=
        (s_Type => Vk.STRUCTURE_TYPE_FENCE_CREATE_INFO,
         p_Next => System.Null_Address,
         flags  => Vk.FENCE_CREATE_SIGNALED_BIT);
      Result : Vk.Result_T;
      Fence_Destroyed : Boolean;
      procedure Destroy_Fence_Call (Handle : Vk.Fence_T) is
      begin
         Vk.Destroy_Fence (Device.Device, Handle, System.Null_Address);
      end Destroy_Fence_Call;
      procedure Report_Fence_Failure
        (Occurrence : Ada.Exceptions.Exception_Occurrence) is
      begin
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Vulkan_Device,
            Occurrence,
            "destroy Vulkan upload fence before restoration");
      end Report_Fence_Failure;
      procedure Destroy_Fence_Once is new Terminal.App.Vulkan_Destroy_Once
        (Vk.Fence_T, System.Null_Address,
         Destroy_Fence_Call, Report_Fence_Failure);
   begin
      Status := Ok;
      Destroy_Fence_Once (Device.Upload_Fence, Fence_Destroyed);
      if not Fence_Destroyed then
         Device.Cleanup_Quarantined := True;
         Status := Copy_Atlas_Failed;
         return;
      end if;
      Result := Vk.Create_Fence
        (Device.Device, Fence_Info'Address, System.Null_Address,
         Device.Upload_Fence'Address);
      case Terminal.App.Vulkan_Retirement.Classify_Fence_Restore
        (Succeeded   => Result = Vk.SUCCESS,
         Device_Lost => Result = Vk.ERROR_DEVICE_LOST)
      is
         when Terminal.App.Vulkan_Retirement.Fence_Restored => null;
         when Terminal.App.Vulkan_Retirement.Fence_Restore_Device_Lost =>
            Device.Upload_Fence := System.Null_Address;
            Status := Device_Lost;
         when Terminal.App.Vulkan_Retirement.Fence_Restore_Failed =>
            Device.Upload_Fence := System.Null_Address;
            Status := Copy_Atlas_Failed;
      end case;
   end Restore_Upload_Fence;
end Terminal.App.Vulkan_Device.Resource_Lifecycle;

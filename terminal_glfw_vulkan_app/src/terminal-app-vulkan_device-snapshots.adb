with System;

package body Terminal.App.Vulkan_Device.Snapshots is
   use type Vk.Buffer_T;
   use type Vk.Command_Pool_T;
   use type Vk.Descriptor_Pool_T;
   use type Vk.Descriptor_Set_Layout_T;
   use type Vk.Descriptor_Set_T;
   use type Vk.Device_Memory_T;
   use type Vk.Framebuffer_T;
   use type Vk.Image_T;
   use type Vk.Image_View_T;
   use type Vk.Pipeline_Layout_T;
   use type Vk.Pipeline_T;
   use type Vk.Render_Pass_T;
   use type Vk.Sample_Count_Flag_Bits_T;
   use type Vk.Sampler_T;
   use type Vk.Swapchain_KHR_T;

   function Sample_Count_Value
     (Value : Vk.Sample_Count_Flag_Bits_T) return Natural
   is
   begin
      if Value = Vk.SAMPLE_COUNT_64_BIT then return 64;
      elsif Value = Vk.SAMPLE_COUNT_32_BIT then return 32;
      elsif Value = Vk.SAMPLE_COUNT_16_BIT then return 16;
      elsif Value = Vk.SAMPLE_COUNT_8_BIT then return 8;
      elsif Value = Vk.SAMPLE_COUNT_4_BIT then return 4;
      elsif Value = Vk.SAMPLE_COUNT_2_BIT then return 2;
      else return 1;
      end if;
   end Sample_Count_Value;

   function Capture
     (Device                : Logical_Device;
      Include_Image_Preview : Boolean) return Device_Diagnostic_Snapshot is
   begin
      return
        (Initialized        => Device.Initialized,
         Queue_Family_Index => Device.Queue_Family_Index,
         Present_Queue_Family_Index => Device.Present_Queue_Family_Index,
         Swapchain_Created  => Device.Swapchain /= System.Null_Address,
         Swapchain_Image_Count => Device.Swapchain_Image_Count,
         Swapchain_View_Count => Device.Swapchain_View_Count,
         Framebuffer_Count => Device.Framebuffer_Count,
         Render_Pass_Created => Device.Render_Pass /= System.Null_Address,
         Command_Pool_Created => Device.Command_Pool /= System.Null_Address,
         Command_Buffer_Count => Device.Command_Buffer_Count,
         Sync_Frame_Count   => Device.Sync_Frame_Count,
         Pipeline_Layout_Created =>
           Device.Pipeline_Layout /= System.Null_Address,
         Graphics_Pipeline_Created =>
           Device.Graphics_Pipeline /= System.Null_Address,
         Descriptor_Set_Layout_Created =>
           Device.Descriptor_Set_Layout /= System.Null_Address,
         Descriptor_Pool_Created =>
           Device.Descriptor_Pool /= System.Null_Address,
         Descriptor_Set_Allocated =>
           Device.Descriptor_Set /= System.Null_Address,
         Vertex_Buffer_Created => Device.Vertex_Buffer /= System.Null_Address,
         Vertex_Buffer_Bytes => Device.Vertex_Buffer_Bytes,
         Uploaded_Vertex_Count => Device.Uploaded_Vertex_Count,
         Uploaded_Image_Command_Count => Device.Uploaded_Image_Command_Count,
         Uploaded_Image_Vertex_Count => Device.Uploaded_Image_Vertex_Count,
         Uploaded_Image_Texture_Vertex_Count =>
           Device.Uploaded_Image_Texture_Vertex_Count,
         Uploaded_Image_Protocol => Device.Uploaded_Image_Protocol,
         Uploaded_Image_Width => Device.Uploaded_Image_Width,
         Uploaded_Image_Height => Device.Uploaded_Image_Height,
         Uploaded_Image_Raw_Format => Device.Uploaded_Image_Raw_Format,
         Uploaded_Image_Pixel_Width => Device.Uploaded_Image_Pixel_Width,
         Uploaded_Image_Pixel_Height => Device.Uploaded_Image_Pixel_Height,
         Uploaded_Image_Payload_Length =>
           Device.Uploaded_Image_Payload_Length,
         Uploaded_Image_Texture_Staging_Bytes =>
           Device.Uploaded_Image_Texture_Staging_Bytes,
         Uploaded_Image_Payload_Preview_Complete =>
           Device.Uploaded_Image_Payload_Preview_Complete,
         Uploaded_Image_Encoded_Preview_Length =>
           Device.Uploaded_Image_Encoded_Preview_Length,
         Uploaded_Image_Decoded_Preview_Length =>
           (if Include_Image_Preview
            then Device.Uploaded_Image_Decoded_Preview_Length else 0),
         Uploaded_Image_Decoded_Preview_Bytes =>
           (if Include_Image_Preview
            then Device.Uploaded_Image_Decoded_Preview_Bytes
            else (others => 0)),
         Uploaded_Image_Preview_Decode_Complete =>
           Device.Uploaded_Image_Preview_Decode_Complete,
         Uploaded_Image_Decode_Status => Device.Uploaded_Image_Decode_Status,
         Uploaded_Image_Placeholder => Device.Uploaded_Image_Placeholder,
         Uploaded_Image_Texture_Downgraded =>
           Device.Uploaded_Image_Texture_Downgraded,
         Uploaded_Image_Texture_Source => Device.Uploaded_Image_Texture_Source,
         Uploaded_Text_Run_Count => Device.Uploaded_Text_Run_Count,
         Uploaded_Shaped_Glyph_Count => Device.Uploaded_Shaped_Glyph_Count,
         Rendered_Frame_Count => Device.Rendered_Frame_Count,
         Color_Sample_Count => Sample_Count_Value (Device.Color_Sample_Count),
         Color_MSAA_Created => Device.Color_MSAA_View /= System.Null_Address,
         Atlas_Image_Created => Device.Atlas_Image /= System.Null_Address,
         Atlas_View_Created => Device.Atlas_View /= System.Null_Address,
         Atlas_Sampler_Created => Device.Atlas_Sampler /= System.Null_Address,
         Image_Texture_Descriptor_Capacity =>
           Device.Image_Texture_Descriptor_Capacity,
         Image_Texture_Descriptor_Bound_Count =>
           Device.Image_Texture_Descriptor_Bound_Count,
         Image_Texture_Upload_Count => Device.Image_Texture_Upload_Count,
         Image_Texture_Cache_Hit_Count =>
           Device.Image_Texture_Cache_Hit_Count,
         Atlas_Width => Device.Atlas_Width,
         Atlas_Height => Device.Atlas_Height,
         Atlas_Bytes => Device.Atlas_Bytes,
         Atlas_Upload_Count => Device.Atlas_Upload_Count,
         Fence_Deferred_Upload_Count => Device.Fence_Deferred_Upload_Count,
         Swapchain_Width => Device.Swapchain_Width,
         Swapchain_Height => Device.Swapchain_Height,
         Last_Status => Device.Last_Status);
   end Capture;
end Terminal.App.Vulkan_Device.Snapshots;

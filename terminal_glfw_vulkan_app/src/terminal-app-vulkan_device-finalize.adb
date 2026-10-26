separate (Terminal.App.Vulkan_Device)
   overriding procedure Finalize (Device : in out Logical_Device) is
      Deferred_Cleanup_Succeeded : Boolean;
      Cleanup_Failed : Boolean := False;
      generic
         type Handle_Type is private;
         Null_Handle : Handle_Type;
         with procedure Destroy
           (Parent    : Vk.Device_T;
            Handle    : Handle_Type;
            Allocator : System.Address);
      procedure Destroy_Safely (Handle : in out Handle_Type);

      procedure Destroy_Safely (Handle : in out Handle_Type) is
      begin
         if Handle /= Null_Handle then
            begin
               Destroy (Device.Device, Handle, System.Null_Address);
            exception
               when others => Cleanup_Failed := True;
            end;
         end if;
         --  Never retry a handle after a best-effort destructor was called:
         --  the foreign call may have consumed it before an Ada exception.
         Handle := Null_Handle;
      end Destroy_Safely;

      procedure Destroy_Fence is new Destroy_Safely
        (Vk.Fence_T, System.Null_Address, Vk.Destroy_Fence);
      procedure Destroy_Semaphore is new Destroy_Safely
        (Vk.Semaphore_T, System.Null_Address, Vk.Destroy_Semaphore);
      procedure Destroy_Command_Pool is new Destroy_Safely
        (Vk.Command_Pool_T, System.Null_Address, Vk.Destroy_Command_Pool);
      procedure Destroy_Buffer is new Destroy_Safely
        (Vk.Buffer_T, System.Null_Address, Vk.Destroy_Buffer);
      procedure Free_Memory is new Destroy_Safely
        (Vk.Device_Memory_T, System.Null_Address, Vk.Free_Memory);
      procedure Destroy_Image_View is new Destroy_Safely
        (Vk.Image_View_T, System.Null_Address, Vk.Destroy_Image_View);
      procedure Destroy_Image is new Destroy_Safely
        (Vk.Image_T, System.Null_Address, Vk.Destroy_Image);
      procedure Destroy_Sampler is new Destroy_Safely
        (Vk.Sampler_T, System.Null_Address, Vk.Destroy_Sampler);
      procedure Destroy_Pipeline is new Destroy_Safely
        (Vk.Pipeline_T, System.Null_Address, Vk.Destroy_Pipeline);
      procedure Destroy_Pipeline_Layout is new Destroy_Safely
        (Vk.Pipeline_Layout_T, System.Null_Address, Vk.Destroy_Pipeline_Layout);
      procedure Destroy_Descriptor_Pool is new Destroy_Safely
        (Vk.Descriptor_Pool_T, System.Null_Address, Vk.Destroy_Descriptor_Pool);
      procedure Destroy_Descriptor_Set_Layout is new Destroy_Safely
        (Vk.Descriptor_Set_Layout_T, System.Null_Address,
         Vk.Destroy_Descriptor_Set_Layout);
      procedure Destroy_Framebuffer is new Destroy_Safely
        (Vk.Framebuffer_T, System.Null_Address, Vk.Destroy_Framebuffer);
      procedure Destroy_Render_Pass is new Destroy_Safely
        (Vk.Render_Pass_T, System.Null_Address, Vk.Destroy_Render_Pass);
      procedure Destroy_Swapchain is new Destroy_Safely
        (Vk.Swapchain_KHR_T, System.Null_Address, Vk.Destroy_Swapchain_KHR);
   begin
      if Device.Device /= System.Null_Address then
         begin
            declare
               Result : constant Vk.Result_T :=
                 Vk.Device_Wait_Idle (Device.Device);
            begin
               Cleanup_Failed := Cleanup_Failed or else Result /= Vk.SUCCESS;
            end;
         exception
            when others => Cleanup_Failed := True;
         end;

         Destroy_Deferred_Upload (Device, Deferred_Cleanup_Succeeded);
         Cleanup_Failed :=
           Cleanup_Failed or else not Deferred_Cleanup_Succeeded;
         Destroy_Fence (Device.Upload_Fence);
         for I in Device.In_Flight'Range loop
            Destroy_Fence (Device.In_Flight (I));
            Destroy_Semaphore (Device.Render_Finished (I));
            Destroy_Semaphore (Device.Image_Available (I));
         end loop;

         if Device.Command_Pool /= System.Null_Address then
            if Device.Upload_Command_Buffer /= System.Null_Address then
               begin
                  Vk.Free_Command_Buffers
                    (Device.Device, Device.Command_Pool, 1,
                     Device.Upload_Command_Buffer'Address);
               exception
                  when others => Cleanup_Failed := True;
               end;
            end if;
            Device.Upload_Command_Buffer := System.Null_Address;
            if Device.Command_Buffer_Count > 0 then
               begin
                  Vk.Free_Command_Buffers
                    (Device.Device,
                     Device.Command_Pool,
                     Interfaces.Unsigned_32 (Device.Command_Buffer_Count),
                     Device.Command_Buffers'Address);
               exception
                  when others => Cleanup_Failed := True;
               end;
            end if;
         end if;
         Device.Command_Buffers := (others => System.Null_Address);
         Device.Command_Buffer_Count := 0;
         Destroy_Command_Pool (Device.Command_Pool);

         Destroy_Buffer (Device.Vertex_Buffer);
         Free_Memory (Device.Vertex_Memory);
         Destroy_Buffer (Device.Readback_Buffer);
         Free_Memory (Device.Readback_Memory);
         Destroy_Image_View (Device.Atlas_View);
         Destroy_Image (Device.Atlas_Image);
         Free_Memory (Device.Atlas_Memory);
         Destroy_Image_View (Device.Image_Texture_View);
         Destroy_Image (Device.Image_Texture_Image);
         Free_Memory (Device.Image_Texture_Memory);
         Destroy_Sampler (Device.Atlas_Sampler);
         Destroy_Pipeline (Device.Graphics_Pipeline);
         Destroy_Pipeline_Layout (Device.Pipeline_Layout);
         Destroy_Descriptor_Pool (Device.Descriptor_Pool);
         Destroy_Descriptor_Set_Layout (Device.Descriptor_Set_Layout);

         for I in Device.Framebuffers'Range loop
            Destroy_Framebuffer (Device.Framebuffers (I));
         end loop;
         Destroy_Render_Pass (Device.Render_Pass);
         Destroy_Image_View (Device.Color_MSAA_View);
         Destroy_Image (Device.Color_MSAA_Image);
         Free_Memory (Device.Color_MSAA_Memory);
         for I in Device.Swapchain_Views'Range loop
            Destroy_Image_View (Device.Swapchain_Views (I));
         end loop;
         Destroy_Swapchain (Device.Swapchain);

         begin
            Vk.Destroy_Device (Device.Device, System.Null_Address);
         exception
            when others => Cleanup_Failed := True;
         end;
         Device.Device := System.Null_Address;
      end if;

      Device.Initialized := False;
      Device.Device := System.Null_Address;
      Device.Queue := System.Null_Address;
      Device.Swapchain := System.Null_Address;
      Device.Swapchain_Format := Vk.FORMAT_UNDEFINED;
      Device.Render_Pass := System.Null_Address;
      Device.Pipeline_Layout := System.Null_Address;
      Device.Graphics_Pipeline := System.Null_Address;
      Device.Descriptor_Set_Layout := System.Null_Address;
      Device.Descriptor_Pool := System.Null_Address;
      Device.Descriptor_Set := System.Null_Address;
      Device.Command_Pool := System.Null_Address;
      Device.Vertex_Buffer := System.Null_Address;
      Device.Vertex_Memory := System.Null_Address;
      Device.Color_MSAA_Image := System.Null_Address;
      Device.Color_MSAA_Memory := System.Null_Address;
      Device.Color_MSAA_View := System.Null_Address;
      Device.Color_Sample_Count := Vk.SAMPLE_COUNT_1_BIT;
      Device.Atlas_Image := System.Null_Address;
      Device.Atlas_Memory := System.Null_Address;
      Device.Atlas_View := System.Null_Address;
      Device.Atlas_Sampler := System.Null_Address;
      Device.Image_Texture_Image := System.Null_Address;
      Device.Image_Texture_Memory := System.Null_Address;
      Device.Image_Texture_View := System.Null_Address;
      Device.Image_Texture_Width := 0;
      Device.Image_Texture_Height := 0;
      Device.Image_Texture_Bytes := 0;
      Device.Image_Texture_Content_Signature := 0;
      Device.Image_Texture_Descriptor_Capacity := 0;
      Device.Image_Texture_Descriptor_Bound_Count := 0;
      Device.Image_Texture_Upload_Count := 0;
      Device.Image_Texture_Cache_Hit_Count := 0;
      Device.Swapchain_Images := (others => System.Null_Address);
      Device.Swapchain_Views := (others => System.Null_Address);
      Device.Framebuffers := (others => System.Null_Address);
      Device.Command_Buffers := (others => System.Null_Address);
      Device.Upload_Command_Buffer := System.Null_Address;
      Device.Image_Available := (others => System.Null_Address);
      Device.Render_Finished := (others => System.Null_Address);
      Device.In_Flight := (others => System.Null_Address);
      Device.Upload_Fence := System.Null_Address;
      Device.Queue_Family_Index := 0;
      Device.Swapchain_Image_Count := 0;
      Device.Swapchain_View_Count := 0;
      Device.Framebuffer_Count := 0;
      Device.Command_Buffer_Count := 0;
      Device.Sync_Frame_Count := 0;
      Device.Vertex_Buffer_Bytes := 0;
      Device.Uploaded_Vertex_Count := 0;
      Device.Uploaded_Text_Run_Count := 0;
      Device.Uploaded_Shaped_Glyph_Count := 0;
      Device.Rendered_Frame_Count := 0;
      Device.Current_Frame := 1;
      Device.Atlas_Width := 0;
      Device.Atlas_Height := 0;
      Device.Atlas_Bytes := 0;
      Device.Atlas_Upload_Count := 0;
      Device.Fence_Deferred_Upload_Count := 0;
      Device.Readback_Supported := False;
      Device.Readback_Enabled := False;
      Device.Readback_Pending := False;
      Device.Readback_Buffer := System.Null_Address;
      Device.Readback_Memory := System.Null_Address;
      Device.Readback_Bytes := 0;
      Device.Readback_Frame := 0;
      Device.Swapchain_Width := 0;
      Device.Swapchain_Height := 0;
      Device.Last_Status := Selection_Not_Ready;
      if Cleanup_Failed then
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Vulkan_Device);
      end if;
   exception
      when others =>
         --  A controlled finalizer must not replace an exception already in
         --  flight.  Mark the device unusable even if a corrupted teardown
         --  invariant prevented complete release.
         Device.Initialized := False;
         Device.Last_Status := Selection_Not_Ready;
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Vulkan_Device);
   end Finalize;


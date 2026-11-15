with Terminal.App.Vulkan_Destroy_Pair;
with Terminal.App.Vulkan_Destroy_Triple;

separate (Terminal.App.Vulkan_Device)
   overriding procedure Finalize (Device : in out Logical_Device) is
      Deferred_Cleanup_Succeeded : Boolean;
      Chain_Cleanup_Succeeded : Boolean;
      Cleanup_Succeeded : Boolean := not Device.Cleanup_Quarantined;
      Step_Succeeded : Boolean;
      Command_Buffers_Succeeded : Boolean := True;
      Pipeline_Layout_Succeeded : Boolean := True;
      Descriptor_Pool_Succeeded : Boolean := True;
      Framebuffers_Succeeded : Boolean := True;
      Swapchain_Views_Succeeded : Boolean := True;
      generic
         type Handle_Type is private;
         Null_Handle : Handle_Type;
         with procedure Destroy
           (Parent    : Vk.Device_T;
            Handle    : Handle_Type;
            Allocator : System.Address);
         Operation : String;
      procedure Destroy_Safely
        (Handle : in out Handle_Type; Success : out Boolean);

      procedure Destroy_Safely
        (Handle : in out Handle_Type; Success : out Boolean) is
      begin
         Success := True;
         if Handle /= Null_Handle then
            begin
               Destroy (Device.Device, Handle, System.Null_Address);
            exception
               when E : others =>
                  Success := False;
                  Terminal.App.Cleanup_Diagnostics.Note_Failure
                    (Terminal.App.Cleanup_Diagnostics.Vulkan_Device,
                     E,
                     Operation);
            end;
         end if;
         --  Never retry a handle after a best-effort destructor was called:
         --  the foreign call may have consumed it before an Ada exception.
         Handle := Null_Handle;
      end Destroy_Safely;

      procedure Destroy_Fence is new Destroy_Safely
        (Vk.Fence_T, System.Null_Address, Vk.Destroy_Fence, "destroy Vulkan fence");
      procedure Destroy_Semaphore is new Destroy_Safely
        (Vk.Semaphore_T, System.Null_Address, Vk.Destroy_Semaphore,
         "destroy Vulkan semaphore");
      procedure Destroy_Command_Pool is new Destroy_Safely
        (Vk.Command_Pool_T, System.Null_Address, Vk.Destroy_Command_Pool,
         "destroy Vulkan command pool");
      procedure Destroy_Image_View is new Destroy_Safely
        (Vk.Image_View_T, System.Null_Address, Vk.Destroy_Image_View,
         "destroy Vulkan image view");
      procedure Destroy_Sampler is new Destroy_Safely
        (Vk.Sampler_T, System.Null_Address, Vk.Destroy_Sampler,
         "destroy Vulkan sampler");
      procedure Destroy_Pipeline is new Destroy_Safely
        (Vk.Pipeline_T, System.Null_Address, Vk.Destroy_Pipeline,
         "destroy Vulkan pipeline");
      procedure Destroy_Pipeline_Layout is new Destroy_Safely
        (Vk.Pipeline_Layout_T, System.Null_Address, Vk.Destroy_Pipeline_Layout,
         "destroy Vulkan pipeline layout");
      procedure Destroy_Descriptor_Pool is new Destroy_Safely
        (Vk.Descriptor_Pool_T, System.Null_Address, Vk.Destroy_Descriptor_Pool,
         "destroy Vulkan descriptor pool");
      procedure Destroy_Descriptor_Set_Layout is new Destroy_Safely
        (Vk.Descriptor_Set_Layout_T, System.Null_Address,
         Vk.Destroy_Descriptor_Set_Layout,
         "destroy Vulkan descriptor-set layout");
      procedure Destroy_Framebuffer is new Destroy_Safely
        (Vk.Framebuffer_T, System.Null_Address, Vk.Destroy_Framebuffer,
         "destroy Vulkan framebuffer");
      procedure Destroy_Render_Pass is new Destroy_Safely
        (Vk.Render_Pass_T, System.Null_Address, Vk.Destroy_Render_Pass,
         "destroy Vulkan render pass");
      procedure Destroy_Swapchain is new Destroy_Safely
        (Vk.Swapchain_KHR_T, System.Null_Address, Vk.Destroy_Swapchain_KHR,
         "destroy Vulkan swapchain");

      procedure Destroy_Buffer_Call (Handle : Vk.Buffer_T) is
      begin
         Vk.Destroy_Buffer (Device.Device, Handle, System.Null_Address);
      end Destroy_Buffer_Call;

      procedure Free_Memory_Call (Handle : Vk.Device_Memory_T) is
      begin
         Vk.Free_Memory (Device.Device, Handle, System.Null_Address);
      end Free_Memory_Call;

      procedure Destroy_Image_View_Call (Handle : Vk.Image_View_T) is
      begin
         Vk.Destroy_Image_View
           (Device.Device, Handle, System.Null_Address);
      end Destroy_Image_View_Call;

      procedure Destroy_Image_Call (Handle : Vk.Image_T) is
      begin
         Vk.Destroy_Image (Device.Device, Handle, System.Null_Address);
      end Destroy_Image_Call;

      procedure Destroy_Buffer_Chain is new Terminal.App.Vulkan_Destroy_Pair
        (Vk.Buffer_T, System.Null_Address, "destroy Vulkan buffer",
         Destroy_Buffer_Call,
         Vk.Device_Memory_T, System.Null_Address,
         "free Vulkan buffer memory", Free_Memory_Call);

      procedure Destroy_Image_Chain is new Terminal.App.Vulkan_Destroy_Triple
        (Vk.Image_View_T, System.Null_Address, "destroy Vulkan image view",
         Destroy_Image_View_Call,
         Vk.Image_T, System.Null_Address, "destroy Vulkan image",
         Destroy_Image_Call,
         Vk.Device_Memory_T, System.Null_Address,
         "free Vulkan image memory", Free_Memory_Call);
   begin
      if Device.Device /= System.Null_Address then
         begin
            declare
               Result : constant Vk.Result_T :=
                 Vk.Device_Wait_Idle (Device.Device);
            begin
               if Result /= Vk.SUCCESS then
                  Terminal.App.Cleanup_Diagnostics.Note_Failure
                    (Terminal.App.Cleanup_Diagnostics.Vulkan_Device,
                     "wait for Vulkan device idle");
               end if;
            end;
         exception
            when E : others =>
               Terminal.App.Cleanup_Diagnostics.Note_Failure
                 (Terminal.App.Cleanup_Diagnostics.Vulkan_Device,
                  E,
                  "wait for Vulkan device idle");
         end;

         Destroy_Deferred_Upload (Device, Deferred_Cleanup_Succeeded);
         if not Deferred_Cleanup_Succeeded then
            Cleanup_Succeeded := False;
            Terminal.App.Cleanup_Diagnostics.Note_Failure
              (Terminal.App.Cleanup_Diagnostics.Vulkan_Device,
               "deferred Vulkan upload cleanup was incomplete");
         end if;
         Destroy_Fence (Device.Upload_Fence, Step_Succeeded);
         Cleanup_Succeeded := Cleanup_Succeeded and Step_Succeeded;
         for I in Device.In_Flight'Range loop
            Destroy_Fence (Device.In_Flight (I), Step_Succeeded);
            Cleanup_Succeeded := Cleanup_Succeeded and Step_Succeeded;
            Destroy_Semaphore
              (Device.Render_Finished (I), Step_Succeeded);
            Cleanup_Succeeded := Cleanup_Succeeded and Step_Succeeded;
            Destroy_Semaphore
              (Device.Image_Available (I), Step_Succeeded);
            Cleanup_Succeeded := Cleanup_Succeeded and Step_Succeeded;
         end loop;

         if Device.Command_Pool /= System.Null_Address then
            if Device.Upload_Command_Buffer /= System.Null_Address then
               begin
                  Vk.Free_Command_Buffers
                    (Device.Device, Device.Command_Pool, 1,
                     Device.Upload_Command_Buffer'Address);
               exception
                  when E : others =>
                     Command_Buffers_Succeeded := False;
                     Terminal.App.Cleanup_Diagnostics.Note_Failure
                       (Terminal.App.Cleanup_Diagnostics.Vulkan_Device,
                        E,
                        "free Vulkan upload command buffer");
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
                  when E : others =>
                     Command_Buffers_Succeeded := False;
                     Terminal.App.Cleanup_Diagnostics.Note_Failure
                       (Terminal.App.Cleanup_Diagnostics.Vulkan_Device,
                        E,
                        "free Vulkan draw command buffers");
               end;
            end if;
         end if;
         Device.Command_Buffers := (others => System.Null_Address);
         Device.Command_Buffer_Count := 0;
         if Command_Buffers_Succeeded then
            Destroy_Command_Pool (Device.Command_Pool, Step_Succeeded);
            Cleanup_Succeeded := Cleanup_Succeeded and Step_Succeeded;
         else
            --  A command buffer may still be live in the pool after the
            --  ambiguous free.  Quarantine the pool and ultimately the device.
            Device.Command_Pool := System.Null_Address;
            Cleanup_Succeeded := False;
         end if;

         Destroy_Buffer_Chain
           (Device.Vertex_Buffer, Device.Vertex_Memory,
            Chain_Cleanup_Succeeded);
         Cleanup_Succeeded := Cleanup_Succeeded and Chain_Cleanup_Succeeded;
         Destroy_Buffer_Chain
           (Device.Readback_Buffer, Device.Readback_Memory,
            Chain_Cleanup_Succeeded);
         Cleanup_Succeeded := Cleanup_Succeeded and Chain_Cleanup_Succeeded;
         Destroy_Image_Chain
           (Device.Atlas_View, Device.Atlas_Image, Device.Atlas_Memory,
            Chain_Cleanup_Succeeded);
         Cleanup_Succeeded := Cleanup_Succeeded and Chain_Cleanup_Succeeded;
         Destroy_Image_Chain
           (Device.Image_Texture_View, Device.Image_Texture_Image,
            Device.Image_Texture_Memory, Chain_Cleanup_Succeeded);
         Cleanup_Succeeded := Cleanup_Succeeded and Chain_Cleanup_Succeeded;
         Destroy_Image_Chain
           (Device.Colour_Sheet_View, Device.Colour_Sheet_Image,
            Device.Colour_Sheet_Memory, Chain_Cleanup_Succeeded);
         Cleanup_Succeeded := Cleanup_Succeeded and Chain_Cleanup_Succeeded;
         Destroy_Sampler (Device.Atlas_Sampler, Step_Succeeded);
         Cleanup_Succeeded := Cleanup_Succeeded and Step_Succeeded;
         Destroy_Pipeline (Device.Graphics_Pipeline, Step_Succeeded);
         Cleanup_Succeeded := Cleanup_Succeeded and Step_Succeeded;
         if Step_Succeeded then
            Destroy_Pipeline_Layout
              (Device.Pipeline_Layout, Pipeline_Layout_Succeeded);
            Cleanup_Succeeded :=
              Cleanup_Succeeded and Pipeline_Layout_Succeeded;
         else
            Device.Pipeline_Layout := System.Null_Address;
            Pipeline_Layout_Succeeded := False;
         end if;
         Destroy_Descriptor_Pool
           (Device.Descriptor_Pool, Descriptor_Pool_Succeeded);
         Cleanup_Succeeded :=
           Cleanup_Succeeded and Descriptor_Pool_Succeeded;
         if Pipeline_Layout_Succeeded and Descriptor_Pool_Succeeded then
            Destroy_Descriptor_Set_Layout
              (Device.Descriptor_Set_Layout, Step_Succeeded);
            Cleanup_Succeeded := Cleanup_Succeeded and Step_Succeeded;
         else
            --  A descriptor set or pipeline layout may still depend on this
            --  set layout after an ambiguous parent cleanup.
            Device.Descriptor_Set_Layout := System.Null_Address;
         end if;

         for I in Device.Framebuffers'Range loop
            Destroy_Framebuffer
              (Device.Framebuffers (I), Step_Succeeded);
            Framebuffers_Succeeded :=
              Framebuffers_Succeeded and Step_Succeeded;
         end loop;
         Cleanup_Succeeded := Cleanup_Succeeded and Framebuffers_Succeeded;
         if Framebuffers_Succeeded then
            Destroy_Render_Pass (Device.Render_Pass, Step_Succeeded);
            Cleanup_Succeeded := Cleanup_Succeeded and Step_Succeeded;
            Destroy_Image_Chain
              (Device.Color_MSAA_View, Device.Color_MSAA_Image,
               Device.Color_MSAA_Memory, Chain_Cleanup_Succeeded);
            Cleanup_Succeeded :=
              Cleanup_Succeeded and Chain_Cleanup_Succeeded;
            for I in Device.Swapchain_Views'Range loop
               Destroy_Image_View
                 (Device.Swapchain_Views (I), Step_Succeeded);
               Swapchain_Views_Succeeded :=
                 Swapchain_Views_Succeeded and Step_Succeeded;
            end loop;
            Cleanup_Succeeded :=
              Cleanup_Succeeded and Swapchain_Views_Succeeded;
            if Swapchain_Views_Succeeded then
               Destroy_Swapchain (Device.Swapchain, Step_Succeeded);
               Cleanup_Succeeded := Cleanup_Succeeded and Step_Succeeded;
            else
               Device.Swapchain := System.Null_Address;
            end if;
         else
            --  Framebuffers retain the render pass and attachment views.
            --  Quarantine the whole dependent chain after an ambiguous
            --  framebuffer destructor rather than issuing invalid calls.
            Device.Render_Pass := System.Null_Address;
            Device.Color_MSAA_View := System.Null_Address;
            Device.Color_MSAA_Image := System.Null_Address;
            Device.Color_MSAA_Memory := System.Null_Address;
            Device.Swapchain_Views := (others => System.Null_Address);
            Device.Swapchain := System.Null_Address;
         end if;

         if Cleanup_Succeeded then
            begin
               Vk.Destroy_Device (Device.Device, System.Null_Address);
            exception
               when E : others =>
                  Terminal.App.Cleanup_Diagnostics.Note_Failure
                    (Terminal.App.Cleanup_Diagnostics.Vulkan_Device,
                     E,
                     "destroy Vulkan logical device");
            end;
         else
            Terminal.App.Cleanup_Diagnostics.Note_Failure
              (Terminal.App.Cleanup_Diagnostics.Vulkan_Device,
               "quarantine Vulkan logical device after incomplete child cleanup");
         end if;
         Device.Device := System.Null_Address;
      end if;

      Reset_State (Device, Selection_Not_Ready);
   exception
      when E : others =>
         --  A controlled finalizer must not replace an exception already in
         --  flight.  Mark the device unusable even if a corrupted teardown
         --  invariant prevented complete release.
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Vulkan_Device,
            E,
            "finalize Vulkan logical device");
         --  The state of the foreign handles is ambiguous after an unexpected
         --  teardown failure.  Forget them rather than retrying a possibly
         --  consumed handle on a later finalization pass.
         Reset_State (Device, Selection_Not_Ready);
   end Finalize;


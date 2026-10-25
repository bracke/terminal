separate (Terminal.App.Vulkan_Device.Create_Logical_Device)
      function Create_Render_Pass_And_Framebuffers
        (Handle : Vk.Device_T)
         return Create_Status
      is
         Samples : constant Vk.Sample_Count_Flag_Bits_T :=
           Choose_Color_Sample_Count;
         MSAA_On : constant Boolean := Samples /= Vk.SAMPLE_COUNT_1_BIT;
         Color_Attachment : aliased Vk.Attachment_Description_T :=
           (flags           => 0,
            format          => Device.Swapchain_Format,
            samples         => Samples,
            load_Op         => Vk.ATTACHMENT_LOAD_OP_CLEAR,
            store_Op        =>
              (if MSAA_On
               then Vk.ATTACHMENT_STORE_OP_DONT_CARE
               else Vk.ATTACHMENT_STORE_OP_STORE),
            stencil_Load_Op => Vk.ATTACHMENT_LOAD_OP_DONT_CARE,
            stencil_Store_Op => Vk.ATTACHMENT_STORE_OP_DONT_CARE,
            initial_Layout  => Vk.IMAGE_LAYOUT_UNDEFINED,
            final_Layout    =>
              (if MSAA_On
               then Vk.IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
               else Image_Layout_Present_Source));
         Resolve_Attachment : aliased Vk.Attachment_Description_T :=
           (flags           => 0,
            format          => Device.Swapchain_Format,
            samples         => Vk.SAMPLE_COUNT_1_BIT,
            load_Op         => Vk.ATTACHMENT_LOAD_OP_DONT_CARE,
            store_Op        => Vk.ATTACHMENT_STORE_OP_STORE,
            stencil_Load_Op => Vk.ATTACHMENT_LOAD_OP_DONT_CARE,
            stencil_Store_Op => Vk.ATTACHMENT_STORE_OP_DONT_CARE,
            initial_Layout  => Vk.IMAGE_LAYOUT_UNDEFINED,
            final_Layout    => Image_Layout_Present_Source);
         Attachments : aliased Attachment_Array (1 .. 2) :=
           (1 => Color_Attachment,
            2 => Resolve_Attachment);
         Color_Reference : aliased Vk.Attachment_Reference_T :=
           (attachment => 0,
            layout     => Vk.IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL);
         Resolve_Reference : aliased Vk.Attachment_Reference_T :=
           (attachment => 1,
            layout     => Vk.IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL);
         Subpass : aliased Vk.Subpass_Description_T :=
           (flags                    => 0,
            pipeline_Bind_Point      => Vk.PIPELINE_BIND_POINT_GRAPHICS,
            input_Attachment_Count   => 0,
            p_Input_Attachments      => System.Null_Address,
            color_Attachment_Count   => 1,
            p_Color_Attachments      => Color_Reference'Address,
            p_Resolve_Attachments    =>
              (if MSAA_On then Resolve_Reference'Address else System.Null_Address),
            p_Depth_Stencil_Attachment => System.Null_Address,
            preserve_Attachment_Count => 0,
            p_Preserve_Attachments   => System.Null_Address);
         Dependency : aliased Vk.Subpass_Dependency_T :=
           (src_Subpass      => Subpass_External,
            dst_Subpass      => 0,
            src_Stage_Mask   => Vk.PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
            dst_Stage_Mask   => Vk.PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
            src_Access_Mask  => 0,
            dst_Access_Mask  =>
              Vk.ACCESS_COLOR_ATTACHMENT_READ_BIT or
              Vk.ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
            dependency_Flags => Vk.DEPENDENCY_BY_REGION_BIT);
         Render_Info : aliased Vk.Render_Pass_Create_Info_T :=
           (s_Type           => Vk.STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
            p_Next           => System.Null_Address,
            flags            => 0,
            attachment_Count => (if MSAA_On then 2 else 1),
            p_Attachments    => Attachments'Address,
            subpass_Count    => 1,
            p_Subpasses      => Subpass'Address,
            dependency_Count => 1,
            p_Dependencies   => Dependency'Address);
         Render_Pass : aliased Vk.Render_Pass_T := System.Null_Address;
         Result : Vk.Result_T;
      begin
         if Device.Swapchain_View_Count = 0
           or else Device.Swapchain_Width = 0
           or else Device.Swapchain_Height = 0
         then
            return Create_Framebuffer_Failed;
         end if;

         Device.Color_Sample_Count := Samples;
         declare
            Target_Status : constant Create_Status :=
              Create_Color_MSAA_Target
                (Handle, Device.Swapchain_Format, Device.Color_Sample_Count);
         begin
            if Target_Status /= Ok then
               return Target_Status;
            end if;
         end;

         Result :=
           Vk.Create_Render_Pass
             (Handle, Render_Info'Address, System.Null_Address, Render_Pass'Address);
         if Result /= Vk.SUCCESS or else Render_Pass = System.Null_Address then
            Destroy_Color_MSAA_Target (Handle);
            return Create_Render_Pass_Failed;
         end if;

         Device.Render_Pass := Render_Pass;

         for I in 1 .. Device.Swapchain_View_Count loop
            declare
               Attachments : aliased Image_View_Array (1 .. 2) :=
                 (1 => System.Null_Address,
                  2 => System.Null_Address);
               Framebuffer : aliased Vk.Framebuffer_T := System.Null_Address;
               FB_Info : aliased Vk.Framebuffer_Create_Info_T :=
                 (s_Type           => Vk.STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                  p_Next           => System.Null_Address,
                  flags            => 0,
                  render_Pass      => Device.Render_Pass,
                  attachment_Count => (if MSAA_On then 2 else 1),
                  p_Attachments    => Attachments'Address,
                  width            => Interfaces.Unsigned_32 (Device.Swapchain_Width),
                  height           => Interfaces.Unsigned_32 (Device.Swapchain_Height),
                  layers           => 1);
            begin
               if MSAA_On then
                  Attachments (1) := Device.Color_MSAA_View;
                  Attachments (2) := Device.Swapchain_Views (I);
               else
                  Attachments (1) := Device.Swapchain_Views (I);
               end if;
               Result :=
                 Vk.Create_Framebuffer
                   (Handle, FB_Info'Address, System.Null_Address, Framebuffer'Address);
               if Result /= Vk.SUCCESS or else Framebuffer = System.Null_Address then
                  Destroy_Framebuffers (Handle);
                  Vk.Destroy_Render_Pass
                    (Handle, Device.Render_Pass, System.Null_Address);
                  Device.Render_Pass := System.Null_Address;
                  Destroy_Color_MSAA_Target (Handle);
                  return Create_Framebuffer_Failed;
               end if;

               Device.Framebuffers (I) := Framebuffer;
               Device.Framebuffer_Count := I;
            end;
         end loop;

         return Ok;
      end Create_Render_Pass_And_Framebuffers;


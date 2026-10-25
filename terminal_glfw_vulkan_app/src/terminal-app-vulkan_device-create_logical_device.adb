separate (Terminal.App.Vulkan_Device)
   procedure Create_Logical_Device
     (Choice : Selection;
      Surface : Vk.Surface_KHR_T;
      Desired_Width : Natural;
      Desired_Height : Natural;
      Device : out Logical_Device;
      Status : out Create_Status)
   is
      Priority : aliased Interfaces.C.C_float := 1.0;
      Extension_Name : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String ("VK_KHR_swapchain");
      Extensions : Chars_Ptr_Array (1 .. 1) := (1 => Extension_Name);
      Queue_Info : aliased Vk.Device_Queue_Create_Info_T :=
        (s_Type             => Vk.STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
         p_Next             => System.Null_Address,
         flags              => 0,
         queue_Family_Index => Interfaces.Unsigned_32 (Choice.Queue_Family_Index),
         queue_Count        => 1,
         p_Queue_Priorities => Priority'Address);
      Create_Info : aliased Vk.Device_Create_Info_T :=
        (s_Type                   => Vk.STRUCTURE_TYPE_DEVICE_CREATE_INFO,
         p_Next                   => System.Null_Address,
         flags                    => 0,
         queue_Create_Info_Count  => 1,
         p_Queue_Create_Infos     => Queue_Info'Address,
         enabled_Layer_Count      => 0,
         pp_Enabled_Layer_Names   => System.Null_Address,
         enabled_Extension_Count  => 1,
         pp_Enabled_Extension_Names => Extensions'Address,
         p_Enabled_Features       => System.Null_Address);
      Handle : aliased Vk.Device_T := System.Null_Address;
      Queue  : aliased Vk.Queue_T := System.Null_Address;
      Result : Vk.Result_T;
      Extension_Count : Natural := 0;

      procedure Reset_Device (Status_Value : Create_Status) is
      begin
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
         Device.Uploaded_Image_Vertex_Count := 0;
         Device.Uploaded_Image_Texture_Vertex_Count := 0;
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
         Device.Last_Status := Status_Value;
      end Reset_Device;

      function Create_Image_Views
        (Handle : Vk.Device_T)
         return Create_Status
      is separate;

      procedure Destroy_Framebuffers (Handle : Vk.Device_T) is
      begin
         for I in 1 .. Device.Framebuffer_Count loop
            if Device.Framebuffers (I) /= System.Null_Address then
               Vk.Destroy_Framebuffer
                 (Handle, Device.Framebuffers (I), System.Null_Address);
               Device.Framebuffers (I) := System.Null_Address;
            end if;
         end loop;
         Device.Framebuffer_Count := 0;
      end Destroy_Framebuffers;

      procedure Destroy_Image_Views (Handle : Vk.Device_T) is
      begin
         for I in 1 .. Device.Swapchain_View_Count loop
            if Device.Swapchain_Views (I) /= System.Null_Address then
               Vk.Destroy_Image_View
                 (Handle, Device.Swapchain_Views (I), System.Null_Address);
               Device.Swapchain_Views (I) := System.Null_Address;
            end if;
         end loop;
         Device.Swapchain_View_Count := 0;
      end Destroy_Image_Views;

      procedure Destroy_Color_MSAA_Target (Handle : Vk.Device_T) is
      begin
         if Device.Color_MSAA_View /= System.Null_Address then
            Vk.Destroy_Image_View
              (Handle, Device.Color_MSAA_View, System.Null_Address);
            Device.Color_MSAA_View := System.Null_Address;
         end if;

         if Device.Color_MSAA_Image /= System.Null_Address then
            Vk.Destroy_Image
              (Handle, Device.Color_MSAA_Image, System.Null_Address);
            Device.Color_MSAA_Image := System.Null_Address;
         end if;

         if Device.Color_MSAA_Memory /= System.Null_Address then
            Vk.Free_Memory
              (Handle, Device.Color_MSAA_Memory, System.Null_Address);
            Device.Color_MSAA_Memory := System.Null_Address;
         end if;

         Device.Color_Sample_Count := Vk.SAMPLE_COUNT_1_BIT;
      end Destroy_Color_MSAA_Target;

      function Choose_Color_Sample_Count
        return Vk.Sample_Count_Flag_Bits_T;

      function Create_Color_MSAA_Target
        (Handle  : Vk.Device_T;
         Format  : Vk.Format_T;
         Samples : Vk.Sample_Count_Flag_Bits_T)
         return Create_Status;

      procedure Destroy_Sync (Handle : Vk.Device_T) is
      begin
         if Device.Upload_Fence /= System.Null_Address then
            Vk.Destroy_Fence
              (Handle, Device.Upload_Fence, System.Null_Address);
            Device.Upload_Fence := System.Null_Address;
         end if;
         for I in 1 .. Device.Sync_Frame_Count loop
            if Device.In_Flight (I) /= System.Null_Address then
               Vk.Destroy_Fence (Handle, Device.In_Flight (I), System.Null_Address);
               Device.In_Flight (I) := System.Null_Address;
            end if;
            if Device.Render_Finished (I) /= System.Null_Address then
               Vk.Destroy_Semaphore
                 (Handle, Device.Render_Finished (I), System.Null_Address);
               Device.Render_Finished (I) := System.Null_Address;
            end if;
            if Device.Image_Available (I) /= System.Null_Address then
               Vk.Destroy_Semaphore
                 (Handle, Device.Image_Available (I), System.Null_Address);
               Device.Image_Available (I) := System.Null_Address;
            end if;
         end loop;
         Device.Sync_Frame_Count := 0;
      end Destroy_Sync;

      procedure Destroy_Command_Resources (Handle : Vk.Device_T) is
      begin
         if Device.Command_Pool /= System.Null_Address then
            if Device.Upload_Command_Buffer /= System.Null_Address then
               Vk.Free_Command_Buffers
                 (Handle,
                  Device.Command_Pool,
                  1,
                  Device.Upload_Command_Buffer'Address);
               Device.Upload_Command_Buffer := System.Null_Address;
            end if;
            if Device.Command_Buffer_Count > 0 then
               Vk.Free_Command_Buffers
                 (Handle,
                  Device.Command_Pool,
                  Interfaces.Unsigned_32 (Device.Command_Buffer_Count),
                  Device.Command_Buffers'Address);
            end if;

            Vk.Destroy_Command_Pool
              (Handle, Device.Command_Pool, System.Null_Address);
         end if;

         Device.Command_Pool := System.Null_Address;
         Device.Command_Buffers := (others => System.Null_Address);
         Device.Command_Buffer_Count := 0;
      end Destroy_Command_Resources;

      procedure Destroy_Descriptor_Resources (Handle : Vk.Device_T) is
      begin
         if Device.Atlas_Sampler /= System.Null_Address then
            Vk.Destroy_Sampler (Handle, Device.Atlas_Sampler, System.Null_Address);
            Device.Atlas_Sampler := System.Null_Address;
         end if;

         if Device.Descriptor_Pool /= System.Null_Address then
            Vk.Destroy_Descriptor_Pool
              (Handle, Device.Descriptor_Pool, System.Null_Address);
            Device.Descriptor_Pool := System.Null_Address;
            Device.Descriptor_Set := System.Null_Address;
         end if;

         if Device.Descriptor_Set_Layout /= System.Null_Address then
            Vk.Destroy_Descriptor_Set_Layout
              (Handle, Device.Descriptor_Set_Layout, System.Null_Address);
            Device.Descriptor_Set_Layout := System.Null_Address;
         end if;
         Device.Image_Texture_Descriptor_Capacity := 0;
         Device.Image_Texture_Descriptor_Bound_Count := 0;
      end Destroy_Descriptor_Resources;

      function Create_Descriptor_Resources
        (Handle : Vk.Device_T)
         return Create_Status
      is separate;

      function Create_Pipeline_Layout
        (Handle : Vk.Device_T)
         return Create_Status
      is separate;

      function Create_Shader_Module
        (Handle : Vk.Device_T;
         Code   : Shaders.Shader_Code;
         Module : out Vk.Shader_Module_T)
         return Create_Status
      is separate;

      function Create_Graphics_Pipeline
        (Handle : Vk.Device_T)
         return Create_Status
      is separate;

      function Create_Render_Pass_And_Framebuffers
        (Handle : Vk.Device_T)
         return Create_Status
      is separate;

      function Create_Command_Resources_And_Sync
        (Handle : Vk.Device_T)
         return Create_Status
      is separate;

      function Select_Surface_Format
        (Format_Count : Interfaces.Unsigned_32;
         Formats      : Surface_Format_Array)
         return Vk.Surface_Format_KHR_T
      is
      begin
         if Format_Count = 1 and then Formats (1).format = Vk.FORMAT_UNDEFINED then
            return
              (format      => Vk.FORMAT_B8G8R8A8_SRGB,
               color_Space => Vk.COLOR_SPACE_SRGB_NONLINEAR_KHR);
         end if;

         for I in 1 .. Natural (Format_Count) loop
            if Formats (I).format = Vk.FORMAT_B8G8R8A8_SRGB
              and then Formats (I).color_Space = Vk.COLOR_SPACE_SRGB_NONLINEAR_KHR
            then
               return Formats (I);
            end if;
         end loop;

         for I in 1 .. Natural (Format_Count) loop
            if Formats (I).format = Vk.FORMAT_B8G8R8A8_UNORM
              and then Formats (I).color_Space = Vk.COLOR_SPACE_SRGB_NONLINEAR_KHR
            then
               return Formats (I);
            end if;
         end loop;

         return Formats (1);
      end Select_Surface_Format;

      function Select_Present_Mode
        (Mode_Count : Interfaces.Unsigned_32;
         Modes      : Present_Mode_Array)
         return Vk.Present_Mode_KHR_T
      is
      begin
         for I in 1 .. Natural (Mode_Count) loop
            if Modes (I) = Vk.PRESENT_MODE_MAILBOX_KHR then
               return Vk.PRESENT_MODE_MAILBOX_KHR;
            end if;
         end loop;

         return Vk.PRESENT_MODE_FIFO_KHR;
      end Select_Present_Mode;

      function Select_Extent
        (Capabilities : Vk.Surface_Capabilities_KHR_T)
         return Vk.Extent2_D_T
      is
         Width : Interfaces.Unsigned_32;
         Height : Interfaces.Unsigned_32;
      begin
         if Capabilities.current_Extent.width /= UInt32_Max then
            return Capabilities.current_Extent;
         end if;

         Width :=
           (if Desired_Width = 0
            then 960
            else Interfaces.Unsigned_32 (Desired_Width));
         Height :=
           (if Desired_Height = 0
            then 600
            else Interfaces.Unsigned_32 (Desired_Height));

         return
           (width  =>
              Clamp_U32
                (Width,
                 Capabilities.min_Image_Extent.width,
                 Capabilities.max_Image_Extent.width),
            height =>
              Clamp_U32
                (Height,
                 Capabilities.min_Image_Extent.height,
                 Capabilities.max_Image_Extent.height));
      end Select_Extent;

      function Choose_Image_Count
        (Capabilities : Vk.Surface_Capabilities_KHR_T)
         return Interfaces.Unsigned_32
      is
         Count : Interfaces.Unsigned_32 := Capabilities.min_Image_Count + 1;
      begin
         if Capabilities.max_Image_Count > 0 then
            Count := U32_Min (Count, Capabilities.max_Image_Count);
         end if;
         return Count;
      end Choose_Image_Count;

      function Choose_Composite_Alpha
        (Capabilities : Vk.Surface_Capabilities_KHR_T)
         return Vk.Composite_Alpha_Flag_Bits_KHR_T is
      begin
         if (Capabilities.supported_Composite_Alpha
             and Vk.COMPOSITE_ALPHA_OPAQUE_BIT_KHR) /= 0
         then
            return Vk.COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
         elsif (Capabilities.supported_Composite_Alpha
                and Vk.COMPOSITE_ALPHA_PRE_MULTIPLIED_BIT_KHR) /= 0
         then
            return Vk.COMPOSITE_ALPHA_PRE_MULTIPLIED_BIT_KHR;
         elsif (Capabilities.supported_Composite_Alpha
                and Vk.COMPOSITE_ALPHA_POST_MULTIPLIED_BIT_KHR) /= 0
         then
            return Vk.COMPOSITE_ALPHA_POST_MULTIPLIED_BIT_KHR;
         else
            return Vk.COMPOSITE_ALPHA_INHERIT_BIT_KHR;
         end if;
      end Choose_Composite_Alpha;

      function Choose_Color_Sample_Count
        return Vk.Sample_Count_Flag_Bits_T
      is
         Properties : aliased Vk.Physical_Device_Properties_T;
         Counts     : Vk.Sample_Count_Flags_T;
      begin
         Vk.Get_Physical_Device_Properties
           (Choice.Physical_Device, Properties'Address);
         Counts := Properties.limits.framebuffer_Color_Sample_Counts;

         if (Counts and Vk.SAMPLE_COUNT_8_BIT) /= 0 then
            return Vk.SAMPLE_COUNT_8_BIT;
         elsif (Counts and Vk.SAMPLE_COUNT_4_BIT) /= 0 then
            return Vk.SAMPLE_COUNT_4_BIT;
         elsif (Counts and Vk.SAMPLE_COUNT_2_BIT) /= 0 then
            return Vk.SAMPLE_COUNT_2_BIT;
         else
            return Vk.SAMPLE_COUNT_1_BIT;
         end if;
      end Choose_Color_Sample_Count;

      function Create_Color_MSAA_Target
        (Handle  : Vk.Device_T;
         Format  : Vk.Format_T;
         Samples : Vk.Sample_Count_Flag_Bits_T)
         return Create_Status
      is
         Memory_Properties : aliased Vk.Physical_Device_Memory_Properties_T;
         Image : aliased Vk.Image_T := System.Null_Address;
         Image_Memory : aliased Vk.Device_Memory_T := System.Null_Address;
         Image_View : aliased Vk.Image_View_T := System.Null_Address;
         Requirements : aliased Vk.Memory_Requirements_T;
         Memory_Type_Index : Interfaces.Unsigned_32 := 0;
         Result : Vk.Result_T;
      begin
         if Samples = Vk.SAMPLE_COUNT_1_BIT then
            return Ok;
         end if;

         declare
            Image_Info : aliased Vk.Image_Create_Info_T :=
              (s_Type => Vk.STRUCTURE_TYPE_IMAGE_CREATE_INFO,
               p_Next => System.Null_Address,
               flags => 0,
               image_Type => Vk.IMAGE_TYPE_2D,
               format => Format,
               extent =>
                 (width => Interfaces.Unsigned_32 (Device.Swapchain_Width),
                  height => Interfaces.Unsigned_32 (Device.Swapchain_Height),
                  depth => 1),
               mip_Levels => 1,
               array_Layers => 1,
               samples => Samples,
               tiling => Vk.IMAGE_TILING_OPTIMAL,
               usage => Vk.IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
               sharing_Mode => Vk.SHARING_MODE_EXCLUSIVE,
               queue_Family_Index_Count => 0,
               p_Queue_Family_Indices => System.Null_Address,
               initial_Layout => Vk.IMAGE_LAYOUT_UNDEFINED);
         begin
            Result :=
              Vk.Create_Image
                (Handle, Image_Info'Address, System.Null_Address, Image'Address);
            if Result /= Vk.SUCCESS or else Image = System.Null_Address then
               return Create_Color_Target_Failed;
            end if;
         end;

         Vk.Get_Image_Memory_Requirements
           (Handle, Image, Requirements'Address);
         Vk.Get_Physical_Device_Memory_Properties
           (Choice.Physical_Device, Memory_Properties'Address);
         if not Has_Memory_Type
           (Memory_Properties, Requirements.memory_Type_Bits, 0, Memory_Type_Index)
         then
            Vk.Destroy_Image (Handle, Image, System.Null_Address);
            return Create_Color_Target_Failed;
         end if;

         declare
            Allocate_Info : aliased Vk.Memory_Allocate_Info_T :=
              (s_Type => Vk.STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
               p_Next => System.Null_Address,
               allocation_Size => Requirements.size,
               memory_Type_Index => Memory_Type_Index);
         begin
            Result :=
              Vk.Allocate_Memory
                (Handle,
                 Allocate_Info'Address,
                 System.Null_Address,
                 Image_Memory'Address);
            if Result /= Vk.SUCCESS or else Image_Memory = System.Null_Address then
               Vk.Destroy_Image (Handle, Image, System.Null_Address);
               return Create_Color_Target_Failed;
            end if;
         end;

         Result := Vk.Bind_Image_Memory (Handle, Image, Image_Memory, 0);
         if Result /= Vk.SUCCESS then
            Vk.Free_Memory (Handle, Image_Memory, System.Null_Address);
            Vk.Destroy_Image (Handle, Image, System.Null_Address);
            return Create_Color_Target_Failed;
         end if;

         declare
            View_Info : aliased Vk.Image_View_Create_Info_T :=
              (s_Type => Vk.STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
               p_Next => System.Null_Address,
               flags => 0,
               image => Image,
               view_Type => Vk.IMAGE_VIEW_TYPE_2D,
               format => Format,
               components =>
                 (r => Vk.COMPONENT_SWIZZLE_IDENTITY,
                  g => Vk.COMPONENT_SWIZZLE_IDENTITY,
                  b => Vk.COMPONENT_SWIZZLE_IDENTITY,
                  a => Vk.COMPONENT_SWIZZLE_IDENTITY),
               subresource_Range =>
                 (aspect_Mask => Vk.IMAGE_ASPECT_COLOR_BIT,
                  base_Mip_Level => 0,
                  level_Count => 1,
                  base_Array_Layer => 0,
                  layer_Count => 1));
         begin
            Result :=
              Vk.Create_Image_View
                (Handle,
                 View_Info'Address,
                 System.Null_Address,
                 Image_View'Address);
            if Result /= Vk.SUCCESS or else Image_View = System.Null_Address then
               Vk.Free_Memory (Handle, Image_Memory, System.Null_Address);
               Vk.Destroy_Image (Handle, Image, System.Null_Address);
               return Create_Color_Target_Failed;
            end if;
         end;

         Device.Color_MSAA_Image := Image;
         Device.Color_MSAA_Memory := Image_Memory;
         Device.Color_MSAA_View := Image_View;
         return Ok;
      end Create_Color_MSAA_Target;

      function Create_Swapchain
        (Handle : Vk.Device_T)
         return Create_Status
      is separate;

      procedure Fail_Creation (Cause : Create_Status) is
      begin
         --  Logical_Device is the single owner for every handle acquired by
         --  this transaction.  Publishing a partial device to that controlled
         --  owner lets every failure use one reverse-order cleanup path.
         if Extension_Name /= Interfaces.C.Strings.Null_Ptr then
            Interfaces.C.Strings.Free (Extension_Name);
         end if;
         if Device.Device = System.Null_Address
           and then Handle /= System.Null_Address
         then
            Device.Device := Handle;
         end if;
         Finalize (Device);
         Device.Last_Status := Cause;
         Status := Cause;
      end Fail_Creation;
   begin
      Reset_Device (Selection_Not_Ready);

      if not Choice.Selected or else Choice.Physical_Device = System.Null_Address then
         Fail_Creation (Selection_Not_Ready);
         return;
      end if;

      if not Device_Supports_Swapchain (Choice.Physical_Device, Extension_Count) then
         Fail_Creation (Swapchain_Extension_Missing);
         return;
      end if;

      Result :=
        Vk.Create_Device
          (Choice.Physical_Device,
           Create_Info'Address,
           System.Null_Address,
           Handle'Address);
      Interfaces.C.Strings.Free (Extension_Name);

      if Result /= Vk.SUCCESS or else Handle = System.Null_Address then
         Fail_Creation (Create_Device_Failed);
         return;
      end if;

      Device.Initialized := True;
      Device.Device := Handle;

      Vk.Get_Device_Queue
        (Handle,
         Interfaces.Unsigned_32 (Choice.Queue_Family_Index),
         0,
         Queue'Address);

      if Queue = System.Null_Address then
         Fail_Creation (Queue_Unavailable);
         return;
      end if;

      Device.Queue := Queue;
      Device.Queue_Family_Index := Choice.Queue_Family_Index;

      declare
         Swapchain_Status : constant Create_Status := Create_Swapchain (Handle);
      begin
         if Swapchain_Status /= Ok then
            Fail_Creation (Swapchain_Status);
            return;
         end if;
      end;

      declare
         View_Status : constant Create_Status := Create_Image_Views (Handle);
      begin
         if View_Status /= Ok then
            Fail_Creation (View_Status);
            return;
         end if;
      end;

      declare
         Render_Status : constant Create_Status :=
           Create_Render_Pass_And_Framebuffers (Handle);
      begin
         if Render_Status /= Ok then
            Fail_Creation (Render_Status);
            return;
         end if;
      end;

      declare
         Command_Status : constant Create_Status :=
           Create_Command_Resources_And_Sync (Handle);
      begin
         if Command_Status /= Ok then
            Fail_Creation (Command_Status);
            return;
         end if;
      end;

      declare
         Descriptor_Status : constant Create_Status :=
           Create_Descriptor_Resources (Handle);
      begin
         if Descriptor_Status /= Ok then
            Fail_Creation (Descriptor_Status);
            return;
         end if;
      end;

      declare
         Layout_Status : constant Create_Status := Create_Pipeline_Layout (Handle);
      begin
         if Layout_Status /= Ok then
            Fail_Creation (Layout_Status);
            return;
         end if;
      end;

      declare
         Default_Atlas_Pixel : aliased Interfaces.Unsigned_8 := 255;
         Atlas_Status : Create_Status;
      begin
         Upload_Atlas_Data
           (Device        => Device,
            Choice        => Choice,
            Width         => 1,
            Height        => 1,
            Bytes_Natural => 1,
            Pixels        => Default_Atlas_Pixel'Address,
            Dirty         => True,
            Status        => Atlas_Status);
         if Atlas_Status /= Ok then
            Fail_Creation (Atlas_Status);
            return;
         end if;
      end;

      declare
         Pipeline_Status : constant Create_Status := Create_Graphics_Pipeline (Handle);
      begin
         if Pipeline_Status /= Ok then
            Fail_Creation (Pipeline_Status);
            return;
         end if;
      end;

      Device.Last_Status := Ok;
      Status := Ok;
   exception
      when others =>
         --  Foreign API wrappers and Ada-side capacity arithmetic can still
         --  raise.  Preserve exception semantics after releasing every handle
         --  acquired by this transaction.
         Fail_Creation (Create_Device_Failed);
         raise;
   end Create_Logical_Device;


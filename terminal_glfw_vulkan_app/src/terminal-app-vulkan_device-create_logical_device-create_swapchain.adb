separate (Terminal.App.Vulkan_Device.Create_Logical_Device)
      function Create_Swapchain
        (Handle : Vk.Device_T)
         return Create_Status
      is
         Capabilities : aliased Vk.Surface_Capabilities_KHR_T;
         Format_Count : aliased Interfaces.Unsigned_32 := 0;
         Present_Mode_Count : aliased Interfaces.Unsigned_32 := 0;
         Formats : Surface_Format_Array;
         Modes : Present_Mode_Array;
         Chosen_Format : Vk.Surface_Format_KHR_T;
         Chosen_Mode : Vk.Present_Mode_KHR_T;
         Chosen_Extent : Vk.Extent2_D_T;
         Chosen_Image_Count : Interfaces.Unsigned_32;
         Swapchain : aliased Vk.Swapchain_KHR_T := System.Null_Address;
         Swap_Info : aliased Vk.Swapchain_Create_Info_KHR_T;
         Result : Vk.Result_T;
      begin
         if Surface = System.Null_Address then
            return Surface_Query_Failed;
         end if;

         Result :=
           Vk.Get_Physical_Device_Surface_Capabilities_KHR
             (Choice.Physical_Device, Surface, Capabilities'Address);
         if Result /= Vk.SUCCESS then
            return Surface_Query_Failed;
         end if;

         if (Capabilities.supported_Usage_Flags and
             Vk.IMAGE_USAGE_COLOR_ATTACHMENT_BIT) = 0
         then
            return Create_Swapchain_Failed;
         end if;
         Device.Readback_Supported :=
           (Capabilities.supported_Usage_Flags and
              Vk.IMAGE_USAGE_TRANSFER_SRC_BIT) /= 0;

         Result :=
           Vk.Get_Physical_Device_Surface_Formats_KHR
             (Choice.Physical_Device,
              Surface,
              Format_Count'Address,
              System.Null_Address);
         if Result /= Vk.SUCCESS or else Format_Count = 0 then
            return Surface_Query_Failed;
         end if;

         Format_Count :=
           U32_Min (Format_Count, Interfaces.Unsigned_32 (Max_Surface_Formats));
         Result :=
           Vk.Get_Physical_Device_Surface_Formats_KHR
             (Choice.Physical_Device, Surface, Format_Count'Address, Formats'Address);
         if Result /= Vk.SUCCESS then
            return Surface_Query_Failed;
         end if;

         Result :=
           Vk.Get_Physical_Device_Surface_Present_Modes_KHR
             (Choice.Physical_Device,
              Surface,
              Present_Mode_Count'Address,
              System.Null_Address);
         if Result /= Vk.SUCCESS or else Present_Mode_Count = 0 then
            return Surface_Query_Failed;
         end if;

         Present_Mode_Count :=
           U32_Min (Present_Mode_Count, Interfaces.Unsigned_32 (Max_Present_Modes));
         Result :=
           Vk.Get_Physical_Device_Surface_Present_Modes_KHR
             (Choice.Physical_Device,
              Surface,
              Present_Mode_Count'Address,
              Modes'Address);
         if Result /= Vk.SUCCESS then
            return Surface_Query_Failed;
         end if;

         Chosen_Format := Select_Surface_Format (Format_Count, Formats);
         Chosen_Mode := Select_Present_Mode (Present_Mode_Count, Modes);
         Chosen_Extent := Select_Extent (Capabilities);
         if Chosen_Extent.width = 0 or else Chosen_Extent.height = 0 then
            return Invalid_Extent;
         end if;
         Chosen_Image_Count := Choose_Image_Count (Capabilities);

         Swap_Info :=
           (s_Type                   => Swapchain_Create_Info_Structure,
            p_Next                   => System.Null_Address,
            flags                    => 0,
            surface                  => Surface,
            min_Image_Count          => Chosen_Image_Count,
            image_Format             => Chosen_Format.format,
            image_Color_Space        => Chosen_Format.color_Space,
            image_Extent             => Chosen_Extent,
            image_Array_Layers       => 1,
            image_Usage              =>
              Vk.IMAGE_USAGE_COLOR_ATTACHMENT_BIT
              or
                (if Device.Readback_Supported
                 then Vk.IMAGE_USAGE_TRANSFER_SRC_BIT
                 else 0),
            image_Sharing_Mode       => Vk.SHARING_MODE_EXCLUSIVE,
            queue_Family_Index_Count => 0,
            p_Queue_Family_Indices   => System.Null_Address,
            pre_Transform            => Capabilities.current_Transform,
            composite_Alpha          => Choose_Composite_Alpha (Capabilities),
            present_Mode             => Chosen_Mode,
            clipped                  => 1,
            old_Swapchain            => System.Null_Address);

         Result :=
           Vk.Create_Swapchain_KHR
             (Handle, Swap_Info'Address, System.Null_Address, Swapchain'Address);
         if Result /= Vk.SUCCESS or else Swapchain = System.Null_Address then
            return Create_Swapchain_Failed;
         end if;

         Device.Swapchain := Swapchain;
         Device.Swapchain_Format := Chosen_Format.format;
         Device.Swapchain_Width := Natural (Chosen_Extent.width);
         Device.Swapchain_Height := Natural (Chosen_Extent.height);
         return Ok;
      end Create_Swapchain;


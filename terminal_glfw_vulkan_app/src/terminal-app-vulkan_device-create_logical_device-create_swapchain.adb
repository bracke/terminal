separate (Terminal.App.Vulkan_Device.Create_Logical_Device)
      function Create_Swapchain
        (Handle : Vk.Device_T)
         return Create_Status
      is
         type Queue_Family_Array is array (Positive range <>) of
           Interfaces.Unsigned_32 with Convention => C;
         Capabilities : aliased Vk.Surface_Capabilities_KHR_T;
         Format_Count : aliased Interfaces.Unsigned_32 := 0;
         Present_Mode_Count : aliased Interfaces.Unsigned_32 := 0;
         Format_Length : Natural := 0;
         Present_Mode_Length : Natural := 0;
         Formats : Surface_Format_Array_Access := null;
         Modes : Present_Mode_Array_Access := null;
         Chosen_Format : Vk.Surface_Format_KHR_T;
         Chosen_Mode : Vk.Present_Mode_KHR_T;
         Chosen_Extent : Vk.Extent2_D_T;
         Chosen_Image_Count : Interfaces.Unsigned_32;
         Swapchain : aliased Vk.Swapchain_KHR_T := System.Null_Address;
         Swap_Info : aliased Vk.Swapchain_Create_Info_KHR_T;
         Result : Vk.Result_T;
         Formats_Ready : Boolean := False;
         Modes_Ready : Boolean := False;
         Queue_Families : aliased Queue_Family_Array (1 .. 2) :=
           (Queue_Plan.Graphics_Family, Queue_Plan.Present_Family);

         function Query_Formats
           (Reported : not null access Interfaces.Unsigned_32;
            Data     : System.Address) return Vk.Result_T
         is (Vk.Get_Physical_Device_Surface_Formats_KHR
               (Choice.Physical_Device,
                Surface,
                Reported.all'Address,
                Data));

         package Format_Enumeration is new Terminal.App.Vulkan_Enumeration
           (Element_Type         => Vk.Surface_Format_KHR_T,
            Element_Array        => Surface_Format_Array,
            Element_Array_Access => Surface_Format_Array_Access,
            Query                => Query_Formats);
         Format_Fetch : Format_Enumeration.Fetch_Status;

         function Query_Modes
           (Reported : not null access Interfaces.Unsigned_32;
            Data     : System.Address) return Vk.Result_T
         is (Vk.Get_Physical_Device_Surface_Present_Modes_KHR
               (Choice.Physical_Device,
                Surface,
                Reported.all'Address,
                Data));

         package Mode_Enumeration is new Terminal.App.Vulkan_Enumeration
           (Element_Type         => Vk.Present_Mode_KHR_T,
            Element_Array        => Present_Mode_Array,
            Element_Array_Access => Present_Mode_Array_Access,
            Query                => Query_Modes);
         Mode_Fetch : Mode_Enumeration.Fetch_Status;
         use type Format_Enumeration.Fetch_Status;
         use type Mode_Enumeration.Fetch_Status;

         procedure Release_Enumerations is
         begin
            Free_Surface_Formats (Formats);
            Free_Present_Modes (Modes);
         end Release_Enumerations;

         function Finish (Value : Create_Status) return Create_Status is
         begin
            Release_Enumerations;
            return Value;
         end Finish;
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

         Format_Enumeration.Fetch
           (Enumeration_Retry_Limit,
            Max_Surface_Formats,
            Formats,
            Format_Length,
            Format_Fetch);
         Formats_Ready := Format_Fetch = Format_Enumeration.Fetch_Ready;
         if not Formats_Ready then
            return Finish (Surface_Query_Failed);
         end if;
         Format_Count := Interfaces.Unsigned_32 (Format_Length);

         Mode_Enumeration.Fetch
           (Enumeration_Retry_Limit,
            Max_Present_Modes,
            Modes,
            Present_Mode_Length,
            Mode_Fetch);
         Modes_Ready := Mode_Fetch = Mode_Enumeration.Fetch_Ready;
         if not Modes_Ready then
            return Finish (Surface_Query_Failed);
         end if;
         Present_Mode_Count := Interfaces.Unsigned_32 (Present_Mode_Length);

         Chosen_Format := Select_Surface_Format (Format_Count, Formats.all);
         Chosen_Mode := Select_Present_Mode (Present_Mode_Count, Modes.all);
         Chosen_Extent := Select_Extent (Capabilities);
         if not Terminal.App.Vulkan_Creation_Plan.Extent_Is_Valid
           (Chosen_Extent.width, Chosen_Extent.height,
            Max_Swapchain_Dimension)
         then
            return Finish (Invalid_Extent);
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
            image_Sharing_Mode       =>
              (if Queue_Plan.Concurrent_Sharing then Vk.SHARING_MODE_CONCURRENT
               else Vk.SHARING_MODE_EXCLUSIVE),
            queue_Family_Index_Count =>
              Queue_Plan.Swapchain_Queue_Family_Count,
            p_Queue_Family_Indices   =>
              (if Queue_Plan.Concurrent_Sharing then Queue_Families'Address
               else System.Null_Address),
            pre_Transform            => Capabilities.current_Transform,
            composite_Alpha          => Choose_Composite_Alpha (Capabilities),
            present_Mode             => Chosen_Mode,
            clipped                  => 1,
            old_Swapchain            => System.Null_Address);

         Result :=
           Vk.Create_Swapchain_KHR
             (Handle, Swap_Info'Address, System.Null_Address, Swapchain'Address);
         Device.Swapchain := Swapchain;
         if Result /= Vk.SUCCESS or else Swapchain = System.Null_Address then
            return Finish (Create_Swapchain_Failed);
         end if;

         Device.Swapchain_Format := Chosen_Format.format;
         Device.Swapchain_Width := Natural (Chosen_Extent.width);
         Device.Swapchain_Height := Natural (Chosen_Extent.height);
         return Finish (Ok);
      exception
         when Storage_Error =>
            Release_Enumerations;
            return Create_Swapchain_Failed;
         when others =>
            Release_Enumerations;
            raise;
      end Create_Swapchain;


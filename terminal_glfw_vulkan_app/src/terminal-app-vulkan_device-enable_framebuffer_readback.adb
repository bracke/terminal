separate (Terminal.App.Vulkan_Device)
   procedure Enable_Framebuffer_Readback
     (Device : in out Logical_Device;
      Choice : Selection;
      Status : out Readback_Status)
   is
      Buffer_Handle : aliased Vk.Buffer_T := System.Null_Address;
      Memory_Handle : aliased Vk.Device_Memory_T := System.Null_Address;
      Requirements : aliased Vk.Memory_Requirements_T;
      Properties : aliased Vk.Physical_Device_Memory_Properties_T;
      Memory_Type : Interfaces.Unsigned_32 := 0;
      Result : Vk.Result_T;
      Byte_Count : Natural := 0;

      procedure Release_Local is
      begin
         if Memory_Handle /= System.Null_Address then
            Vk.Free_Memory
              (Device.Device, Memory_Handle, System.Null_Address);
            Memory_Handle := System.Null_Address;
         end if;
         if Buffer_Handle /= System.Null_Address then
            Vk.Destroy_Buffer
              (Device.Device, Buffer_Handle, System.Null_Address);
            Buffer_Handle := System.Null_Address;
         end if;
      end Release_Local;
   begin
      if not Device.Initialized
        or else Device.Device = System.Null_Address
      then
         Status := Readback_Not_Initialized;
         return;
      elsif not Device.Readback_Supported
        or else
          Device.Swapchain_Format not in
            Vk.FORMAT_B8G8R8A8_UNORM | Vk.FORMAT_B8G8R8A8_SRGB
              | Format_R8G8B8A8_Unorm | Vk.Format_T (43)
      then
         Status := Readback_Not_Supported;
         return;
      elsif Device.Swapchain_Width = 0
        or else Device.Swapchain_Height = 0
        or else Device.Swapchain_Width >
          Max_Framebuffer_Readback_Bytes / 4 / Device.Swapchain_Height
      then
         Status := Readback_Invalid_Extent;
         return;
      end if;

      Byte_Count := Device.Swapchain_Width * Device.Swapchain_Height * 4;
      if Device.Readback_Buffer /= System.Null_Address
        and then Device.Readback_Memory /= System.Null_Address
        and then Device.Readback_Bytes = Byte_Count
      then
         Device.Readback_Enabled := True;
         Status := Readback_Ok;
         return;
      end if;

      declare
         Buffer_Info : aliased Vk.Buffer_Create_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            p_Next => System.Null_Address,
            flags => 0,
            size => Interfaces.Unsigned_64 (Byte_Count),
            usage => Vk.BUFFER_USAGE_TRANSFER_DST_BIT,
            sharing_Mode => Vk.SHARING_MODE_EXCLUSIVE,
            queue_Family_Index_Count => 0,
            p_Queue_Family_Indices => System.Null_Address);
      begin
         Result :=
           Vk.Create_Buffer
             (Device.Device,
              Buffer_Info'Address,
              System.Null_Address,
              Buffer_Handle'Address);
      end;
      if Result /= Vk.SUCCESS or else Buffer_Handle = System.Null_Address then
         Status := Readback_Create_Buffer_Failed;
         return;
      end if;

      Vk.Get_Buffer_Memory_Requirements
        (Device.Device, Buffer_Handle, Requirements'Address);
      Vk.Get_Physical_Device_Memory_Properties
        (Choice.Physical_Device, Properties'Address);
      declare
         Required : constant Vk.Memory_Property_Flags_T :=
           Vk.MEMORY_PROPERTY_HOST_VISIBLE_BIT
           or Vk.MEMORY_PROPERTY_HOST_COHERENT_BIT;
         Preferred : constant Vk.Memory_Property_Flags_T :=
           Required or Vk.MEMORY_PROPERTY_HOST_CACHED_BIT;
      begin
         if not Has_Memory_Type
           (Properties,
            Requirements.memory_Type_Bits,
            Preferred,
            Memory_Type)
           and then not Has_Memory_Type
             (Properties,
              Requirements.memory_Type_Bits,
              Required,
              Memory_Type)
         then
            Release_Local;
            Status := Readback_Allocate_Memory_Failed;
            return;
         end if;
      end;

      declare
         Allocate_Info : aliased Vk.Memory_Allocate_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            p_Next => System.Null_Address,
            allocation_Size => Requirements.size,
            memory_Type_Index => Memory_Type);
      begin
         Result :=
           Vk.Allocate_Memory
             (Device.Device,
              Allocate_Info'Address,
              System.Null_Address,
              Memory_Handle'Address);
      end;
      if Result /= Vk.SUCCESS or else Memory_Handle = System.Null_Address then
         Release_Local;
         Status := Readback_Allocate_Memory_Failed;
         return;
      end if;

      Result :=
        Vk.Bind_Buffer_Memory
          (Device.Device, Buffer_Handle, Memory_Handle, 0);
      if Result /= Vk.SUCCESS then
         Release_Local;
         Status := Readback_Bind_Memory_Failed;
         return;
      end if;

      Device.Readback_Buffer := Buffer_Handle;
      Device.Readback_Memory := Memory_Handle;
      Device.Readback_Bytes := Byte_Count;
      Device.Readback_Enabled := True;
      Device.Readback_Pending := False;
      Device.Readback_Frame := 0;
      Buffer_Handle := System.Null_Address;
      Memory_Handle := System.Null_Address;
      Status := Readback_Ok;
   exception
      when others =>
         Release_Local;
         Status := Readback_Allocate_Memory_Failed;
   end Enable_Framebuffer_Readback;


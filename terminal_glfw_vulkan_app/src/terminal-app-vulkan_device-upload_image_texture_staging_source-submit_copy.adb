separate (Terminal.App.Vulkan_Device.Upload_Image_Texture_Staging_Source)
procedure Submit_Copy is
   Command_Buffer : constant Vk.Command_Buffer_T :=
     Device.Upload_Command_Buffer;
   Begin_Info : aliased Vk.Command_Buffer_Begin_Info_T :=
     (s_Type => Vk.STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
      p_Next => System.Null_Address,
      flags => Vk.COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
      p_Inheritance_Info => System.Null_Address);
   To_Transfer : aliased Vk.Image_Memory_Barrier_T :=
     (s_Type => Vk.STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
      p_Next => System.Null_Address,
      src_Access_Mask => 0,
      dst_Access_Mask => Vk.ACCESS_TRANSFER_WRITE_BIT,
      old_Layout => Vk.IMAGE_LAYOUT_UNDEFINED,
      new_Layout => Vk.IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
      src_Queue_Family_Index => Queue_Family_Ignored,
      dst_Queue_Family_Index => Queue_Family_Ignored,
      image => Image,
      subresource_Range =>
        (aspect_Mask => Vk.IMAGE_ASPECT_COLOR_BIT,
         base_Mip_Level => 0,
         level_Count => 1,
         base_Array_Layer => 0,
         layer_Count => 1));
   Region : aliased Vk.Buffer_Image_Copy_T :=
     (buffer_Offset => 0,
      buffer_Row_Length => Vulkan_Buffer_Row_Length,
      buffer_Image_Height => 0,
      image_Subresource =>
        (aspect_Mask => Vk.IMAGE_ASPECT_COLOR_BIT,
         mip_Level => 0,
         base_Array_Layer => 0,
         layer_Count => 1),
      image_Offset => (x => 0, y => 0, z => 0),
      image_Extent =>
        (width => Interfaces.Unsigned_32 (Width),
         height => Interfaces.Unsigned_32 (Height),
         depth => 1));
   To_Shader : aliased Vk.Image_Memory_Barrier_T :=
     (s_Type => Vk.STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
      p_Next => System.Null_Address,
      src_Access_Mask => Vk.ACCESS_TRANSFER_WRITE_BIT,
      dst_Access_Mask => Vk.ACCESS_SHADER_READ_BIT,
      old_Layout => Vk.IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
      new_Layout => Vk.IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
      src_Queue_Family_Index => Queue_Family_Ignored,
      dst_Queue_Family_Index => Queue_Family_Ignored,
      image => Image,
      subresource_Range =>
        (aspect_Mask => Vk.IMAGE_ASPECT_COLOR_BIT,
         base_Mip_Level => 0,
         level_Count => 1,
         base_Array_Layer => 0,
         layer_Count => 1));
   Submit_Command_Buffers : aliased Command_Buffer_Submit_Array :=
     (1 => Command_Buffer);
   Submit_Info : aliased Vk.Submit_Info_T :=
     (s_Type => Vk.STRUCTURE_TYPE_SUBMIT_INFO,
      p_Next => System.Null_Address,
      wait_Semaphore_Count => 0,
      p_Wait_Semaphores => System.Null_Address,
      p_Wait_Dst_Stage_Mask => System.Null_Address,
      command_Buffer_Count => 1,
      p_Command_Buffers => Submit_Command_Buffers'Address,
      signal_Semaphore_Count => 0,
      p_Signal_Semaphores => System.Null_Address);
begin
   if Command_Buffer = System.Null_Address
     or else Device.Upload_Fence = System.Null_Address
   then
      Cleanup_New_Image;
      Destroy_Staging;
      Status := Copy_Atlas_Failed;
      return;
   end if;

   Result :=
     Vk.Wait_For_Fences
       (Device.Device,
        1,
        Device.Upload_Fence'Address,
        1,
        Interfaces.Unsigned_64'Last);
   if Result /= Vk.SUCCESS then
      Cleanup_New_Image;
      Destroy_Staging;
      Status :=
        (if Result = Vk.ERROR_DEVICE_LOST then Device_Lost
         else Copy_Atlas_Failed);
      return;
   end if;

   Result := Vk.Reset_Command_Buffer (Command_Buffer, 0);
   if Result /= Vk.SUCCESS then
      Cleanup_New_Image;
      Destroy_Staging;
      Status :=
        (if Result = Vk.ERROR_DEVICE_LOST then Device_Lost
         else Copy_Atlas_Failed);
      return;
   end if;

   Result := Vk.Begin_Command_Buffer (Command_Buffer, Begin_Info'Address);
   if Result /= Vk.SUCCESS then
      Cleanup_New_Image;
      Destroy_Staging;
      Status :=
        (if Result = Vk.ERROR_DEVICE_LOST then Device_Lost
         else Copy_Atlas_Failed);
      return;
   end if;

   Vk.Cmd_Pipeline_Barrier
     (Command_Buffer,
      Vk.PIPELINE_STAGE_TRANSFER_BIT,
      Vk.PIPELINE_STAGE_TRANSFER_BIT,
      0,
      0,
      System.Null_Address,
      0,
      System.Null_Address,
      1,
      To_Transfer'Address);
   Vk.Cmd_Copy_Buffer_To_Image
     (Command_Buffer,
      Staging_Buffer,
      Image,
      Vk.IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
      1,
      Region'Address);
   Vk.Cmd_Pipeline_Barrier
     (Command_Buffer,
      Vk.PIPELINE_STAGE_TRANSFER_BIT,
      Vk.PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
      0,
      0,
      System.Null_Address,
      0,
      System.Null_Address,
      1,
      To_Shader'Address);

   Result := Vk.End_Command_Buffer (Command_Buffer);
   if Result /= Vk.SUCCESS then
      Cleanup_New_Image;
      Destroy_Staging;
      Status := Copy_Atlas_Failed;
      return;
   end if;

   Result := Vk.Reset_Fences
     (Device.Device, 1, Device.Upload_Fence'Address);
   if Result /= Vk.SUCCESS then
      Cleanup_New_Image;
      Destroy_Staging;
      Status :=
        (if Result = Vk.ERROR_DEVICE_LOST then Device_Lost
         else Copy_Atlas_Failed);
      return;
   end if;
   Upload_Fence_Reset := True;

   Result :=
     Vk.Queue_Submit
       (Device.Queue, 1, Submit_Info'Address, Device.Upload_Fence);
   if Result /= Vk.SUCCESS then
      if Result /= Vk.ERROR_DEVICE_LOST then
         Restore_Upload_Fence (Device);
         Upload_Fence_Reset := False;
      end if;
      Cleanup_New_Image;
      Destroy_Staging;
      Status :=
        (if Result = Vk.ERROR_DEVICE_LOST then Device_Lost
         else Copy_Atlas_Failed);
      return;
   end if;
   Upload_Fence_Reset := False;
   Upload_Submitted := True;

   Result :=
     Vk.Wait_For_Fences
       (Device.Device,
        1,
        Device.Upload_Fence'Address,
        1,
        Interfaces.Unsigned_64'Last);
   if Result /= Vk.SUCCESS then
      Defer_Upload_Resources
        (Device,
         Staging_Buffer,
         Staging_Memory,
         Image,
         Image_Memory,
         Image_View);
      Upload_Submitted := False;
      Status :=
        (if Result = Vk.ERROR_DEVICE_LOST then Device_Lost
         else Copy_Atlas_Failed);
      return;
   end if;
   Upload_Submitted := False;
end Submit_Copy;

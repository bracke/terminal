separate (Terminal.App.Vulkan_Device)
procedure Upload_Atlas_Data
  (Device        : in out Logical_Device;
   Choice        : Selection;
   Width         : Natural;
   Height        : Natural;
   Bytes_Natural : Natural;
   Pixels        : System.Address;
   Dirty         : Boolean;
   Status        : out Create_Status)
is
   Bytes : constant Interfaces.Unsigned_64 :=
     Interfaces.Unsigned_64 (Bytes_Natural);
   Image : aliased Vk.Image_T := System.Null_Address;
   Image_Memory : aliased Vk.Device_Memory_T := System.Null_Address;
   Image_View : aliased Vk.Image_View_T := System.Null_Address;
   Staging_Buffer : aliased Vk.Buffer_T := System.Null_Address;
   Staging_Memory : aliased Vk.Device_Memory_T := System.Null_Address;
   Data : aliased System.Address := System.Null_Address;
   Memory_Requirements : aliased Vk.Memory_Requirements_T;
   Memory_Properties : aliased Vk.Physical_Device_Memory_Properties_T;
   Memory_Type_Index : Interfaces.Unsigned_32 := 0;
   Result : Vk.Result_T;

   procedure Destroy_Staging is
   begin
      if Staging_Buffer /= System.Null_Address then
         Vk.Destroy_Buffer
           (Device.Device, Staging_Buffer, System.Null_Address);
         Staging_Buffer := System.Null_Address;
      end if;

      if Staging_Memory /= System.Null_Address then
         Vk.Free_Memory
           (Device.Device, Staging_Memory, System.Null_Address);
         Staging_Memory := System.Null_Address;
      end if;
   end Destroy_Staging;

   procedure Cleanup_New_Image is
   begin
      if Image_View /= System.Null_Address then
         Vk.Destroy_Image_View
           (Device.Device, Image_View, System.Null_Address);
         Image_View := System.Null_Address;
      end if;

      if Image /= System.Null_Address then
         Vk.Destroy_Image (Device.Device, Image, System.Null_Address);
         Image := System.Null_Address;
      end if;

      if Image_Memory /= System.Null_Address then
         Vk.Free_Memory
           (Device.Device, Image_Memory, System.Null_Address);
         Image_Memory := System.Null_Address;
      end if;
   end Cleanup_New_Image;

begin
   if Width = 0
     or else Height = 0
     or else Bytes_Natural = 0
     or else Bytes_Natural > Max_Atlas_Bytes
     or else Pixels = System.Null_Address
   then
      Status := Atlas_Too_Large;
      return;
   end if;

   if not Dirty
     and then Device.Atlas_Image /= System.Null_Address
     and then Device.Atlas_Width = Width
     and then Device.Atlas_Height = Height
     and then Device.Atlas_Bytes = Bytes_Natural
   then
      Status := Ok;
      return;
   end if;

   declare
      Buffer_Info : aliased Vk.Buffer_Create_Info_T :=
        (s_Type => Vk.STRUCTURE_TYPE_BUFFER_CREATE_INFO,
         p_Next => System.Null_Address,
         flags => 0,
         size => Bytes,
         usage => Vk.BUFFER_USAGE_TRANSFER_SRC_BIT,
         sharing_Mode => Vk.SHARING_MODE_EXCLUSIVE,
         queue_Family_Index_Count => 0,
         p_Queue_Family_Indices => System.Null_Address);
   begin
      Result :=
        Vk.Create_Buffer
          (Device.Device,
           Buffer_Info'Address,
           System.Null_Address,
           Staging_Buffer'Address);
      if Result /= Vk.SUCCESS or else Staging_Buffer = System.Null_Address then
         Status := Create_Atlas_Staging_Buffer_Failed;
         return;
      end if;
   end;

   Vk.Get_Buffer_Memory_Requirements
     (Device.Device, Staging_Buffer, Memory_Requirements'Address);
   Vk.Get_Physical_Device_Memory_Properties
     (Choice.Physical_Device, Memory_Properties'Address);

   if not Has_Memory_Type
     (Memory_Properties,
      Memory_Requirements.memory_Type_Bits,
      Vk.MEMORY_PROPERTY_HOST_VISIBLE_BIT or
        Vk.MEMORY_PROPERTY_HOST_COHERENT_BIT,
      Memory_Type_Index)
   then
      Destroy_Staging;
      Status := Allocate_Atlas_Staging_Memory_Failed;
      return;
   end if;

   declare
      Allocate_Info : aliased Vk.Memory_Allocate_Info_T :=
        (s_Type => Vk.STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
         p_Next => System.Null_Address,
         allocation_Size => Memory_Requirements.size,
         memory_Type_Index => Memory_Type_Index);
   begin
      Result :=
        Vk.Allocate_Memory
          (Device.Device,
           Allocate_Info'Address,
           System.Null_Address,
           Staging_Memory'Address);
      if Result /= Vk.SUCCESS or else Staging_Memory = System.Null_Address then
         Destroy_Staging;
         Status := Allocate_Atlas_Staging_Memory_Failed;
         return;
      end if;
   end;

   Result :=
     Vk.Bind_Buffer_Memory (Device.Device, Staging_Buffer, Staging_Memory, 0);
   if Result /= Vk.SUCCESS then
      Destroy_Staging;
      Status := Bind_Atlas_Staging_Buffer_Failed;
      return;
   end if;

   Result :=
     Vk.Map_Memory
       (Device.Device, Staging_Memory, 0, Bytes, 0, Data'Address);
   if Result /= Vk.SUCCESS or else Data = System.Null_Address then
      Destroy_Staging;
      Status := Map_Atlas_Staging_Buffer_Failed;
      return;
   end if;

   declare
      Source : constant Byte_Mapping.Object_Pointer :=
        Byte_Mapping.To_Pointer (Pixels);
      Target : constant Byte_Mapping.Object_Pointer :=
        Byte_Mapping.To_Pointer (Data);
   begin
      for I in 1 .. Bytes_Natural loop
         Target.all (I) := Source.all (I);
      end loop;
   end;
   Vk.Unmap_Memory (Device.Device, Staging_Memory);

   declare
      Image_Info : aliased Vk.Image_Create_Info_T :=
        (s_Type => Vk.STRUCTURE_TYPE_IMAGE_CREATE_INFO,
         p_Next => System.Null_Address,
         flags => 0,
         image_Type => Vk.IMAGE_TYPE_2D,
         format => Vk.FORMAT_R8_UNORM,
         extent =>
           (width => Interfaces.Unsigned_32 (Width),
            height => Interfaces.Unsigned_32 (Height),
            depth => 1),
         mip_Levels => 1,
         array_Layers => 1,
         samples => Vk.SAMPLE_COUNT_1_BIT,
         tiling => Vk.IMAGE_TILING_OPTIMAL,
         usage => Vk.IMAGE_USAGE_TRANSFER_DST_BIT or Vk.IMAGE_USAGE_SAMPLED_BIT,
         sharing_Mode => Vk.SHARING_MODE_EXCLUSIVE,
         queue_Family_Index_Count => 0,
         p_Queue_Family_Indices => System.Null_Address,
         initial_Layout => Vk.IMAGE_LAYOUT_UNDEFINED);
   begin
      Result :=
        Vk.Create_Image
          (Device.Device, Image_Info'Address, System.Null_Address, Image'Address);
      if Result /= Vk.SUCCESS or else Image = System.Null_Address then
         Destroy_Staging;
         Status := Create_Atlas_Image_Failed;
         return;
      end if;
   end;

   Vk.Get_Image_Memory_Requirements
     (Device.Device, Image, Memory_Requirements'Address);
   if not Has_Memory_Type
     (Memory_Properties, Memory_Requirements.memory_Type_Bits, 0, Memory_Type_Index)
   then
      Cleanup_New_Image;
      Destroy_Staging;
      Status := Allocate_Atlas_Memory_Failed;
      return;
   end if;

   declare
      Allocate_Info : aliased Vk.Memory_Allocate_Info_T :=
        (s_Type => Vk.STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
         p_Next => System.Null_Address,
         allocation_Size => Memory_Requirements.size,
         memory_Type_Index => Memory_Type_Index);
   begin
      Result :=
        Vk.Allocate_Memory
          (Device.Device,
           Allocate_Info'Address,
           System.Null_Address,
           Image_Memory'Address);
      if Result /= Vk.SUCCESS or else Image_Memory = System.Null_Address then
         Cleanup_New_Image;
         Destroy_Staging;
         Status := Allocate_Atlas_Memory_Failed;
         return;
      end if;
   end;

   Result := Vk.Bind_Image_Memory (Device.Device, Image, Image_Memory, 0);
   if Result /= Vk.SUCCESS then
      Cleanup_New_Image;
      Destroy_Staging;
      Status := Bind_Atlas_Image_Failed;
      return;
   end if;

   declare
      View_Info : aliased Vk.Image_View_Create_Info_T :=
        (s_Type => Vk.STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
         p_Next => System.Null_Address,
         flags => 0,
         image => Image,
         view_Type => Vk.IMAGE_VIEW_TYPE_2D,
         format => Vk.FORMAT_R8_UNORM,
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
          (Device.Device,
           View_Info'Address,
           System.Null_Address,
           Image_View'Address);
      if Result /= Vk.SUCCESS or else Image_View = System.Null_Address then
         Cleanup_New_Image;
         Destroy_Staging;
         Status := Create_Atlas_View_Failed;
         return;
      end if;
   end;

   declare
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
         buffer_Row_Length => 0,
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

      Result :=
        Vk.Queue_Submit
          (Device.Queue, 1, Submit_Info'Address, Device.Upload_Fence);
      if Result /= Vk.SUCCESS then
         if Result /= Vk.ERROR_DEVICE_LOST then
            Restore_Upload_Fence (Device);
         end if;
         Cleanup_New_Image;
         Destroy_Staging;
         Status :=
           (if Result = Vk.ERROR_DEVICE_LOST then Device_Lost
            else Copy_Atlas_Failed);
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
   end;

   declare
      Image_Info : aliased Vk.Descriptor_Image_Info_T :=
        (sampler => Device.Atlas_Sampler,
         image_View => Image_View,
         image_Layout => Vk.IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL);
      Write : aliased Vk.Write_Descriptor_Set_T :=
        (s_Type => Vk.STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
         p_Next => System.Null_Address,
         dst_Set => Device.Descriptor_Set,
         dst_Binding => 0,
         dst_Array_Element => 0,
         descriptor_Count => 1,
         descriptor_Type => Vk.DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
         p_Image_Info => Image_Info'Address,
         p_Buffer_Info => System.Null_Address,
         p_Texel_Buffer_View => System.Null_Address);
   begin
      Vk.Update_Descriptor_Sets
        (Device.Device, 1, Write'Address, 0, System.Null_Address);
   end;

   Destroy_Atlas_Image (Device);
   Device.Atlas_Image := Image;
   Device.Atlas_Memory := Image_Memory;
   Device.Atlas_View := Image_View;
   Device.Atlas_Width := Width;
   Device.Atlas_Height := Height;
   Device.Atlas_Bytes := Bytes_Natural;
   Device.Atlas_Upload_Count := Device.Atlas_Upload_Count + 1;
   if Device.Image_Texture_Descriptor_Bound_Count = 0 then
      Device.Image_Texture_Descriptor_Bound_Count := 1;
   end if;
   Image := System.Null_Address;
   Image_Memory := System.Null_Address;
   Image_View := System.Null_Address;
   Destroy_Staging;
   Status := Ok;
end Upload_Atlas_Data;

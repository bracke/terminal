separate (Terminal.App.Vulkan_Device.Upload_Image_Texture_Staging_Source)
procedure Prepare_Staging is
begin
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
Staging_Mapped := True;

declare
   Target : constant Image_Texture_Byte_Mapping.Object_Pointer :=
     Image_Texture_Byte_Mapping.To_Pointer (Data);
   Fill_Status : Create_Status := Ok;
begin
   Fill_Staging (Target, Staging_Bytes_Natural, Fill_Status);
   if Fill_Status /= Ok then
      Vk.Unmap_Memory (Device.Device, Staging_Memory);
      Staging_Mapped := False;
      Data := System.Null_Address;
      Destroy_Staging;
      Status := Fill_Status;
      return;
   end if;
end;
Vk.Unmap_Memory (Device.Device, Staging_Memory);
Staging_Mapped := False;
Data := System.Null_Address;
end Prepare_Staging;

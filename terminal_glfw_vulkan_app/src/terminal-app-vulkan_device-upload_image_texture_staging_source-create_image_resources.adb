separate (Terminal.App.Vulkan_Device.Upload_Image_Texture_Staging_Source)
procedure Create_Image_Resources is
begin
declare
   Image_Info : aliased Vk.Image_Create_Info_T :=
     (s_Type => Vk.STRUCTURE_TYPE_IMAGE_CREATE_INFO,
      p_Next => System.Null_Address,
      flags => 0,
      image_Type => Vk.IMAGE_TYPE_2D,
      format => Format_R8G8B8A8_Unorm,
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
      format => Format_R8G8B8A8_Unorm,
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
end Create_Image_Resources;

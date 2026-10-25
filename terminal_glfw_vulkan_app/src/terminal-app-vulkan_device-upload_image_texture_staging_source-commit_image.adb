separate (Terminal.App.Vulkan_Device.Upload_Image_Texture_Staging_Source)
procedure Commit_Image is
begin
declare
   Image_Info : aliased Vk.Descriptor_Image_Info_T :=
     (sampler => Device.Atlas_Sampler,
      image_View => Image_View,
      image_Layout => Vk.IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL);
   Write : aliased Vk.Write_Descriptor_Set_T :=
     (s_Type => Vk.STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
      p_Next => System.Null_Address,
      dst_Set => Device.Descriptor_Set,
      dst_Binding =>
        (case Slot is
           when Text_Glyphs    => 0,
           when Inline_Picture => 1,
           when Colour_Glyphs  => 2),
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

if Slot /= Text_Glyphs and then Device.Atlas_View = System.Null_Address then
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
end if;

if Slot = Text_Glyphs then
   Destroy_Atlas_Image (Device);
   Device.Atlas_Image := Image;
   Device.Atlas_Memory := Image_Memory;
   Device.Atlas_View := Image_View;
   Device.Atlas_Width := Width;
   Device.Atlas_Height := Height;
   Device.Atlas_Bytes := Upload_Bytes_Natural;
   Device.Atlas_Upload_Count := Device.Atlas_Upload_Count + 1;
elsif Slot = Colour_Glyphs then
   Destroy_Colour_Sheet (Device);
   Device.Colour_Sheet_Image := Image;
   Device.Colour_Sheet_Memory := Image_Memory;
   Device.Colour_Sheet_View := Image_View;
   Device.Colour_Sheet_Width := Width;
   Device.Colour_Sheet_Height := Height;
else
   Destroy_Image_Texture (Device);
   Device.Image_Texture_Image := Image;
   Device.Image_Texture_Memory := Image_Memory;
   Device.Image_Texture_View := Image_View;
   Device.Image_Texture_Width := Width;
   Device.Image_Texture_Height := Height;
   Device.Image_Texture_Content_Signature := Content_Signature;
   Device.Image_Texture_Upload_Count :=
     Device.Image_Texture_Upload_Count + 1;
end if;
if Slot = Inline_Picture then
   Device.Image_Texture_Bytes := Upload_Bytes_Natural;
end if;
if Slot = Text_Glyphs then
   if Device.Image_Texture_Descriptor_Bound_Count = 0 then
      Device.Image_Texture_Descriptor_Bound_Count := 1;
   end if;
else
   Device.Image_Texture_Descriptor_Bound_Count := 2;
end if;
Image := System.Null_Address;
Image_Memory := System.Null_Address;
Image_View := System.Null_Address;
Destroy_Staging;
Status := Ok;
end Commit_Image;

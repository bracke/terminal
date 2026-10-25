separate (Terminal.App.Vulkan_Device)
procedure Upload_Image_Texture_Staging_Source
  (Device        : in out Logical_Device;
   Slot          : Texture_Slot;
   Choice        : Selection;
   Width         : Natural;
   Height        : Natural;
   Source_Bytes_Per_Pixel : Natural;
   Row_Stride_Bytes : Natural;
   Bytes_Natural : Natural;
   Fill_Staging  : not null access procedure
     (Target   : Image_Texture_Byte_Mapping.Object_Pointer;
      Capacity : Positive;
      Status : out Create_Status);
   Status        : out Create_Status;
   Image_Format  : Vk.Format_T := Format_R8G8B8A8_Unorm;
   Maximum_Bytes : Positive := Max_Image_Texture_Bytes;
   Content_Signature : Interfaces.Unsigned_64 := 0)
is
   Image : aliased Vk.Image_T := System.Null_Address;
   Image_Memory : aliased Vk.Device_Memory_T := System.Null_Address;
   Image_View : aliased Vk.Image_View_T := System.Null_Address;
   Staging_Buffer : aliased Vk.Buffer_T := System.Null_Address;
   Staging_Memory : aliased Vk.Device_Memory_T := System.Null_Address;
   Data : aliased System.Address := System.Null_Address;
   Memory_Requirements : aliased Vk.Memory_Requirements_T;
   Memory_Properties : aliased Vk.Physical_Device_Memory_Properties_T;
   Memory_Type_Index : Interfaces.Unsigned_32 := 0;
   Upload_Bytes_Natural : Natural := 0;
   Staging_Bytes_Natural : Natural := 0;
   Vulkan_Buffer_Row_Length : Interfaces.Unsigned_32 := 0;
   Upload_Layout : Terminal.App.Image_Upload_Layout.Layout;
   Layout_Status : Terminal.App.Image_Upload_Layout.Layout_Status;
   Bytes : Interfaces.Unsigned_64 := 0;
   Result : Vk.Result_T;
   Staging_Mapped : Boolean := False;
   Upload_Fence_Reset : Boolean := False;
   Upload_Submitted : Boolean := False;
   Deferred_Ready : Boolean := False;

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

   procedure Submit_Copy is separate;
   procedure Commit_Image is separate;
   procedure Prepare_Staging is separate;
   procedure Create_Image_Resources is separate;

begin
   Reap_Deferred_Upload (Device, Deferred_Ready, Status);
   if not Deferred_Ready then
      return;
   end if;
   Terminal.App.Image_Upload_Layout.Calculate
     (Width                  => Width,
      Height                 => Height,
      Source_Bytes_Per_Pixel => Source_Bytes_Per_Pixel,
      Row_Stride_Bytes       => Row_Stride_Bytes,
      Source_Bytes           => Bytes_Natural,
      Maximum_Bytes          => Maximum_Bytes,
      Result                 => Upload_Layout,
      Status                 => Layout_Status);
   if Layout_Status /= Terminal.App.Image_Upload_Layout.Layout_Ok then
      Status := Atlas_Too_Large;
      return;
   end if;
   Upload_Bytes_Natural := Upload_Layout.Upload_Bytes;
   Staging_Bytes_Natural := Upload_Layout.Staging_Bytes;
   Vulkan_Buffer_Row_Length := Interfaces.Unsigned_32
     (Upload_Layout.Vulkan_Buffer_Row_Pixels);
   Bytes := Interfaces.Unsigned_64 (Staging_Bytes_Natural);

   if Slot = Inline_Picture
     and then Content_Signature /= 0
     and then Device.Image_Texture_Image /= System.Null_Address
     and then Device.Image_Texture_Content_Signature = Content_Signature
     and then Device.Image_Texture_Width = Width
     and then Device.Image_Texture_Height = Height
     and then Device.Image_Texture_Bytes = Upload_Bytes_Natural
   then
      Device.Image_Texture_Cache_Hit_Count :=
        Device.Image_Texture_Cache_Hit_Count + 1;
      Status := Ok;
      return;
   end if;

   Status := Ok;
   Prepare_Staging;
   if Status /= Ok then
      return;
   end if;

   Status := Ok;
   Create_Image_Resources;
   if Status /= Ok then
      return;
   end if;

   Status := Ok;
   Submit_Copy;
   if Status /= Ok then
      return;
   end if;

   Commit_Image;
exception
   when others =>
      if Staging_Mapped and then Staging_Memory /= System.Null_Address then
         Vk.Unmap_Memory (Device.Device, Staging_Memory);
         Staging_Mapped := False;
         Data := System.Null_Address;
      end if;
      if Upload_Fence_Reset then
         Restore_Upload_Fence (Device);
         Upload_Fence_Reset := False;
      end if;
      if Upload_Submitted then
         Defer_Upload_Resources
           (Device,
            Staging_Buffer,
            Staging_Memory,
            Image,
            Image_Memory,
            Image_View);
         Upload_Submitted := False;
      else
         Cleanup_New_Image;
         Destroy_Staging;
      end if;
      raise;
end Upload_Image_Texture_Staging_Source;

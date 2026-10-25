separate (Terminal.App.Vulkan_Device.Create_Logical_Device)
      function Create_Image_Views
        (Handle : Vk.Device_T)
         return Create_Status
      is
         Image_Count : aliased Interfaces.Unsigned_32 := 0;
         Result : Vk.Result_T;
      begin
         Result :=
           Vk.Get_Swapchain_Images_KHR
             (Handle,
              Device.Swapchain,
              Image_Count'Address,
              System.Null_Address);
         if Result /= Vk.SUCCESS or else Image_Count = 0 then
            return Get_Swapchain_Images_Failed;
         end if;

         if Image_Count > Interfaces.Unsigned_32 (Max_Swapchain_Images) then
            return Too_Many_Swapchain_Images;
         end if;

         Result :=
           Vk.Get_Swapchain_Images_KHR
             (Handle,
              Device.Swapchain,
              Image_Count'Address,
              Device.Swapchain_Images'Address);
         if Result /= Vk.SUCCESS then
            return Get_Swapchain_Images_Failed;
         end if;

         Device.Swapchain_Image_Count := Natural (Image_Count);

         for I in 1 .. Natural (Image_Count) loop
            declare
               View : aliased Vk.Image_View_T := System.Null_Address;
               Create_Info : aliased Vk.Image_View_Create_Info_T :=
                 (s_Type             => Vk.STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                  p_Next             => System.Null_Address,
                  flags              => 0,
                  image              => Device.Swapchain_Images (I),
                  view_Type          => Vk.IMAGE_VIEW_TYPE_2D,
                  format             => Device.Swapchain_Format,
                  components         =>
                    (r => Vk.COMPONENT_SWIZZLE_IDENTITY,
                     g => Vk.COMPONENT_SWIZZLE_IDENTITY,
                     b => Vk.COMPONENT_SWIZZLE_IDENTITY,
                     a => Vk.COMPONENT_SWIZZLE_IDENTITY),
                  subresource_Range  =>
                    (aspect_Mask      => Vk.IMAGE_ASPECT_COLOR_BIT,
                     base_Mip_Level   => 0,
                     level_Count      => 1,
                     base_Array_Layer => 0,
                     layer_Count      => 1));
            begin
               Result :=
                 Vk.Create_Image_View
                   (Handle, Create_Info'Address, System.Null_Address, View'Address);
               if Result /= Vk.SUCCESS or else View = System.Null_Address then
                  for J in 1 .. Device.Swapchain_View_Count loop
                     Vk.Destroy_Image_View
                       (Handle, Device.Swapchain_Views (J), System.Null_Address);
                     Device.Swapchain_Views (J) := System.Null_Address;
                  end loop;
                  Device.Swapchain_View_Count := 0;
                  return Create_Image_View_Failed;
               end if;

               Device.Swapchain_Views (I) := View;
               Device.Swapchain_View_Count := I;
            end;
         end loop;

         return Ok;
      end Create_Image_Views;


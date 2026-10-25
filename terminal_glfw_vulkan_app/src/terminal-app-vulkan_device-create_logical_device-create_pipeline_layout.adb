separate (Terminal.App.Vulkan_Device.Create_Logical_Device)
      function Create_Pipeline_Layout
        (Handle : Vk.Device_T)
         return Create_Status
      is
         Set_Layouts : aliased Descriptor_Set_Layout_Array :=
           (1 => Device.Descriptor_Set_Layout);
         Layout_Info : aliased Vk.Pipeline_Layout_Create_Info_T :=
           (s_Type                   => Vk.STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
            p_Next                   => System.Null_Address,
            flags                    => 0,
            set_Layout_Count         => 1,
            p_Set_Layouts            => Set_Layouts'Address,
            push_Constant_Range_Count => 0,
            p_Push_Constant_Ranges   => System.Null_Address);
         Layout : aliased Vk.Pipeline_Layout_T := System.Null_Address;
         Result : constant Vk.Result_T :=
           Vk.Create_Pipeline_Layout
             (Handle, Layout_Info'Address, System.Null_Address, Layout'Address);
      begin
         if Result /= Vk.SUCCESS or else Layout = System.Null_Address then
            return Create_Pipeline_Layout_Failed;
         end if;

         Device.Pipeline_Layout := Layout;
         return Ok;
      end Create_Pipeline_Layout;


separate (Terminal.App.Vulkan_Device.Create_Logical_Device)
      function Create_Descriptor_Resources
        (Handle : Vk.Device_T)
         return Create_Status
      is
         Bindings : aliased Descriptor_Set_Layout_Binding_Array :=
           (1 =>
              (binding => 0,
               descriptor_Type => Vk.DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
               descriptor_Count => 1,
               stage_Flags => Vk.SHADER_STAGE_FRAGMENT_BIT,
               p_Immutable_Samplers => System.Null_Address),
            2 =>
              (binding => 1,
               descriptor_Type => Vk.DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
               descriptor_Count => 1,
               stage_Flags => Vk.SHADER_STAGE_FRAGMENT_BIT,
               p_Immutable_Samplers => System.Null_Address),

            --  The colour glyph sheet. Its own binding rather than a share of
            --  the image texture: that holds one picture at a time, and a line
            --  of emoji beside a Sixel has to be able to draw.
            3 =>
              (binding => 2,
               descriptor_Type => Vk.DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
               descriptor_Count => 1,
               stage_Flags => Vk.SHADER_STAGE_FRAGMENT_BIT,
               p_Immutable_Samplers => System.Null_Address));
         Layout_Info : aliased Vk.Descriptor_Set_Layout_Create_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            p_Next => System.Null_Address,
            flags => 0,
            binding_Count => Bindings'Length,
            p_Bindings => Bindings'Address);
         Layout : aliased Vk.Descriptor_Set_Layout_T := System.Null_Address;
         Pool_Size : aliased Descriptor_Pool_Size_Array :=
           (1 =>
              (type_F => Vk.DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
               descriptor_Count => 3));
         Pool_Info : aliased Vk.Descriptor_Pool_Create_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
            p_Next => System.Null_Address,
            flags => 0,
            max_Sets => 1,
            pool_Size_Count => Pool_Size'Length,
            p_Pool_Sizes => Pool_Size'Address);
         Pool : aliased Vk.Descriptor_Pool_T := System.Null_Address;
         Layouts : aliased Descriptor_Set_Layout_Array := (1 => System.Null_Address);
         Allocate_Info : aliased Vk.Descriptor_Set_Allocate_Info_T;
         Descriptor_Set : aliased Vk.Descriptor_Set_T := System.Null_Address;
         Sampler_Info : aliased Vk.Sampler_Create_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
            p_Next => System.Null_Address,
            flags => 0,
            mag_Filter => Vk.FILTER_LINEAR,
            min_Filter => Vk.FILTER_LINEAR,
            mipmap_Mode => Vk.SAMPLER_MIPMAP_MODE_NEAREST,
            address_Mode_U => Vk.SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
            address_Mode_V => Vk.SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
            address_Mode_W => Vk.SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
            mip_Lod_Bias => 0.0,
            anisotropy_Enable => 0,
            max_Anisotropy => 1.0,
            compare_Enable => 0,
            compare_Op => Vk.COMPARE_OP_ALWAYS,
            min_Lod => 0.0,
            max_Lod => 0.0,
            border_Color => Vk.BORDER_COLOR_FLOAT_TRANSPARENT_BLACK,
            unnormalized_Coordinates => 0);
         Sampler : aliased Vk.Sampler_T := System.Null_Address;
         Result : Vk.Result_T;
      begin
         Result :=
           Vk.Create_Descriptor_Set_Layout
             (Handle, Layout_Info'Address, System.Null_Address, Layout'Address);
         if Result /= Vk.SUCCESS or else Layout = System.Null_Address then
            return Create_Descriptor_Set_Layout_Failed;
         end if;
         Device.Descriptor_Set_Layout := Layout;

         Result :=
           Vk.Create_Descriptor_Pool
             (Handle, Pool_Info'Address, System.Null_Address, Pool'Address);
         if Result /= Vk.SUCCESS or else Pool = System.Null_Address then
            Destroy_Descriptor_Resources (Handle);
            return Create_Descriptor_Pool_Failed;
         end if;
         Device.Descriptor_Pool := Pool;

         Layouts (1) := Device.Descriptor_Set_Layout;
         Allocate_Info :=
           (s_Type => Vk.STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
            p_Next => System.Null_Address,
            descriptor_Pool => Device.Descriptor_Pool,
            descriptor_Set_Count => 1,
            p_Set_Layouts => Layouts'Address);
         Result :=
           Vk.Allocate_Descriptor_Sets
             (Handle, Allocate_Info'Address, Descriptor_Set'Address);
         if Result /= Vk.SUCCESS or else Descriptor_Set = System.Null_Address then
            Destroy_Descriptor_Resources (Handle);
            return Allocate_Descriptor_Set_Failed;
         end if;
         Device.Descriptor_Set := Descriptor_Set;

         Result :=
           Vk.Create_Sampler
             (Handle, Sampler_Info'Address, System.Null_Address, Sampler'Address);
         if Result /= Vk.SUCCESS or else Sampler = System.Null_Address then
            Destroy_Descriptor_Resources (Handle);
            return Create_Atlas_Sampler_Failed;
         end if;
         Device.Atlas_Sampler := Sampler;
         Device.Image_Texture_Descriptor_Capacity := 2;
         Device.Image_Texture_Descriptor_Bound_Count := 0;

         return Ok;
      end Create_Descriptor_Resources;


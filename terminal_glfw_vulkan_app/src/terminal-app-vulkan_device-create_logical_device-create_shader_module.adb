separate (Terminal.App.Vulkan_Device.Create_Logical_Device)
      function Create_Shader_Module
        (Handle : Vk.Device_T;
         Code   : Shaders.Shader_Code;
         Module : out Vk.Shader_Module_T)
         return Create_Status
      is
         Create_Info : aliased Vk.Shader_Module_Create_Info_T :=
           (s_Type    => Vk.STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
            p_Next    => System.Null_Address,
            flags     => 0,
            code_Size => Interfaces.C.size_t (Shaders.Byte_Size (Code)),
            p_Code    => Shaders.Address (Code));
         Shader : aliased Vk.Shader_Module_T := System.Null_Address;
         Result : constant Vk.Result_T :=
           Vk.Create_Shader_Module
             (Handle, Create_Info'Address, System.Null_Address, Shader'Address);
      begin
         Module := System.Null_Address;
         if Result /= Vk.SUCCESS or else Shader = System.Null_Address then
            return Create_Shader_Module_Failed;
         end if;

         Module := Shader;
         return Ok;
      end Create_Shader_Module;


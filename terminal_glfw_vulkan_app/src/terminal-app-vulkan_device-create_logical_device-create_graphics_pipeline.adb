separate (Terminal.App.Vulkan_Device.Create_Logical_Device)
      function Create_Graphics_Pipeline
        (Handle : Vk.Device_T)
         return Create_Status
      is
         Vertex_Code : Shaders.Shader_Code;
         Fragment_Code : Shaders.Shader_Code;
         Load_Status : Shaders.Load_Status;
         Vertex_Module : Vk.Shader_Module_T := System.Null_Address;
         Fragment_Module : Vk.Shader_Module_T := System.Null_Address;
         Module_Status : Create_Status;
         Main_Name : aliased Interfaces.C.char_array := Interfaces.C.To_C ("main");
         Stages : aliased Shader_Stage_Array :=
           (1 =>
              (s_Type => Vk.STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
               p_Next => System.Null_Address,
               flags  => 0,
               stage  => Vk.SHADER_STAGE_VERTEX_BIT,
               module => System.Null_Address,
               p_Name => Main_Name'Address,
               p_Specialization_Info => System.Null_Address),
            2 =>
              (s_Type => Vk.STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
               p_Next => System.Null_Address,
               flags  => 0,
               stage  => Vk.SHADER_STAGE_FRAGMENT_BIT,
               module => System.Null_Address,
               p_Name => Main_Name'Address,
               p_Specialization_Info => System.Null_Address));
         Binding : aliased Vk.Vertex_Input_Binding_Description_T :=
           (binding    => 0,
            stride     => 40,
            input_Rate => Vk.VERTEX_INPUT_RATE_VERTEX);
         Attributes : aliased Vertex_Attribute_Array :=
           (1 =>
              (location => 0, binding => 0,
               format => Vk.FORMAT_R32G32_SFLOAT, offset => 0),
            2 =>
              (location => 1, binding => 0,
               format => Vk.FORMAT_R32G32_SFLOAT, offset => 8),
            3 =>
              (location => 2, binding => 0,
               format => Vk.FORMAT_R32G32B32A32_SFLOAT, offset => 16),
            4 =>
              (location => 3, binding => 0,
               format => Vk.FORMAT_R32_SFLOAT, offset => 32),
            5 =>
              (location => 4, binding => 0,
               format => Vk.FORMAT_R32_SFLOAT, offset => 36));
         Vertex_Input : aliased Vk.Pipeline_Vertex_Input_State_Create_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
            p_Next => System.Null_Address,
            flags  => 0,
            vertex_Binding_Description_Count => 1,
            p_Vertex_Binding_Descriptions => Binding'Address,
            vertex_Attribute_Description_Count => Attributes'Length,
            p_Vertex_Attribute_Descriptions => Attributes'Address);
         Input_Assembly : aliased Vk.Pipeline_Input_Assembly_State_Create_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
            p_Next => System.Null_Address,
            flags  => 0,
            topology => Vk.PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
            primitive_Restart_Enable => 0);
         Viewport_State : aliased Vk.Pipeline_Viewport_State_Create_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
            p_Next => System.Null_Address,
            flags  => 0,
            viewport_Count => 1,
            p_Viewports => System.Null_Address,
            scissor_Count => 1,
            p_Scissors => System.Null_Address);
         Rasterization : aliased Vk.Pipeline_Rasterization_State_Create_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
            p_Next => System.Null_Address,
            flags  => 0,
            depth_Clamp_Enable => 0,
            rasterizer_Discard_Enable => 0,
            polygon_Mode => Vk.POLYGON_MODE_FILL,
            cull_Mode => Vk.CULL_MODE_NONE,
            front_Face => Vk.FRONT_FACE_COUNTER_CLOCKWISE,
            depth_Bias_Enable => 0,
            depth_Bias_Constant_Factor => 0.0,
            depth_Bias_Clamp => 0.0,
            depth_Bias_Slope_Factor => 0.0,
            line_Width => 1.0);
         Multisample : aliased Vk.Pipeline_Multisample_State_Create_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
            p_Next => System.Null_Address,
            flags  => 0,
            rasterization_Samples => Device.Color_Sample_Count,
            sample_Shading_Enable => 0,
            min_Sample_Shading => 1.0,
            p_Sample_Mask => System.Null_Address,
            alpha_To_Coverage_Enable => 0,
            alpha_To_One_Enable => 0);
         Color_Attachment : aliased Vk.Pipeline_Color_Blend_Attachment_State_T :=
           (blend_Enable => 1,
            src_Color_Blend_Factor => Vk.BLEND_FACTOR_SRC_ALPHA,
            dst_Color_Blend_Factor => Vk.BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
            color_Blend_Op => Vk.BLEND_OP_ADD,
            src_Alpha_Blend_Factor => Vk.BLEND_FACTOR_ONE,
            dst_Alpha_Blend_Factor => Vk.BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
            alpha_Blend_Op => Vk.BLEND_OP_ADD,
            color_Write_Mask =>
              Vk.COLOR_COMPONENT_R_BIT or Vk.COLOR_COMPONENT_G_BIT or
              Vk.COLOR_COMPONENT_B_BIT or Vk.COLOR_COMPONENT_A_BIT);
         Color_Blend : aliased Vk.Pipeline_Color_Blend_State_Create_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
            p_Next => System.Null_Address,
            flags  => 0,
            logic_Op_Enable => 0,
            logic_Op => Vk.LOGIC_OP_COPY,
            attachment_Count => 1,
            p_Attachments => Color_Attachment'Address,
            blend_Constants => (others => 0.0));
         Dynamic_States : aliased Dynamic_State_Array :=
           (1 => Vk.DYNAMIC_STATE_VIEWPORT,
            2 => Vk.DYNAMIC_STATE_SCISSOR);
         Dynamic_State : aliased Vk.Pipeline_Dynamic_State_Create_Info_T :=
           (s_Type => Vk.STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
            p_Next => System.Null_Address,
            flags => 0,
            dynamic_State_Count => Dynamic_States'Length,
            p_Dynamic_States => Dynamic_States'Address);
         Pipeline_Info : aliased Vk.Graphics_Pipeline_Create_Info_T;
         Pipeline : aliased Vk.Pipeline_T := System.Null_Address;
         Result : Vk.Result_T;
      begin
         Shaders.Load ("terminal.vert.spv", Vertex_Code, Load_Status);
         if Load_Status /= Shaders.Ok then
            return Shader_Load_Failed;
         end if;

         Shaders.Load ("terminal.frag.spv", Fragment_Code, Load_Status);
         if Load_Status /= Shaders.Ok then
            Shaders.Release (Vertex_Code);
            return Shader_Load_Failed;
         end if;

         Module_Status := Create_Shader_Module (Handle, Vertex_Code, Vertex_Module);
         Shaders.Release (Vertex_Code);
         if Module_Status /= Ok then
            Shaders.Release (Fragment_Code);
            return Module_Status;
         end if;

         Module_Status := Create_Shader_Module (Handle, Fragment_Code, Fragment_Module);
         Shaders.Release (Fragment_Code);
         if Module_Status /= Ok then
            Vk.Destroy_Shader_Module (Handle, Vertex_Module, System.Null_Address);
            return Module_Status;
         end if;

         Stages (1).module := Vertex_Module;
         Stages (2).module := Fragment_Module;
         Pipeline_Info :=
           (s_Type => Vk.STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
            p_Next => System.Null_Address,
            flags => 0,
            stage_Count => Stages'Length,
            p_Stages => Stages'Address,
            p_Vertex_Input_State => Vertex_Input'Address,
            p_Input_Assembly_State => Input_Assembly'Address,
            p_Tessellation_State => System.Null_Address,
            p_Viewport_State => Viewport_State'Address,
            p_Rasterization_State => Rasterization'Address,
            p_Multisample_State => Multisample'Address,
            p_Depth_Stencil_State => System.Null_Address,
            p_Color_Blend_State => Color_Blend'Address,
            p_Dynamic_State => Dynamic_State'Address,
            layout => Device.Pipeline_Layout,
            render_Pass => Device.Render_Pass,
            subpass => 0,
            base_Pipeline_Handle => System.Null_Address,
            base_Pipeline_Index => Interfaces.Integer_32'(-1));

         Result :=
           Vk.Create_Graphics_Pipelines
             (Handle,
              System.Null_Address,
              1,
              Pipeline_Info'Address,
              System.Null_Address,
              Pipeline'Address);

         Vk.Destroy_Shader_Module (Handle, Fragment_Module, System.Null_Address);
         Vk.Destroy_Shader_Module (Handle, Vertex_Module, System.Null_Address);

         if Result /= Vk.SUCCESS then
            --  Vulkan permits a failed batch creation to return handles for
            --  entries completed before the failure.  This call creates one
            --  pipeline, so destroy that partial result before reporting it.
            if Pipeline /= System.Null_Address then
               Vk.Destroy_Pipeline
                 (Handle, Pipeline, System.Null_Address);
               Pipeline := System.Null_Address;
            end if;
            return Create_Graphics_Pipeline_Failed;
         elsif Pipeline = System.Null_Address then
            return Create_Graphics_Pipeline_Failed;
         end if;

         Device.Graphics_Pipeline := Pipeline;
         return Ok;
      end Create_Graphics_Pipeline;


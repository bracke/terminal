separate (Terminal.App.Vulkan_Device)
   procedure Render
     (Device : in out Logical_Device;
      Status : out Render_Status)
   is
      Frame : Natural := Device.Current_Frame;
      Image_Index : aliased Interfaces.Unsigned_32 := 0;
      Result : Vk.Result_T;
   begin
      if not Device.Initialized
        or else Device.Swapchain = System.Null_Address
        or else Device.Render_Pass = System.Null_Address
        or else Device.Graphics_Pipeline = System.Null_Address
        or else Device.Vertex_Buffer = System.Null_Address
        or else Device.Command_Buffer_Count = 0
        or else Device.Sync_Frame_Count = 0
      then
         Status := Not_Initialized;
         return;
      end if;

      if Device.Uploaded_Vertex_Count = 0 then
         Status := No_Uploaded_Vertices;
         return;
      end if;

      --  Validation readback uses one bounded transfer buffer.  Do not let a
      --  later frame overwrite it while the previous copy is still in flight.
      if Device.Readback_Enabled
        and then Device.Readback_Pending
        and then Device.Readback_Frame in 1 .. Device.Sync_Frame_Count
      then
         Result :=
           Vk.Wait_For_Fences
             (Device.Device,
              1,
              Device.In_Flight (Device.Readback_Frame)'Address,
              1,
              Interfaces.Unsigned_64'Last);
         if Result /= Vk.SUCCESS then
            Status :=
              (if Result = Vk.ERROR_DEVICE_LOST then Device_Lost
               else Wait_Fence_Failed);
            return;
         end if;
         Device.Readback_Pending := False;
      end if;

      if Frame = 0 or else Frame > Device.Sync_Frame_Count then
         Frame := 1;
      end if;

      Result :=
        Vk.Wait_For_Fences
          (Device.Device,
           1,
           Device.In_Flight (Frame)'Address,
           1,
           Interfaces.Unsigned_64'Last);
      if Result /= Vk.SUCCESS then
         Status :=
           (if Result = Vk.ERROR_DEVICE_LOST then Device_Lost
            else Wait_Fence_Failed);
         return;
      end if;

      Result :=
        Vk.Acquire_Next_Image_KHR
          (Device.Device,
           Device.Swapchain,
           Interfaces.Unsigned_64'Last,
           Device.Image_Available (Frame),
           System.Null_Address,
           Image_Index'Address);
      if Is_Swapchain_Stale (Result) then
         Status := Swapchain_Out_Of_Date;
         return;
      elsif Result /= Vk.SUCCESS then
         Status :=
           (if Result = Vk.ERROR_DEVICE_LOST then Device_Lost
            else Acquire_Image_Failed);
         return;
      end if;

      declare
         Image_Slot : constant Natural := Natural (Image_Index) + 1;
      begin
         if Image_Slot = 0
           or else Image_Slot > Device.Framebuffer_Count
           or else Image_Slot > Device.Command_Buffer_Count
         then
            Status := Acquire_Image_Failed;
            return;
         end if;

         declare
            Command_Buffer : constant Vk.Command_Buffer_T :=
              Device.Command_Buffers (Image_Slot);
            Begin_Info : aliased Vk.Command_Buffer_Begin_Info_T :=
              (s_Type => Vk.STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
               p_Next => System.Null_Address,
               flags  => Vk.COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
               p_Inheritance_Info => System.Null_Address);
            Clear_Value : aliased Vk.Clear_Value_T :=
              (Kind => 0,
               color =>
                 (Kind => 0,
                  float32 => (0 => 0.0, 1 => 0.0, 2 => 0.0, 3 => 1.0)));
            Render_Area : constant Vk.Rect2_D_T :=
              (offset => (x => 0, y => 0),
               extent =>
                 (width  => Interfaces.Unsigned_32 (Device.Swapchain_Width),
                  height => Interfaces.Unsigned_32 (Device.Swapchain_Height)));
            Render_Info : aliased Vk.Render_Pass_Begin_Info_T :=
              (s_Type => Vk.STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
               p_Next => System.Null_Address,
               render_Pass => Device.Render_Pass,
               framebuffer => Device.Framebuffers (Image_Slot),
               render_Area => Render_Area,
               clear_Value_Count => 1,
               p_Clear_Values => Clear_Value'Address);
            Viewport : aliased Vk.Viewport_T :=
              (x => 0.0,
               y => 0.0,
               width => Interfaces.C.C_float (Device.Swapchain_Width),
               height => Interfaces.C.C_float (Device.Swapchain_Height),
               min_Depth => 0.0,
               max_Depth => 1.0);
            Scissor : aliased Vk.Rect2_D_T := Render_Area;
            Buffers : aliased Buffer_Binding_Array :=
              (1 => Device.Vertex_Buffer);
            Offsets : aliased Device_Size_Array := (1 => 0);
            Command_Buffers : aliased Command_Buffer_Submit_Array :=
              (1 => Command_Buffer);
            Wait_Semaphores : aliased Semaphore_Submit_Array :=
              (1 => Device.Image_Available (Frame));
            Signal_Semaphores : aliased Semaphore_Submit_Array :=
              (1 => Device.Render_Finished (Frame));
            Wait_Stages : aliased Pipeline_Stage_Array :=
              (1 => Vk.PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT);
            Submit_Info : aliased Vk.Submit_Info_T :=
              (s_Type => Vk.STRUCTURE_TYPE_SUBMIT_INFO,
               p_Next => System.Null_Address,
               wait_Semaphore_Count => 1,
               p_Wait_Semaphores => Wait_Semaphores'Address,
               p_Wait_Dst_Stage_Mask => Wait_Stages'Address,
               command_Buffer_Count => 1,
               p_Command_Buffers => Command_Buffers'Address,
               signal_Semaphore_Count => 1,
               p_Signal_Semaphores => Signal_Semaphores'Address);
            Swapchains : aliased Swapchain_Submit_Array :=
              (1 => Device.Swapchain);
            Image_Indices : aliased Image_Index_Array := (1 => Image_Index);
            Present_Info : aliased Vk.Present_Info_KHR_T :=
              (s_Type => Present_Info_Structure,
               p_Next => System.Null_Address,
               wait_Semaphore_Count => 1,
               p_Wait_Semaphores => Signal_Semaphores'Address,
               swapchain_Count => 1,
               p_Swapchains => Swapchains'Address,
               p_Image_Indices => Image_Indices'Address,
               p_Results => System.Null_Address);
         begin
            Result := Vk.Reset_Command_Buffer (Command_Buffer, 0);
            if Result /= Vk.SUCCESS then
               Status :=
                 (if Result = Vk.ERROR_DEVICE_LOST then Device_Lost
                  else Reset_Command_Buffer_Failed);
               return;
            end if;

            Result :=
              Vk.Begin_Command_Buffer (Command_Buffer, Begin_Info'Address);
            if Result /= Vk.SUCCESS then
               Status :=
                 (if Result = Vk.ERROR_DEVICE_LOST then Device_Lost
                  else Begin_Command_Buffer_Failed);
               return;
            end if;

            Vk.Cmd_Begin_Render_Pass
              (Command_Buffer, Render_Info'Address, Vk.SUBPASS_CONTENTS_INLINE);
            Vk.Cmd_Bind_Pipeline
              (Command_Buffer,
               Vk.PIPELINE_BIND_POINT_GRAPHICS,
               Device.Graphics_Pipeline);
            if Device.Descriptor_Set /= System.Null_Address then
               Vk.Cmd_Bind_Descriptor_Sets
                 (Command_Buffer,
                  Vk.PIPELINE_BIND_POINT_GRAPHICS,
                  Device.Pipeline_Layout,
                  0,
                  1,
                  Device.Descriptor_Set'Address,
                  0,
                  System.Null_Address);
            end if;
            Vk.Cmd_Set_Viewport (Command_Buffer, 0, 1, Viewport'Address);
            Vk.Cmd_Set_Scissor (Command_Buffer, 0, 1, Scissor'Address);
            Vk.Cmd_Bind_Vertex_Buffers
              (Command_Buffer, 0, 1, Buffers'Address, Offsets'Address);
            Vk.Cmd_Draw
              (Command_Buffer,
               Interfaces.Unsigned_32 (Device.Uploaded_Vertex_Count),
               1,
               0,
               0);
            Vk.Cmd_End_Render_Pass (Command_Buffer);

            if Device.Readback_Enabled
              and then Device.Readback_Buffer /= System.Null_Address
              and then Device.Readback_Bytes > 0
            then
               declare
                  To_Transfer : aliased Vk.Image_Memory_Barrier_T :=
                    (s_Type => Vk.STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
                     p_Next => System.Null_Address,
                     src_Access_Mask => Vk.ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
                     dst_Access_Mask => Vk.ACCESS_TRANSFER_READ_BIT,
                     old_Layout => Image_Layout_Present_Source,
                     new_Layout => Vk.IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                     src_Queue_Family_Index => Queue_Family_Ignored,
                     dst_Queue_Family_Index => Queue_Family_Ignored,
                     image => Device.Swapchain_Images (Image_Slot),
                     subresource_Range =>
                       (aspect_Mask => Vk.IMAGE_ASPECT_COLOR_BIT,
                        base_Mip_Level => 0,
                        level_Count => 1,
                        base_Array_Layer => 0,
                        layer_Count => 1));
                  Copy_Region : aliased Vk.Buffer_Image_Copy_T :=
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
                       (width => Interfaces.Unsigned_32
                          (Device.Swapchain_Width),
                        height => Interfaces.Unsigned_32
                          (Device.Swapchain_Height),
                        depth => 1));
                  To_Present : aliased Vk.Image_Memory_Barrier_T :=
                    (s_Type => Vk.STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
                     p_Next => System.Null_Address,
                     src_Access_Mask => Vk.ACCESS_TRANSFER_READ_BIT,
                     dst_Access_Mask => 0,
                     old_Layout => Vk.IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                     new_Layout => Image_Layout_Present_Source,
                     src_Queue_Family_Index => Queue_Family_Ignored,
                     dst_Queue_Family_Index => Queue_Family_Ignored,
                     image => Device.Swapchain_Images (Image_Slot),
                     subresource_Range =>
                       (aspect_Mask => Vk.IMAGE_ASPECT_COLOR_BIT,
                        base_Mip_Level => 0,
                        level_Count => 1,
                        base_Array_Layer => 0,
                        layer_Count => 1));
               begin
                  Vk.Cmd_Pipeline_Barrier
                    (Command_Buffer,
                     Vk.PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
                     Vk.PIPELINE_STAGE_TRANSFER_BIT,
                     0,
                     0,
                     System.Null_Address,
                     0,
                     System.Null_Address,
                     1,
                     To_Transfer'Address);
                  Vk.Cmd_Copy_Image_To_Buffer
                    (Command_Buffer,
                     Device.Swapchain_Images (Image_Slot),
                     Vk.IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                     Device.Readback_Buffer,
                     1,
                     Copy_Region'Address);
                  Vk.Cmd_Pipeline_Barrier
                    (Command_Buffer,
                     Vk.PIPELINE_STAGE_TRANSFER_BIT,
                     Vk.PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
                     0,
                     0,
                     System.Null_Address,
                     0,
                     System.Null_Address,
                     1,
                     To_Present'Address);
               end;
            end if;

            Result := Vk.End_Command_Buffer (Command_Buffer);
            if Result /= Vk.SUCCESS then
               Status :=
                 (if Result = Vk.ERROR_DEVICE_LOST then Device_Lost
                  else End_Command_Buffer_Failed);
               return;
            end if;

            Result :=
              Vk.Reset_Fences
                (Device.Device, 1, Device.In_Flight (Frame)'Address);
            if Result /= Vk.SUCCESS then
               Status :=
                 (if Result = Vk.ERROR_DEVICE_LOST then Device_Lost
                  else Reset_Fence_Failed);
               return;
            end if;

            Result :=
              Vk.Queue_Submit
                (Device.Queue, 1, Submit_Info'Address, Device.In_Flight (Frame));
            if Result /= Vk.SUCCESS then
               Status :=
                 (if Result = Vk.ERROR_DEVICE_LOST then Device_Lost
                  else Queue_Submit_Failed);
               return;
            end if;

            if Device.Readback_Enabled then
               Device.Readback_Frame := Frame;
               Device.Readback_Pending := True;
            end if;

            Result := Vk.Queue_Present_KHR (Device.Queue, Present_Info'Address);
            if Is_Swapchain_Stale (Result) then
               Status := Swapchain_Out_Of_Date;
               return;
            elsif Result /= Vk.SUCCESS then
               Status :=
                 (if Result = Vk.ERROR_DEVICE_LOST then Device_Lost
                  else Queue_Present_Failed);
               return;
            end if;
         end;
      end;

      Device.Rendered_Frame_Count := Device.Rendered_Frame_Count + 1;
      if Frame = Device.Sync_Frame_Count then
         Device.Current_Frame := 1;
      else
         Device.Current_Frame := Frame + 1;
      end if;
      Status := Ok;
   end Render;


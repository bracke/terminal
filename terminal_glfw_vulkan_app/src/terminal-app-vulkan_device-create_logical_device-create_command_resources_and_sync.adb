separate (Terminal.App.Vulkan_Device.Create_Logical_Device)
      function Create_Command_Resources_And_Sync
        (Handle : Vk.Device_T)
         return Create_Status
      is
         Pool_Info : aliased Vk.Command_Pool_Create_Info_T :=
           (s_Type             => Vk.STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            p_Next             => System.Null_Address,
            flags              => Vk.COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
            queue_Family_Index =>
              Interfaces.Unsigned_32 (Device.Queue_Family_Index));
         Pool : aliased Vk.Command_Pool_T := System.Null_Address;
         Result : Vk.Result_T;
      begin
         if Device.Framebuffer_Count = 0 then
            return Allocate_Command_Buffers_Failed;
         end if;

         Result :=
           Vk.Create_Command_Pool
             (Handle, Pool_Info'Address, System.Null_Address, Pool'Address);
         if Result /= Vk.SUCCESS or else Pool = System.Null_Address then
            return Create_Command_Pool_Failed;
         end if;

         Device.Command_Pool := Pool;

         declare
            Allocate_Info : aliased Vk.Command_Buffer_Allocate_Info_T :=
              (s_Type               => Vk.STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
               p_Next               => System.Null_Address,
               command_Pool         => Device.Command_Pool,
               level                => Vk.COMMAND_BUFFER_LEVEL_PRIMARY,
               command_Buffer_Count =>
                 Interfaces.Unsigned_32 (Device.Framebuffer_Count));
         begin
            Result :=
              Vk.Allocate_Command_Buffers
                (Handle, Allocate_Info'Address, Device.Command_Buffers'Address);
            if Result /= Vk.SUCCESS then
               Destroy_Command_Resources (Handle);
               return Allocate_Command_Buffers_Failed;
            end if;

            Device.Command_Buffer_Count := Device.Framebuffer_Count;
         end;

         declare
            Allocate_Info : aliased Vk.Command_Buffer_Allocate_Info_T :=
              (s_Type               =>
                 Vk.STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
               p_Next               => System.Null_Address,
               command_Pool         => Device.Command_Pool,
               level                => Vk.COMMAND_BUFFER_LEVEL_PRIMARY,
               command_Buffer_Count => 1);
         begin
            Result :=
              Vk.Allocate_Command_Buffers
                (Handle,
                 Allocate_Info'Address,
                 Device.Upload_Command_Buffer'Address);
            if Result /= Vk.SUCCESS
              or else Device.Upload_Command_Buffer = System.Null_Address
            then
               Destroy_Command_Resources (Handle);
               return Allocate_Command_Buffers_Failed;
            end if;
         end;

         declare
            Semaphore_Info : aliased Vk.Semaphore_Create_Info_T :=
              (s_Type => Vk.STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
               p_Next => System.Null_Address,
               flags  => 0);
            Fence_Info : aliased Vk.Fence_Create_Info_T :=
              (s_Type => Vk.STRUCTURE_TYPE_FENCE_CREATE_INFO,
               p_Next => System.Null_Address,
               flags  => Vk.FENCE_CREATE_SIGNALED_BIT);
         begin
            for I in 1 .. Device.Framebuffer_Count loop
               declare
                  Image_Sem : aliased Vk.Semaphore_T := System.Null_Address;
                  Render_Sem : aliased Vk.Semaphore_T := System.Null_Address;
                  Fence : aliased Vk.Fence_T := System.Null_Address;
               begin
                  Result :=
                    Vk.Create_Semaphore
                      (Handle,
                       Semaphore_Info'Address,
                       System.Null_Address,
                       Image_Sem'Address);
                  if Result /= Vk.SUCCESS or else Image_Sem = System.Null_Address then
                     Destroy_Sync (Handle);
                     Destroy_Command_Resources (Handle);
                     return Create_Sync_Failed;
                  end if;

                  Result :=
                    Vk.Create_Semaphore
                      (Handle,
                       Semaphore_Info'Address,
                       System.Null_Address,
                       Render_Sem'Address);
                  if Result /= Vk.SUCCESS or else Render_Sem = System.Null_Address then
                     Vk.Destroy_Semaphore (Handle, Image_Sem, System.Null_Address);
                     Destroy_Sync (Handle);
                     Destroy_Command_Resources (Handle);
                     return Create_Sync_Failed;
                  end if;

                  Result :=
                    Vk.Create_Fence
                      (Handle,
                       Fence_Info'Address,
                       System.Null_Address,
                       Fence'Address);
                  if Result /= Vk.SUCCESS or else Fence = System.Null_Address then
                     Vk.Destroy_Semaphore (Handle, Render_Sem, System.Null_Address);
                     Vk.Destroy_Semaphore (Handle, Image_Sem, System.Null_Address);
                     Destroy_Sync (Handle);
                     Destroy_Command_Resources (Handle);
                     return Create_Sync_Failed;
                  end if;

                  Device.Image_Available (I) := Image_Sem;
                  Device.Render_Finished (I) := Render_Sem;
                  Device.In_Flight (I) := Fence;
                  Device.Sync_Frame_Count := I;
               end;
            end loop;

            Result :=
              Vk.Create_Fence
                (Handle,
                 Fence_Info'Address,
                 System.Null_Address,
                 Device.Upload_Fence'Address);
            if Result /= Vk.SUCCESS
              or else Device.Upload_Fence = System.Null_Address
            then
               Destroy_Sync (Handle);
               Destroy_Command_Resources (Handle);
               return Create_Sync_Failed;
            end if;
         end;

         return Ok;
      end Create_Command_Resources_And_Sync;


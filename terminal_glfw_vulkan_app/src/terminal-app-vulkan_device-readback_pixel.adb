separate (Terminal.App.Vulkan_Device)
   procedure Readback_Pixel
     (Device : in out Logical_Device;
      X, Y   : Natural;
      Red, Green, Blue, Alpha : out Terminal.Common.Bytes.Byte;
      Status : out Readback_Status)
   is
      Mapped : aliased System.Address := System.Null_Address;
      Mapping_Active : Boolean := False;
      Result : Vk.Result_T;
      Offset : Natural := 0;

      procedure Unmap_Readback (Success : out Boolean) is
         procedure Perform_Unmap is
         begin
            Vk.Unmap_Memory (Device.Device, Device.Readback_Memory);
         end Perform_Unmap;

         procedure Handle_Failure
           (E : Ada.Exceptions.Exception_Occurrence) is
         begin
            Device.Cleanup_Quarantined := True;
            Terminal.App.Cleanup_Diagnostics.Note_Failure
              (Terminal.App.Cleanup_Diagnostics.Vulkan_Device,
               E,
               "unmap Vulkan readback memory");
            Device.Readback_Buffer := System.Null_Address;
            Device.Readback_Memory := System.Null_Address;
            Device.Readback_Bytes := 0;
            Device.Readback_Enabled := False;
            Device.Readback_Pending := False;
         end Handle_Failure;
      begin
         Mapped := System.Null_Address;
         Terminal.App.Vulkan_Unmap_Once.Run
           (Mapping_Active,
            Perform_Unmap'Access,
            Handle_Failure'Access,
            Success);
      end Unmap_Readback;
   begin
      Red := 0;
      Green := 0;
      Blue := 0;
      Alpha := 0;
      if not Device.Initialized or else not Device.Readback_Enabled then
         Status := Readback_Not_Initialized;
         return;
      elsif not Device.Readback_Pending
        or else Device.Readback_Frame = 0
        or else Device.Readback_Frame > Device.Sync_Frame_Count
      then
         Status := Readback_No_Completed_Frame;
         return;
      elsif X >= Device.Swapchain_Width or else Y >= Device.Swapchain_Height then
         Status := Readback_Pixel_Out_Of_Range;
         return;
      end if;

      Result :=
        Vk.Wait_For_Fences
          (Device.Device,
           1,
           Device.In_Flight (Device.Readback_Frame)'Address,
           1,
           Interfaces.Unsigned_64'Last);
      if Result /= Vk.SUCCESS then
         Status := Readback_Wait_Fence_Failed;
         return;
      end if;

      Result :=
        Vk.Map_Memory
          (Device.Device,
           Device.Readback_Memory,
           0,
           Interfaces.Unsigned_64 (Device.Readback_Bytes),
           0,
           Mapped'Address);
      Mapping_Active := Result = Vk.SUCCESS;
      if Result /= Vk.SUCCESS or else Mapped = System.Null_Address then
         declare
            Cleanup_Ok : Boolean;
         begin
            Unmap_Readback (Cleanup_Ok);
         end;
         Status := Readback_Map_Failed;
         return;
      end if;

      Offset := (Y * Device.Swapchain_Width + X) * 4;
      declare
         Bytes : constant Readback_Byte_Conversions.Object_Pointer :=
           Readback_Byte_Conversions.To_Pointer (Mapped);
         C0 : constant Terminal.Common.Bytes.Byte :=
           Terminal.Common.Bytes.Byte (Bytes.all (Offset + 1));
         C1 : constant Terminal.Common.Bytes.Byte :=
           Terminal.Common.Bytes.Byte (Bytes.all (Offset + 2));
         C2 : constant Terminal.Common.Bytes.Byte :=
           Terminal.Common.Bytes.Byte (Bytes.all (Offset + 3));
         C3 : constant Terminal.Common.Bytes.Byte :=
           Terminal.Common.Bytes.Byte (Bytes.all (Offset + 4));
      begin
         if Device.Swapchain_Format in
           Vk.FORMAT_B8G8R8A8_UNORM | Vk.FORMAT_B8G8R8A8_SRGB
         then
            Red := C2;
            Green := C1;
            Blue := C0;
            Alpha := C3;
         else
            Red := C0;
            Green := C1;
            Blue := C2;
            Alpha := C3;
         end if;
      end;
      declare
         Cleanup_Ok : Boolean;
      begin
         Unmap_Readback (Cleanup_Ok);
         Status := (if Cleanup_Ok then Readback_Ok else Readback_Map_Failed);
      end;
   exception
      when E : others =>
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Vulkan_Device,
            E,
            "read Vulkan framebuffer pixel");
         declare
            Cleanup_Ok : Boolean;
         begin
            Unmap_Readback (Cleanup_Ok);
         end;
         Device.Readback_Pending := False;
         Status := Readback_Map_Failed;
   end Readback_Pixel;


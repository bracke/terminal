separate (Terminal.App.Vulkan_Device)
   procedure Readback_Pixel
     (Device : in out Logical_Device;
      X, Y   : Natural;
      Red, Green, Blue, Alpha : out Terminal.Common.Bytes.Byte;
      Status : out Readback_Status)
   is
      Mapped : aliased System.Address := System.Null_Address;
      Result : Vk.Result_T;
      Offset : Natural := 0;
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
      if Result /= Vk.SUCCESS or else Mapped = System.Null_Address then
         if Mapped /= System.Null_Address then
            Vk.Unmap_Memory (Device.Device, Device.Readback_Memory);
            Mapped := System.Null_Address;
         end if;
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
      Vk.Unmap_Memory (Device.Device, Device.Readback_Memory);
      Mapped := System.Null_Address;
      Status := Readback_Ok;
   exception
      when others =>
         if Mapped /= System.Null_Address then
            Vk.Unmap_Memory (Device.Device, Device.Readback_Memory);
         end if;
         Device.Readback_Pending := False;
         Status := Readback_Map_Failed;
   end Readback_Pixel;


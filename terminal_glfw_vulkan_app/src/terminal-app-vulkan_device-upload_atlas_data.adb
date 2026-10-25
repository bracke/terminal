separate (Terminal.App.Vulkan_Device)
procedure Upload_Atlas_Data
  (Device        : in out Logical_Device;
   Choice        : Selection;
   Width         : Natural;
   Height        : Natural;
   Bytes_Natural : Natural;
   Pixels        : System.Address;
   Dirty         : Boolean;
   Status        : out Create_Status)
is
   procedure Fill_Atlas
     (Target   : Image_Texture_Byte_Mapping.Object_Pointer;
      Capacity : Positive;
      Status   : out Create_Status)
   is
      Source : constant Byte_Mapping.Object_Pointer :=
        Byte_Mapping.To_Pointer (Pixels);
   begin
      if Source = null
        or else Target = null
        or else Bytes_Natural > Capacity
      then
         Status := Atlas_Too_Large;
         return;
      end if;
      for I in 1 .. Bytes_Natural loop
         Target.all (I) := Source.all (I);
      end loop;
      Status := Ok;
   end Fill_Atlas;
begin
   if not Dirty
     and then Device.Atlas_Image /= System.Null_Address
     and then Device.Atlas_Width = Width
     and then Device.Atlas_Height = Height
     and then Device.Atlas_Bytes = Bytes_Natural
   then
      Status := Ok;
      return;
   end if;

   Upload_Image_Texture_Staging_Source
     (Device                 => Device,
      Slot                   => Text_Glyphs,
      Choice                 => Choice,
      Width                  => Width,
      Height                 => Height,
      Source_Bytes_Per_Pixel => 1,
      Row_Stride_Bytes       => Width,
      Bytes_Natural          => Bytes_Natural,
      Fill_Staging           => Fill_Atlas'Access,
      Status                 => Status,
      Image_Format           => Format_R8_Unorm,
      Maximum_Bytes          => Max_Atlas_Bytes);
end Upload_Atlas_Data;

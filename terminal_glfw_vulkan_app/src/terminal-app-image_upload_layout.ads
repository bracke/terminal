package Terminal.App.Image_Upload_Layout is
   type Layout_Status is (Layout_Ok, Invalid_Layout);

   type Layout is record
      Source_Row_Bytes       : Natural := 0;
      Target_Row_Bytes       : Natural := 0;
      Required_Source_Bytes  : Natural := 0;
      Upload_Bytes           : Natural := 0;
      Staging_Bytes          : Natural := 0;
      Vulkan_Buffer_Row_Pixels : Natural := 0;
   end record;

   procedure Calculate
     (Width                  : Natural;
      Height                 : Natural;
      Source_Bytes_Per_Pixel : Natural;
      Row_Stride_Bytes       : Natural;
      Source_Bytes           : Natural;
      Maximum_Bytes          : Positive;
      Result                 : out Layout;
      Status                 : out Layout_Status);
end Terminal.App.Image_Upload_Layout;

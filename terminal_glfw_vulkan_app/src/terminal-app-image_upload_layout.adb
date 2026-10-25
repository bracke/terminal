package body Terminal.App.Image_Upload_Layout is
   procedure Calculate
     (Width                  : Natural;
      Height                 : Natural;
      Source_Bytes_Per_Pixel : Natural;
      Row_Stride_Bytes       : Natural;
      Source_Bytes           : Natural;
      Maximum_Bytes          : Positive;
      Result                 : out Layout;
      Status                 : out Layout_Status)
   is
      Source_Row : Natural;
      Target_Row : Natural;
      Required   : Natural;
      Upload     : Natural;
      Staging    : Natural;
      Row_Pixels : Natural := 0;
   begin
      Result := (others => 0);
      Status := Invalid_Layout;
      if Width = 0
        or else Height = 0
        or else Source_Bytes_Per_Pixel not in 3 | 4
        or else Width > Maximum_Bytes / 4
        or else Width > Maximum_Bytes / Source_Bytes_Per_Pixel
      then
         return;
      end if;

      Target_Row := Width * 4;
      Source_Row := Width * Source_Bytes_Per_Pixel;
      if Row_Stride_Bytes < Source_Row
        or else Row_Stride_Bytes > Maximum_Bytes
        or else Height > Maximum_Bytes / Target_Row
        or else
          (Height > 1
           and then Row_Stride_Bytes >
             (Maximum_Bytes - Source_Row) / (Height - 1))
      then
         return;
      end if;

      Upload := Target_Row * Height;
      Required := (Height - 1) * Row_Stride_Bytes + Source_Row;
      if Source_Bytes_Per_Pixel = 4
        and then Row_Stride_Bytes > Target_Row
        and then Row_Stride_Bytes mod 4 = 0
      then
         Staging := Required;
         Row_Pixels := Row_Stride_Bytes / 4;
      else
         Staging := Upload;
      end if;

      if Upload = 0
        or else Upload > Maximum_Bytes
        or else Staging = 0
        or else Staging > Maximum_Bytes
        or else Source_Bytes < Required
        or else Source_Bytes > Maximum_Bytes
      then
         return;
      end if;

      Result :=
        (Source_Row_Bytes         => Source_Row,
         Target_Row_Bytes         => Target_Row,
         Required_Source_Bytes    => Required,
         Upload_Bytes             => Upload,
         Staging_Bytes            => Staging,
         Vulkan_Buffer_Row_Pixels => Row_Pixels);
      Status := Layout_Ok;
   end Calculate;
end Terminal.App.Image_Upload_Layout;

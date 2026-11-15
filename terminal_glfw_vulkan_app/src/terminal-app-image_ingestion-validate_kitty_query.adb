with Terminal.App.Graphics.Media_Decoders;
with Terminal.App.Graphics.Decoding;
with Terminal.App.Owned_Image_Data;

separate (Terminal.App.Image_Ingestion)
function Validate_Kitty_Query
     (Header        : Terminal.App.Graphics.Graphics_Header;
      Text          : String;
      Policy        : Terminal.App.Graphics_Transport.Access_Policy;
      Maximum_Bytes : Positive;
      Maximum_Pixel_Dimension : Positive :=
        Terminal.Common.Graphics_Limits.Max_Pixel_Dimension;
      Maximum_Frames : Positive :=
        Terminal.Common.Graphics_Limits.Max_Animation_Frames)
      return Terminal.Core.Graphics_Completion_Code
   is
      use type Terminal.App.Graphics.Data_Decode_Status;
      use type Terminal.App.Graphics_Transport.Load_Status;

      Data : Terminal.App.Graphics.Graphics_Data_Preview :=
        Terminal.App.Graphics.Metadata_Preview
          (Header_Recognized => Header.Recognized,
           Has_Data          => Header.Has_Data,
           Raw_Format        => 0,
           Pixel_Width       => 0,
           Pixel_Height      => 0);
      Row_Failed : Boolean := False;
      Decoded_Bytes : Natural := 0;

      procedure Set_Data
        (Raw_Format   : Natural;
         Pixel_Width  : Natural;
         Pixel_Height : Natural;
         Length       : Natural;
         Row_Stride   : Natural;
         Status       : Terminal.App.Graphics.Data_Decode_Status)
      is
      begin
         Terminal.App.Graphics.Record_External_Decode
           (Data,
            Encoded_Length           => 0,
            Raw_Format               => Raw_Format,
            Pixel_Width              => Pixel_Width,
            Pixel_Height             => Pixel_Height,
            Decoded_Length           => Length,
            Decoded_Row_Stride_Bytes => Row_Stride,
            Status                   => Status);
      end Set_Data;

      function One_Chunk (Index : Positive) return String is
         First : constant Natural := Payload_Start (Kitty, Text);
      begin
         if Index /= 1 or else First = 0 then
            return "";
         end if;
         return Text (First .. Text'Last);
      end One_Chunk;

      procedure Discard_Row
        (Y        : Natural;
         Row      : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean)
      is
         pragma Unreferenced (Y);
      begin
         if Row'Length = 0
           or else Decoded_Bytes > Maximum_Bytes
           or else Row'Length > Maximum_Bytes - Decoded_Bytes
         then
            Row_Failed := True;
            Continue := False;
         else
            Decoded_Bytes := Decoded_Bytes + Row'Length;
            Continue := True;
         end if;
      end Discard_Row;

      function Decoded_Size_Exceeds_Limit return Boolean is
         Bytes_Per_Pixel : constant Natural :=
           (case Data.Raw_Format is
               when 8      => 1,
               when 16     => 2,
               when 24     => 3,
               when 32     => 4,
               when others => 0);
         Row_Bytes : Natural;
      begin
         if Bytes_Per_Pixel = 0
           or else Data.Pixel_Width = 0
           or else Data.Pixel_Height = 0
         then
            return False;
         elsif Data.Pixel_Width > Maximum_Bytes / Bytes_Per_Pixel then
            return True;
         end if;
         Row_Bytes := Data.Pixel_Width * Bytes_Per_Pixel;
         return Data.Pixel_Height > Maximum_Bytes / Row_Bytes;
      end Decoded_Size_Exceeds_Limit;

      function Finish_Result
        return Terminal.Core.Graphics_Completion_Code
      is
         Too_Large : constant Boolean :=
           Row_Failed
           or else Decoded_Size_Exceeds_Limit
           or else Data.Pixel_Width > Maximum_Pixel_Dimension
           or else Data.Pixel_Height > Maximum_Pixel_Dimension
           or else
             (Data.Decode_Complete
              and then Data.Decoded_Length > Maximum_Bytes);
         Resource_Failure : constant Boolean :=
           Data.Decode_Status in
             Terminal.App.Graphics.Decode_Allocation_Failed
             | Terminal.App.Graphics.Decode_Too_Large
             | Terminal.App.Graphics.Decode_Preview_Truncated;
         Valid : constant Boolean :=
           not Too_Large
           and then Data.Decode_Complete
           and then Data.Raw_Format in 8 | 16 | 24 | 32
           and then Data.Pixel_Width > 0
           and then Data.Pixel_Height > 0;
      begin
         Terminal.App.Graphics.Release (Data);
         return
           (if Too_Large or else Resource_Failure
            then Terminal.Core.Graphics_ENOMEM
            elsif Valid then Terminal.Core.Graphics_OK
            else Terminal.Core.Graphics_EINVAL);
      end Finish_Result;

      procedure Decode_Uncompressed
        (Bytes  : Terminal.Common.Bytes.Byte_Array;
         Length : Natural)
      is
      begin
         if Header.Kitty_Format in 8 | 16 | 24 | 32 then
            declare
               Pixel_Size : constant Natural := Header.Kitty_Format / 8;
               Expected : Natural := 0;
            begin
               if Header.Pixel_Width = 0 or else Header.Pixel_Height = 0 then
                  Terminal.App.Graphics.Set_Decode_Failure
                    (Data, Terminal.App.Graphics.Decode_Invalid_Data);
                  return;
               elsif Header.Pixel_Width > Maximum_Pixel_Dimension
                 or else Header.Pixel_Height > Maximum_Pixel_Dimension
                 or else Header.Pixel_Width > Maximum_Bytes / Pixel_Size
                 or else Header.Pixel_Height >
                   Maximum_Bytes / (Header.Pixel_Width * Pixel_Size)
               then
                  Terminal.App.Graphics.Set_Decode_Failure
                    (Data, Terminal.App.Graphics.Decode_Too_Large);
                  return;
               end if;
               Expected :=
                 Header.Pixel_Width * Header.Pixel_Height * Pixel_Size;
               Set_Data
                 (Header.Kitty_Format,
                  Header.Pixel_Width,
                  Header.Pixel_Height,
                  Length,
                  Header.Pixel_Width * Pixel_Size,
                  (if Length = Expected
                   then Terminal.App.Graphics.Decode_Ok
                   else Terminal.App.Graphics.Decode_Invalid_Byte));
            end;
         elsif Header.Kitty_Format = 100 then
            Terminal.App.Graphics.Media_Decoders.Decode_PNG_RGBA_Rows
              (Bytes, Length, Discard_Row'Access, Data);
         elsif Header.Kitty_Format = Terminal.App.Graphics.Kitty_JPEG_Format
         then
            Terminal.App.Graphics.Media_Decoders.Decode_JPEG_RGBA_Data
              (Bytes,
               Length,
               Data,
               Maximum_Decoded_Bytes => Maximum_Bytes,
               Maximum_Pixel_Dimension => Maximum_Pixel_Dimension);
         elsif Header.Kitty_Format = Terminal.App.Graphics.Kitty_GIF_Format
         then
            declare
               Media : Terminal.App.Image_Media.Decoded_Image;
               Media_Status : Terminal.App.Image_Media.Decode_Status;
            begin
               Terminal.App.Image_Media.Decode
                 (Bytes,
                  Length,
                  Maximum_Bytes,
                  Maximum_Pixel_Dimension,
                  Media,
                  Media_Status,
                  Maximum_Frames => Maximum_Frames);
               if Media_Status = Terminal.App.Image_Media.Decode_Ok then
                  Set_Data
                    (32,
                     Media.Pixel_Width,
                     Media.Pixel_Height,
                     Media.Frame_Bytes,
                     Media.Pixel_Width * 4,
                     Terminal.App.Graphics.Decode_Ok);
               else
                  Terminal.App.Graphics.Set_Decode_Failure
                    (Data,
                     (case Media_Status is
                         when Terminal.App.Image_Media.
                                Decode_Allocation_Failed =>
                            Terminal.App.Graphics.Decode_Allocation_Failed,
                         when Terminal.App.Image_Media.Decode_Too_Large =>
                            Terminal.App.Graphics.Decode_Too_Large,
                         when others =>
                            Terminal.App.Graphics.Decode_Invalid_Byte));
               end if;
               Terminal.App.Image_Media.Release (Media);
            end;
         else
            Terminal.App.Graphics.Set_Decode_Failure
              (Data, Terminal.App.Graphics.Decode_Unsupported_Format);
         end if;
      end Decode_Uncompressed;
   begin
      if Header.Kitty_Transmission in 'f' | 't' | 's' then
         declare
            First : constant Natural := Payload_Start (Kitty, Text);
            Loaded : Terminal.App.Graphics_Transport.Byte_Array_Access := null;
            Loaded_Length : Natural := 0;
            Load_Status : Terminal.App.Graphics_Transport.Load_Status;
         begin
            if First = 0
              or else not Header.Kitty_Data_Size_Valid
              or else not Header.Kitty_Data_Offset_Valid
              or else Header.Kitty_More_Specified
            then
               Terminal.App.Graphics.Release (Data);
               return Terminal.Core.Graphics_EINVAL;
            end if;
            Terminal.App.Graphics_Transport.Load
              (Medium           => Header.Kitty_Transmission,
               Encoded_Location => Text (First .. Text'Last),
               Offset           => Header.Kitty_Data_Offset,
               Size             => Header.Kitty_Data_Size,
               Size_Specified   => Header.Kitty_Data_Size_Specified,
               Policy           => Policy,
               Maximum_Bytes    => Maximum_Bytes,
               Bytes            => Loaded,
               Length           => Loaded_Length,
               Status           => Load_Status);
            if Load_Status /= Terminal.App.Graphics_Transport.Load_Ok then
               Terminal.App.Graphics.Release (Data);
               return
                 (if Load_Status in
                       Terminal.App.Graphics_Transport.Load_Too_Large
                       | Terminal.App.Graphics_Transport.Load_Allocation_Failed
                  then Terminal.Core.Graphics_ENOMEM
                  else Terminal.Core.Graphics_EBADF);
            end if;
            begin
               Terminal.App.Graphics.Release (Data);
               if Header.Kitty_Compression = 'z' then
                  declare
                     Inflated : Terminal.App.Owned_Image_Data.Owner;
                     Inflated_Length : Natural := 0;
                     Inflate_Status : Terminal.App.Graphics.Data_Decode_Status;
                     Pixel_Size : constant Natural :=
                       (case Header.Kitty_Format is
                           when 8 => 1, when 16 => 2,
                           when 24 => 3, when 32 => 4,
                           when others => 0);
                     Expected : Natural := 0;
                     Limit : Natural := Maximum_Bytes;
                     Exact : Boolean := False;
                  begin
                     if Pixel_Size > 0 then
                        if Header.Pixel_Width = 0
                          or else Header.Pixel_Height = 0
                        then
                           Terminal.App.Graphics_Transport.Release (Loaded);
                           return Terminal.Core.Graphics_EINVAL;
                        elsif Header.Pixel_Width > Maximum_Pixel_Dimension
                          or else Header.Pixel_Height > Maximum_Pixel_Dimension
                        then
                           Terminal.App.Graphics_Transport.Release (Loaded);
                           return Terminal.Core.Graphics_ENOMEM;
                        elsif Header.Pixel_Width > Maximum_Bytes / Pixel_Size
                          or else Header.Pixel_Height >
                            Maximum_Bytes / (Header.Pixel_Width * Pixel_Size)
                        then
                           Terminal.App.Graphics_Transport.Release (Loaded);
                           return Terminal.Core.Graphics_ENOMEM;
                        end if;
                        Expected :=
                          Header.Pixel_Width * Header.Pixel_Height * Pixel_Size;
                        Limit := Expected;
                        Exact := True;
                     elsif Header.Kitty_Format = 100 then
                        --  For local media S bounds the selected source
                        --  range. It is not the inflated PNG byte count.
                        Limit := Maximum_Bytes;
                        Exact := False;
                     else
                        Terminal.App.Graphics_Transport.Release (Loaded);
                        return Terminal.Core.Graphics_EINVAL;
                     end if;
                     Terminal.App.Graphics.Decoding.Decode_Zlib_Data
                       (Loaded.all, Loaded_Length, Limit, Exact,
                        Inflated, Inflated_Length, Inflate_Status);
                     Terminal.App.Graphics_Transport.Release (Loaded);
                     if Inflate_Status /= Terminal.App.Graphics.Decode_Ok
                       or else Terminal.App.Owned_Image_Data.Is_Empty (Inflated)
                     then
                        return
                          (if Inflate_Status in
                                Terminal.App.Graphics.Decode_Allocation_Failed
                                | Terminal.App.Graphics.Decode_Too_Large
                                | Terminal.App.Graphics.Decode_Preview_Truncated
                           then Terminal.Core.Graphics_ENOMEM
                           else Terminal.Core.Graphics_EINVAL);
                     end if;
                     if Pixel_Size > 0 then
                        Set_Data
                          (Header.Kitty_Format,
                           Header.Pixel_Width,
                           Header.Pixel_Height,
                           Inflated_Length,
                           Header.Pixel_Width * Pixel_Size,
                           Terminal.App.Graphics.Decode_Ok);
                     else
                        declare
                           procedure Decode_PNG
                             (Bytes : Terminal.Common.Bytes.Byte_Array) is
                           begin
                              Terminal.App.Graphics.Media_Decoders.Decode_PNG_RGBA_Rows
                                (Bytes, Inflated_Length,
                                 Discard_Row'Access, Data);
                           end Decode_PNG;
                        begin
                           Terminal.App.Owned_Image_Data.Read
                             (Inflated, Decode_PNG'Access);
                        end;
                     end if;
                  exception
                     when others =>
                        Terminal.App.Graphics_Transport.Release (Loaded);
                        raise;
                  end;
               else
                  Decode_Uncompressed (Loaded.all, Loaded_Length);
                  Terminal.App.Graphics_Transport.Release (Loaded);
               end if;
               return Finish_Result;
            exception
               when others =>
                  Terminal.App.Graphics_Transport.Release (Loaded);
                  raise;
            end;
         end;
      end if;

      if not Header.Has_Data
        or else Header.Kitty_Format not in 8 | 16 | 24 | 32 | 100
             | Terminal.App.Graphics.Kitty_JPEG_Format
             | Terminal.App.Graphics.Kitty_GIF_Format
        or else Header.Kitty_Compression not in ASCII.NUL | 'z'
      then
         Terminal.App.Graphics.Release (Data);
         return Terminal.Core.Graphics_EINVAL;
      end if;
      if Header.Kitty_Compression = 'z' then
         if Header.Kitty_Format in 8 | 16 | 24 | 32 then
            Terminal.App.Graphics.Decoding.Decode_Base64_Zlib_Raw_Chunk_Rows
              (1,
               One_Chunk'Access,
               Header.Kitty_Format,
               Header.Pixel_Width,
               Header.Pixel_Height,
               Discard_Row'Access,
               Data);
         elsif Header.Kitty_Format = 100
           and then Header.Kitty_Data_Size > 0
         then
            declare
               Encoded_Length : Natural := 0;
            begin
               Terminal.App.Graphics.Decoding.Decode_Base64_Zlib_PNG_Chunk_Rows
                 (1,
                  One_Chunk'Access,
                  Header.Kitty_Data_Size,
                  Encoded_Length,
                  Discard_Row'Access,
                  Data);
            end;
         end if;
      else
         declare
            First : constant Natural := Payload_Start (Kitty, Text);
            Decoded : Terminal.App.Owned_Image_Data.Owner;
            Length : Natural := 0;
            Decode_Status : Terminal.App.Graphics.Data_Decode_Status;
         begin
            if First = 0 then
               return Terminal.Core.Graphics_EINVAL;
            end if;
            Terminal.App.Graphics.Decoding.Decode_Base64_Data
              (Text (First .. Text'Last), Maximum_Bytes,
               Decoded, Length, Decode_Status);
            if Decode_Status /= Terminal.App.Graphics.Decode_Ok
              or else Terminal.App.Owned_Image_Data.Is_Empty (Decoded)
            then
               return
                 (if Decode_Status in
                       Terminal.App.Graphics.Decode_Allocation_Failed
                       | Terminal.App.Graphics.Decode_Too_Large
                       | Terminal.App.Graphics.Decode_Preview_Truncated
                  then Terminal.Core.Graphics_ENOMEM
                  else Terminal.Core.Graphics_EINVAL);
            end if;

            declare
               procedure Decode
                 (Bytes : Terminal.Common.Bytes.Byte_Array) is
               begin
                  Decode_Uncompressed (Bytes, Length);
               end Decode;
            begin
               Terminal.App.Owned_Image_Data.Read (Decoded, Decode'Access);
            end;
         end;
      end if;
      return Finish_Result;
   exception
      when Storage_Error =>
         Terminal.App.Graphics.Release (Data);
         return Terminal.Core.Graphics_ENOMEM;
      when Constraint_Error =>
         Terminal.App.Graphics.Release (Data);
         return Terminal.Core.Graphics_EINVAL;
      when others =>
         Terminal.App.Graphics.Release (Data);
         raise;
   end Validate_Kitty_Query;

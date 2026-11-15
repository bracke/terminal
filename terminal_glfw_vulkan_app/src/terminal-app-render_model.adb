with Terminal.App.Image_Decode;
with Terminal.App.Image_Upload_Layout;

package body Terminal.App.Render_Model is
   use type Terminal.Common.Bytes.Byte;
   use type Terminal.App.Image_Decode.Status;

   function Image_Decode_Status_Suffix
     (Status : Image_Decode_Status) return String
      is (Terminal.App.Image_Decode.Suffix (Status));

   function Image_Payload_Status_Suffix
     (Preview_Complete : Boolean) return String
   is
   begin
      if Preview_Complete then
         return " payload-complete";
      else
         return " payload-preview";
      end if;
   end Image_Payload_Status_Suffix;

   function Image_Decoded_Source_Bytes
     (Image : Image_Command) return Natural
   is
      Bytes_Per_Pixel : constant Natural :=
        (if Image.Raw_Format = 24 then 3
         elsif Image.Raw_Format = 32 then 4
         else 0);
      Row_Stride : Natural := 0;
   begin
      if Image.Decoded_Source = Image_Decoded_Source_None
        or else Image.Pixel_Width = 0
        or else Image.Pixel_Height = 0
        or else Bytes_Per_Pixel = 0
        or else Image.Pixel_Width > Natural'Last / Bytes_Per_Pixel
      then
         return 0;
      end if;

      Row_Stride :=
        (if Image.Decoded_Row_Stride_Bytes > 0
         then Image.Decoded_Row_Stride_Bytes
         else Image.Pixel_Width * Bytes_Per_Pixel);
      return Terminal.App.Image_Upload_Layout.Required_Source_Bytes
        (Image.Pixel_Width,
         Image.Pixel_Height,
         Bytes_Per_Pixel,
         Row_Stride,
         Max_Image_Decoded_Data_Length);
   end Image_Decoded_Source_Bytes;

   function Image_Decoded_Source_Available
     (Image : Image_Command) return Boolean
   is
      Required : constant Natural := Image_Decoded_Source_Bytes (Image);
   begin
      case Image.Decoded_Source is
         when Image_Decoded_Source_None =>
            return False;
         when Image_Decoded_Source_Buffer =>
            return Image.Decoded_Bytes /= null
              and then Required > 0
              and then Image.Decoded_Byte_Length >= Required
              and then Required <= Image.Decoded_Bytes'Length;
         when Image_Decoded_Source_Raw_Base64 =>
            return Image.Encoded_Source_Bytes /= null
              and then Image.Encoded_Source_Length > 0
              and then Image.Encoded_Source_Length <=
                Image.Encoded_Source_Bytes'Length
              and then Required > 0
              and then Image.Decoded_Byte_Length >= Required;
         when Image_Decoded_Source_PNG_Base64 |
              Image_Decoded_Source_Sixel_Text =>
            return Image.Encoded_Source_Bytes /= null
              and then Image.Encoded_Source_Length > 0
              and then Image.Encoded_Source_Length <=
                Image.Encoded_Source_Bytes'Length
              and then Required > 0
              and then Image.Decoded_Byte_Length >= Required;
      end case;
   end Image_Decoded_Source_Available;

   function Image_Decoded_Random_Access_Bytes
     (Image : Image_Command) return Natural
   is
      Required : constant Natural := Image_Decoded_Source_Bytes (Image);
   begin
      case Image.Decoded_Source is
         when Image_Decoded_Source_Buffer =>
            if Image.Decoded_Bytes = null then
               return 0;
            end if;
            return Natural'Min
              (Required,
               Natural'Min
                 (Image.Decoded_Byte_Length, Image.Decoded_Bytes'Length));
         when Image_Decoded_Source_Raw_Base64 =>
            if not Image.Preview_Decode_Complete
              or else Image.Decode_Status /= Image_Decode_Ok
              or else Image.Decoded_Preview_Bytes = null
            then
               return 0;
            end if;
            return Natural'Min
              (Required,
               Natural'Min
                 (Image.Decoded_Preview_Length,
                  Image.Decoded_Preview_Bytes'Length));
         when Image_Decoded_Source_PNG_Base64 |
              Image_Decoded_Source_Sixel_Text |
              Image_Decoded_Source_None =>
            return 0;
      end case;
   end Image_Decoded_Random_Access_Bytes;

   function Image_Decoded_Row_Byte
     (Image       : Image_Command;
      Row         : Natural;
      Byte_Offset : Natural) return Terminal.Common.Bytes.Byte
   is
      Bytes_Per_Pixel : constant Natural :=
        (if Image.Raw_Format = 24 then 3
         elsif Image.Raw_Format = 32 then 4
         else 0);
      Row_Bytes : Natural := 0;
      Row_Stride : constant Natural :=
        (if Image.Decoded_Row_Stride_Bytes > 0
         then Image.Decoded_Row_Stride_Bytes
         elsif Bytes_Per_Pixel > 0
           and then Image.Pixel_Width <= Natural'Last / Bytes_Per_Pixel
         then Image.Pixel_Width * Bytes_Per_Pixel
         else 0);
      Accessible : constant Natural :=
        Image_Decoded_Random_Access_Bytes (Image);
      Index : Natural := 0;
   begin
      if Image.Decoded_Source = Image_Decoded_Source_None
        or else Row_Stride = 0
        or else Row >= Image.Pixel_Height
        or else Byte_Offset >= Row_Stride
        or else Accessible = 0
      then
         return 0;
      end if;

      Row_Bytes := Image.Pixel_Width * Bytes_Per_Pixel;
      if Row_Bytes = 0 or else Row_Stride < Row_Bytes then
         return 0;
      end if;

      if Row > (Natural'Last - Byte_Offset - 1) / Row_Stride then
         return 0;
      end if;
      Index := Row * Row_Stride + Byte_Offset + 1;
      if Index > Accessible
      then
         return 0;
      end if;

      case Image.Decoded_Source is
         when Image_Decoded_Source_Buffer =>
            if Image.Decoded_Bytes = null
              or else Index > Image.Decoded_Bytes'Last
            then
               return 0;
            end if;
            return Image.Decoded_Bytes (Index);
         when Image_Decoded_Source_Raw_Base64 =>
            --  Encoded sources are decoded once per upload by Image_Staging.
            --  This random-access helper deliberately exposes only the
            --  already validated diagnostic prefix; decoding the complete
            --  source for every requested byte made row inspection quadratic.
            return Image.Decoded_Preview_Bytes (Index);
         when Image_Decoded_Source_PNG_Base64 |
              Image_Decoded_Source_Sixel_Text =>
            return 0;
         when Image_Decoded_Source_None =>
            return 0;
      end case;
   end Image_Decoded_Row_Byte;

   function Image_Decoded_Preview_Byte
     (Image : Image_Command;
      Index : Positive) return Terminal.Common.Bytes.Byte is
   begin
      if Index > Image.Decoded_Preview_Length
        or else Index > Max_Image_Decoded_Preview_Length
        or else Image.Decoded_Preview_Bytes = null
        or else Index > Image.Decoded_Preview_Bytes'Length
      then
         return 0;
      end if;
      return Image.Decoded_Preview_Bytes (Index);
   end Image_Decoded_Preview_Byte;
end Terminal.App.Render_Model;

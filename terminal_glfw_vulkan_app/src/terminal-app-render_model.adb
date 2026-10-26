with Terminal.App.Image_Decode;
with Terminal.Common.Base64;

package body Terminal.App.Render_Model is
   use type Terminal.Common.Bytes.Byte;
   use type Terminal.Common.Base64.Decoder_Status;

   function Read_Only (Data : Image_Data_Access) return Image_Data_View is
     (Image_Data_View (Data));

   function Base64_Source_Byte
     (Image  : Image_Command;
      Target : Positive) return Terminal.Common.Bytes.Byte
   is
      Decoder : Terminal.Common.Base64.Decoder_State;
      Bytes : Terminal.Common.Base64.Decoded_Quantum;
      Byte_Count : Natural := 0;
      Decode_Status : Terminal.Common.Base64.Decoder_Status;
      Decoded_Position : Natural := 0;
      Result : Terminal.Common.Bytes.Byte := 0;
      Found : Boolean := False;

      procedure Consume_Output is
      begin
         if Decode_Status = Terminal.Common.Base64.Invalid_Data then
            Found := True;
            Result := 0;
            return;
         end if;
         for I in 1 .. Byte_Count loop
            Decoded_Position := Decoded_Position + 1;
            if Decoded_Position = Target then
               Result := Bytes (I);
               Found := True;
               return;
            end if;
         end loop;
      end Consume_Output;
   begin
      if Image.Encoded_Source_Bytes = null
        or else Target > Image.Decoded_Byte_Length
      then
         return 0;
      end if;

      Terminal.Common.Base64.Reset
        (Decoder, Allow_Unpadded => True, Allow_Whitespace => True);

      for Index in 1 .. Natural'Min
        (Image.Encoded_Source_Length, Image.Encoded_Source_Bytes'Length)
      loop
         Terminal.Common.Base64.Push
           (Decoder,
            Image.Encoded_Source_Bytes (Index),
            Bytes,
            Byte_Count,
            Decode_Status);
         Consume_Output;
         exit when Found;
      end loop;
      if not Found then
         Terminal.Common.Base64.Finish
           (Decoder, Bytes, Byte_Count, Decode_Status);
         Consume_Output;
      end if;
      return Result;
   end Base64_Source_Byte;

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
      Row_Bytes : Natural := 0;
      Row_Stride : Natural := 0;
      Extent : Natural := 0;
   begin
      if Image.Decoded_Source = Image_Decoded_Source_None
        or else Image.Pixel_Width = 0
        or else Image.Pixel_Height = 0
        or else Bytes_Per_Pixel = 0
        or else Image.Pixel_Width > Natural'Last / Bytes_Per_Pixel
      then
         return 0;
      end if;

      Row_Bytes := Image.Pixel_Width * Bytes_Per_Pixel;
      Row_Stride :=
        (if Image.Decoded_Row_Stride_Bytes > 0
         then Image.Decoded_Row_Stride_Bytes
         else Row_Bytes);

      if Row_Bytes = 0
        or else Row_Stride < Row_Bytes
        or else
          (Image.Pixel_Height > 1
           and then Row_Stride >
             (Natural'Last - Row_Bytes) / (Image.Pixel_Height - 1))
      then
         return 0;
      end if;

      Extent :=
        (if Image.Pixel_Height = 1
         then Row_Bytes
         else (Image.Pixel_Height - 1) * Row_Stride + Row_Bytes);
      if Extent > Max_Image_Decoded_Data_Length then
         return 0;
      end if;

      return Extent;
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
      Required : constant Natural := Image_Decoded_Source_Bytes (Image);
      Index : Natural := 0;
   begin
      if Image.Decoded_Source = Image_Decoded_Source_None
        or else Row_Stride = 0
        or else Row >= Image.Pixel_Height
        or else Byte_Offset >= Row_Stride
        or else Required = 0
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
      if Index > Required
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
            return Base64_Source_Byte (Image, Index);
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

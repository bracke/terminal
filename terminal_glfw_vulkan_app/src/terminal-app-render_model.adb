package body Terminal.App.Render_Model is
   use type Terminal.Common.Bytes.Byte;

   function Base64_Value (Value : Terminal.Common.Bytes.Byte) return Integer is
   begin
      if Value >= Character'Pos ('A') and then Value <= Character'Pos ('Z') then
         return Integer (Value) - Character'Pos ('A');
      elsif Value >= Character'Pos ('a') and then Value <= Character'Pos ('z') then
         return Integer (Value) - Character'Pos ('a') + 26;
      elsif Value >= Character'Pos ('0') and then Value <= Character'Pos ('9') then
         return Integer (Value) - Character'Pos ('0') + 52;
      elsif Value = Character'Pos ('+') then
         return 62;
      elsif Value = Character'Pos ('/') then
         return 63;
      else
         return -1;
      end if;
   end Base64_Value;

   function Base64_Source_Byte
     (Image  : Image_Command;
      Target : Positive) return Terminal.Common.Bytes.Byte
   is
      Values : array (1 .. 4) of Natural := (others => 0);
      Count : Natural := 0;
      Padding : Natural := 0;
      Decoded_Position : Natural := 0;

      function Group_Length return Natural is
      begin
         if Count = 0 or else Count = 1 or else Padding > 2 then
            return 0;
         elsif Count = 2 then
            return 1;
         elsif Count = 3 then
            return (if Padding = 0 then 2 else 1);
         else
            return 3 - Padding;
         end if;
      end Group_Length;

      function Group_Byte
        (Index : Positive) return Terminal.Common.Bytes.Byte
      is
      begin
         case Index is
            when 1 =>
               return Terminal.Common.Bytes.Byte
                 ((Values (1) * 4) + (Values (2) / 16));
            when 2 =>
               return Terminal.Common.Bytes.Byte
                 (((Values (2) mod 16) * 16) + (Values (3) / 4));
            when others =>
               return Terminal.Common.Bytes.Byte
                 (((Values (3) mod 4) * 64) + Values (4));
         end case;
      end Group_Byte;

      function Flush_Group return Terminal.Common.Bytes.Byte is
         Length : constant Natural := Group_Length;
      begin
         if Length = 0 then
            return 0;
         end if;

         for I in 1 .. Length loop
            Decoded_Position := Decoded_Position + 1;
            if Decoded_Position = Target then
               return Group_Byte (I);
            end if;
         end loop;

         return 0;
      end Flush_Group;
   begin
      if Image.Encoded_Source_Bytes = null
        or else Target > Image.Decoded_Byte_Length
      then
         return 0;
      end if;

      for Index in 1 .. Natural'Min
        (Image.Encoded_Source_Length, Image.Encoded_Source_Bytes'Length)
      loop
         declare
            Ch : constant Terminal.Common.Bytes.Byte :=
              Image.Encoded_Source_Bytes (Index);
            V : constant Integer := Base64_Value (Ch);
         begin
            if Ch = Character'Pos (ASCII.CR)
              or else Ch = Character'Pos (ASCII.LF)
              or else Ch = Character'Pos (' ')
            then
               null;
            elsif Ch = Character'Pos ('=') then
               Count := Count + 1;
               if Count > 4 then
                  return 0;
               end if;
               Padding := Padding + 1;
               Values (Count) := 0;
               if Count = 4 then
                  return Flush_Group;
               end if;
            elsif V < 0 or else Padding > 0 then
               return 0;
            else
               Count := Count + 1;
               if Count > 4 then
                  return 0;
               end if;
               Values (Count) := Natural (V);
               if Count = 4 then
                  declare
                     Result : constant Terminal.Common.Bytes.Byte := Flush_Group;
                  begin
                     if Decoded_Position >= Target then
                        return Result;
                     end if;
                  end;
                  Values := (others => 0);
                  Count := 0;
               end if;
            end if;
         end;
      end loop;

      if Count > 0 then
         return Flush_Group;
      end if;

      return 0;
   end Base64_Source_Byte;

   function Image_Decode_Status_Suffix
     (Status : Image_Decode_Status) return String
   is
   begin
      case Status is
         when Image_Decode_Not_Attempted | Image_Decode_Ok =>
            return "";
         when Image_Decode_Invalid_Byte =>
            return " invalid-byte";
         when Image_Decode_Trailing_Data =>
            return " trailing-data";
         when Image_Decode_Preview_Truncated =>
            return " truncated";
         when Image_Decode_Unsupported_Format =>
            return " unsupported-format";
      end case;
   end Image_Decode_Status_Suffix;

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
end Terminal.App.Render_Model;

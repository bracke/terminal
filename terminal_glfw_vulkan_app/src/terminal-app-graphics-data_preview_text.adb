separate (Terminal.App.Graphics)
function Data_Preview_Text
  (Protocol : Terminal.Core.Graphics_Protocol_Kind;
   Text     : String) return Graphics_Data_Preview
is
   H    : constant Graphics_Header := Header_Text (Protocol, Text);
   From : Natural;
   Result : Graphics_Data_Preview :=
     (Ada.Finalization.Limited_Controlled with
      Header_Recognized => H.Recognized,
      Has_Data          => H.Has_Data,
      Raw_Format        => H.Raw_Format,
      Pixel_Width       => H.Pixel_Width,
      Pixel_Height      => H.Pixel_Height,
      others            => <>);
begin
   if not H.Recognized or else not H.Has_Data or else Text = "" then
      return Take (Result);
   end if;

   From := Data_First (Protocol, Text);
   if From = 0 then
      Result.Has_Data := False;
      return Take (Result);
   end if;

   Result.Encoded_Length := Text'Last - From + 1;

   case Protocol is
      when Terminal.Core.Kitty_Graphics =>
         declare
            Bytes_Per_Pixel : constant Natural :=
              Terminal.App.Graphics.Pixel_Layout.Raw_Bytes_Per_Pixel
                (H.Kitty_Format);
            Has_Raw_Metadata : constant Boolean :=
              Bytes_Per_Pixel > 0
              and then H.Pixel_Width > 0
              and then H.Pixel_Height > 0;
            Expected_Decoded_Length : constant Natural :=
              Terminal.App.Graphics.Pixel_Layout.Raw_Decoded_Length
                (H.Kitty_Format, H.Pixel_Width, H.Pixel_Height);
         begin
            if H.Kitty_Compression /= ASCII.NUL then
               --  The renderer uses the bounded streaming zlib row paths.
               --  Do not interpret compressed bytes as raw preview pixels.
               Result.Decode_Status :=
                 (if H.Kitty_Compression = 'z'
                  then Decode_Not_Attempted
                  else Decode_Unsupported_Format);
               Result.Decode_Complete := False;
               return Take (Result);
            elsif Has_Raw_Metadata and then Expected_Decoded_Length = 0 then
               Result.Decode_Status := Decode_Preview_Truncated;
               Result.Decode_Complete := False;
               return Take (Result);
            else
               Terminal.App.Graphics.Decoding.Decode_Base64_Preview
                 (Text (From .. Text'Last),
                  Result,
                  (if Has_Raw_Metadata then Expected_Decoded_Length else 0));
            end if;
         end;
         if H.Kitty_Format = 100
           and then Result.Decode_Complete
           and then Has_Bytes (Result)
         then
            declare
               PNG : Image_Data_Holder;
               PNG_Length : constant Natural := Result.Decoded_Length;
            begin
               Preview_Storage.Extract_Bytes (Result, PNG);
               Result.Decoded_Length := 0;
               Result.Decoded_Row_Stride_Bytes := 0;
               Result.Raw_Format := 0;
               Result.Pixel_Width := 0;
               Result.Pixel_Height := 0;
               --  Kitty f=100 is specifically PNG.  JPEG remains valid
               --  for the iTerm2 File protocol, but accepting it here
               --  would advertise a non-standard Kitty extension.
               declare
                  procedure Decode (Bytes : Terminal.Common.Bytes.Byte_Array) is
                  begin
                     Terminal.App.Graphics.Media_Decoders.Decode_PNG_RGBA_Data
                       (Bytes, PNG_Length, Result);
                  end Decode;
               begin
                  PNG.Read (Decode'Access);
               end;
            end;
         end if;
         if H.Kitty_Format in Kitty_JPEG_Format | Kitty_GIF_Format
           and then Result.Decode_Complete
           and then Has_Bytes (Result)
         then
            declare
               Encoded : Image_Data_Holder;
               Length  : constant Natural := Result.Decoded_Length;

               function Byte (Index : Positive) return Natural is
                 (if Index <= Length
                  then Natural
                    (Encoded.Element (Index))
                  else 256);

            begin
               Preview_Storage.Extract_Bytes (Result, Encoded);
               Result.Decoded_Length := 0;
               Result.Decoded_Row_Stride_Bytes := 0;
               Result.Raw_Format := 0;
               Result.Pixel_Width := 0;
               Result.Pixel_Height := 0;

               declare
                  --  The payload must be what its format code says: a JPEG
                  --  starts FF D8 FF, a GIF with GIF8.
                  Matches : constant Boolean :=
                    (if H.Kitty_Format = Kitty_JPEG_Format
                     then Byte (1) = 16#FF#
                       and then Byte (2) = 16#D8#
                       and then Byte (3) = 16#FF#
                     else Byte (1) = Character'Pos ('G')
                       and then Byte (2) = Character'Pos ('I')
                       and then Byte (3) = Character'Pos ('F')
                       and then Byte (4) = Character'Pos ('8'));
               begin
                  if Matches then
                     declare
                        procedure Decode
                          (Bytes : Terminal.Common.Bytes.Byte_Array) is
                        begin
                           Terminal.App.Graphics.Media_Decoders
                             .Decode_Image_RGBA_Data (Bytes, Length, Result);
                        end Decode;
                     begin
                        Encoded.Read (Decode'Access);
                     end;
                  else
                     Result.Decode_Status := Decode_Unsupported_Format;
                     Result.Decode_Complete := False;
                  end if;
               end;
            end;
         end if;
      when Terminal.Core.ITerm2_Graphics =>
         Terminal.App.Graphics.Decoding.Decode_Base64_Preview
           (Text (From .. Text'Last), Result);
         if Result.Decode_Complete and then Has_Bytes (Result) then
            declare
               PNG : Image_Data_Holder;
               PNG_Length : constant Natural := Result.Decoded_Length;
            begin
               Preview_Storage.Extract_Bytes (Result, PNG);
               Result.Decoded_Length := 0;
               Result.Decoded_Row_Stride_Bytes := 0;
               Result.Raw_Format := 0;
               Result.Pixel_Width := 0;
               Result.Pixel_Height := 0;
               declare
                  procedure Decode (Bytes : Terminal.Common.Bytes.Byte_Array) is
                  begin
                     Terminal.App.Graphics.Media_Decoders.Decode_Image_RGBA_Data
                       (Bytes, PNG_Length, Result);
                  end Decode;
               begin
                  PNG.Read (Decode'Access);
               end;
            end;
         end if;
      when Terminal.Core.Sixel_Graphics =>
         Terminal.App.Graphics.Media_Decoders.Decode_Sixel_Data
           (Text,
            Width => H.Pixel_Width,
            Height => H.Pixel_Height,
            Logical_Height => H.Pixel_Height,
            Vertical_Aspect => 1,
            Transparent => H.Sixel_Transparent,
            Result => Result);
      when Terminal.Core.No_Graphics =>
         null;
   end case;

   return Take (Result);
end Data_Preview_Text;

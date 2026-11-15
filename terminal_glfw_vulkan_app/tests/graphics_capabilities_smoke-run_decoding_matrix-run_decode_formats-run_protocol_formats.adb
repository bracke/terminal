separate (Graphics_Capabilities_Smoke.Run_Decoding_Matrix.Run_Decode_Formats)
procedure Run_Protocol_Formats is
   begin
      Graphics.Data_Preview (Kitty_Large_RGBA, Kitty_Large_RGBA_Data);
      Assert
        (Kitty_Large_RGBA_Data.Raw_Format = 32
         and then Kitty_Large_RGBA_Data.Pixel_Width = 33
         and then Kitty_Large_RGBA_Data.Pixel_Height = 32,
         "large kitty RGBA pixel metadata");
      Assert
        (Kitty_Large_RGBA_Data.Decoded_Length = 33 * 32 * 4,
         "large kitty RGBA decoded byte length");
      Assert
        (Graphics.Has_Bytes (Kitty_Large_RGBA_Data)
         and then Kitty_Large_RGBA_Data.Decoded_Length = 33 * 32 * 4,
         "large kitty RGBA decoded buffer should be exact length");
      Assert
        (Kitty_Large_RGBA_Data.Decode_Complete,
         "large kitty RGBA decode complete");
      Assert
        (Kitty_Large_RGBA_Data.Decode_Status = Graphics.Decode_Ok,
         "large kitty RGBA decode status");

      Graphics.Data_Preview (Kitty_Oversized_RGBA, Kitty_Oversized_RGBA_Data);
      Assert
        (Kitty_Oversized_RGBA_Data.Raw_Format = 32
         and then Kitty_Oversized_RGBA_Data.Pixel_Width = 16_385
         and then Kitty_Oversized_RGBA_Data.Pixel_Height = 1_024,
         "oversized kitty RGBA pixel metadata");
      Assert
        (Kitty_Oversized_RGBA_Data.Decoded_Length = 0
         and then not Graphics.Has_Bytes (Kitty_Oversized_RGBA_Data)
         and then not Kitty_Oversized_RGBA_Data.Decode_Complete
         and then Kitty_Oversized_RGBA_Data.Decode_Status =
           Graphics.Decode_Preview_Truncated,
         "oversized kitty RGBA decode should be rejected before allocation");

      Graphics.Data_Preview (Kitty_Partial, Kitty_Partial_Data);
      Assert
        (Kitty_Partial_Data.Decoded_Length = 0,
         "partial kitty decoded data preview length");
      Assert
        (not Kitty_Partial_Data.Decode_Complete,
         "partial kitty data preview decode should be incomplete");
      Assert
        (Kitty_Partial_Data.Decode_Status = Graphics.Decode_Invalid_Byte,
         "partial kitty data preview decode status");
      Assert
        (Graphics.Data_Status_Label (Kitty_Partial) =
         "kitty data preview decoded=0/4 partial invalid-byte",
         "partial kitty data status label");

      Graphics.Data_Preview (Kitty_Trailing, Kitty_Trailing_Data);
      Assert
        (Kitty_Trailing_Data.Decode_Status = Graphics.Decode_Trailing_Data,
         "trailing kitty data preview decode status");
      Assert
        (Graphics.Data_Status_Label (Kitty_Trailing) =
         "kitty data preview decoded=2/5 bytes=4869 partial trailing-data",
         "trailing kitty data status label");

      ITerm2_Header := Graphics.Header (ITerm2);
      Assert (ITerm2_Header.Recognized, "iTerm2 header recognized");
      Assert (ITerm2_Header.Has_Data, "iTerm2 header data marker");
      Assert (ITerm2_Header.ITerm2_Inline, "iTerm2 inline field");
      Assert (ITerm2_Header.ITerm2_Name_Length = 1, "iTerm2 name field length");
      Assert
        (ITerm2_Header.ITerm2_Width_Specified
         and then ITerm2_Header.ITerm2_Width_Valid
         and then ITerm2_Header.ITerm2_Width_Value = 12
         and then ITerm2_Header.ITerm2_Width_Unit = Graphics.ITerm2_Cells,
         "iTerm2 cell width parsed");
      Assert
        (ITerm2_Header.ITerm2_Height_Specified
         and then ITerm2_Header.ITerm2_Height_Valid
         and then ITerm2_Header.ITerm2_Height_Value = 5
         and then ITerm2_Header.ITerm2_Height_Unit = Graphics.ITerm2_Cells,
         "iTerm2 cell height parsed");
      Assert
        (Graphics.Placeholder_Cols (ITerm2) = 12,
         "iTerm2 numeric width placeholder cols");
      Assert
        (Graphics.Placeholder_Rows (ITerm2) = 5,
         "iTerm2 numeric height placeholder rows");
      declare
         Sized : constant Graphics.Graphics_Header := Graphics.Header_Text
           (Terminal.Core.ITerm2_Graphics,
            "File=inline=1;width=25%;height=40px;preserveAspectRatio=0;doNotMoveCursor=1:AAAA");
         Automatic : constant Graphics.Graphics_Header := Graphics.Header_Text
           (Terminal.Core.ITerm2_Graphics,
            "File=inline=1;width=auto;height=bad:AAAA");
         Invalid_Controls : constant Graphics.Graphics_Header :=
           Graphics.Header_Text
             (Terminal.Core.ITerm2_Graphics,
              "File=inline=2;size=bad;preserveAspectRatio=7;doNotMoveCursor=7:AAAA");
         Comma_Controls : constant Graphics.Graphics_Header :=
           Graphics.Header_Text
             (Terminal.Core.ITerm2_Graphics,
              "File=inline=1,width=12,height=5:AAAA");
         Duplicate_Controls : constant Graphics.Graphics_Header :=
           Graphics.Header_Text
             (Terminal.Core.ITerm2_Graphics,
              "File=inline=1;inline=0:AAAA");
         Malformed_Controls : constant Graphics.Graphics_Header :=
           Graphics.Header_Text
             (Terminal.Core.ITerm2_Graphics,
              "File=inline=1;broken:AAAA");
         Empty_Known_Control : constant Graphics.Graphics_Header :=
           Graphics.Header_Text
             (Terminal.Core.ITerm2_Graphics,
              "File=inline=:AAAA");
         Padded_Name : constant Graphics.Graphics_Header :=
           Graphics.Header_Text
             (Terminal.Core.ITerm2_Graphics,
              "File=name=cmVwb3J0LnR4dA==:AAAA");
      begin
         Assert
           (Sized.ITerm2_Width_Unit = Graphics.ITerm2_Percent
            and then Sized.ITerm2_Width_Value = 25
            and then Sized.ITerm2_Height_Unit = Graphics.ITerm2_Pixels
            and then Sized.ITerm2_Height_Value = 40
            and then not Sized.ITerm2_Preserve_Aspect_Ratio
            and then Sized.ITerm2_Do_Not_Move_Cursor,
            "iTerm2 percent/pixel sizing parsed");
         Assert
           (Automatic.ITerm2_Width_Unit = Graphics.ITerm2_Auto
            and then Automatic.ITerm2_Width_Valid
            and then not Automatic.ITerm2_Height_Valid,
            "iTerm2 auto and invalid sizing parsed");
         Assert
           (not Invalid_Controls.ITerm2_Control_Data_Valid
            and then not Invalid_Controls.ITerm2_Declared_Size_Valid,
            "iTerm2 enumerated controls and declared size are validated");
         Assert
           (Comma_Controls.ITerm2_Inline
            and then Comma_Controls.ITerm2_Width_Value = 12
            and then Comma_Controls.ITerm2_Height_Value = 5,
            "iTerm2 comma-separated controls use the shared parser");
         Assert
           (not Duplicate_Controls.ITerm2_Control_Data_Valid
            and then not Malformed_Controls.ITerm2_Control_Data_Valid
            and then not Empty_Known_Control.ITerm2_Control_Data_Valid,
            "iTerm2 duplicate and malformed controls are rejected");
         Assert
           (Padded_Name.ITerm2_Control_Data_Valid
            and then Padded_Name.ITerm2_Name_Length = 16,
            "iTerm2 Base64 name padding remains valid control data");
      end;
      Assert
        (Graphics.Header_Status_Label (ITerm2) =
         "iTerm2 header ready; inline=yes; name bytes=1",
         "iTerm2 header status label");
      Graphics.Data_Preview (ITerm2, ITerm2_Data);
      Assert
        (ITerm2_Data.Encoded_Length = 4,
         "iTerm2 encoded data preview length");
      Assert
        (ITerm2_Data.Decoded_Length = 0,
         "non-PNG iTerm2 decoded image length");
      Assert
        (not ITerm2_Data.Decode_Complete,
         "non-PNG iTerm2 data should not decode as an image");
      Assert
        (ITerm2_Data.Decode_Status = Graphics.Decode_Unsupported_Format,
         "non-PNG iTerm2 data decode status");
      Assert
        (Graphics.Data_Status_Label (ITerm2) =
         "iTerm2 data preview decoded=0/4 partial unsupported-format",
         "iTerm2 data status label");

      Graphics.Data_Preview (ITerm2_PNG, ITerm2_PNG_Data);
      Assert
        (ITerm2_PNG_Data.Raw_Format = 32
         and then ITerm2_PNG_Data.Pixel_Width = 1
         and then ITerm2_PNG_Data.Pixel_Height = 1,
         "iTerm2 PNG pixel metadata");
      Assert
        (ITerm2_PNG_Data.Decoded_Length = 4,
         "iTerm2 PNG decoded RGBA length");
      Assert
        (ITerm2_PNG_Data.Decode_Complete,
         "iTerm2 PNG decode complete");
      Assert
        (ITerm2_PNG_Data.Decode_Status = Graphics.Decode_Ok,
         "iTerm2 PNG decode status");
      Assert
        (ITerm2_PNG_Data.Byte_At (1) = 16#FF#
         and then ITerm2_PNG_Data.Byte_At (2) = 16#00#
         and then ITerm2_PNG_Data.Byte_At (3) = 16#00#
         and then ITerm2_PNG_Data.Byte_At (4) = 16#FF#,
         "iTerm2 PNG decoded RGBA bytes");
      Assert_Storage_Invariant (ITerm2_PNG_Data, "iTerm2 PNG");

      Graphics.Data_Preview (ITerm2_JPEG, ITerm2_JPEG_Data);
      Assert
        (ITerm2_JPEG_Data.Raw_Format = 32
         and then ITerm2_JPEG_Data.Pixel_Width = 1
         and then ITerm2_JPEG_Data.Pixel_Height = 1,
         "iTerm2 JPEG pixel metadata");
      Assert
        (ITerm2_JPEG_Data.Decoded_Length = 4
         and then ITerm2_JPEG_Data.Decode_Complete
         and then ITerm2_JPEG_Data.Decode_Status = Graphics.Decode_Ok,
         "iTerm2 JPEG decode complete");
      Assert
        (Graphics.Has_Bytes (ITerm2_JPEG_Data)
         and then ITerm2_JPEG_Data.Byte_At (4) = 16#FF#,
         "iTerm2 JPEG decoded alpha");
      Assert_Storage_Invariant (ITerm2_JPEG_Data, "iTerm2 JPEG");

      Graphics.Data_Preview (ITerm2_Gray_PNG, ITerm2_Gray_PNG_Data);
      Assert
        (ITerm2_Gray_PNG_Data.Decoded_Length = 4
         and then ITerm2_Gray_PNG_Data.Decode_Complete,
         "iTerm2 grayscale PNG decode complete");
      Assert
        (ITerm2_Gray_PNG_Data.Byte_At (1) = 16#80#
         and then ITerm2_Gray_PNG_Data.Byte_At (2) = 16#80#
         and then ITerm2_Gray_PNG_Data.Byte_At (3) = 16#80#
         and then ITerm2_Gray_PNG_Data.Byte_At (4) = 16#FF#,
         "iTerm2 grayscale PNG decoded RGBA bytes");

      Graphics.Data_Preview (ITerm2_Palette_PNG, ITerm2_Palette_PNG_Data);
      Assert
        (ITerm2_Palette_PNG_Data.Decoded_Length = 4
         and then ITerm2_Palette_PNG_Data.Decode_Complete,
         "iTerm2 palette PNG decode complete");
      Assert
        (ITerm2_Palette_PNG_Data.Byte_At (1) = 16#11#
         and then ITerm2_Palette_PNG_Data.Byte_At (2) = 16#22#
         and then ITerm2_Palette_PNG_Data.Byte_At (3) = 16#33#
         and then ITerm2_Palette_PNG_Data.Byte_At (4) = 16#44#,
         "iTerm2 palette PNG decoded RGBA bytes");

      Graphics.Data_Preview (ITerm2_Gray1_PNG, ITerm2_Gray1_PNG_Data);
      Assert
        (ITerm2_Gray1_PNG_Data.Decoded_Length = 32
         and then ITerm2_Gray1_PNG_Data.Decode_Complete,
         "iTerm2 1-bit grayscale PNG decode complete");
      Assert
        (ITerm2_Gray1_PNG_Data.Byte_At (1) = 16#FF#
         and then ITerm2_Gray1_PNG_Data.Byte_At (5) = 16#00#,
         "iTerm2 1-bit grayscale PNG decoded RGBA bytes");

      Graphics.Data_Preview (ITerm2_Gray2_PNG, ITerm2_Gray2_PNG_Data);
      Assert
        (ITerm2_Gray2_PNG_Data.Decoded_Length = 16
         and then ITerm2_Gray2_PNG_Data.Decode_Complete,
         "iTerm2 2-bit grayscale PNG decode complete");
      Assert
        (ITerm2_Gray2_PNG_Data.Byte_At (1) = 16#00#
         and then ITerm2_Gray2_PNG_Data.Byte_At (5) = 16#55#
         and then ITerm2_Gray2_PNG_Data.Byte_At (9) = 16#AA#
         and then ITerm2_Gray2_PNG_Data.Byte_At (13) = 16#FF#,
         "iTerm2 2-bit grayscale PNG decoded RGBA bytes");

      Graphics.Data_Preview (ITerm2_Gray4_PNG, ITerm2_Gray4_PNG_Data);
      Assert
        (ITerm2_Gray4_PNG_Data.Decoded_Length = 8
         and then ITerm2_Gray4_PNG_Data.Decode_Complete,
         "iTerm2 4-bit grayscale PNG decode complete");
      Assert
        (ITerm2_Gray4_PNG_Data.Byte_At (1) = 16#FF#
         and then ITerm2_Gray4_PNG_Data.Byte_At (5) = 16#00#,
         "iTerm2 4-bit grayscale PNG decoded RGBA bytes");

      Graphics.Data_Preview (ITerm2_RGB16_PNG, ITerm2_RGB16_PNG_Data);
      Assert
        (ITerm2_RGB16_PNG_Data.Decoded_Length = 4
         and then ITerm2_RGB16_PNG_Data.Decode_Complete,
         "iTerm2 16-bit RGB PNG decode complete");
      Assert
        (ITerm2_RGB16_PNG_Data.Byte_At (1) = 16#FF#
         and then ITerm2_RGB16_PNG_Data.Byte_At (2) = 16#80#
         and then ITerm2_RGB16_PNG_Data.Byte_At (3) = 16#00#
         and then ITerm2_RGB16_PNG_Data.Byte_At (4) = 16#FF#,
         "iTerm2 16-bit RGB PNG decoded RGBA bytes");

      Graphics.Data_Preview (ITerm2_GA16_PNG, ITerm2_GA16_PNG_Data);
      Assert
        (ITerm2_GA16_PNG_Data.Decoded_Length = 4
         and then ITerm2_GA16_PNG_Data.Decode_Complete,
         "iTerm2 16-bit grayscale-alpha PNG decode complete");
      Assert
        (ITerm2_GA16_PNG_Data.Byte_At (1) = 16#80#
         and then ITerm2_GA16_PNG_Data.Byte_At (4) = 16#80#,
         "iTerm2 16-bit grayscale-alpha PNG decoded RGBA bytes");

      Graphics.Data_Preview (ITerm2_RGBA16_PNG, ITerm2_RGBA16_PNG_Data);
      Assert
        (ITerm2_RGBA16_PNG_Data.Decoded_Length = 4
         and then ITerm2_RGBA16_PNG_Data.Decode_Complete,
         "iTerm2 16-bit RGBA PNG decode complete");
      Assert
        (ITerm2_RGBA16_PNG_Data.Byte_At (1) = 16#FF#
         and then ITerm2_RGBA16_PNG_Data.Byte_At (2) = 16#00#
         and then ITerm2_RGBA16_PNG_Data.Byte_At (3) = 16#80#
         and then ITerm2_RGBA16_PNG_Data.Byte_At (4) = 16#80#,
         "iTerm2 16-bit RGBA PNG decoded RGBA bytes");

      Graphics.Data_Preview (ITerm2_Palette1_PNG, ITerm2_Palette1_PNG_Data);
      Assert
        (ITerm2_Palette1_PNG_Data.Decoded_Length = 8
         and then ITerm2_Palette1_PNG_Data.Decode_Complete,
         "iTerm2 1-bit palette PNG decode complete");
      Assert
        (ITerm2_Palette1_PNG_Data.Byte_At (1) = 16#11#
         and then ITerm2_Palette1_PNG_Data.Byte_At (2) = 16#22#
         and then ITerm2_Palette1_PNG_Data.Byte_At (3) = 16#33#
         and then ITerm2_Palette1_PNG_Data.Byte_At (4) = 16#44#
         and then ITerm2_Palette1_PNG_Data.Byte_At (5) = 16#00#
         and then ITerm2_Palette1_PNG_Data.Byte_At (8) = 16#FF#,
         "iTerm2 1-bit palette PNG decoded RGBA bytes");

      Graphics.Data_Preview (ITerm2_Adam7_PNG, ITerm2_Adam7_PNG_Data);
      Assert
        (ITerm2_Adam7_PNG_Data.Decoded_Length = 16
         and then ITerm2_Adam7_PNG_Data.Decode_Complete,
         "iTerm2 Adam7 PNG decode complete");
      Assert
        (ITerm2_Adam7_PNG_Data.Pixel_Width = 2
         and then ITerm2_Adam7_PNG_Data.Pixel_Height = 2,
         "iTerm2 Adam7 PNG pixel metadata");
      Assert
        (ITerm2_Adam7_PNG_Data.Byte_At (1) = 16#FF#
         and then ITerm2_Adam7_PNG_Data.Byte_At (5) = 16#00#
         and then ITerm2_Adam7_PNG_Data.Byte_At (6) = 16#FF#
         and then ITerm2_Adam7_PNG_Data.Byte_At (9) = 16#00#
         and then ITerm2_Adam7_PNG_Data.Byte_At (10) = 16#00#
         and then ITerm2_Adam7_PNG_Data.Byte_At (11) = 16#FF#
         and then ITerm2_Adam7_PNG_Data.Byte_At (13) = 16#FF#
         and then ITerm2_Adam7_PNG_Data.Byte_At (14) = 16#FF#
         and then ITerm2_Adam7_PNG_Data.Byte_At (15) = 16#FF#,
         "iTerm2 Adam7 PNG decoded RGBA bytes");

      Sized_Header := Graphics.Header (Kitty_Sized);
      Assert (Sized_Header.Kitty_Format = 100, "sized kitty format field");
      Assert
        (Graphics.Placeholder_Cols (Kitty_Sized) = 9,
         "kitty c field placeholder cols");
      Assert
        (Graphics.Placeholder_Rows (Kitty_Sized) = 4,
         "kitty r field placeholder rows");
      Graphics.Data_Preview (Sixel, Sixel_Data);
      Assert (Sixel_Data.Header_Recognized, "sixel data header recognized");
      Assert (Sixel_Data.Has_Data, "sixel raster data found");
      Assert (Sixel_Data.Encoded_Length = 4, "sixel raster data preview length");
      Assert (Sixel_Data.Decoded_Length = 96, "sixel raster decoded byte length");
      Assert
        (Graphics.Has_Bytes (Sixel_Data)
         and then Sixel_Data.Decoded_Length = 96,
         "sixel raster decoded buffer should be exact length");
      Assert (Sixel_Data.Decode_Complete, "sixel raster decode complete");
      Assert
        (Sixel_Data.Decode_Status = Graphics.Decode_Ok,
         "sixel raster decode status");
      Assert
        (Graphics.Header (Sixel).Pixel_Width = 4
         and then Graphics.Header (Sixel).Pixel_Height = 6
         and then Graphics.Header (Sixel).Raw_Format = 32,
         "sixel raster header pixel metadata");
      Assert
        (Graphics.Data_Status_Label (Sixel) =
         "sixel raster decoded=96/4 bytes=000000FF decoded",
         "sixel data status label");
   end Run_Protocol_Formats;

separate (Graphics_Capabilities_Smoke.Run_Decoding_Matrix.Run_Decode_Formats)
procedure Run_Streaming_Decoders is
   begin
      declare
         Transparent_Raster : Graphics.Graphics_Data_Preview :=
           Graphics.Data_Preview_Text
             (Terminal.Core.Sixel_Graphics,
              "1;1q""1;1;3;8#2;2;100;0;0~");
         Opaque_Raster : Graphics.Graphics_Data_Preview :=
           Graphics.Data_Preview_Text
             (Terminal.Core.Sixel_Graphics, "q""1;1;2;7?");
         HLS_Raster : Graphics.Graphics_Data_Preview :=
           Graphics.Data_Preview_Text
             (Terminal.Core.Sixel_Graphics, "q#5;1;120;50;100~");
         Aspect_Raster : Graphics.Graphics_Data_Preview :=
           Graphics.Data_Preview_Text
             (Terminal.Core.Sixel_Graphics, "q""2;1;1;6~");
         DCS_Aspect_Raster : Graphics.Graphics_Data_Preview :=
           Graphics.Data_Preview_Text
             (Terminal.Core.Sixel_Graphics, "5q~");
      begin
         Assert
           (Transparent_Raster.Decode_Complete
            and then Transparent_Raster.Pixel_Width = 3
            and then Transparent_Raster.Pixel_Height = 8
            and then Transparent_Raster.Decoded_Length = 96,
            "sixel raster attributes should declare a minimum canvas");
         Assert
           (Graphics.Has_Bytes (Transparent_Raster)
            and then Transparent_Raster.Byte_At (1) = 16#FF#
            and then Transparent_Raster.Byte_At (2) = 0
            and then Transparent_Raster.Byte_At (3) = 0
            and then Transparent_Raster.Byte_At (4) = 16#FF#
            and then Transparent_Raster.Byte_At (8) = 0,
            "sixel transparent background mode should preserve unset alpha");
         Assert
           (Opaque_Raster.Decode_Complete
            and then Opaque_Raster.Pixel_Width = 2
            and then Opaque_Raster.Pixel_Height = 7
            and then Graphics.Has_Bytes (Opaque_Raster)
            and then Opaque_Raster.Byte_At (4) = 16#FF#,
            "sixel default background mode should erase to register zero");
         Assert
           (HLS_Raster.Decode_Complete
            and then Graphics.Has_Bytes (HLS_Raster)
            and then HLS_Raster.Byte_At (1) = 16#FF#
            and then HLS_Raster.Byte_At (2) = 0
            and then HLS_Raster.Byte_At (3) = 0
            and then HLS_Raster.Byte_At (4) = 16#FF#,
            "sixel HLS palette definitions should use the DEC color wheel");
         Assert
           (Aspect_Raster.Decode_Complete
            and then Aspect_Raster.Pixel_Width = 1
            and then Aspect_Raster.Pixel_Height = 12
            and then Aspect_Raster.Decoded_Length = 48,
            "sixel Pan/Pad should apply the vertical pixel aspect ratio");
         Assert
           (DCS_Aspect_Raster.Decode_Complete
            and then DCS_Aspect_Raster.Pixel_Width = 1
            and then DCS_Aspect_Raster.Pixel_Height = 12
            and then DCS_Aspect_Raster.Decoded_Length = 48,
            "sixel DCS aspect selector should scale raster rows");
         Graphics.Release (Transparent_Raster);
         Graphics.Release (Aspect_Raster);
         Graphics.Release (DCS_Aspect_Raster);
         Graphics.Release (Opaque_Raster);
         Graphics.Release (HLS_Raster);
      end;

      Transport_Decoding.Decode_Base64_Raw_Rows
        ("/wAA/w==", 32, 1, 1, Capture_Raw_Row'Access, Raw_Row_Result);
      Assert
        (Raw_Row_Result.Raw_Format = 32
         and then Raw_Row_Result.Pixel_Width = 1
         and then Raw_Row_Result.Pixel_Height = 1
         and then Raw_Row_Result.Decoded_Row_Stride_Bytes = 4,
         "raw row decoder pixel metadata");
      Assert
        (Raw_Row_Result.Decoded_Length = 4
         and then Raw_Row_Result.Decode_Complete
         and then Raw_Row_Result.Decode_Status = Graphics.Decode_Ok,
         "raw row decoder completion");
      Assert
        (not Graphics.Has_Bytes (Raw_Row_Result),
         "raw row decoder should not allocate result image bytes");
      Assert
        (Raw_Row_Count = 1,
         "raw row decoder row count");
      Assert
        (Raw_Row_Bytes (1) = 16#FF#
         and then Raw_Row_Bytes (2) = 16#00#
         and then Raw_Row_Bytes (3) = 16#00#
         and then Raw_Row_Bytes (4) = 16#FF#,
         "raw row decoder RGBA bytes");

      Transport_Decoding.Decode_Base64_Raw_Chunk_Rows
        (2,
         Raw_Chunk_Text'Access,
         32,
         1,
         1,
         Capture_Raw_Chunk_Row'Access,
         Raw_Chunk_Row_Result);
      Assert
        (Raw_Chunk_Row_Result.Decoded_Length = 4
         and then Raw_Chunk_Row_Result.Decode_Complete
         and then Raw_Chunk_Row_Result.Decode_Status = Graphics.Decode_Ok,
         "chunked raw row decoder completion");
      Assert
        (Raw_Chunk_Row_Result.Encoded_Length = 8,
         "chunked raw row decoder encoded length");
      Assert
        (not Graphics.Has_Bytes (Raw_Chunk_Row_Result),
         "chunked raw row decoder should not allocate result image bytes");
      Assert
        (Raw_Chunk_Row_Count = 1,
         "chunked raw row decoder row count");
      Assert
        (Raw_Chunk_Row_Bytes (1) = 16#FF#
         and then Raw_Chunk_Row_Bytes (2) = 16#00#
         and then Raw_Chunk_Row_Bytes (3) = 16#00#
         and then Raw_Chunk_Row_Bytes (4) = 16#FF#,
         "chunked raw row decoder RGBA bytes");

      Transport_Decoding.Decode_Base64_Zlib_Raw_Chunk_Rows
        (2,
         Zlib_Raw_Chunk_Text'Access,
         32,
         1,
         1,
         Capture_Zlib_Raw_Row'Access,
         Zlib_Raw_Result);
      Assert
        (Zlib_Raw_Result.Encoded_Length = 16
         and then Zlib_Raw_Result.Decoded_Length = 4
         and then Zlib_Raw_Result.Decode_Complete
         and then Zlib_Raw_Result.Decode_Status = Graphics.Decode_Ok,
         "zlib raw row decoder completion");
      Assert
        (Zlib_Raw_Row_Count = 1
         and then Zlib_Raw_Row_Bytes (1) = 16#FF#
         and then Zlib_Raw_Row_Bytes (2) = 16#00#
         and then Zlib_Raw_Row_Bytes (3) = 16#00#
         and then Zlib_Raw_Row_Bytes (4) = 16#FF#,
         "zlib raw row decoder bytes");

      Transport_Decoding.Decode_Base64_Zlib_Raw_Chunk_Rows
        (1,
         Zlib_Raw_Invalid_Text'Access,
         32,
         1,
         1,
         Capture_Zlib_Raw_Row'Access,
         Zlib_Raw_Invalid_Result);
      Assert
        (not Zlib_Raw_Invalid_Result.Decode_Complete
         and then Zlib_Raw_Invalid_Result.Decode_Status =
           Graphics.Decode_Invalid_Byte,
         "zlib raw decoder rejects invalid checksum");

      Transport_Decoding.Decode_Base64_Zlib_PNG_Chunk_Rows
        (2,
         Zlib_PNG_Chunk_Text'Access,
         69,
         Zlib_PNG_Encoded_Length,
         Capture_Zlib_PNG_Row'Access,
         Zlib_PNG_Result);
      Assert
        (Zlib_PNG_Encoded_Length = 96
         and then Zlib_PNG_Result.Decoded_Length = 4
         and then Zlib_PNG_Result.Decode_Complete
         and then Zlib_PNG_Result.Decode_Status = Graphics.Decode_Ok,
         "zlib PNG row decoder completion");
      Assert
        (Zlib_PNG_Row_Count = 1
         and then Zlib_PNG_Row_Bytes (1) = 16#FF#
         and then Zlib_PNG_Row_Bytes (2) = 16#00#
         and then Zlib_PNG_Row_Bytes (3) = 16#00#
         and then Zlib_PNG_Row_Bytes (4) = 16#FF#,
         "zlib PNG row decoder RGBA bytes");

      Zlib_PNG_Row_Count := 0;
      Zlib_PNG_Row_Bytes := (others => 0);
      Transport_Decoding.Decode_Base64_Zlib_PNG_Chunk_Rows
        (2,
         Zlib_PNG_Chunk_Text'Access,
         0,
         Zlib_PNG_Encoded_Length,
         Capture_Zlib_PNG_Row'Access,
         Zlib_PNG_Result);
      Assert
        (Zlib_PNG_Result.Decode_Complete
         and then Zlib_PNG_Result.Decode_Status = Graphics.Decode_Ok
         and then Zlib_PNG_Row_Count = 1
         and then Zlib_PNG_Row_Bytes (1) = 16#FF#,
         "bounded zlib PNG decoder discovers inflated length");

      Transport_Decoding.Decode_Base64_Chunk_Bytes
        (2,
         Base64_Chunk_Text'Access,
         Capture_Base64_Byte'Access,
         Base64_Byte_Result);
      Assert
        (Base64_Byte_Result.Encoded_Length = 4
         and then Base64_Byte_Result.Decoded_Length = 2
         and then Base64_Byte_Result.Decode_Complete
         and then Base64_Byte_Result.Decode_Status = Graphics.Decode_Ok,
         "chunked byte decoder completion");
      Assert
        (not Graphics.Has_Bytes (Base64_Byte_Result),
         "chunked byte decoder should not allocate result bytes");
      Assert
        (Base64_Byte_Count = 2
         and then Base64_Bytes (1) =
           Terminal.Common.Bytes.Byte (Character'Pos ('H'))
         and then Base64_Bytes (2) =
           Terminal.Common.Bytes.Byte (Character'Pos ('i')),
         "chunked byte decoder bytes");

      Transport_Decoding.Decode_Base64_Chunk_Bytes
        (1,
         Base64_Trailing_Text'Access,
         Count_Base64_Trailing_Byte'Access,
         Base64_Byte_Trailing_Result);
      Assert
        (Base64_Byte_Trailing_Result.Encoded_Length = 5
         and then Base64_Byte_Trailing_Result.Decoded_Length = 2
         and then not Base64_Byte_Trailing_Result.Decode_Complete
         and then Base64_Byte_Trailing_Result.Decode_Status =
           Graphics.Decode_Trailing_Data,
         "chunked byte decoder trailing status");
      Assert
        (Base64_Byte_Trailing_Count = 2,
         "chunked byte decoder trailing bytes before error");

      Transport_Decoding.Decode_Base64_Chunk_Bytes
        (1,
         Adam7_Base64_Text'Access,
         Capture_Adam7_PNG_Byte'Access,
         Adam7_Base64_Result);
      Assert
        (Adam7_Base64_Result.Decode_Complete
         and then Adam7_Base64_Result.Decode_Status = Graphics.Decode_Ok
         and then Adam7_PNG_Length > 0,
         "Adam7 PNG fixture base64 decode");
      Media_Decoding.Decode_PNG_RGBA_Rows
        (Adam7_PNG_Bytes,
         Adam7_PNG_Length,
         Capture_Adam7_Row'Access,
         Adam7_Row_Result);
      Assert
        (Adam7_Row_Result.Decoded_Length = 16
         and then Adam7_Row_Result.Decode_Complete
         and then Adam7_Row_Result.Decode_Status = Graphics.Decode_Ok,
         "Adam7 row decoder completion");
      Assert
        (not Graphics.Has_Bytes (Adam7_Row_Result),
         "Adam7 row decoder should not allocate result image bytes");
      Assert
        (Adam7_Row_Count = 2,
         "Adam7 row decoder row count");
      Assert
        (Adam7_First_Row (1) = 16#FF#
         and then Adam7_First_Row (5) = 16#00#
         and then Adam7_First_Row (6) = 16#FF#
         and then Adam7_Second_Row (1) = 16#00#
         and then Adam7_Second_Row (2) = 16#00#
         and then Adam7_Second_Row (3) = 16#FF#
         and then Adam7_Second_Row (5) = 16#FF#
         and then Adam7_Second_Row (6) = 16#FF#
         and then Adam7_Second_Row (7) = 16#FF#,
         "Adam7 row decoder RGBA bytes");
   end Run_Streaming_Decoders;

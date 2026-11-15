separate (Graphics_Capabilities_Smoke.Run_Decoding_Matrix.Run_Decode_Core)
procedure Run_Core_Group_2 is
begin
      declare
         Duplicate : constant Graphics.Graphics_Header :=
           Graphics.Header_Text
             (Terminal.Core.Kitty_Graphics,
              "Ga=t,i=1,i=2,f=32,s=1,v=1;/wAA/w==");
         Malformed : constant Graphics.Graphics_Header :=
           Graphics.Header_Text
             (Terminal.Core.Kitty_Graphics,
              "Ga=t,i=1,f=32,s=bad,v=1;/wAA/w==");
         Bad_Action_Shape : constant Graphics.Graphics_Header :=
           Graphics.Header_Text
             (Terminal.Core.Kitty_Graphics,
              "Ga=p,i=1;AAAA");
         Default_Format : constant Graphics.Graphics_Header :=
           Graphics.Header_Text
             (Terminal.Core.Kitty_Graphics,
              "Ga=t,s=1,v=1;/wAA/w==");
      begin
         Assert
           (not Duplicate.Kitty_Control_Data_Valid,
            "kitty duplicate controls are invalid");
         Assert
           (not Malformed.Kitty_Control_Data_Valid,
            "kitty malformed numeric controls are invalid");
         Assert
           (not Bad_Action_Shape.Kitty_Action_Controls_Valid,
            "kitty put action rejects transmitted payload data");
         Assert
           (Default_Format.Kitty_Format = 32
            and then Default_Format.Raw_Format = 32
            and then Default_Format.Kitty_Action_Controls_Valid,
            "kitty omitted format defaults to RGBA");
      end;
      Assert (Graphics.Placeholder_Cols (Kitty) = 6, "kitty parsed placeholder cols");
      Assert (Graphics.Placeholder_Rows (Kitty) = 3, "kitty parsed placeholder rows");
      Assert
        (not Kitty_Header.Kitty_Columns_Specified
         and then Kitty_Header.Kitty_Columns_Valid
         and then not Kitty_Header.Kitty_Rows_Specified
         and then Kitty_Header.Kitty_Rows_Valid,
         "kitty omitted placement span validity");
      declare
         Exact_Span : constant Graphics.Graphics_Header :=
           Graphics.Header_Text
             (Terminal.Core.Kitty_Graphics, "Ga=p,c=1000,r=2000");
         Invalid_Span : constant Graphics.Graphics_Header :=
           Graphics.Header_Text
             (Terminal.Core.Kitty_Graphics, "Ga=p,c=0,r=bad");
         Omitted_Span : constant Graphics.Graphics_Header :=
           Graphics.Header_Text
             (Terminal.Core.Kitty_Graphics, "Ga=p,i=1");
         Invalid_Geometry : constant Graphics.Graphics_Header :=
           Graphics.Header_Text
             (Terminal.Core.Kitty_Graphics, "Ga=p,x=bad,w=999999999999999999999");
      begin
         Assert
           (Exact_Span.Placeholder_Cols = 1000
            and then Exact_Span.Placeholder_Rows = 2000,
            "kitty placement spans are not silently clamped");
         Assert
           (Invalid_Span.Kitty_Columns_Specified
            and then not Invalid_Span.Kitty_Columns_Valid
            and then Invalid_Span.Kitty_Rows_Specified
            and then not Invalid_Span.Kitty_Rows_Valid,
            "kitty invalid placement spans remain distinguishable");
         Assert
           (not Omitted_Span.Kitty_Columns_Specified
            and then not Omitted_Span.Kitty_Rows_Specified,
            "kitty omitted placement spans remain distinguishable");
         Assert
           (not Invalid_Geometry.Kitty_Geometry_Controls_Valid,
            "kitty malformed and overflowing geometry fields are invalid");
      end;
      Assert
        (Graphics.Header_Status_Label (Kitty) =
         "kitty header ready; format=32; data previewed",
         "kitty header status label");
      Graphics.Data_Preview (Kitty, Kitty_Data);
      Assert (Kitty_Data.Header_Recognized, "kitty data header recognized");
      Assert (Kitty_Data.Has_Data, "kitty data found");
      Assert (Kitty_Data.Encoded_Length = 4, "kitty encoded data preview length");
      Assert (Kitty_Data.Decoded_Length = 2, "kitty decoded data preview length");
      Assert (Kitty_Data.Decode_Complete, "kitty data preview decode complete");
      Assert
        (Kitty_Data.Decode_Status = Graphics.Decode_Ok,
         "kitty data preview decode status");
      Assert
        (Kitty_Data.Byte_At (1) = Terminal.Common.Bytes.Byte (Character'Pos ('H'))
         and then Kitty_Data.Byte_At (2) =
           Terminal.Common.Bytes.Byte (Character'Pos ('i')),
         "kitty decoded data preview bytes");
      Assert
        (Graphics.Data_Status_Label (Kitty) =
         "kitty data preview decoded=2/4 bytes=4869 decoded",
         "kitty data status label");
      Assert_Storage_Invariant (Kitty_Data, "Kitty base64");

      Graphics.Data_Preview (Kitty_RGBA, Kitty_RGBA_Data);
      Assert
        (Kitty_RGBA_Data.Decoded_Length = 4,
         "padded kitty RGBA decoded data preview length");
      Assert
        (Graphics.Has_Bytes (Kitty_RGBA_Data)
         and then Kitty_RGBA_Data.Decoded_Length = 4,
         "padded kitty RGBA decoded buffer should be exact length");
      Assert
        (Kitty_RGBA_Data.Byte_At (1) = 16#FF#
         and then Kitty_RGBA_Data.Byte_At (2) = 16#00#
         and then Kitty_RGBA_Data.Byte_At (3) = 16#00#
         and then Kitty_RGBA_Data.Byte_At (4) = 16#FF#,
         "padded kitty RGBA decoded data preview bytes");
      Assert_Storage_Invariant (Kitty_RGBA_Data, "Kitty RGBA");

      Kitty_Chunk_Header := Graphics.Header (Kitty_Chunk);
      Assert
        (Kitty_Chunk_Header.Kitty_More
         and then Kitty_Chunk_Header.Kitty_More_Specified
         and then Kitty_Chunk_Header.Kitty_More_Valid,
         "kitty chunk continuation field");
      Assert
        (not Graphics.Header_Text
           (Terminal.Core.Kitty_Graphics, "Gm=2;AAAA").Kitty_More_Valid,
         "invalid kitty chunk continuation value");

      Graphics.Data_Preview (Kitty_PNG, Kitty_PNG_Data);
      Assert
        (Kitty_PNG_Data.Raw_Format = 32
         and then Kitty_PNG_Data.Pixel_Width = 1
         and then Kitty_PNG_Data.Pixel_Height = 1,
         "kitty PNG pixel metadata");
      Assert
        (Kitty_PNG_Data.Decoded_Length = 4,
         "kitty PNG decoded RGBA length");
      Assert
        (Graphics.Has_Bytes (Kitty_PNG_Data)
         and then Kitty_PNG_Data.Decoded_Length = 4,
         "kitty PNG decoded buffer should be exact length");
      Assert
        (Kitty_PNG_Data.Decode_Complete,
         "kitty PNG decode complete");
      Assert
        (Kitty_PNG_Data.Decode_Status = Graphics.Decode_Ok,
         "kitty PNG decode status");
      Assert
        (Kitty_PNG_Data.Byte_At (1) = 16#FF#
         and then Kitty_PNG_Data.Byte_At (2) = 16#00#
         and then Kitty_PNG_Data.Byte_At (3) = 16#00#
         and then Kitty_PNG_Data.Byte_At (4) = 16#FF#,
         "kitty PNG decoded RGBA bytes");
      Assert_Storage_Invariant (Kitty_PNG_Data, "Kitty PNG");

      Graphics.Data_Preview (Kitty_JPEG, Kitty_JPEG_Data);
      Assert
        (Kitty_JPEG_Data.Decoded_Length = 0
         and then not Kitty_JPEG_Data.Decode_Complete
         and then not Graphics.Has_Bytes (Kitty_JPEG_Data)
         and then Kitty_JPEG_Data.Decode_Status =
           Graphics.Decode_Unsupported_Format,
         "Kitty f=100 rejects non-PNG image data");
      Assert_Storage_Invariant (Kitty_JPEG_Data, "rejected Kitty f=100");

      Media_Decoding.Decode_PNG_RGBA_Rows
        (PNG_Row_Data,
         PNG_Row_Data'Length,
         Capture_PNG_Row'Access,
         PNG_Row_Result);
      Assert
        (PNG_Row_Result.Raw_Format = 32
         and then PNG_Row_Result.Pixel_Width = 1
         and then PNG_Row_Result.Pixel_Height = 1
         and then PNG_Row_Result.Decoded_Row_Stride_Bytes = 4,
         "PNG row decoder pixel metadata");
      Assert
        (PNG_Row_Result.Decoded_Length = 4
         and then PNG_Row_Result.Decode_Complete
         and then PNG_Row_Result.Decode_Status = Graphics.Decode_Ok,
         "PNG row decoder completion");
      Assert
        (not Graphics.Has_Bytes (PNG_Row_Result),
         "PNG row decoder should not allocate result image bytes");
      Assert
        (PNG_Row_Count = 1,
         "PNG row decoder row count");
      Assert
        (PNG_Row_Bytes (1) = 16#FF#
         and then PNG_Row_Bytes (2) = 16#00#
         and then PNG_Row_Bytes (3) = 16#00#
         and then PNG_Row_Bytes (4) = 16#FF#,
         "PNG row decoder RGBA bytes");end Run_Core_Group_2;

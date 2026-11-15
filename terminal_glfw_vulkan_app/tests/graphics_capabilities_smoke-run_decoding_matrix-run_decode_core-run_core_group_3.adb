with Interfaces;

separate (Graphics_Capabilities_Smoke.Run_Decoding_Matrix.Run_Decode_Core)
procedure Run_Core_Group_3 is
   use type Interfaces.Unsigned_32;

   function CRC32
     (Data : Terminal.Common.Bytes.Byte_Array;
      First, Last : Positive) return Interfaces.Unsigned_32
   is
      Value : Interfaces.Unsigned_32 := 16#FFFF_FFFF#;
   begin
      for I in First .. Last loop
         Value := Value xor Interfaces.Unsigned_32 (Data (I));
         for Bit in 1 .. 8 loop
            Value :=
              (if (Value and 1) /= 0
               then Interfaces.Shift_Right (Value, 1) xor 16#EDB8_8320#
               else Interfaces.Shift_Right (Value, 1));
         end loop;
      end loop;
      return Value xor 16#FFFF_FFFF#;
   end CRC32;
begin
      declare
         Rebased : Terminal.Common.Bytes.Byte_Array
           (17 .. 16 + PNG_Row_Data'Length) := PNG_Row_Data;
         Rebased_Result : Graphics.Graphics_Data_Preview;
      begin
         Media_Decoding.Decode_PNG_RGBA_Rows
           (Rebased,
            Rebased'Length,
            Capture_PNG_Row'Access,
            Rebased_Result);
         Assert
           (Rebased_Result.Decode_Complete
            and then Rebased_Result.Decode_Status = Graphics.Decode_Ok
            and then Rebased_Result.Pixel_Width = 1
            and then Rebased_Result.Pixel_Height = 1,
            "PNG row decoding accepts a non-one lower bound");
         Graphics.Release (Rebased_Result);
      end;

      declare
         Invalid_PNG : constant Terminal.Common.Bytes.Byte_Array :=
           (1 => 0);
      begin
         Media_Decoding.Decode_PNG_RGBA_Rows
           (Invalid_PNG,
            Invalid_PNG'Length,
            Capture_PNG_Row'Access,
            PNG_Row_Result);
         Assert
           (not Graphics.Has_Bytes (PNG_Row_Result)
            and then PNG_Row_Result.Raw_Format = 0
            and then PNG_Row_Result.Pixel_Width = 0
            and then PNG_Row_Result.Pixel_Height = 0
            and then PNG_Row_Result.Decoded_Row_Stride_Bytes = 0
            and then PNG_Row_Result.Decoded_Length = 0
            and then not PNG_Row_Result.Decode_Complete,
            "failed PNG reuse clears successful decode metadata");
         Media_Decoding.Decode_PNG_RGBA_Rows
           (Invalid_PNG,
            Invalid_PNG'Length + 1,
            Capture_PNG_Row'Access,
            PNG_Row_Result);
         Assert
           (PNG_Row_Result.Decode_Status = Graphics.Decode_Invalid_Data
            and then not PNG_Row_Result.Decode_Complete,
            "PNG row decoder owns its input-length validation");
      end;

      Media_Decoding.Decode_PNG_RGBA_Source_Rows
        (PNG_Row_Data'Length,
         PNG_Source_Byte'Access,
         Capture_PNG_Source_Row'Access,
         PNG_Source_Row_Result);
      Assert
        (PNG_Source_Row_Result.Raw_Format = 32
         and then PNG_Source_Row_Result.Pixel_Width = 1
         and then PNG_Source_Row_Result.Pixel_Height = 1
         and then PNG_Source_Row_Result.Decoded_Row_Stride_Bytes = 4,
         "PNG source row decoder pixel metadata");
      Assert
        (PNG_Source_Row_Result.Decoded_Length = 4
         and then PNG_Source_Row_Result.Decode_Complete
         and then PNG_Source_Row_Result.Decode_Status = Graphics.Decode_Ok,
         "PNG source row decoder completion");
      Assert
        (not Graphics.Has_Bytes (PNG_Source_Row_Result),
         "PNG source row decoder should not allocate result image bytes");
      Assert
        (PNG_Source_Row_Count = 1,
         "PNG source row decoder row count");
      Assert
        (PNG_Source_Row_Bytes (1) = 16#FF#
         and then PNG_Source_Row_Bytes (2) = 16#00#
         and then PNG_Source_Row_Bytes (3) = 16#00#
         and then PNG_Source_Row_Bytes (4) = 16#FF#,
         "PNG source row decoder RGBA bytes");

      PNG_Corrupt_CRC (55) := 16#01#;
      Media_Decoding.Decode_PNG_RGBA_Rows
        (PNG_Corrupt_CRC,
         PNG_Corrupt_CRC'Length,
         Capture_PNG_Row'Access,
         PNG_Corrupt_CRC_Result);
      Assert
        (not PNG_Corrupt_CRC_Result.Decode_Complete
         and then PNG_Corrupt_CRC_Result.Decode_Status =
           Graphics.Decode_Invalid_Byte,
         "PNG row decoder rejects a corrupt chunk CRC");

      PNG_Corrupt_Adler (53) := PNG_Corrupt_Adler (53) xor 1;
      declare
         CRC : constant Interfaces.Unsigned_32 :=
           CRC32 (PNG_Corrupt_Adler, 38, 53);
      begin
         PNG_Corrupt_Adler (54) := Terminal.Common.Bytes.Byte
           (Interfaces.Shift_Right (CRC, 24) and 16#FF#);
         PNG_Corrupt_Adler (55) := Terminal.Common.Bytes.Byte
           (Interfaces.Shift_Right (CRC, 16) and 16#FF#);
         PNG_Corrupt_Adler (56) := Terminal.Common.Bytes.Byte
           (Interfaces.Shift_Right (CRC, 8) and 16#FF#);
         PNG_Corrupt_Adler (57) := Terminal.Common.Bytes.Byte (CRC and 16#FF#);
      end;
      Media_Decoding.Decode_PNG_RGBA_Rows
        (PNG_Corrupt_Adler,
         PNG_Corrupt_Adler'Length,
         Capture_PNG_Row'Access,
         PNG_Corrupt_Adler_Result);
      Assert
        (not PNG_Corrupt_Adler_Result.Decode_Complete
         and then PNG_Corrupt_Adler_Result.Decode_Status =
           Graphics.Decode_Invalid_Byte,
         "PNG row decoder rejects a corrupt zlib Adler checksum");

      Media_Decoding.Decode_PNG_RGBA_Rows
        (PNG_Huge_Chunk,
         PNG_Huge_Chunk'Length,
         Capture_PNG_Row'Access,
         PNG_Huge_Chunk_Result);
      Assert
        (not PNG_Huge_Chunk_Result.Decode_Complete
         and then PNG_Huge_Chunk_Result.Decode_Status =
           Graphics.Decode_Invalid_Byte,
         "PNG row decoder rejects an overflowing chunk length");

      PNG_Trailing (PNG_Row_Data'Range) := PNG_Row_Data;
      PNG_Trailing (PNG_Trailing'Last) := 16#00#;
      Media_Decoding.Decode_PNG_RGBA_Rows
        (PNG_Trailing,
         PNG_Trailing'Length,
         Capture_PNG_Row'Access,
         PNG_Trailing_Result);
      Assert
        (not PNG_Trailing_Result.Decode_Complete
         and then PNG_Trailing_Result.Decode_Status =
           Graphics.Decode_Trailing_Data,
         "PNG row decoder rejects bytes after IEND");

      Transport_Decoding.Decode_Base64_PNG_Chunk_Rows
        (2,
         Base64_PNG_Text'Access,
         Base64_PNG_Encoded_Length,
         Base64_PNG_Length,
         Capture_Base64_PNG_Row'Access,
         Base64_PNG_Row_Result);
      Assert
        (Base64_PNG_Encoded_Length = 92
         and then Base64_PNG_Length = PNG_Row_Data'Length,
         "Base64 PNG row decoder byte counts");
      Assert
        (Base64_PNG_Row_Result.Decoded_Length = 4
         and then Base64_PNG_Row_Result.Decode_Complete
         and then Base64_PNG_Row_Result.Decode_Status = Graphics.Decode_Ok,
         "Base64 PNG row decoder completion");
      Assert
        (not Graphics.Has_Bytes (Base64_PNG_Row_Result),
         "Base64 PNG row decoder should not allocate result image bytes");
      Assert
        (Base64_PNG_Row_Count = 1,
         "Base64 PNG row decoder row count");
      Assert
        (Base64_PNG_Row_Bytes (1) = 16#FF#
         and then Base64_PNG_Row_Bytes (2) = 16#00#
         and then Base64_PNG_Row_Bytes (3) = 16#00#
         and then Base64_PNG_Row_Bytes (4) = 16#FF#,
         "Base64 PNG row decoder RGBA bytes");

      Transport_Decoding.Decode_Base64_PNG_Chunk_Rows
        (1,
         Base64_PNG_Invalid_Text'Access,
         Base64_PNG_Invalid_Encoded_Length,
         Base64_PNG_Invalid_Length,
         Capture_Base64_PNG_Row'Access,
         Base64_PNG_Invalid_Result);
      Assert
        (Base64_PNG_Invalid_Encoded_Length = 3
         and then Base64_PNG_Invalid_Length = 0
         and then not Base64_PNG_Invalid_Result.Decode_Complete
         and then Base64_PNG_Invalid_Result.Decode_Status =
           Graphics.Decode_Invalid_Byte,
         "invalid Base64 PNG row decoder status");

      Transport_Decoding.Decode_Base64_PNG_Chunk_Rows
        (1,
         Base64_PNG_Not_PNG_Text'Access,
         Base64_PNG_Not_PNG_Encoded_Length,
         Base64_PNG_Not_PNG_Length,
         Capture_Base64_PNG_Row'Access,
         Base64_PNG_Not_PNG_Result);
      Assert
        (Base64_PNG_Not_PNG_Encoded_Length = 4
         and then Base64_PNG_Not_PNG_Length = 2
         and then not Base64_PNG_Not_PNG_Result.Decode_Complete
         and then Base64_PNG_Not_PNG_Result.Decode_Status =
           Graphics.Decode_Unsupported_Format,
         "padded non-PNG Base64 row decoder status");

      Transport_Decoding.Decode_Base64_PNG_Chunk_Rows
        (1,
         Base64_PNG_Trailing_Text'Access,
         Base64_PNG_Trailing_Encoded_Length,
         Base64_PNG_Trailing_Length,
         Capture_Base64_PNG_Row'Access,
         Base64_PNG_Trailing_Result);
      Assert
        (Base64_PNG_Trailing_Encoded_Length = 5
         and then Base64_PNG_Trailing_Length = 2
         and then not Base64_PNG_Trailing_Result.Decode_Complete
         and then Base64_PNG_Trailing_Result.Decode_Status =
           Graphics.Decode_Trailing_Data,
         "trailing Base64 PNG row decoder status");

      Transport_Decoding.Decode_Base64_PNG_Chunk_Rows
        (2,
         Base64_PNG_Text'Access,
         Base64_PNG_Stop_Encoded_Length,
         Base64_PNG_Stop_Length,
         Reject_Base64_PNG_Row'Access,
         Base64_PNG_Stop_Result);
      Assert
        (Base64_PNG_Stop_Encoded_Length = 92
         and then Base64_PNG_Stop_Length = PNG_Row_Data'Length
         and then not Base64_PNG_Stop_Result.Decode_Complete
         and then Base64_PNG_Stop_Result.Decode_Status =
           Graphics.Decode_Invalid_Byte,
         "Base64 PNG row decoder sink stop status");

      Media_Decoding.Decode_Sixel_Rows
        ("q~", Capture_Sixel_Row'Access, Sixel_Row_Result);
      Assert
        (Sixel_Row_Result.Raw_Format = 32
         and then Sixel_Row_Result.Pixel_Width = 1
         and then Sixel_Row_Result.Pixel_Height = 6
         and then Sixel_Row_Result.Decoded_Row_Stride_Bytes = 4,
         "sixel row decoder pixel metadata");
      Assert
        (Sixel_Row_Result.Decoded_Length = 24
         and then Sixel_Row_Result.Decode_Complete
         and then Sixel_Row_Result.Decode_Status = Graphics.Decode_Ok,
         "sixel row decoder completion");
      Assert
        (not Graphics.Has_Bytes (Sixel_Row_Result),
         "sixel row decoder should not allocate result image bytes");
      Assert
        (Sixel_Row_Count = 6,
         "sixel row decoder row count");
      Assert
        (Sixel_First_Row (1) = 16#FF#
         and then Sixel_First_Row (2) = 16#FF#
         and then Sixel_First_Row (3) = 16#FF#
         and then Sixel_First_Row (4) = 16#FF#,
         "sixel row decoder first RGBA row");
end Run_Core_Group_3;

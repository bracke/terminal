separate (Vulkan_Submit_Smoke)
procedure Source_Cases is
begin
   Reset_Fixture;
   Configure_Raw_Image_Fixture;
   declare
      Overflow_Count : constant := VS.Max_Image_Atlas_Sources + 1;
      Overflow_Images : aliased RM.Image_Array :=
        [1 .. Overflow_Count => (others => <>)];
      type Source_Array is
        array (Positive range <>) of Terminal.App.Image_Data.Image_Data_Access;
      Sources : Source_Array (1 .. Overflow_Count) := (others => null);
      Overflow_Frame : RM.Frame_Commands := Frame;
      procedure Free_Source is new Ada.Unchecked_Deallocation
        (Terminal.Common.Bytes.Byte_Array, Terminal.App.Image_Data.Image_Data_Access);
   begin
      for I in Overflow_Images'Range loop
         Sources (I) :=
           new Terminal.Common.Bytes.Byte_Array'
             (1 => Terminal.Common.Bytes.Byte (I mod 256),
              2 => 0,
              3 => 0,
              4 => 16#FF#);
         Overflow_Images (I) := Images (1);
         Overflow_Images (I).Image_ID := Interfaces.Unsigned_32 (I);
         Overflow_Images (I).Decoded_Bytes := Terminal.App.Image_Data.Read_Only (Sources (I));
      end loop;
      Overflow_Frame.Images := Overflow_Images'Unchecked_Access;
      Overflow_Frame.Image_Count := Overflow_Count;
      VS.Set_Image_Atlas_Limits
        (Batch,
         (Bytes => VS.Min_Image_Atlas_Bytes,
          Dimension => VS.Min_Image_Atlas_Dimension));
      VS.Build (Overflow_Frame, Batch, Status);
      Assert
        (Status = VS.Ok
         and then VS.Image_Atlas_Source_Count (Batch) =
           VS.Max_Image_Atlas_Sources
         and then VS.Image_Texture_Vertex_Count (Batch) =
           VS.Max_Image_Atlas_Sources * 6,
         "atlas overflow retains the bounded texture set");
      Assert
        (VS.Last_Image_Texture_Downgraded (Batch),
         "only an atlas source beyond the bound is downgraded");
      VS.Release (Batch);
      VS.Set_Image_Atlas_Limits (Batch, VS.Default_Image_Atlas_Limits);
      for I in Sources'Range loop
         Free_Source (Sources (I));
      end loop;
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("atlas capacity", E);
   end;

   declare
   begin
      Images (1).Decoded_Source := RM.Image_Decoded_Source_Raw_Base64;
   Images (1).Decoded_Bytes := null;
   Images (1).Encoded_Source_Bytes := Raw_Base64_RGBA'Unchecked_Access;
   Images (1).Encoded_Source_Length := Raw_Base64_RGBA'Length;
   VS.Build (Frame, Batch, Status);
   Assert (Status = VS.Ok, "raw Base64 source image batch build failed");
   Assert
     (not VS.Last_Image_Placeholder (Batch),
      "raw Base64 source image should remain textured in submit");
   Assert
     (VS.Last_Image_Decoded_Source (Batch) =
      RM.Image_Decoded_Source_Raw_Base64,
      "raw Base64 source image should report encoded decoded source");
   Assert
     (VS.Last_Image_Decoded_Source_Available (Batch),
      "raw Base64 source image should expose rows");
   Assert
     (VS.Last_Image_Decoded_Row_Byte (Batch, 0, 0) = 16#FF#
      and then VS.Last_Image_Decoded_Row_Byte (Batch, 0, 3) = 16#FF#,
      "raw Base64 source image row bytes");
   VS.Release (Batch);

   Images (1).Decoded_Source := RM.Image_Decoded_Source_PNG_Base64;
   Images (1).Decoded_Bytes := null;
   Images (1).Encoded_Source_Bytes := Raw_Base64_RGBA'Unchecked_Access;
   Images (1).Encoded_Source_Length := Raw_Base64_RGBA'Length;
   VS.Build (Frame, Batch, Status);
   Assert (Status = VS.Ok, "PNG Base64 source image batch build failed");
   Assert
     (VS.Last_Image_Decoded_Source (Batch) =
      RM.Image_Decoded_Source_PNG_Base64,
      "PNG Base64 source image should report encoded decoded source");
   Assert
     (VS.Last_Image_Decoded_Source_Available (Batch),
      "PNG Base64 source image should expose deferred rows");
   VS.Release (Batch);

   Images (1).Protocol := RM.Image_Sixel;
   Images (1).Decoded_Source := RM.Image_Decoded_Source_Sixel_Text;
   Images (1).Decoded_Bytes := null;
   Images (1).Encoded_Source_Bytes := Raw_Base64_RGBA'Unchecked_Access;
   Images (1).Encoded_Source_Length := Raw_Base64_RGBA'Length;
   VS.Build (Frame, Batch, Status);
   Assert (Status = VS.Ok, "sixel text source image batch build failed");
   Assert
     (VS.Last_Image_Decoded_Source (Batch) =
      RM.Image_Decoded_Source_Sixel_Text,
      "sixel text source image should report encoded decoded source");
   Assert
     (VS.Last_Image_Decoded_Source_Available (Batch),
      "sixel text source image should expose deferred rows");
   VS.Release (Batch);
   Images (1).Protocol := RM.Image_Kitty;

   Images (1).Decoded_Source := RM.Image_Decoded_Source_None;
   Images (1).Encoded_Source_Bytes := null;
   Images (1).Encoded_Source_Length := 0;
   Images (1).Decoded_Bytes := Red_RGBA'Unchecked_Access;
   VS.Build (Frame, Batch, Status);
   Assert (Status = VS.Ok, "missing source image batch build failed");
   Assert
     (VS.Last_Image_Texture_Downgraded (Batch),
      "image bytes without source kind should downgrade");
   Assert
     (VS.Last_Image_Texture_Source (Batch) = VS.Texture_None,
      "image bytes without source kind should not texture");
   Assert
     (VS.Last_Image_Decoded_Source (Batch) = RM.Image_Decoded_Source_None,
      "downgraded image should clear decoded source");
   Assert
     (not VS.Last_Image_Decoded_Source_Available (Batch),
      "image bytes without source kind should not expose rows");
   VS.Release (Batch);

   Images (1).Protocol := RM.Image_Kitty;
   Images (1).Placeholder := False;
   Images (1).Raw_Format := 32;
   Images (1).Pixel_Width := 2;
   Images (1).Pixel_Height := 2;
   Images (1).Payload_Length := 32;
   Images (1).Payload_Preview_Complete := True;
   Images (1).Encoded_Preview_Length := 24;
   Images (1).Decoded_Byte_Length := 20;
   Images (1).Decoded_Row_Stride_Bytes := 12;
   Images (1).Decoded_Source := RM.Image_Decoded_Source_Buffer;
   Images (1).Decoded_Bytes := Strided_RGBA'Unchecked_Access;
   Images (1).Decoded_Preview_Length := 8;
   Images (1).Decoded_Preview_Bytes := Strided_RGBA'Unchecked_Access;
   Images (1).Preview_Decode_Complete := True;
   Images (1).Decode_Status := RM.Image_Decode_Ok;
   VS.Build (Frame, Batch, Status);
   Assert (Status = VS.Ok, "strided image texture batch build failed");
   Assert
     (not VS.Last_Image_Texture_Downgraded (Batch),
      "strided image should not report submit downgrade");
   Assert
     (VS.Last_Image_Texture_Source (Batch) = VS.Texture_Image,
      "strided image should use image texture source");
   Assert
     (VS.Last_Image_Decoded_Row_Stride_Bytes (Batch) = 12,
      "strided image should carry decoded row stride");
   Assert
     (VS.Last_Image_Decoded_Data_Byte (Batch, 20) = 16#FF#,
      "strided image should expose full source row span");
   Assert
     (VS.Last_Image_Decoded_Source_Bytes (Batch) = 20,
      "strided image source byte extent");
   Assert
     (VS.Last_Image_Decoded_Source_Available (Batch),
      "strided image decoded source availability");
   Assert
     (VS.Last_Image_Decoded_Row_Byte (Batch, 0, 0) = 16#FF#
      and then VS.Last_Image_Decoded_Row_Byte (Batch, 0, 4) = 16#00#
      and then VS.Last_Image_Decoded_Row_Byte (Batch, 1, 0) = 16#00#
      and then VS.Last_Image_Decoded_Row_Byte (Batch, 1, 7) = 16#FF#,
      "strided image row byte access");
   Assert
     (VS.Last_Image_Decoded_Row_Byte (Batch, 2, 0) = 0
      and then VS.Last_Image_Decoded_Row_Byte (Batch, 1, 12) = 0,
      "strided image row byte bounds");
   VS.Release (Batch);
   Images (1).Decoded_Row_Stride_Bytes := 0;

   Images (1).Protocol := RM.Image_Sixel;
   Images (1).Placeholder := False;
   Images (1).Raw_Format := 32;
   Images (1).Pixel_Width := 1;
   Images (1).Pixel_Height := 1;
   Images (1).Payload_Length := 2;
   Images (1).Payload_Preview_Complete := True;
   Images (1).Encoded_Preview_Length := 1;
   Images (1).Decoded_Byte_Length := 4;
   Images (1).Decoded_Source := RM.Image_Decoded_Source_Buffer;
   Images (1).Decoded_Bytes := White_RGBA'Unchecked_Access;
   Images (1).Decoded_Preview_Length := 4;
   Images (1).Decoded_Preview_Bytes := White_RGBA'Unchecked_Access;
   Images (1).Preview_Decode_Complete := True;
   Images (1).Decode_Status := RM.Image_Decode_Ok;
   VS.Build (Frame, Batch, Status);
   Assert (Status = VS.Ok, "sixel image texture batch build failed");
   Assert
     (not VS.Last_Image_Placeholder (Batch),
      "sixel image should remain textured in submit");
   Assert
     (not VS.Last_Image_Texture_Downgraded (Batch),
      "sixel image should not report submit downgrade");
   Assert
     (VS.Last_Image_Texture_Source (Batch) = VS.Texture_Image,
      "sixel image should use image texture source");
   Assert
     (VS.Image_Texture_Vertex_Count (Batch) = 6,
      "sixel image texture vertex count");
   Assert
     (VST.Vertices (Batch) (13).Textured
      and then VST.Vertices (Batch) (13).Texture = VS.Texture_Image,
      "sixel image vertices should use image texture");
   Assert
     (VS.Image_Status_Label (Batch) =
      "submit image sixel size=30x16 pixels=1x1 format=32 payload=2 payload-complete preview=4/1 bytes=FFFFFFFF texture=image textured decoded",
      "sixel image status label");
   VS.Release (Batch);

   Images (1).Protocol := RM.Image_ITerm2;
   Images (1).Placeholder := False;
   Images (1).Raw_Format := 32;
   Images (1).Pixel_Width := 1;
   Images (1).Pixel_Height := 1;
   Images (1).Payload_Length := 108;
   Images (1).Payload_Preview_Complete := True;
   Images (1).Encoded_Preview_Length := 92;
   Images (1).Decoded_Byte_Length := 4;
   Images (1).Decoded_Source := RM.Image_Decoded_Source_Buffer;
   Images (1).Decoded_Bytes := Red_RGBA'Unchecked_Access;
   Images (1).Decoded_Preview_Length := 4;
   Images (1).Decoded_Preview_Bytes := Red_RGBA'Unchecked_Access;
   Images (1).Preview_Decode_Complete := True;
   Images (1).Decode_Status := RM.Image_Decode_Ok;
   VS.Build (Frame, Batch, Status);
   Assert (Status = VS.Ok, "iTerm2 PNG image texture batch build failed");
   Assert
     (not VS.Last_Image_Placeholder (Batch),
      "iTerm2 PNG image should remain textured in submit");
   Assert
     (not VS.Last_Image_Texture_Downgraded (Batch),
      "iTerm2 PNG image should not report submit downgrade");
   Assert
     (VS.Last_Image_Texture_Source (Batch) = VS.Texture_Image,
      "iTerm2 PNG image should use image texture source");
   Assert
     (VS.Image_Texture_Vertex_Count (Batch) = 6,
      "iTerm2 PNG image texture vertex count");
   VS.Release (Batch);

   Images (1).Protocol := RM.Image_Kitty;
   Images (1).Placeholder := False;
   Images (1).Raw_Format := 32;
   Images (1).Pixel_Width := 65;
   Images (1).Pixel_Height := 64;
   Images (1).Payload_Length := 5_632;
   Images (1).Payload_Preview_Complete := True;
   Images (1).Encoded_Preview_Length := 5_632;
   Images (1).Decoded_Byte_Length := 65 * 64 * 4;
   Images (1).Decoded_Source := RM.Image_Decoded_Source_Buffer;
   Images (1).Decoded_Bytes := Terminal.App.Image_Data.Read_Only (Large_RGBA);
   Images (1).Decoded_Preview_Length := RM.Max_Image_Decoded_Preview_Length;
   Images (1).Decoded_Preview_Bytes := Terminal.App.Image_Data.Read_Only (Large_RGBA);
   Images (1).Preview_Decode_Complete := True;
   Images (1).Decode_Status := RM.Image_Decode_Ok;
   VS.Set_Image_Atlas_Limits
     (Batch,
      (Bytes => VS.Min_Image_Atlas_Bytes,
       Dimension => VS.Min_Image_Atlas_Dimension));
   VS.Build (Frame, Batch, Status);
   Assert (Status = VS.Ok, "large image texture batch build failed");
   Assert
     (not VS.Last_Image_Placeholder (Batch),
      "large image should remain textured with capped diagnostics preview");
   Assert
     (VS.Last_Image_Texture_Source (Batch) = VS.Texture_Image,
      "large image should use image texture source");
   Assert
     (VS.Last_Image_Decoded_Preview_Length (Batch) =
      RM.Max_Image_Decoded_Preview_Length,
      "large image should keep capped decoded diagnostics preview");
   Assert
     (VS.Last_Image_Decoded_Data_Byte (Batch, 65 * 64 * 4) = 16#7F#,
      "large image should expose decoded bytes through row source");
   Assert
     (VS.Image_Texture_Vertex_Count (Batch) = 6,
      "large image texture vertex count");
   Assert
     (VST.Owned_Image_Source_Bytes (Batch) = 65 * 64 * 4,
      "aliased decoded and preview views are retained only once");
   Assert
     (VS.Image_Atlas_Source_Width (Batch, 1) = 33
      and then VS.Image_Atlas_Source_Height (Batch, 1) = 32
      and then VS.Image_Atlas_Bytes (Batch) <= VS.Min_Image_Atlas_Bytes,
      "oversized image is reduced to fit without losing its texture");
   VS.Invalidate (Batch);
   Assert
     (VS.Vertex_Count (Batch) = 0
      and then VS.Image_Atlas_Source_Count (Batch) = 0
      and then VS.Width (Batch) = 0,
      "invalidation removes all frame-specific borrowed state");
   VS.Release (Batch);
   VS.Set_Image_Atlas_Limits (Batch, VS.Default_Image_Atlas_Limits);
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise
           ("encoded, strided, and large sources", E);
   end;

end Source_Cases;

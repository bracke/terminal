separate (Vulkan_Submit_Smoke)
procedure Multi_Image_Cases is
begin
   Reset_Fixture;
   Configure_Raw_Image_Fixture;
   declare
      Multi_Images : aliased RM.Image_Array :=
        [1 => Images (1), 2 => Images (1), 3 => Images (1)];
      Multi_Frame : RM.Frame_Commands := Frame;
      Active_Source : Positive := 1;
      Captured_R : Terminal.Common.Bytes.Byte_Array (1 .. 2) := (others => 0);
      Captured_B : Terminal.Common.Bytes.Byte_Array (1 .. 2) := (others => 0);
      Read_Status : VS.Image_Source_Read_Status;

      procedure Capture_Row
        (Y        : Natural;
         Row      : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean) is
      begin
         if Y = 0 and then Row'Length >= 3 then
            Captured_R (Active_Source) := Row (Row'First);
            Captured_B (Active_Source) := Row (Row'First + 2);
         end if;
         Continue := True;
      end Capture_Row;
   begin
      Multi_Images (1).Decoded_Bytes := Red_RGBA'Unchecked_Access;
      Multi_Images (1).Image_ID := 2;
      Multi_Images (1).X := 0.0;
      Multi_Images (2).Decoded_Bytes := Blue_RGBA'Unchecked_Access;
      Multi_Images (2).Image_ID := 1;
      Multi_Images (2).X := 10.0;
      Multi_Images (3).Decoded_Bytes := Red_RGBA'Unchecked_Access;
      Multi_Images (3).Image_ID := 2;
      Multi_Images (3).X := 20.0;
      Multi_Frame.Images := Multi_Images'Unchecked_Access;
      Multi_Frame.Image_Count := Multi_Images'Length;

      VS.Build (Multi_Frame, Batch, Status);
      Assert (Status = VS.Ok, "multi-image atlas batch build failed");
      Red_RGBA (Red_RGBA'First) := 0;
      Assert
        (VS.Image_Atlas_Source_Count (Batch) = 2,
         "atlas should deduplicate repeated image storage");
      Assert
        (VS.Image_Atlas_Width (Batch) = 3
         and then VS.Image_Atlas_Height (Batch) = 6
         and then VS.Image_Atlas_Bytes (Batch) = 72,
         "two one-pixel images should have isolated padded atlas slots");
      for Source_Index in 1 .. 2 loop
         Active_Source := Source_Index;
         VS.Read_Image_Atlas_Source_Rows
           (Batch, Source_Index, Capture_Row'Access, Read_Status);
         Assert
           (Read_Status = VS.Image_Source_Ok,
            "atlas source rows should remain readable during batch lifetime");
      end loop;
      Assert
        (Captured_R (1) = 16#FF# and then Captured_B (1) = 0
         and then Captured_R (2) = 0 and then Captured_B (2) = 16#FF#,
         "atlas rows are owned and preserve both distinct image sources");
      Red_RGBA (Red_RGBA'First) := 16#FF#;
      Assert
        (Near (VST.Vertices (Batch) (13).U, 1.0 / 3.0)
         and then Near (VST.Vertices (Batch) (13).V, 4.0 / 6.0)
         and then Near (VST.Vertices (Batch) (19).U, 1.0 / 3.0)
         and then Near (VST.Vertices (Batch) (19).V, 1.0 / 6.0)
         and then Near (VST.Vertices (Batch) (25).U, 1.0 / 3.0)
         and then Near (VST.Vertices (Batch) (25).V, 1.0 / 6.0),
         "equal-z images should sort by id and address their own atlas slots");
      Assert
        (VST.Vertices (Batch) (19).X < VST.Vertices (Batch) (25).X,
         "equal-z equal-id images should preserve source order");
      Assert
        (VS.Image_Texture_Vertex_Count (Batch) = 18,
         "all multi-image vertices should remain textured");
      declare
         First_Signature : constant Interfaces.Unsigned_64 :=
           VS.Image_Atlas_Signature (Batch);
      begin
         Assert (First_Signature /= 0, "cacheable atlas has a signature");
         VS.Release (Batch);
         VS.Build (Multi_Frame, Batch, Status);
         Assert
           (Status = VS.Ok
            and then VS.Image_Atlas_Signature (Batch) = First_Signature,
            "unchanged atlas sources retain a stable signature");
         VS.Release (Batch);
         Multi_Images (2).Encoded_Source_Length := 1;
         VS.Build (Multi_Frame, Batch, Status);
         Assert
           (Status = VS.Ok
            and then VS.Image_Atlas_Signature (Batch) /= First_Signature,
            "source layout metadata invalidates the atlas signature");
         VS.Release (Batch);
         Multi_Images (2).Encoded_Source_Length := 0;
         Multi_Images (2).Content_Serial := 2;
         VS.Build (Multi_Frame, Batch, Status);
         Assert
           (Status = VS.Ok
            and then VS.Image_Atlas_Signature (Batch) /= First_Signature,
            "pixel content generation invalidates the atlas signature");
         VS.Release (Batch);
         Multi_Images (2).Content_Serial := 0;
         VS.Build (Multi_Frame, Batch, Status);
         Assert
           (Status = VS.Ok
            and then VS.Image_Atlas_Signature (Batch) = 0,
            "sources without a content generation disable atlas reuse");
         Multi_Images (2).Content_Serial := 2;
      end;
      VS.Release (Batch);

      VS.Set_Image_Atlas_Limits
        (Batch,
         (Bytes => VS.Min_Image_Atlas_Bytes,
          Dimension => VS.Min_Image_Atlas_Dimension));
      Assert
        (VS.Image_Atlas_Limit (Batch) =
           (Bytes => VS.Min_Image_Atlas_Bytes,
            Dimension => VS.Min_Image_Atlas_Dimension),
         "configurable image atlas limits");
      VS.Build (Multi_Frame, Batch, Status);
      Assert
        (Status = VS.Ok
         and then VS.Image_Atlas_Source_Count (Batch) = 2
         and then VS.Image_Texture_Vertex_Count (Batch) = 18,
         "minimum GPU atlas limits retain all configured image objects");
      VS.Release (Batch);
      VS.Set_Image_Atlas_Limits
        (Batch, VS.Default_Image_Atlas_Limits);
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("multi-image atlas", E);
   end;

   declare
      Shared_Layout_Images : aliased RM.Image_Array :=
        [1 => Images (1), 2 => Images (1)];
      Shared_Layout_Frame : RM.Frame_Commands := Frame;
   begin
      for Image of Shared_Layout_Images loop
         Image.Placeholder := False;
         Image.Raw_Format := 32;
         Image.Payload_Preview_Complete := True;
         Image.Preview_Decode_Complete := True;
         Image.Decode_Status := RM.Image_Decode_Ok;
         Image.Decoded_Source := RM.Image_Decoded_Source_Buffer;
         Image.Decoded_Bytes := Strided_RGBA'Unchecked_Access;
         Image.Image_ID := 77;
         Image.Content_Serial := 91;
      end loop;
      Shared_Layout_Images (1).Pixel_Width := 2;
      Shared_Layout_Images (1).Pixel_Height := 2;
      Shared_Layout_Images (1).Decoded_Row_Stride_Bytes := 12;
      Shared_Layout_Images (1).Decoded_Byte_Length := 20;
      Shared_Layout_Images (2).Pixel_Width := 1;
      Shared_Layout_Images (2).Pixel_Height := 1;
      Shared_Layout_Images (2).Decoded_Row_Stride_Bytes := 4;
      Shared_Layout_Images (2).Decoded_Byte_Length := 4;
      Shared_Layout_Frame.Images := Shared_Layout_Images'Unchecked_Access;
      Shared_Layout_Frame.Image_Count := Shared_Layout_Images'Length;

      VS.Build (Shared_Layout_Frame, Batch, Status);
      Assert
        (Status = VS.Ok and then VS.Image_Atlas_Source_Count (Batch) = 2,
         "shared storage with distinct layouts uses distinct atlas slots");
      VS.Release (Batch);
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("shared image layouts", E);
   end;

   declare
      Two_Rows : aliased Terminal.Common.Bytes.Byte_Array :=
        (1 => 16#FF#, 2 => 0, 3 => 0, 4 => 16#FF#,
         5 => 0, 6 => 0, 7 => 16#FF#, 8 => 16#FF#);
      Reentrant_Image : aliased RM.Image_Array := [1 => Images (1)];
      Reentrant_Frame : RM.Frame_Commands := Frame;
      Rows_Seen : Natural := 0;
      Read_Status : VS.Image_Source_Read_Status;

      procedure Release_During_First_Row
        (Y        : Natural;
         Row      : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean) is
         pragma Unreferenced (Row);
      begin
         Rows_Seen := Rows_Seen + 1;
         if Y = 0 then
            VS.Release (Batch);
         end if;
         Continue := True;
      end Release_During_First_Row;
   begin
      Reentrant_Image (1).Placeholder := False;
      Reentrant_Image (1).Raw_Format := 32;
      Reentrant_Image (1).Pixel_Width := 1;
      Reentrant_Image (1).Pixel_Height := 2;
      Reentrant_Image (1).Decoded_Byte_Length := Two_Rows'Length;
      Reentrant_Image (1).Decoded_Source := RM.Image_Decoded_Source_Buffer;
      Reentrant_Image (1).Decoded_Bytes := Two_Rows'Unchecked_Access;
      Reentrant_Frame.Images := Reentrant_Image'Unchecked_Access;
      Reentrant_Frame.Image_Count := 1;
      VS.Build (Reentrant_Frame, Batch, Status);
      Assert (Status = VS.Ok, "reentrant row-source batch build failed");
      VS.Read_Image_Atlas_Source_Rows
        (Batch, 1, Release_During_First_Row'Access, Read_Status);
      Assert
        (Read_Status = VS.Image_Source_Ok
         and then Rows_Seen = 2
         and then VS.Image_Atlas_Source_Count (Batch) = 0,
         "row iteration survives a callback that releases its source batch");
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("reentrant row reader", E);
   end;

end Multi_Image_Cases;

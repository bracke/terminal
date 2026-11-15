separate (Terminal.App.Vulkan_Submit)
procedure Append_Image_Command
  (Frame : RM.Frame_Commands;
   Batch : in out Submission_Batch;
   Image : RM.Image_Command)
is
   Before : constant Natural := Batch.Count;
   Bytes_Per_Pixel : constant Natural :=
     (if Image.Raw_Format = 24 then 3 elsif Image.Raw_Format = 32 then 4 else 0);
   Row_Bytes : constant Natural :=
     (if Bytes_Per_Pixel > 0
        and then Image.Pixel_Width <= Natural'Last / Bytes_Per_Pixel
      then Image.Pixel_Width * Bytes_Per_Pixel else 0);
   Row_Stride_Bytes : constant Natural :=
     (if Image.Decoded_Row_Stride_Bytes > 0
      then Image.Decoded_Row_Stride_Bytes else Row_Bytes);
   Atlas_Index : constant Natural := Atlas_Source_Index (Batch, Image);
   Eligible : constant Boolean := Texture_Eligible (Image) and then Atlas_Index > 0;
   Source : constant Texture_Source :=
     (if Eligible then Texture_Image else Texture_None);
   U0 : Float := Image.U0;
   V0 : Float := Image.V0;
   U1 : Float := Image.U1;
   V1 : Float := Image.V1;
begin
   if Eligible then
      U0 := (Float (Batch.Image_Atlas_Sources (Atlas_Index).X)
        + Image.U0 * Float (Batch.Image_Atlas_Sources (Atlas_Index).Width))
        / Float (Batch.Image_Atlas_W);
      U1 := (Float (Batch.Image_Atlas_Sources (Atlas_Index).X)
        + Image.U1 * Float (Batch.Image_Atlas_Sources (Atlas_Index).Width))
        / Float (Batch.Image_Atlas_W);
      V0 := (Float (Batch.Image_Atlas_Sources (Atlas_Index).Y)
        + Image.V0 * Float (Batch.Image_Atlas_Sources (Atlas_Index).Height))
        / Float (Batch.Image_Atlas_H);
      V1 := (Float (Batch.Image_Atlas_Sources (Atlas_Index).Y)
        + Image.V1 * Float (Batch.Image_Atlas_Sources (Atlas_Index).Height))
        / Float (Batch.Image_Atlas_H);
   end if;
   Batch.Image_Command_Total := Batch.Image_Command_Total + 1;
   Batch.Last_Image_Protocol := Image.Protocol;
   Batch.Last_Image_Width := Natural (Image.Width);
   Batch.Last_Image_Height := Natural (Image.Height);
   Batch.Last_Image_Raw_Format := Image.Raw_Format;
   Batch.Last_Image_Pixel_Width := Image.Pixel_Width;
   Batch.Last_Image_Pixel_Height := Image.Pixel_Height;
   Batch.Last_Image_Payload_Length := Image.Payload_Length;
   Batch.Last_Image_Payload_Preview_Complete := Image.Payload_Preview_Complete;
   Batch.Last_Image_Encoded_Preview_Length := Image.Encoded_Preview_Length;
   Batch.Last_Image_Decoded_Preview_Length := Image.Decoded_Preview_Length;
   Batch.Last_Image_Decoded_Source :=
     (if Eligible then Image.Decoded_Source else RM.Image_Decoded_Source_None);
   Batch.Last_Image_Row_Source :=
     (if Eligible
      then Batch.Image_Atlas_Sources (Atlas_Index).Command
      else Image);
   Batch.Last_Image_Decoded_Row_Stride_Bytes :=
     (if Eligible then Row_Stride_Bytes else 0);
   Batch.Last_Image_Preview_Decode_Complete := Image.Preview_Decode_Complete;
   Batch.Last_Image_Decode_Status := Image.Decode_Status;
   Batch.Last_Image_Placeholder := not Eligible;
   Batch.Last_Image_Texture_Downgraded :=
     not Image.Placeholder and then not Eligible;
   Batch.Last_Image_Texture_Source := Source;
   Append_Quad
     (Batch, Frame.Width, Frame.Height,
      Image.X, Image.Y, Image.Width, Image.Height,
      U0, V0, U1, V1, Image.Tint, Source = Texture_Image, Source);
   Batch.Image_Vertex_Total := Batch.Image_Vertex_Total + (Batch.Count - Before);
   if Batch.Last_Image_Texture_Source = Texture_Image then
      Batch.Image_Texture_Vertex_Total :=
        Batch.Image_Texture_Vertex_Total + (Batch.Count - Before);
   end if;
end Append_Image_Command;

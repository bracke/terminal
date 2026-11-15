separate (Graphics_Capabilities_Smoke.Run_Decoding_Matrix.Run_Decode_Core)
procedure Run_Core_Group_4 is
begin
      declare
         Oversized : Graphics.Graphics_Data_Preview;
      begin
         Sixel_Row_Count := 0;
         Media_Decoding.Decode_Sixel_Rows
           ("q""1;1;999999999;999999999~",
            Capture_Sixel_Row'Access,
            Oversized,
            Maximum_Decoded_Bytes => 1_024,
            Maximum_Pixel_Dimension => 1_024);
         Assert
           (not Oversized.Decode_Complete
            and then Oversized.Decode_Status =
              Graphics.Decode_Preview_Truncated
            and then Sixel_Row_Count = 0,
            "oversized sixel raster is rejected before band allocation");
      end;

end Run_Core_Group_4;

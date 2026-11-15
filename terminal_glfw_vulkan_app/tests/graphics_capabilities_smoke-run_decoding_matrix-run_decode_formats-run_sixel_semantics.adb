separate (Graphics_Capabilities_Smoke.Run_Decoding_Matrix.Run_Decode_Formats)
procedure Run_Sixel_Semantics is
   begin
      declare
         Palette : Graphics.Sixel_Palette_State :=
           Graphics.Default_Sixel_Palette;
         Shared_Result : Graphics.Graphics_Data_Preview;
      begin
         Sixel_Row_Count := 0;
         Sixel_First_Row := (others => 0);
         Media_Decoding.Decode_Sixel_Rows
           ("q#5;2;100;0;0~",
            Capture_Sixel_Row'Access,
            Palette,
            Reset_Palette => False,
            Result => Shared_Result);
         Media_Decoding.Decode_Sixel_Rows
           ("q#5~",
            Capture_Sixel_Row'Access,
            Palette,
            Reset_Palette => False,
            Result => Shared_Result);
         Assert
           (Shared_Result.Decode_Complete
            and then Sixel_First_Row (1) = 16#FF#
            and then Sixel_First_Row (2) = 0
            and then Sixel_First_Row (3) = 0,
            "sixel shared palette definitions persist across graphics");
         Media_Decoding.Decode_Sixel_Rows
           ("q#5~",
            Capture_Sixel_Row'Access,
            Palette,
            Reset_Palette => True,
            Result => Shared_Result);
         Assert
           (Sixel_First_Row (1) = 16#FF#
            and then Sixel_First_Row (2) = 16#FF#
            and then Sixel_First_Row (3) = 16#FF#,
            "sixel private palette resets for each graphic");
      end;
   end Run_Sixel_Semantics;

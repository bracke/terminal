separate (Terminal.App.Renderer)
procedure Add_Conventional_Images
  (R        : in out Renderer;
   Snapshot : Terminal.Core.Render_Snapshot)
is
   Placement : Conventional_Placement_Access := R.Conventional_Placements;
begin
   if Frame_Image_Commands (R) = null then
      return;
   end if;
   Prepare_Placement_Index (R, Snapshot);
   if R.Graphics_Event_Tracking_Failed then
      return;
   end if;

   while Placement /= null
     and then Frame_Image_Count (R) < Frame_Image_Capacity (R)
   loop
      declare
         Object : Image_Object_Access;
         Placement_Row : Integer := 0;
         Placement_Col : Integer := 0;
      begin
         Object := Terminal.App.Placeholder_Index.Find_Object
           (R.Placement_Index,
            Snapshot.Graphics_Stream,
            Placement.Image_Storage_Order);
         if Placement.Stream_ID = Snapshot.Graphics_Stream
           and then Placement.Alternate_Screen = Snapshot.Alternate_Screen
           and then Placement.Screen_Generation = Snapshot.Screen_Generation
           and then Object /= null
           and then Resolve_Conventional_Placement_Origin
             (R,
              Snapshot,
              Placement,
              Placement_Row,
              Placement_Col,
              Use_Index => True)
           and then Placement_Row <= Snapshot.Rows
           and then Placement_Col <= Snapshot.Cols
           and then
             Long_Long_Integer (Placement_Row)
               + Long_Long_Integer (Placement.Rows) - 1 >= 1
           and then
             Long_Long_Integer (Placement_Col)
               + Long_Long_Integer (Placement.Columns) - 1 >= 1
           and then Placement.Source_X < Object.Pixel_Width
           and then Placement.Source_Y < Object.Pixel_Height
         then
            declare
               Available_Width : constant Natural :=
                 Object.Pixel_Width - Placement.Source_X;
               Available_Height : constant Natural :=
                 Object.Pixel_Height - Placement.Source_Y;
               Source_Width : constant Natural :=
                 (if Placement.Source_Width = 0
                  then Available_Width
                  else Natural'Min
                    (Placement.Source_Width, Available_Width));
               Source_Height : constant Natural :=
                 (if Placement.Source_Height = 0
                  then Available_Height
                  else Natural'Min
                    (Placement.Source_Height, Available_Height));
               Frame_Bytes : constant RM.Image_Data_View :=
                 Display_Frame_Bytes (Object);
               Frame_Format : constant Natural :=
                 Display_Frame_Format (Object);
               Frame_Length : constant Natural :=
                 Display_Frame_Length (Object);
               Preview_Length : constant Natural :=
                 Natural'Min
                   (Frame_Length, RM.Max_Image_Decoded_Preview_Length);
               Frame_Stride : constant Natural :=
                 Display_Frame_Stride (Object);
               Raw_X : constant Long_Long_Integer :=
                 Long_Long_Integer (Origin_X (R))
                 + Long_Long_Integer (Placement.Cell_X)
                 + Long_Long_Integer (Placement.Draw_Offset_X)
                 + Long_Long_Integer (Placement_Col - 1)
                   * Long_Long_Integer (R.CW);
               Raw_Y : constant Long_Long_Integer :=
                 Long_Long_Integer (Origin_Y (R))
                 + Long_Long_Integer (Placement.Cell_Y)
                 + Long_Long_Integer (Placement.Draw_Offset_Y)
                 + Long_Long_Integer (Placement_Row - 1)
                   * Long_Long_Integer (R.CH);
               View_Left : constant Long_Long_Integer :=
                 Long_Long_Integer (Origin_X (R));
               View_Right : constant Long_Long_Integer :=
                 View_Left
                 + Long_Long_Integer (Snapshot.Cols)
                   * Long_Long_Integer (R.CW);
               View_Top : constant Long_Long_Integer :=
                 Long_Long_Integer (Origin_Y (R));
               View_Bottom : constant Long_Long_Integer :=
                 View_Top
                 + Long_Long_Integer (Snapshot.Rows)
                   * Long_Long_Integer (R.CH);
               Region_Top : constant Long_Long_Integer :=
                 (if Placement.Clip_Top = 0
                  then View_Top
                  else Long_Long_Integer (Origin_Y (R))
                    + Long_Long_Integer (Placement.Clip_Top - 1)
                      * Long_Long_Integer (R.CH));
               Region_Bottom : constant Long_Long_Integer :=
                 (if Placement.Clip_Bottom = 0
                  then View_Bottom
                  else Long_Long_Integer (Origin_Y (R))
                    + Long_Long_Integer (Placement.Clip_Bottom)
                      * Long_Long_Integer (R.CH));
               Clip_X0 : constant Long_Long_Integer :=
                 Long_Long_Integer'Max (Raw_X, View_Left);
               Clip_Y0 : constant Long_Long_Integer :=
                 Long_Long_Integer'Max
                   (Raw_Y, Long_Long_Integer'Max (View_Top, Region_Top));
               Clip_X1 : constant Long_Long_Integer :=
                 Long_Long_Integer'Min
                   (Raw_X + Long_Long_Integer (Placement.Draw_Width),
                    View_Right);
               Clip_Y1 : constant Long_Long_Integer :=
                 Long_Long_Integer'Min
                   (Raw_Y + Long_Long_Integer (Placement.Draw_Height),
                    Long_Long_Integer'Min (View_Bottom, Region_Bottom));
               Base_U0 : constant Float := Float (Placement.Source_X)
                 / Float (Object.Pixel_Width);
               Base_V0 : constant Float := Float (Placement.Source_Y)
                 / Float (Object.Pixel_Height);
               U_Span : constant Float := Float (Source_Width)
                 / Float (Object.Pixel_Width);
               V_Span : constant Float := Float (Source_Height)
                 / Float (Object.Pixel_Height);
            begin
               if Frame_Bytes /= null
                 and then Clip_X0 < Clip_X1
                 and then Clip_Y0 < Clip_Y1
               then
                  Append_Image_Command
                    (R,
                    (X => Float (Clip_X0),
                  Y => Float (Clip_Y0),
                  Width => Float (Clip_X1 - Clip_X0),
                  Height => Float (Clip_Y1 - Clip_Y0),
                  Protocol => Object.Protocol,
                  Placeholder => False,
                  Raw_Format => Frame_Format,
                  Pixel_Width => Object.Pixel_Width,
                  Pixel_Height => Object.Pixel_Height,
                  Payload_Length => 0,
                  Staging_Byte_Length => 0,
                  Payload_Preview_Complete => True,
                  Encoded_Preview_Length => 0,
                  Decoded_Byte_Length => Frame_Length,
                  Decoded_Row_Stride_Bytes =>
                    Frame_Stride,
                  Decoded_Source => RM.Image_Decoded_Source_Buffer,
                  Decoded_Bytes => Frame_Bytes,
                  Encoded_Source_Bytes => null,
                  Encoded_Source_Length => 0,
                  Decoded_Preview_Length => Preview_Length,
                  Decoded_Preview_Bytes => Frame_Bytes,
                  Preview_Decode_Complete => True,
                  Decode_Status => RM.Image_Decode_Ok,
                  U0 => Base_U0
                    + U_Span
                      * Float (Clip_X0 - Raw_X)
                      / Float (Placement.Draw_Width),
                  V0 => Base_V0
                    + V_Span
                      * Float (Clip_Y0 - Raw_Y)
                      / Float (Placement.Draw_Height),
                  U1 => Base_U0
                    + U_Span
                      * Float (Clip_X1 - Raw_X)
                      / Float (Placement.Draw_Width),
                  V1 => Base_V0
                    + V_Span
                      * Float (Clip_Y1 - Raw_Y)
                      / Float (Placement.Draw_Height),
                  Image_ID => Interfaces.Unsigned_32 (Placement.Image_ID),
                  Content_Serial => Object.Content_Serial,
                  Z_Index => Placement.Z_Index,
                  Tint => (R => 1.0, G => 1.0, B => 1.0, A => 1.0)));
               end if;
            end;
         end if;
      end;
      Placement := Placement.Next;
   end loop;
   if Placement /= null then
      R.Frame_Command_Overflowed := True;
   end if;
end Add_Conventional_Images;

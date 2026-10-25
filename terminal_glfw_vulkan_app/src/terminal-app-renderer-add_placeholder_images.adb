separate (Terminal.App.Renderer)
procedure Add_Placeholder_Images
  (R        : in out Renderer;
   Snapshot : Terminal.Core.Render_Snapshot)
is
begin
   if Frame_Image_Commands (R) = null
     or else Snapshot.Image_Cell_Count = 0
   then
      return;
   end if;

   for Row in 1 .. Snapshot.Rows loop
      for Col in 1 .. Snapshot.Cols loop
         declare
            Cell : constant Terminal.Core.Cell :=
              Terminal.Core.Cell_At (Snapshot, Row, Col);
         begin
            if Cell.Image.Is_Placeholder
              and then Cell.Image.Image_ID_Valid
              and then Frame_Image_Count (R) >= Frame_Image_Capacity (R)
            then
               R.Frame_Command_Overflowed := True;
            elsif Cell.Image.Is_Placeholder
              and then Cell.Image.Image_ID_Valid
            then
               declare
                  Image_ID : constant Terminal.Core.Graphics_ID :=
                    Cell.Image.Image_ID;
                  Placement_ID : constant Terminal.Core.Graphics_ID :=
                    Cell.Image.Placement_ID;
                  Placement : Virtual_Placement_Access;
                  Object : Image_Object_Access;
               begin
                  Placement := Terminal.App.Placeholder_Index.Find_Placement
                    (R.Placement_Index,
                     Snapshot.Graphics_Stream,
                     Snapshot.Alternate_Screen,
                     Snapshot.Screen_Generation,
                     Image_ID,
                     Placement_ID);

                  if Placement = null then
                     Object := null;
                  else
                     Object := Terminal.App.Placeholder_Index.Find_Object
                       (R.Placement_Index,
                        Snapshot.Graphics_Stream,
                        Placement.Image_Storage_Order);
                  end if;
                  if Placement /= null
                    and then Object /= null
                    and then Cell.Image.Image_Column < Placement.Columns
                    and then Cell.Image.Image_Row < Placement.Rows
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
                        Column : constant Natural := Cell.Image.Image_Column;
                        Image_Row : constant Natural := Cell.Image.Image_Row;
                        Cell_Left : constant Float :=
                          Float (Column) * Float (R.CW);
                        Cell_Top : constant Float :=
                          Float (Image_Row) * Float (R.CH);
                        Cell_Right : constant Float :=
                          Cell_Left + Float (R.CW);
                        Cell_Bottom : constant Float :=
                          Cell_Top + Float (R.CH);
                        Draw_Left : constant Float :=
                          Float
                            (Placement.Cell_X + Placement.Draw_Offset_X);
                        Draw_Top : constant Float :=
                          Float
                            (Placement.Cell_Y + Placement.Draw_Offset_Y);
                        Draw_Right : constant Float :=
                          Draw_Left + Float (Placement.Draw_Width);
                        Draw_Bottom : constant Float :=
                          Draw_Top + Float (Placement.Draw_Height);
                        Clip_Left : constant Float :=
                          Float'Max (Cell_Left, Draw_Left);
                        Clip_Top : constant Float :=
                          Float'Max (Cell_Top, Draw_Top);
                        Clip_Right : constant Float :=
                          Float'Min (Cell_Right, Draw_Right);
                        Clip_Bottom : constant Float :=
                          Float'Min (Cell_Bottom, Draw_Bottom);
                        U0 : constant Float :=
                          (Float (Placement.Source_X)
                           + (Clip_Left - Draw_Left)
                             * Float (Source_Width)
                             / Float (Placement.Draw_Width))
                          / Float (Object.Pixel_Width);
                        V0 : constant Float :=
                          (Float (Placement.Source_Y)
                           + (Clip_Top - Draw_Top)
                             * Float (Source_Height)
                             / Float (Placement.Draw_Height))
                          / Float (Object.Pixel_Height);
                        U1 : constant Float :=
                          (Float (Placement.Source_X)
                           + (Clip_Right - Draw_Left)
                             * Float (Source_Width)
                             / Float (Placement.Draw_Width))
                          / Float (Object.Pixel_Width);
                        V1 : constant Float :=
                          (Float (Placement.Source_Y)
                           + (Clip_Bottom - Draw_Top)
                             * Float (Source_Height)
                             / Float (Placement.Draw_Height))
                          / Float (Object.Pixel_Height);
                        Frame_Bytes : constant RM.Image_Data_View :=
                          Display_Frame_Bytes (Object);
                        Frame_Format : constant Natural :=
                          Display_Frame_Format (Object);
                        Frame_Length : constant Natural :=
                          Display_Frame_Length (Object);
                        Preview_Length : constant Natural :=
                          Natural'Min
                            (Frame_Length,
                             RM.Max_Image_Decoded_Preview_Length);
                        Frame_Stride : constant Natural :=
                          Display_Frame_Stride (Object);
                     begin
                        if Frame_Bytes /= null
                          and then Clip_Right > Clip_Left
                          and then Clip_Bottom > Clip_Top
                        then
                           Append_Image_Command
                             (R,
                             (X => Float
                                (Origin_X (R) + (Col - 1) * R.CW)
                                + Clip_Left - Cell_Left,
                              Y => Float
                                (Origin_Y (R) + (Row - 1) * R.CH)
                                + Clip_Top - Cell_Top,
                              Width => Clip_Right - Clip_Left,
                              Height => Clip_Bottom - Clip_Top,
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
                              Decoded_Source =>
                                RM.Image_Decoded_Source_Buffer,
                              Decoded_Bytes => Frame_Bytes,
                              Encoded_Source_Bytes => null,
                              Encoded_Source_Length => 0,
                              Decoded_Preview_Length => Preview_Length,
                              Decoded_Preview_Bytes => Frame_Bytes,
                              Preview_Decode_Complete => True,
                              Decode_Status => RM.Image_Decode_Ok,
                              U0 => U0,
                              V0 => V0,
                              U1 => U1,
                              V1 => V1,
                              Image_ID =>
                                Interfaces.Unsigned_32 (Placement.Image_ID),
                              Content_Serial => Object.Content_Serial,
                              Z_Index => Placement.Z_Index,
                              Tint =>
                                (R => 1.0, G => 1.0, B => 1.0, A => 1.0)));
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
   end loop;
end Add_Placeholder_Images;

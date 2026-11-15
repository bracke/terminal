separate (Terminal.App.Renderer)
procedure Add_Placeholder_Images
  (R        : in out Renderer;
   Snapshot : Terminal.Core.Render_Snapshot)
is
begin
   if Image_Commands.Commands (R) = null
     or else Terminal.Core.Image_Cell_Count (Snapshot) = 0
   then
      return;
   end if;

   for Row in 1 .. Snapshot.Rows loop
      for Col in 1 .. Snapshot.Cols loop
         declare
            Cell : constant Terminal.Core.Cell_Content :=
              Terminal.Core.Cell_Content_At (Snapshot, Row, Col);
         begin
            if Cell.Image.Is_Placeholder
              and then Cell.Image.Image_ID_Valid
              and then Image_Commands.Count (R) >= Image_Commands.Capacity (R)
            then
               R.Frame_State.Frame_Command_Overflowed := True;
            elsif Cell.Image.Is_Placeholder
              and then Cell.Image.Image_ID_Valid
            then
               declare
                  Image_ID : constant Terminal.Core.Graphics_ID :=
                    Cell.Image.Image_ID;
                  Placement_ID : constant Terminal.Core.Graphics_ID :=
                    Cell.Image.Placement_ID;
                  Placement : Virtual_Placement_Access;
                  Placement_State : Virtual_Placement_State;
                  Object : Image_Object_Access;
               begin
                  Placement := Terminal.App.Placeholder_Index.Find_Placement
                    (R.Frame_State.Placement_Index,
                     Snapshot.Graphics_Stream,
                     Snapshot.Alternate_Screen,
                     Snapshot.Screen_Generation,
                     Image_ID,
                     Placement_ID);

                  if Placement = null then
                     Object := null;
                  else
                     Placement_State :=
                       Terminal.App.Image_Placements.State (Placement);
                     Object := Terminal.App.Placeholder_Index.Find_Object
                       (R.Frame_State.Placement_Index,
                        Snapshot.Graphics_Stream,
                        Placement_State.Image_Storage_Order);
                  end if;
                  if Placement /= null
                    and then Object /= null
                    and then Cell.Image.Image_Column < Placement_State.Columns
                    and then Cell.Image.Image_Row < Placement_State.Rows
                    and then Placement_State.Source_X < Object.Pixel_Width
                    and then Placement_State.Source_Y < Object.Pixel_Height
                  then
                     declare
                        Available_Width : constant Natural :=
                          Object.Pixel_Width - Placement_State.Source_X;
                        Available_Height : constant Natural :=
                          Object.Pixel_Height - Placement_State.Source_Y;
                        Source_Width : constant Natural :=
                          (if Placement_State.Source_Width = 0
                           then Available_Width
                           else Natural'Min
                             (Placement_State.Source_Width, Available_Width));
                        Source_Height : constant Natural :=
                          (if Placement_State.Source_Height = 0
                           then Available_Height
                           else Natural'Min
                             (Placement_State.Source_Height, Available_Height));
                        Column : constant Natural := Cell.Image.Image_Column;
                        Image_Row : constant Natural := Cell.Image.Image_Row;
                        Cell_Left : constant Float :=
                          Float (Column) * Float (R.Text_State.CW);
                        Cell_Top : constant Float :=
                          Float (Image_Row) * Float (R.Text_State.CH);
                        Cell_Right : constant Float :=
                          Cell_Left + Float (R.Text_State.CW);
                        Cell_Bottom : constant Float :=
                          Cell_Top + Float (R.Text_State.CH);
                        Draw_Left : constant Float :=
                          Float
                            (Placement_State.Cell_X
                             + Placement_State.Draw_Offset_X);
                        Draw_Top : constant Float :=
                          Float
                            (Placement_State.Cell_Y
                             + Placement_State.Draw_Offset_Y);
                        Draw_Right : constant Float :=
                          Draw_Left + Float (Placement_State.Draw_Width);
                        Draw_Bottom : constant Float :=
                          Draw_Top + Float (Placement_State.Draw_Height);
                        Clip_Left : constant Float :=
                          Float'Max (Cell_Left, Draw_Left);
                        Clip_Top : constant Float :=
                          Float'Max (Cell_Top, Draw_Top);
                        Clip_Right : constant Float :=
                          Float'Min (Cell_Right, Draw_Right);
                        Clip_Bottom : constant Float :=
                          Float'Min (Cell_Bottom, Draw_Bottom);
                        U0 : constant Float :=
                          (Float (Placement_State.Source_X)
                           + (Clip_Left - Draw_Left)
                             * Float (Source_Width)
                             / Float (Placement_State.Draw_Width))
                          / Float (Object.Pixel_Width);
                        V0 : constant Float :=
                          (Float (Placement_State.Source_Y)
                           + (Clip_Top - Draw_Top)
                             * Float (Source_Height)
                             / Float (Placement_State.Draw_Height))
                          / Float (Object.Pixel_Height);
                        U1 : constant Float :=
                          (Float (Placement_State.Source_X)
                           + (Clip_Right - Draw_Left)
                             * Float (Source_Width)
                             / Float (Placement_State.Draw_Width))
                          / Float (Object.Pixel_Width);
                        V1 : constant Float :=
                          (Float (Placement_State.Source_Y)
                           + (Clip_Bottom - Draw_Top)
                             * Float (Source_Height)
                             / Float (Placement_State.Draw_Height))
                          / Float (Object.Pixel_Height);
                        Display_Borrow :
                          Terminal.App.Image_Store.Data_Borrow;
                        Frame_Available : Boolean := False;
                        Frame_Format : constant Natural :=
                          Animation_State.Display_Format (Object);
                        Frame_Length : constant Natural :=
                          Animation_State.Display_Length (Object);
                        Preview_Length : constant Natural :=
                          Natural'Min
                            (Frame_Length,
                             RM.Max_Image_Decoded_Preview_Length);
                        Frame_Stride : constant Natural :=
                          Animation_State.Display_Stride (Object);
                        procedure Capture_Frame_Bytes
                          (Bytes : Terminal.Common.Bytes.Byte_Array) is
                           pragma Unreferenced (Bytes);
                        begin
                           Frame_Available := True;
                        end Capture_Frame_Bytes;
                     begin
                        Animation_State.Visit_Display_Bytes
                          (Object,
                           Display_Borrow,
                           Capture_Frame_Bytes'Access);
                        if Frame_Available
                          and then Clip_Right > Clip_Left
                          and then Clip_Bottom > Clip_Top
                        then
                           Append_Borrowed_Frame_Command
                             (R,
                             (X => Float
                                (Origin_X (R) + (Col - 1) * R.Text_State.CW)
                                + Clip_Left - Cell_Left,
                              Y => Float
                                (Origin_Y (R) + (Row - 1) * R.Text_State.CH)
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
                              Decoded_Bytes => null,
                              Encoded_Source_Bytes => null,
                              Encoded_Source_Length => 0,
                              Decoded_Preview_Length => Preview_Length,
                              Decoded_Preview_Bytes => null,
                              Preview_Decode_Complete => True,
                              Decode_Status => RM.Image_Decode_Ok,
                              U0 => U0,
                              V0 => V0,
                              U1 => U1,
                              V1 => V1,
                              Image_ID =>
                                Interfaces.Unsigned_32 (Placement_State.Image_ID),
                              Content_Serial => Object.Content_Serial,
                              Z_Index => Placement_State.Z_Index,
                              Tint =>
                                (R => 1.0, G => 1.0, B => 1.0, A => 1.0)),
                              Object,
                              Animation_State.Display_Frame (Object));
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
   end loop;
end Add_Placeholder_Images;

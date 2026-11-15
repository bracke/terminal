separate (Terminal.App.Renderer.Animations)
procedure Composite_Frame
  (R      : in out Renderer;
   Object : Image_Object_Access;
   Header : Terminal.App.Graphics.Graphics_Header;
   Data   : Terminal.App.Graphics.Graphics_Data_Preview;
   Canvas : in out Terminal.App.Owned_Image_Data.Owner)
is
   procedure Composite
     (Target : in out Terminal.Common.Bytes.Byte_Array);

   procedure Composite
     (Target : in out Terminal.Common.Bytes.Byte_Array)
   is
      procedure Read_Source (Source : Terminal.Common.Bytes.Byte_Array);

      procedure Read_Source (Source : Terminal.Common.Bytes.Byte_Array) is
      begin
         for Y in 0 .. Data.Pixel_Height - 1 loop
            for X in 0 .. Data.Pixel_Width - 1 loop
               declare
                  Source_Index : constant Positive :=
                    Positive
                      (Y * Data.Decoded_Row_Stride_Bytes
                       + X
                         * (if Data.Raw_Format = 8 then 1
                            elsif Data.Raw_Format = 16 then 2
                            else Data.Raw_Format / 8)
                       + 1);
                  Target_Index : constant Positive :=
                    Positive
                      (((Header.Kitty_Source_Y + Y) * Object.Pixel_Width
                        + Header.Kitty_Source_X + X) * 4 + 1);
                  Palette_Color : constant RM.Pixel_Color :=
                    (if Data.Raw_Format in 8 | 16
                     then Style.Kitty_Indexed_Color
                       (R, Natural (Source (Source_Index)))
                     else (0.0, 0.0, 0.0, 1.0));
                  SR : constant Natural :=
                    (if Data.Raw_Format in 8 | 16
                     then Natural (Style.Color_Byte (Palette_Color.R))
                     else Natural (Source (Source_Index)));
                  SG : constant Natural :=
                    (if Data.Raw_Format in 8 | 16
                     then Natural (Style.Color_Byte (Palette_Color.G))
                     else Natural (Source (Source_Index + 1)));
                  SB : constant Natural :=
                    (if Data.Raw_Format in 8 | 16
                     then Natural (Style.Color_Byte (Palette_Color.B))
                     else Natural (Source (Source_Index + 2)));
                  SA : constant Natural :=
                    (if Data.Raw_Format = 16
                     then Natural (Source (Source_Index + 1))
                     elsif Data.Raw_Format = 32
                     then Natural (Source (Source_Index + 3))
                     else 255);
               begin
                  if Header.Kitty_Composition_Mode = 1 or else SA = 255 then
                     Target (Target_Index) := Terminal.Common.Bytes.Byte (SR);
                     Target (Target_Index + 1) :=
                       Terminal.Common.Bytes.Byte (SG);
                     Target (Target_Index + 2) :=
                       Terminal.Common.Bytes.Byte (SB);
                     Target (Target_Index + 3) :=
                       Terminal.Common.Bytes.Byte (SA);
                  elsif SA > 0 then
                     declare
                        DR : constant Natural := Natural (Target (Target_Index));
                        DG : constant Natural :=
                          Natural (Target (Target_Index + 1));
                        DB : constant Natural :=
                          Natural (Target (Target_Index + 2));
                        DA : constant Natural :=
                          Natural (Target (Target_Index + 3));
                        OA : constant Natural :=
                          SA + (DA * (255 - SA) + 127) / 255;
                        Denom : constant Natural := Natural'Max (1, OA * 255);
                     begin
                        Target (Target_Index) := Terminal.Common.Bytes.Byte
                          ((SR * SA * 255 + DR * DA * (255 - SA)
                            + Denom / 2) / Denom);
                        Target (Target_Index + 1) := Terminal.Common.Bytes.Byte
                          ((SG * SA * 255 + DG * DA * (255 - SA)
                            + Denom / 2) / Denom);
                        Target (Target_Index + 2) := Terminal.Common.Bytes.Byte
                          ((SB * SA * 255 + DB * DA * (255 - SA)
                            + Denom / 2) / Denom);
                        Target (Target_Index + 3) :=
                          Terminal.Common.Bytes.Byte (OA);
                     end;
                  end if;
               end;
            end loop;
         end loop;
      end Read_Source;
   begin
      Terminal.App.Graphics.Read_Bytes (Data, Read_Source'Access);
   end Composite;
begin
   Terminal.App.Owned_Image_Data.Modify (Canvas, Composite'Access);
end Composite_Frame;

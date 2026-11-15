with Terminal.App.Graphics.PNG_Support;

package body Terminal.App.Graphics.PNG_Pixels is
   procedure Convert_Row
     (Info              : PNG_Types.PNG_Info;
      Bit_Depth         : Natural;
      Palette           : PNG_Types.PNG_Palette;
      Palette_Count     : Natural;
      Gray_Transparent  : Natural;
      Red_Transparent   : Natural;
      Green_Transparent : Natural;
      Blue_Transparent  : Natural;
      Source            : Terminal.Common.Bytes.Byte_Array;
      Pass_Width        : Natural;
      X_Start, Y, X_Step : Natural;
      Interlaced        : Boolean;
      Destination       : in out Terminal.Common.Bytes.Byte_Array;
      Status            : out Data_Decode_Status) is
   begin
      Status := Decode_Ok;
      if Pass_Width = 0 then
         return;
      end if;
      for X in 0 .. Pass_Width - 1 loop
         declare
            Actual_X : constant Natural := X_Start + X * X_Step;
            Out_Pos : constant Natural :=
              Destination'First
              + (if Interlaced then Y * Info.Width + Actual_X else Actual_X) * 4;
            Src_8 : constant Natural := Source'First
              + X * PNG_Support.Filter_BPP (Info.Color_Type, 8);
            Src_16 : constant Natural := Source'First
              + X * PNG_Support.Filter_BPP (Info.Color_Type, 16);
            Gray, Red, Green, Blue : Natural;
            Alpha : Natural := 255;
         begin
            case Info.Color_Type is
               when 0 =>
                  if Bit_Depth = 16 then
                     Gray := PNG_Support.Sample_16 (Source, Src_16);
                  elsif Bit_Depth = 8 then
                     Gray := Natural (Source (Src_8));
                  else
                     Gray := PNG_Support.Packed_Sample (Source, Bit_Depth, X);
                  end if;
                  Red := PNG_Support.Scale_Sample (Gray, Bit_Depth);
                  Green := Red;
                  Blue := Red;
                  if Gray = Gray_Transparent then
                     Alpha := 0;
                  end if;
               when 2 =>
                  if Bit_Depth = 16 then
                     Red := PNG_Support.Sample_16 (Source, Src_16);
                     Green := PNG_Support.Sample_16 (Source, Src_16 + 2);
                     Blue := PNG_Support.Sample_16 (Source, Src_16 + 4);
                  else
                     Red := Natural (Source (Src_8));
                     Green := Natural (Source (Src_8 + 1));
                     Blue := Natural (Source (Src_8 + 2));
                  end if;
                  if Red = Red_Transparent
                    and then Green = Green_Transparent
                    and then Blue = Blue_Transparent
                  then
                     Alpha := 0;
                  end if;
                  Red := PNG_Support.Scale_Sample (Red, Bit_Depth);
                  Green := PNG_Support.Scale_Sample (Green, Bit_Depth);
                  Blue := PNG_Support.Scale_Sample (Blue, Bit_Depth);
               when 3 =>
                  declare
                     Index : constant Natural :=
                       (if Bit_Depth = 8 then Natural (Source (Src_8))
                        else PNG_Support.Packed_Sample (Source, Bit_Depth, X));
                  begin
                     if Index >= Palette_Count then
                        Status := Decode_Invalid_Byte;
                        return;
                     end if;
                     Red := Natural (Palette (Index).R);
                     Green := Natural (Palette (Index).G);
                     Blue := Natural (Palette (Index).B);
                     Alpha := Natural (Palette (Index).A);
                  end;
               when 4 =>
                  if Bit_Depth = 16 then
                     Gray := PNG_Support.Sample_16 (Source, Src_16);
                     Alpha := PNG_Support.Sample_16 (Source, Src_16 + 2);
                  else
                     Gray := Natural (Source (Src_8));
                     Alpha := Natural (Source (Src_8 + 1));
                  end if;
                  Red := PNG_Support.Scale_Sample (Gray, Bit_Depth);
                  Green := Red;
                  Blue := Red;
                  Alpha := PNG_Support.Scale_Sample (Alpha, Bit_Depth);
               when others =>
                  if Bit_Depth = 16 then
                     Red := PNG_Support.Sample_16 (Source, Src_16);
                     Green := PNG_Support.Sample_16 (Source, Src_16 + 2);
                     Blue := PNG_Support.Sample_16 (Source, Src_16 + 4);
                     Alpha := PNG_Support.Sample_16 (Source, Src_16 + 6);
                  else
                     Red := Natural (Source (Src_8));
                     Green := Natural (Source (Src_8 + 1));
                     Blue := Natural (Source (Src_8 + 2));
                     Alpha := Natural (Source (Src_8 + 3));
                  end if;
                  Red := PNG_Support.Scale_Sample (Red, Bit_Depth);
                  Green := PNG_Support.Scale_Sample (Green, Bit_Depth);
                  Blue := PNG_Support.Scale_Sample (Blue, Bit_Depth);
                  Alpha := PNG_Support.Scale_Sample (Alpha, Bit_Depth);
            end case;

            Destination (Out_Pos) := Terminal.Common.Bytes.Byte (Red);
            Destination (Out_Pos + 1) := Terminal.Common.Bytes.Byte (Green);
            Destination (Out_Pos + 2) := Terminal.Common.Bytes.Byte (Blue);
            Destination (Out_Pos + 3) := Terminal.Common.Bytes.Byte (Alpha);
         end;
      end loop;
   end Convert_Row;
end Terminal.App.Graphics.PNG_Pixels;

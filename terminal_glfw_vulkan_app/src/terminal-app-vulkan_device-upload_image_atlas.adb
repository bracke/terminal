separate (Terminal.App.Vulkan_Device)
procedure Upload_Image_Atlas
  (Device : in out Logical_Device;
   Choice : Selection;
   Batch  : VS.Submission_Batch;
   Status : out Create_Status)
is
   Atlas_Width  : constant Natural := VS.Image_Atlas_Width (Batch);
   Atlas_Height : constant Natural := VS.Image_Atlas_Height (Batch);
   Atlas_Bytes  : constant Natural := VS.Image_Atlas_Bytes (Batch);

   procedure Fill_Atlas
     (Target   : Image_Texture_Byte_Mapping.Object_Pointer;
      Capacity : Positive;
      Fill_Status : out Create_Status)
   is
      function Pixel_Index (X, Y : Natural) return Positive is
        ((Y * Atlas_Width + X) * 4 + 1);

      procedure Copy_Pixel
        (From_X, From_Y, To_X, To_Y : Natural)
      is
         From_Index : constant Positive := Pixel_Index (From_X, From_Y);
         To_Index   : constant Positive := Pixel_Index (To_X, To_Y);
      begin
         for Channel in 0 .. 3 loop
            Target.all (To_Index + Channel) :=
              Target.all (From_Index + Channel);
         end loop;
      end Copy_Pixel;
   begin
      Fill_Status := Ok;
      if Target = null
        or else Atlas_Width = 0
        or else Atlas_Height = 0
        or else Atlas_Bytes = 0
        or else Capacity < Atlas_Bytes
        or else Atlas_Bytes > Max_Image_Texture_Bytes
      then
         Fill_Status := Atlas_Too_Large;
         return;
      end if;

      for I in 1 .. Atlas_Bytes loop
         Target.all (I) := 0;
      end loop;

      for Source_Index in 1 .. VS.Image_Atlas_Source_Count (Batch) loop
         declare
            Source : constant RM.Image_Command :=
              VS.Image_Atlas_Source_Command (Batch, Source_Index);
            X : constant Natural :=
              VS.Image_Atlas_Source_X (Batch, Source_Index);
            Y : constant Natural :=
              VS.Image_Atlas_Source_Y (Batch, Source_Index);
            Target_Width : constant Natural :=
              VS.Image_Atlas_Source_Width (Batch, Source_Index);
            Target_Height : constant Natural :=
              VS.Image_Atlas_Source_Height (Batch, Source_Index);
            Bytes_Per_Pixel : constant Natural :=
              (if Source.Raw_Format = 24 then 3
               elsif Source.Raw_Format = 32 then 4
               else 0);
            Rows_Seen : Natural := 0;
            Target_Rows_Written : Natural := 0;
            Decode_Failed : Boolean := False;

            procedure Write_Row
              (Row_Y : Natural;
               Row   : Terminal.Common.Bytes.Byte_Array;
               Continue : in out Boolean)
            is
            begin
               if Row_Y >= Source.Pixel_Height
                 or else Row'Length < Source.Pixel_Width * Bytes_Per_Pixel
                 or else X = 0
                 or else Y = 0
                 or else Target_Width = 0
                 or else Target_Height = 0
                 or else X + Target_Width >= Atlas_Width
                 or else Y + Target_Height >= Atlas_Height
               then
                  Decode_Failed := True;
                  Continue := False;
                  return;
               end if;

               Rows_Seen := Rows_Seen + 1;
               --  Nearest-neighbour reduction into the bounded atlas.  A
               --  source row can supply zero or more destination rows.
               while Target_Rows_Written < Target_Height
                 and then
                   (Target_Rows_Written * Source.Pixel_Height) /
                     Target_Height = Row_Y
               loop
                  declare
                     Target_Index : constant Positive :=
                       Pixel_Index (X, Y + Target_Rows_Written);
                  begin
                     for Pixel in 0 .. Target_Width - 1 loop
                        declare
                           Source_Pixel : constant Natural :=
                             (Pixel * Source.Pixel_Width) / Target_Width;
                           Source_Offset : constant Natural :=
                             Source_Pixel * Bytes_Per_Pixel;
                           Target_Offset : constant Natural := Pixel * 4;
                        begin
                           Target.all (Target_Index + Target_Offset) :=
                             Interfaces.Unsigned_8
                               (Row (Row'First + Source_Offset));
                           Target.all (Target_Index + Target_Offset + 1) :=
                             Interfaces.Unsigned_8
                               (Row (Row'First + Source_Offset + 1));
                           Target.all (Target_Index + Target_Offset + 2) :=
                             Interfaces.Unsigned_8
                               (Row (Row'First + Source_Offset + 2));
                           Target.all (Target_Index + Target_Offset + 3) :=
                             (if Bytes_Per_Pixel = 4
                              then Interfaces.Unsigned_8
                                (Row (Row'First + Source_Offset + 3))
                              else 16#FF#);
                        end;
                     end loop;
                  end;
                  Target_Rows_Written := Target_Rows_Written + 1;
               end loop;
            end Write_Row;

            procedure Write_Buffer_Rows is
               Row : Terminal.Common.Bytes.Byte_Array
                 (1 .. Source.Pixel_Width * Bytes_Per_Pixel);
               Continue : Boolean := True;
            begin
               for Row_Y in 0 .. Source.Pixel_Height - 1 loop
                  for Offset in 0 .. Row'Length - 1 loop
                     Row (Offset + 1) :=
                       RM.Image_Decoded_Row_Byte (Source, Row_Y, Offset);
                  end loop;
                  Write_Row (Row_Y, Row, Continue);
                  exit when not Continue;
               end loop;
            end Write_Buffer_Rows;

            procedure Write_Encoded_Rows is
               Decode_Status : Terminal.App.Image_Staging.Decode_Status;
            begin
               Terminal.App.Image_Staging.Decode_Encoded_Rows
                 (Source, Write_Row'Access, Decode_Status);
               case Decode_Status is
                  when Terminal.App.Image_Staging.Decode_Ok =>
                     null;
                  when Terminal.App.Image_Staging.Invalid_Source =>
                     Decode_Failed := True;
                     Fill_Status := Image_Staging_Invalid_Source;
                  when Terminal.App.Image_Staging.Allocation_Failed =>
                     Decode_Failed := True;
                     Fill_Status := Image_Staging_Allocation_Failed;
               end case;
            end Write_Encoded_Rows;
         begin
            if Bytes_Per_Pixel = 0 then
               Decode_Failed := True;
            elsif Source.Decoded_Source = RM.Image_Decoded_Source_Buffer then
               Write_Buffer_Rows;
            else
               Write_Encoded_Rows;
            end if;

            if Decode_Failed
              or else Rows_Seen /= Source.Pixel_Height
              or else Target_Rows_Written /= Target_Height
            then
               if Fill_Status = Ok then
                  Fill_Status := Atlas_Too_Large;
               end if;
               return;
            end if;

            --  Duplicate edge texels into a one-pixel gutter. The sampler
            --  is linear, so transparent padding would darken image edges.
            for Row_Y in 0 .. Target_Height - 1 loop
               Copy_Pixel (X, Y + Row_Y, X - 1, Y + Row_Y);
               Copy_Pixel
                 (X + Target_Width - 1,
                  Y + Row_Y,
                  X + Target_Width,
                  Y + Row_Y);
            end loop;
            for Column in X - 1 .. X + Target_Width loop
               Copy_Pixel (Column, Y, Column, Y - 1);
               Copy_Pixel
                 (Column,
                  Y + Target_Height - 1,
                  Column,
                  Y + Target_Height);
            end loop;
         end;
      end loop;
   end Fill_Atlas;
begin
   Upload_Image_Texture_Staging_Source
     (Device        => Device,
      Slot          => Inline_Picture,
      Choice        => Choice,
      Width         => Atlas_Width,
      Height        => Atlas_Height,
      Source_Bytes_Per_Pixel => 4,
      Row_Stride_Bytes => Atlas_Width * 4,
      Bytes_Natural => Atlas_Bytes,
      Fill_Staging  => Fill_Atlas'Access,
      Status        => Status,
      Content_Signature => VS.Image_Atlas_Signature (Batch));
end Upload_Image_Atlas;

with Terminal.App.Image_Staging;

package body Terminal.App.Vulkan_Submit.Source_Rows is
   package RM renames Terminal.App.Render_Model;
   use type RM.Image_Decoded_Source_Kind;

   function Is_Valid
     (Batch : Submission_Batch; Index : Positive) return Boolean is
     (Batch.Image_Atlas_Sources /= null
      and then Index <= Batch.Image_Atlas_Source_Total);

   function Raw_Format
     (Batch : Submission_Batch; Index : Positive) return Natural is
     (if Is_Valid (Batch, Index)
      then Batch.Image_Atlas_Sources (Index).Command.Raw_Format else 0);

   function Pixel_Width
     (Batch : Submission_Batch; Index : Positive) return Natural is
     (if Is_Valid (Batch, Index)
      then Batch.Image_Atlas_Sources (Index).Command.Pixel_Width else 0);

   function Pixel_Height
     (Batch : Submission_Batch; Index : Positive) return Natural is
     (if Is_Valid (Batch, Index)
      then Batch.Image_Atlas_Sources (Index).Command.Pixel_Height else 0);

   procedure Read
     (Batch : Submission_Batch;
      Index : Positive;
      Write : not null access procedure
        (Y        : Natural;
         Row      : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Status : out Image_Source_Read_Status)
   is
      Staging_Status : Terminal.App.Image_Staging.Decode_Status;
   begin
      Status := Image_Source_Invalid;
      if not Is_Valid (Batch, Index) then
         return;
      end if;

      declare
         --  The controlled handles retain the immutable byte storage across
         --  callbacks, including a callback that releases or rebuilds Batch.
         Retained : constant Image_Atlas_Source :=
           Batch.Image_Atlas_Sources (Index);
         Source : RM.Image_Command renames Retained.Command;
         Bytes_Per_Pixel : constant Natural :=
           (if Source.Raw_Format = 24 then 3
            elsif Source.Raw_Format = 32 then 4
            else 0);
         Row_Bytes : constant Natural :=
           (if Bytes_Per_Pixel > 0
              and then Source.Pixel_Width <= Natural'Last / Bytes_Per_Pixel
            then Source.Pixel_Width * Bytes_Per_Pixel
            else 0);
      begin
         if Source.Pixel_Height = 0 or else Row_Bytes = 0 then
            return;
         elsif Source.Decoded_Source = RM.Image_Decoded_Source_Buffer then
            if not RM.Image_Decoded_Source_Available (Source) then
               return;
            end if;
            declare
               Row : Terminal.Common.Bytes.Byte_Array (1 .. Row_Bytes);
               Continue : Boolean := True;
            begin
               for Y in 0 .. Source.Pixel_Height - 1 loop
                  for Offset in 0 .. Row_Bytes - 1 loop
                     Row (Offset + 1) :=
                       RM.Image_Decoded_Row_Byte (Source, Y, Offset);
                  end loop;
                  Write (Y, Row, Continue);
                  if not Continue then
                     return;
                  end if;
               end loop;
               Status := Image_Source_Ok;
            end;
         else
            Terminal.App.Image_Staging.Decode_Encoded_Rows
              (Source, Write, Staging_Status);
            Status :=
              (case Staging_Status is
                  when Terminal.App.Image_Staging.Decode_Ok =>
                    Image_Source_Ok,
                  when Terminal.App.Image_Staging.Invalid_Source =>
                    Image_Source_Invalid,
                  when Terminal.App.Image_Staging.Allocation_Failed =>
                    Image_Source_Allocation_Failed);
         end if;
      end;
   end Read;
end Terminal.App.Vulkan_Submit.Source_Rows;

separate (Terminal.App.Renderer.Add_Image_Event.Emit_PNG_Rows)
procedure Decode_ITerm2 is
begin
   --  Try the bounded PNG row decoder first. JPEG and auxiliary formats use
   --  their own quota-aware decoders.
   Terminal.App.Graphics.Decoding.Decode_Base64_PNG_Chunk_Rows
     (1, PNG_Text'Access, Encoded_Length, PNG_Length,
      Capture_PNG_Row'Access, Data);
   if Data.Decode_Status = Terminal.App.Graphics.Decode_Unsupported_Format then
      Terminal.App.Graphics.Release (Data);
      declare
         JPEG_Data : Terminal.App.Graphics.Graphics_Data_Preview :=
           Terminal.App.Graphics.JPEG_Data_Preview_Text
             (Image_Text,
              R.Graphics_State.Policy.Limits.Per_Image_Bytes,
              R.Graphics_State.Policy.Limits.Pixel_Dimension);
      begin
         Terminal.App.Graphics.Move (JPEG_Data, Data);
      end;
      if Terminal.App.Graphics.Has_Bytes (Data) then
         Terminal.App.Graphics.Take_Bytes (Data, Image_Owner);
         Image_Buffers.Copy_Preview
           (Image_Owner, Data.Decoded_Length, Preview_Length, Preview_Bytes);
      end if;
   end if;
   if Data.Decode_Status = Terminal.App.Graphics.Decode_Unsupported_Format
     and then Terminal.App.Image_Media.Available
   then
      declare
         Blob          : Terminal.App.Owned_Image_Data.Owner;
         Blob_Length   : Natural := 0;
         Base64_Status : Terminal.App.Graphics.Data_Decode_Status;
         Media_Status  : Terminal.App.Image_Media.Decode_Status;
      begin
         Terminal.App.Graphics.Decoding.Decode_Base64_Data
           (Image_Text (From .. Image_Text'Last),
            R.Graphics_State.Policy.Limits.Per_Image_Bytes,
            Blob, Blob_Length, Base64_Status);
         if Base64_Status = Terminal.App.Graphics.Decode_Ok
           and then not Terminal.App.Owned_Image_Data.Is_Empty (Blob)
         then
            declare
               procedure Decode_Media
                 (Bytes : Terminal.Common.Bytes.Byte_Array) is
               begin
                  Terminal.App.Image_Media.Decode
                    (Bytes,
                     Blob_Length,
                     R.Graphics_State.Policy.Limits.Per_Image_Bytes,
                     R.Graphics_State.Policy.Limits.Pixel_Dimension,
                     Media,
                     Media_Status,
                     Maximum_Frames =>
                       R.Graphics_State.Policy.Limits.Animation_Frames);
               end Decode_Media;
            begin
               Terminal.App.Owned_Image_Data.Read (Blob, Decode_Media'Access);
            end;
            Terminal.App.Image_Rendering.Capture
              (R.Graphics_State.Telemetry.Last_Media, Media, Media_Status);
            if Media_Status = Terminal.App.Image_Media.Decode_Ok
              and then Media.Has_Bytes
              and then Media.Frame_Count > 0
              and then Terminal.App.Image_Rendering.Animation_Capacity_Available
                (Stored_Animation_Frame_Count (R),
                 Media.Frame_Count,
                 R.Graphics_State.Policy.Limits.Animation_Frames)
            then
               Terminal.App.Graphics.Release (Data);
               if Media.Frame_Count = 1 then
                  Terminal.App.Image_Media.Move_Bytes (Media, Image_Owner);
               else
                  Terminal.App.Owned_Image_Data.Allocate
                    (Image_Owner, Media.Frame_Bytes);
                  Terminal.App.Owned_Image_Data.Modify
                    (Image_Owner, Copy_First_Media_Frame'Access);
               end if;
               Terminal.App.Graphics.Record_External_Decode
                 (Data,
                  Encoded_Length           => Encoded_Length,
                  Raw_Format               => 32,
                  Pixel_Width              => Media.Pixel_Width,
                  Pixel_Height             => Media.Pixel_Height,
                  Decoded_Length           => Media.Frame_Bytes,
                  Decoded_Row_Stride_Bytes => Media.Pixel_Width * 4,
                  Status                   => Terminal.App.Graphics.Decode_Ok);
               Media_Used := True;
               Image_Buffers.Copy_Preview
                 (Image_Owner, Media.Frame_Bytes,
                  Preview_Length, Preview_Bytes);
            elsif Media_Status = Terminal.App.Image_Media.Decode_Ok then
               if not Media.Has_Bytes or else Media.Frame_Count = 0 then
                  Terminal.App.Graphics.Set_Decode_Failure
                    (Data, Terminal.App.Graphics.Decode_Invalid_Data);
                  Terminal.App.Image_Rendering.Set_Status
                    (R.Graphics_State.Telemetry.Last_Media,
                     Terminal.App.Image_Media.Decode_Invalid);
               else
                  Terminal.App.Graphics.Set_Decode_Failure
                    (Data, Terminal.App.Graphics.Decode_Too_Large);
                  Terminal.App.Image_Rendering.Set_Status
                    (R.Graphics_State.Telemetry.Last_Media,
                     Terminal.App.Image_Media.Decode_Too_Large);
               end if;
            else
               Terminal.App.Graphics.Set_Decode_Failure (Data, Media_Status);
            end if;
         else
            Terminal.App.Graphics.Set_Decode_Failure (Data, Base64_Status);
         end if;
      end;
   end if;
end Decode_ITerm2;

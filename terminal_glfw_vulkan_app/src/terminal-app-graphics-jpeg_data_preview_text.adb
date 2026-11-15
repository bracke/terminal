separate (Terminal.App.Graphics)
function JPEG_Data_Preview_Text
  (Text                    : String;
   Maximum_Decoded_Bytes   : Data_Decode_Byte_Limit;
   Maximum_Pixel_Dimension : Positive) return Graphics_Data_Preview
is
   Header : constant Graphics_Header :=
     Header_Text (Terminal.Core.ITerm2_Graphics, Text);
   Result : Graphics_Data_Preview;
   From   : Natural := 0;

   function Finished return Graphics_Data_Preview is
   begin
      return Output : Graphics_Data_Preview do
         Move (Result, Output);
      end return;
   end Finished;
begin
   Result.Header_Recognized := Header.Recognized;
   Result.Has_Data := Header.Has_Data;
   if not Header.Recognized or else not Header.Has_Data or else Text = "" then
      return Finished;
   end if;

   for I in Text'Range loop
      if Text (I) = ':' then
         if I < Text'Last then
            From := I + 1;
         end if;
         exit;
      end if;
   end loop;
   if From = 0 then
      Result.Has_Data := False;
      return Finished;
   end if;

   Result.Encoded_Length := Text'Last - From + 1;
   declare
      Encoded_Owner  : Image_Data_Holder;
      Encoded_Length : Natural := 0;
      Status         : Data_Decode_Status;
   begin
      Terminal.App.Graphics.Decoding.Decode_Base64_Data
        (Text (From .. Text'Last), Max_Data_Preview_Length,
         Encoded_Owner, Encoded_Length, Status);
      if Status /= Decode_Ok
        or else Terminal.App.Owned_Image_Data.Is_Empty (Encoded_Owner)
      then
         Result.Decode_Status := Status;
         Result.Decode_Complete := False;
      else
         declare
            procedure Decode (Encoded_Data : Terminal.Common.Bytes.Byte_Array) is
            begin
               Terminal.App.Graphics.Media_Decoders.Decode_JPEG_RGBA_Data
                 (Encoded_Data, Encoded_Length, Result,
                  Maximum_Decoded_Bytes, Maximum_Pixel_Dimension);
            end Decode;
         begin
            Encoded_Owner.Read (Decode'Access);
         end;
      end if;
   end;
   return Finished;
exception
   when Storage_Error =>
      Release (Result);
      Result.Decode_Status := Decode_Allocation_Failed;
      Result.Decode_Complete := False;
      return Finished;
   when Constraint_Error =>
      Release (Result);
      Result.Decode_Status := Decode_Preview_Truncated;
      Result.Decode_Complete := False;
      return Finished;
   when others =>
      Release (Result);
      raise;
end JPEG_Data_Preview_Text;

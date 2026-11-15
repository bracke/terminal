separate (Terminal.App.Graphics.Transport_Decoders)
procedure Decode_Base64_Preview
  (Text   : String;
   Result : in out Graphics_Data_Preview;
   Expected_Decoded_Length : Natural := 0)
is
   Decoder : Terminal.Common.Base64.Decoder_State;
   Bytes : Terminal.Common.Base64.Decoded_Quantum;
   Byte_Count : Natural := 0;
   Base64_Status : Terminal.Common.Base64.Decoder_Status;
   Done   : Boolean := False;

   procedure Append_Byte (Value : Natural) is
   begin
      if Expected_Decoded_Length > 0
        and then Result.Decoded_Length = Expected_Decoded_Length
      then
         Result.Decode_Status := Decode_Trailing_Data;
         Result.Decode_Complete := False;
         Done := True;
         return;
      elsif Result.Decoded_Length = Max_Data_Preview_Length then
         Result.Decode_Status := Decode_Preview_Truncated;
         Result.Decode_Complete := False;
         Done := True;
         return;
      end if;

      if Expected_Decoded_Length > 0 then
         Preview_Storage.Ensure_Bytes (Result, Expected_Decoded_Length);
      else
         Preview_Storage.Ensure_Bytes (Result);
      end if;
      Result.Decoded_Length := Result.Decoded_Length + 1;
      Terminal.App.Owned_Image_Data.Replace_Element
        (Result.Storage.Bytes,
         Result.Decoded_Length,
         Terminal.Common.Bytes.Byte (Value mod 256));
   end Append_Byte;

   procedure Append_Output is
   begin
      if Base64_Status = Terminal.Common.Base64.Invalid_Data then
         if Result.Decode_Status /= Decode_Trailing_Data then
            Result.Decode_Status := Decode_Invalid_Byte;
         end if;
         Result.Decode_Complete := False;
         Done := True;
         return;
      end if;
      for I in 1 .. Byte_Count loop
         Append_Byte (Natural (Bytes (I)));
         exit when Done;
      end loop;
   end Append_Output;
begin
   Terminal.Common.Base64.Reset
     (Decoder, Allow_Unpadded => True, Allow_Whitespace => True);
   for Ch of Text loop
      declare
         Was_Complete : constant Boolean :=
           Terminal.Common.Base64.Is_Complete (Decoder);
      begin
         Terminal.Common.Base64.Push
           (Decoder, Ch, Bytes, Byte_Count, Base64_Status);
         if Base64_Status = Terminal.Common.Base64.Invalid_Data
           and then Was_Complete
         then
            Result.Decode_Status := Decode_Trailing_Data;
         end if;
         Append_Output;
         exit when Done;
      end;
   end loop;

   if Done then
      return;
   end if;
   Terminal.Common.Base64.Finish
     (Decoder, Bytes, Byte_Count, Base64_Status);
   Append_Output;
   if Done then
      return;
   end if;

   Result.Decode_Complete :=
     Result.Has_Data
     and then
       (Expected_Decoded_Length = 0
        or else Result.Decoded_Length = Expected_Decoded_Length);
   Result.Decode_Status :=
     (if Result.Decode_Complete then Decode_Ok
      elsif Expected_Decoded_Length > 0
        and then Result.Decoded_Length < Expected_Decoded_Length
      then Decode_Invalid_Data
      else Decode_Not_Attempted);
end Decode_Base64_Preview;

separate (Terminal.App.Graphics.Transport_Decoders)
   procedure Decode_Base64_Data
     (Text                  : String;
      Maximum_Decoded_Bytes : Positive;
      Data                  : in out Terminal.App.Owned_Image_Data.Owner;
      Length                : out Natural;
      Status                : out Data_Decode_Status)
   is
      Result : Graphics_Data_Preview :=
        (Ada.Finalization.Limited_Controlled with
         Header_Recognized => True,
         Has_Data          => Text'Length > 0,
         others            => <>);
      Expected : Natural := 0;
      Owner : Image_Data_Holder;
   begin
      Terminal.App.Owned_Image_Data.Release (Data);
      Length := 0;
      Status := Decode_Not_Attempted;
      if not Base64_Decoded_Length (Text, Expected) then
         Status := Decode_Invalid_Byte;
         return;
      end if;
      if Expected > Maximum_Decoded_Bytes then
         Status := Decode_Preview_Truncated;
         return;
      end if;
      Decode_Base64_Preview (Text, Result, Expected);
      Status := Result.Decode_Status;
      if Result.Decode_Complete
        and then Result.Decode_Status = Decode_Ok
        and then Result.Decoded_Length = Expected
        and then Has_Bytes (Result)
      then
         Take_Bytes (Result, Owner);
         Terminal.App.Owned_Image_Data.Move (Owner, Data);
         Length := Expected;
      end if;
      Release (Result);
   exception
      when Storage_Error =>
         Release (Result);
         Terminal.App.Owned_Image_Data.Release (Data);
         Length := 0;
         Status := Decode_Allocation_Failed;
   end Decode_Base64_Data;

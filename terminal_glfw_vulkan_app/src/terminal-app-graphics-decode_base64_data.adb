separate (Terminal.App.Graphics)
   procedure Decode_Base64_Data
     (Text                  : String;
      Maximum_Decoded_Bytes : Positive;
      Data                  : out Terminal.App.Render_Model.Image_Data_Access;
      Length                : out Natural;
      Status                : out Data_Decode_Status)
   is
      Encoded_Count : Natural := 0;
      Padding       : Natural := 0;
      Result : Graphics_Data_Preview :=
        (Header_Recognized => True,
         Has_Data          => Text'Length > 0,
         others            => <>);
      Expected : Natural := 0;
   begin
      Data := null;
      Length := 0;
      Status := Decode_Not_Attempted;
      for Ch of Text loop
         if Ch /= ASCII.CR and then Ch /= ASCII.LF and then Ch /= ' ' then
            Encoded_Count := Encoded_Count + 1;
            if Ch = '=' then
               Padding := Padding + 1;
            end if;
         end if;
      end loop;
      if Encoded_Count = 0
        or else Encoded_Count mod 4 /= 0
        or else Padding > 2
        or else Encoded_Count / 4 > Natural'Last / 3
      then
         Status := Decode_Invalid_Byte;
         return;
      end if;
      Expected := (Encoded_Count / 4) * 3 - Padding;
      if Expected = 0 or else Expected > Maximum_Decoded_Bytes then
         Status := Decode_Preview_Truncated;
         return;
      end if;
      Decode_Base64_Preview (Text, Result, Expected);
      Status := Result.Decode_Status;
      if Result.Decode_Complete
        and then Result.Decode_Status = Decode_Ok
        and then Result.Decoded_Length = Expected
        and then Result.Bytes /= null
      then
         Data := Result.Bytes;
         Result.Bytes := null;
         Length := Expected;
      end if;
      Release (Result);
   exception
      when Storage_Error =>
         Release (Result);
         Data := null;
         Length := 0;
         Status := Decode_Allocation_Failed;
   end Decode_Base64_Data;


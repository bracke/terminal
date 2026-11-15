separate (Terminal.App.Graphics.Media_Decoders)
procedure Decode_PNG_RGBA_Data
  (PNG : Terminal.Common.Bytes.Byte_Array; Length : Natural;
   Result : in out Graphics_Data_Preview)
is
begin
   if Length <= PNG'Length then
      Decode_PNG_RGBA (PNG, Length, Result);
   else
      Set_Decode_Failure (Result, Decode_Invalid_Data);
   end if;
end Decode_PNG_RGBA_Data;

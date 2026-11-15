separate (Terminal.App.Graphics.Media_Decoders)
procedure Decode_PNG_RGBA
  (PNG    : Terminal.Common.Bytes.Byte_Array;
   Length : Natural;
   Result : in out Graphics_Data_Preview)
is
   procedure Capture_Row
     (Y        : Natural;
      Row      : Terminal.Common.Bytes.Byte_Array;
      Continue : in out Boolean) is
   begin
      Preview_Storage.Capture_RGBA_Row (Result, Y, Row, Continue);
   end Capture_Row;
begin
   Decode_PNG_RGBA_Rows (PNG, Length, Capture_Row'Access, Result);
   if Result.Decode_Complete
     and then not Preview_Storage.RGBA_Rows_Complete (Result)
   then
      Preview_Storage.Set_Decode_Failure (Result, Decode_Invalid_Data);
   end if;
end Decode_PNG_RGBA;

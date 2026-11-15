separate (Terminal.App.Graphics.Media_Decoders)
procedure Decode_Sixel_Raster
  (Text   : String;
   Info   : Sixel_Info;
   Result : in out Graphics_Data_Preview)
is
   pragma Unreferenced (Info);
   procedure Capture_Row
     (Y        : Natural;
      Row      : Terminal.Common.Bytes.Byte_Array;
      Continue : in out Boolean) is
   begin
      Preview_Storage.Capture_RGBA_Row (Result, Y, Row, Continue);
   end Capture_Row;
begin
   Decode_Sixel_Rows (Text, Capture_Row'Access, Result);
   if Result.Decode_Complete
     and then not Preview_Storage.RGBA_Rows_Complete (Result)
   then
      Preview_Storage.Set_Decode_Failure (Result, Decode_Invalid_Data);
   end if;
end Decode_Sixel_Raster;

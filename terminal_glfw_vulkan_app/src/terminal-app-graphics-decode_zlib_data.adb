separate (Terminal.App.Graphics)
   procedure Decode_Zlib_Data
     (Compressed      : Terminal.Common.Bytes.Byte_Array;
      Length          : Natural;
      Maximum_Length  : Natural;
      Exact_Length    : Boolean;
      Inflated        : out Terminal.App.Render_Model.Image_Data_Access;
      Inflated_Length : out Natural;
      Status          : out Data_Decode_Status)
   is
      Decoder : Terminal.App.Zlib_Inflation.Decoder;
      Continue : Boolean := True;
   begin
      Inflated := null;
      Inflated_Length := 0;
      Status := Decode_Invalid_Byte;
      if Length = 0
        or else Length > Compressed'Length
      then
         return;
      end if;
      Terminal.App.Zlib_Inflation.Start
        (Decoder, Maximum_Length, Exact_Length, Status);
      if Status /= Decode_Ok then
         return;
      end if;
      for I in 0 .. Length - 1 loop
         Terminal.App.Zlib_Inflation.Push
           (Decoder, Compressed (Compressed'First + I), Continue);
         exit when not Continue;
      end loop;
      Terminal.App.Zlib_Inflation.Finish
        (Decoder, Inflated, Inflated_Length, Status);
   end Decode_Zlib_Data;


separate (Terminal.App.Renderer)
function Decode_Colour_PNG
  (Data   : Textrender.Encoded_Image;
   Width  : Natural;
   Height : Natural;
   Pixels : out Textrender.Rgba_Buffer)
   return Boolean
is
   Result : Terminal.App.Graphics.Graphics_Data_Preview;
   Pixels_Expected : Natural := 0;
   Pixel_Count : Natural := 0;
begin
   if Data'Length = 0
     or else Width = 0
     or else Height = 0
     or else not Terminal.App.Size_Arithmetic.Try_Multiply
       (Width, Height, Pixel_Count)
     or else not Terminal.App.Size_Arithmetic.Try_Multiply
       (Pixel_Count, 4, Pixels_Expected)
     or else Pixels'Length /= Pixels_Expected
   then
      return False;
   end if;

   declare
      Source : Terminal.Common.Bytes.Byte_Array (1 .. Data'Length);
   begin
      for I in Data'Range loop
         Source (I - Data'First + 1) :=
           Terminal.Common.Bytes.Byte (Data (I));
      end loop;

      Terminal.App.Graphics.Decode_PNG_RGBA_Data
        (PNG    => Source,
         Length => Source'Length,
         Result => Result);
   end;

   if Result.Decode_Status /= Terminal.App.Graphics.Decode_Ok
     or else not Result.Decode_Complete
     or else Result.Pixel_Width /= Width
     or else Result.Pixel_Height /= Height
     or else Result.Decoded_Length /= Pixels'Length
     or else Result.Bytes = null
   then
      Terminal.App.Graphics.Release (Result);
      return False;
   end if;

   for I in Pixels'Range loop
      Pixels (I) :=
        Textrender.Alpha
          (Result.Bytes (Result.Bytes'First + I - Pixels'First));
   end loop;

   Terminal.App.Graphics.Release (Result);
   return True;
exception
   when Storage_Error =>
      Terminal.App.Graphics.Release (Result);
      return False;
   when others =>
      Terminal.App.Graphics.Release (Result);
      raise;
end Decode_Colour_PNG;

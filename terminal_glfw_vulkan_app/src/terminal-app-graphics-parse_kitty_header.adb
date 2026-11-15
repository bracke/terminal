separate (Terminal.App.Graphics)
function Parse_Kitty_Header (Text : String) return Graphics_Header is
   Result      : Graphics_Header (Kitty);
   Header_Last : Natural;
begin
   if Text = "" or else Text (Text'First) /= 'G' then
      return Result;
   end if;

   Result.Recognized := True;
   Header_Last := Text'Last;
   for I in Text'Range loop
      if Text (I) = ';' then
         Header_Last := I - 1;
         Result.Has_Data := I < Text'Last;
         exit;
      end if;
   end loop;

   if Header_Last > Text'First then
      Kitty_Validation.Parse_Header
        (Params   => Text (Text'First + 1 .. Header_Last),
         Has_Data => Result.Has_Data,
         Result   => Result);
   else
      --  Empty control data is valid. The protocol defaults are a direct,
      --  uncompressed 32-bit transmission with action 't'.
      Kitty_Validation.Parse_Header
        (Params => "", Has_Data => Result.Has_Data, Result => Result);
   end if;
   return Result;
end Parse_Kitty_Header;

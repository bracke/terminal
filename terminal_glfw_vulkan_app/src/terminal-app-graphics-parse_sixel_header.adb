separate (Terminal.App.Graphics)
function Parse_Sixel_Header (Text : String) return Graphics_Header is
   Result : Graphics_Header (Sixel);
begin
   if Text = "" then
      return Result;
   end if;
            Result.Recognized := Text (Text'First) = 'q'
              or else Text (Text'First) in '0' .. '9'
              or else Text (Text'First) = '?';
            Result.Has_Data := Text'Length > 0;
            if Result.Recognized then
               declare
                  Info : constant Sixel_Info := Analyze_Sixel (Text);
               begin
                  Result.Raw_Format := (if Info.Width > 0 then 32 else 0);
                  Result.Pixel_Width := Info.Width;
                  Result.Pixel_Height := Info.Height;
                  Result.Sixel_Transparent := Info.Transparent;
               end;
            end if;
   return Result;
end Parse_Sixel_Header;

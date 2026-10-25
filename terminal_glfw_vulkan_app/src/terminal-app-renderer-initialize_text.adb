separate (Terminal.App.Renderer)
procedure Initialize_Text
  (R      : in out Renderer;
   Status  : out Init_Status)
is
   Font_Path   : constant String := Terminal.App.Fonts.Default_Font_Path;
   Text_Status : Textrender.Status_Code;
   Shape_Backend_Status : Terminal.App.Text_Shaper.Backend_Status;
begin
   R.CW := 8;
   R.CH := 16;
   R.Glyph_Count := 0;
   R.Colour_Glyph_Count := 0;
   R.Shaped_Glyph_Count := 0;
   R.Shaping_Fallback_Count := 0;
   R.Text_Fallback_Run_Count := 0;
   R.Color_Glyph_Count := 0;
   R.Color_Emoji_Fallback_Count := 0;
   R.Paragraph_Bidi_Fallback_Count := 0;
   R.Missing_Glyph_Count := 0;
   R.Rectangle_Count := 0;
   R.Vertex_Count := 0;
   R.Last_Cell_Count := 0;
   R.Last_Dirty_Rows := 0;
   R.Last_Frame_Width := 0;
   R.Last_Frame_Height := 0;
   R.Atlas_Dirty := False;
   R.Colour_Sheet_Dirty := False;

   if Font_Path = "" then
      R.Initialized := False;
      R.Text_Loaded := False;
      Status := Failed;
      return;
   end if;

   Text_Status :=
     Textrender.Load_Font
       (R            => R.Text,
        Path         => Font_Path,
        Pixel_Size   => Pixel_Size,
        Cell_Width   => R.CW,
        Cell_Height  => R.CH,
        Atlas_Width  => Atlas_Width,
        Atlas_Height => Atlas_Height);

   if Text_Status /= Textrender.Success then
      R.Initialized := False;
      R.Text_Loaded := False;
      Status := Failed;
      return;
   end if;

   Terminal.App.Text_Shaper.Configure_Font
     (Path       => Font_Path,
      Pixel_Size => Pixel_Size,
      Status     => Shape_Backend_Status);

   declare
      Measured_CW : constant Positive :=
        Measured_Cell_Width (R.Text, R.CW);
   begin
      if Measured_CW /= R.CW then
         R.CW := Measured_CW;
         Text_Status :=
           Textrender.Load_Font
             (R            => R.Text,
              Path         => Font_Path,
              Pixel_Size   => Pixel_Size,
              Cell_Width   => R.CW,
              Cell_Height  => R.CH,
              Atlas_Width  => Atlas_Width,
              Atlas_Height => Atlas_Height);

         if Text_Status /= Textrender.Success then
            R.Initialized := False;
            R.Text_Loaded := False;
            Status := Failed;
            return;
         end if;

         Terminal.App.Text_Shaper.Configure_Font
           (Path       => Font_Path,
            Pixel_Size => Pixel_Size,
            Status     => Shape_Backend_Status);
      end if;
   end;

   Textrender.Set_Image_Decoder
     (R      => R.Text,
      Extent => Colour_PNG_Extent'Access,
      Decode => Decode_Colour_PNG'Access);

   R.CH := Positive'Max
     (R.CH, Ceiling_Positive (Textrender.Line_Height (R.Text)));

   for Path of Terminal.App.Fonts.Fallback_Font_Paths loop
      declare
         Fallback_Status : constant Textrender.Status_Code :=
           Textrender.Add_Fallback_Font
             (R    => R.Text,
              Path => Terminal.App.Fonts.To_String (Path));
      begin
         if Fallback_Status = Textrender.Success then
            Terminal.App.Text_Shaper.Add_Fallback_Font
              (Path       => Terminal.App.Fonts.To_String (Path),
               Pixel_Size => Pixel_Size,
               Status     => Shape_Backend_Status);
         end if;
      end;
   end loop;

   declare
      Ignored : constant Textrender.Status_Code :=
        Textrender.Preload
          (R     => R.Text,
           First => 32,
           Last  => 126);
   begin
      null;
   end;

   R.Initialized := True;
   R.Text_Loaded := True;
   R.Atlas_Dirty := Textrender.Atlas_Dirty (R.Text);
   Status := Ok;
end Initialize_Text;

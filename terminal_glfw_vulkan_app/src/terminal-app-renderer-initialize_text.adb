separate (Terminal.App.Renderer)
procedure Initialize_Text
  (R      : in out Renderer;
   Font_Path : String;
   Font_Pixel_Size : Positive;
   Bold_Font_Path : String;
   Italic_Font_Path : String;
   Bold_Italic_Font_Path : String;
   Font_Features : String;
   Font_Variations : String;
   Status  : out Init_Status)
is
   Effective_Font_Path : constant String :=
     (if Font_Path'Length = 0
      then Terminal.App.Fonts.Default_Font_Path
      else Font_Path);
   Text_Status : Textrender.Status_Code;
   Shape_Backend_Status : Terminal.App.Text_Shaper.Backend_Status;
   Effective_Bold : constant String :=
     (if Bold_Font_Path = "" then Effective_Font_Path else Bold_Font_Path);
   Effective_Italic : constant String :=
     (if Italic_Font_Path = "" then Effective_Font_Path else Italic_Font_Path);
   Effective_Bold_Italic : constant String :=
     (if Bold_Italic_Font_Path = "" then Effective_Font_Path
      else Bold_Italic_Font_Path);
   procedure Add_Style_Font (Path : String) is
      Result : constant Textrender.Status_Code :=
        Textrender.Add_Fallback_Font (R.Text_State.Text, Path);
   begin
      if Result /= Textrender.Success then
         raise Constraint_Error with "style font load failed";
      end if;
   end Add_Style_Font;
begin
   R.Text_State.CW := 8;
   R.Text_State.CH := 16;
   Frame_Lifecycle.Reset_Counters (R);
   R.Text_State.Atlas_Dirty := False;
   R.Text_State.Colour_Sheet_Dirty := False;

   if Effective_Font_Path = "" then
      R.Lifecycle.Initialized := False;
      R.Text_State.Text_Loaded := False;
      Status := Failed;
      return;
   end if;

   Text_Status :=
     Textrender.Load_Font
       (R            => R.Text_State.Text,
        Path         => Effective_Font_Path,
        Pixel_Size   => Font_Pixel_Size,
        Cell_Width   => R.Text_State.CW,
        Cell_Height  => R.Text_State.CH,
        Atlas_Width  => Atlas_Width,
        Atlas_Height => Atlas_Height);

   if Text_Status /= Textrender.Success then
      R.Lifecycle.Initialized := False;
      R.Text_State.Text_Loaded := False;
      Status := Failed;
      return;
   end if;

   Terminal.App.Text_Shaper.Configure_Font
     (Item   => R.Text_State.Shaper,
      Path   => Effective_Font_Path,
      Status => Shape_Backend_Status);

   declare
      Measured_CW : constant Positive :=
        Measured_Cell_Width (R.Text_State.Text, R.Text_State.CW);
   begin
      if Measured_CW /= R.Text_State.CW then
         R.Text_State.CW := Measured_CW;
         Text_Status :=
           Textrender.Load_Font
             (R            => R.Text_State.Text,
              Path         => Effective_Font_Path,
              Pixel_Size   => Font_Pixel_Size,
              Cell_Width   => R.Text_State.CW,
              Cell_Height  => R.Text_State.CH,
              Atlas_Width  => Atlas_Width,
              Atlas_Height => Atlas_Height);

         if Text_Status /= Textrender.Success then
            R.Lifecycle.Initialized := False;
            R.Text_State.Text_Loaded := False;
            Status := Failed;
            return;
         end if;

         Terminal.App.Text_Shaper.Configure_Font
           (Item   => R.Text_State.Shaper,
            Path   => Effective_Font_Path,
            Status => Shape_Backend_Status);
      end if;
   end;

   Textrender.Set_Image_Decoder
     (R      => R.Text_State.Text,
      Extent => Colour_PNG_Extent'Access,
      Decode => Decode_Colour_PNG'Access);

   begin
      Add_Style_Font (Effective_Bold);
      Add_Style_Font (Effective_Italic);
      Add_Style_Font (Effective_Bold_Italic);
   exception
      when Constraint_Error =>
         R.Lifecycle.Initialized := False;
         R.Text_State.Text_Loaded := False;
         Status := Failed;
         return;
   end;
   Terminal.App.Text_Shaper.Configure_Style_Fonts
     (R.Text_State.Shaper, Effective_Bold, Effective_Italic,
      Effective_Bold_Italic,
      Bold_Font_Path /= "", Italic_Font_Path /= "",
      Bold_Italic_Font_Path /= "",
      Font_Features, Font_Variations,
      Shape_Backend_Status);
   if Shape_Backend_Status /= Terminal.App.Text_Shaper.Backend_Ok then
      R.Lifecycle.Initialized := False;
      R.Text_State.Text_Loaded := False;
      Status := Failed;
      return;
   end if;

   R.Text_State.CH := Positive'Max
     (R.Text_State.CH, Ceiling_Positive (Textrender.Line_Height (R.Text_State.Text)));

   for Path of Terminal.App.Fonts.Fallback_Font_Paths loop
      declare
         Fallback_Status : constant Textrender.Status_Code :=
           Textrender.Add_Fallback_Font
             (R    => R.Text_State.Text,
              Path => Terminal.App.Fonts.To_String (Path));
      begin
         if Fallback_Status = Textrender.Success then
            Terminal.App.Text_Shaper.Add_Fallback_Font
              (Item   => R.Text_State.Shaper,
               Path   => Terminal.App.Fonts.To_String (Path),
               Status => Shape_Backend_Status);
         end if;
      end;
   end loop;

   declare
      Ignored : constant Textrender.Status_Code :=
        Textrender.Preload
          (R     => R.Text_State.Text,
           First => 32,
           Last  => 126);
   begin
      null;
   end;

   R.Lifecycle.Initialized := True;
   R.Text_State.Text_Loaded := True;
   R.Text_State.Atlas_Dirty := Textrender.Atlas_Dirty (R.Text_State.Text);
   Status := Ok;
end Initialize_Text;

separate (Terminal.App.Renderer)
function Last_Frame (R : Renderer) return RM.Frame_Commands is
   Pixels : constant access constant Textrender.Alpha_Buffer :=
     (if R.Text_Loaded then Textrender.Atlas_Pixels (R.Text) else null);
   Address : constant System.Address :=
     (if Pixels = null then System.Null_Address else Pixels.all'Address);
   Width   : constant Natural :=
     (if R.Text_Loaded then Textrender.Atlas_Width (R.Text) else 0);
   Height  : constant Natural :=
     (if R.Text_Loaded then Textrender.Atlas_Height (R.Text) else 0);
begin
   return
     (Width           => R.Last_Frame_Width,
      Height          => R.Last_Frame_Height,
      Rectangles      => RM.Rectangle_Array_View (R.Rectangles),
      Rectangle_Count => R.Rectangle_Count,
      Glyphs          => RM.Glyph_Array_View (R.Glyphs),
      Glyph_Count     => R.Glyph_Count,
      Colour_Glyphs   => RM.Colour_Glyph_Array_View (R.Colour_Glyphs),
      Colour_Glyph_Count => R.Colour_Glyph_Count,
      Colour_Sheet_Width => Textrender.Colour_Sheet_Width (R.Text),
      Colour_Sheet_Height => Textrender.Colour_Sheet_Height (R.Text),
      Colour_Sheet_Pixels =>
        (if Textrender.Colour_Sheet_Pixels (R.Text) = null
         then System.Null_Address
         else Textrender.Colour_Sheet_Pixels (R.Text).all'Address),
      Colour_Sheet_Dirty => R.Colour_Sheet_Dirty,
      Images          => Frame_Image_Commands (R),
      Image_Count     => Frame_Image_Count (R),
      Text_Runs       => RM.Text_Run_Array_View (R.Text_Runs),
      Text_Run_Count  => R.Text_Run_Count,
      Atlas_Width     => Width,
      Atlas_Height    => Height,
      Atlas_Pixels    => Address,
      Atlas_Bytes     => Width * Height,
      Atlas_Dirty     => R.Atlas_Dirty);
end Last_Frame;

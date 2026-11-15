separate (Terminal.App.Renderer)
function Last_Frame (R : Renderer) return RM.Frame_Commands is
   Pixels : constant access constant Textrender.Alpha_Buffer :=
     (if R.Text_State.Text_Loaded then Textrender.Atlas_Pixels (R.Text_State.Text) else null);
   Address : constant System.Address :=
     (if Pixels = null then System.Null_Address else Pixels.all'Address);
   Width   : constant Natural :=
     (if R.Text_State.Text_Loaded then Textrender.Atlas_Width (R.Text_State.Text) else 0);
   Height  : constant Natural :=
     (if R.Text_State.Text_Loaded then Textrender.Atlas_Height (R.Text_State.Text) else 0);
begin
   return
     (Width           => R.Frame_State.Last_Frame_Width,
      Height          => R.Frame_State.Last_Frame_Height,
      Rectangles      => RM.Rectangle_Array_View (R.Frame_State.Rectangles),
      Rectangle_Count => R.Frame_State.Rectangle_Count,
      Glyphs          => RM.Glyph_Array_View (R.Frame_State.Glyphs),
      Glyph_Count     => R.Frame_State.Glyph_Count,
      Colour_Glyphs   => RM.Colour_Glyph_Array_View (R.Frame_State.Colour_Glyphs),
      Colour_Glyph_Count => R.Frame_State.Colour_Glyph_Count,
      Colour_Sheet_Width => Textrender.Colour_Sheet_Width (R.Text_State.Text),
      Colour_Sheet_Height => Textrender.Colour_Sheet_Height (R.Text_State.Text),
      Colour_Sheet_Pixels =>
        (if Textrender.Colour_Sheet_Pixels (R.Text_State.Text) = null
         then System.Null_Address
         else Textrender.Colour_Sheet_Pixels (R.Text_State.Text).all'Address),
      Colour_Sheet_Bytes =>
        (if Textrender.Colour_Sheet_Pixels (R.Text_State.Text) = null
         then 0
         else Textrender.Colour_Sheet_Pixels (R.Text_State.Text).all'Length),
      Colour_Sheet_Dirty => R.Text_State.Colour_Sheet_Dirty,
      Images          => Image_Commands.Commands (R),
      Image_Count     => Image_Commands.Count (R),
      Text_Runs       => RM.Text_Run_Array_View (R.Frame_State.Text_Runs),
      Text_Run_Count  => R.Frame_State.Text_Run_Count,
      Atlas_Width     => Width,
      Atlas_Height    => Height,
      Atlas_Pixels    => Address,
      Atlas_Bytes     => Width * Height,
      Atlas_Dirty     => R.Text_State.Atlas_Dirty);
end Last_Frame;

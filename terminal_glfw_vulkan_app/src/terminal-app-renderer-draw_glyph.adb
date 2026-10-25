separate (Terminal.App.Renderer)
procedure Draw_Glyph
  (R         : in out Renderer;
   Codepoint : Terminal.Common.Code_Point;
   X         : Float;
   Y         : Float;
   Color     : RM.Pixel_Color;
   Bold      : Boolean;
   Italic    : Boolean;
   Status    : out Render_Status)
is
   Metric       : Textrender.Glyph_Metric;
   Glyph_Status : Textrender.Status_Code;
   Placement : Textrender.Glyph_Placement;
begin
   --  A codepoint the font holds as a picture leaves here as a tile rather
   --  than a glyph: the glyph atlas is one coverage channel, with nowhere to
   --  keep a colour. Tried first, because for such a codepoint the outline
   --  lookup below has nothing to find.
   if Add_Colour_Glyph (R, Codepoint, X, Y) then
      R.Color_Glyph_Count := R.Color_Glyph_Count + 1;
      Status := Ok;
      return;
   end if;

   if Is_Emoji_Scalar (Codepoint) then
      R.Color_Emoji_Fallback_Count := R.Color_Emoji_Fallback_Count + 1;
   end if;

   Glyph_Status :=
     Textrender.Get_Glyph
       (R     => R.Text,
        C     => Textrender.Codepoint (Natural (Codepoint)),
        M     => Metric,
        Style =>
          (if Italic then Textrender.Italic else Textrender.Regular));

   case Glyph_Status is
      when Textrender.Success | Textrender.Glyph_Missing =>
         if Glyph_Status = Textrender.Glyph_Missing then
            R.Missing_Glyph_Count := R.Missing_Glyph_Count + 1;
         end if;

         if Metric.W > 0 and then Metric.H > 0 then
            Placement :=
              Textrender.Place_Glyph_In_Cell
                (R      => R.Text,
                 M      => Metric,
                 Cell_X => X,
                 Cell_Y => Y);
            Add_Glyph
              (R,
               Placement => Placement,
               Metric    => Metric,
               Color     => Color,
               Codepoint => Natural (Codepoint));
            if Bold then
               Placement.X := Placement.X + 1.0;
               Add_Glyph
                 (R,
                  Placement => Placement,
                  Metric    => Metric,
                  Color     => Color,
                  Codepoint => Natural (Codepoint));
            end if;
         end if;
         Status := Ok;
      when others =>
         Status := Glyph_Load_Failed;
   end case;
end Draw_Glyph;

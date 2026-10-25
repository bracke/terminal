separate (Terminal.App.Renderer)
procedure Draw_Shaped_Run
  (R      : in out Renderer;
   Run    : RM.Text_Run_Command;
   Status : out Render_Status)
is
   Pen_X : Float :=
     (if Run.Direction = RM.Direction_Right_To_Left
      then Run.X + Run.Cell_Width * Float (Run.Cell_Span)
      else Run.X);
begin
   if Run.Shape_Status /= RM.Shape_Ok
     or else Run.Fallback_Glyphs
     or else Run.Shaped_Glyph_Count = 0
   then
      Status := Glyph_Load_Failed;
      return;
   end if;

   for I in 1 .. Run.Shaped_Glyph_Count loop
      declare
         Glyph : constant RM.Shaped_Glyph_Command := Run.Shaped_Glyphs (I);
         Advance_X : constant Float := Glyph.X_Advance;
         Step_X    : constant Float :=
           (if Run.Direction = RM.Direction_Right_To_Left
              and then Advance_X > 0.0
            then -Advance_X
            else Advance_X);
         Glyph_X   : constant Float :=
           (if Run.Direction = RM.Direction_Right_To_Left
            then Pen_X + Step_X
            else Pen_X);
         Metric : Textrender.Glyph_Metric;
         Glyph_Status : constant Textrender.Status_Code :=
           Textrender.Get_Glyph_By_Index
             (R           => R.Text,
              Glyph_Index => Glyph.Glyph_ID,
              M           => Metric,
              Font_Index  => Glyph.Font_Index,
              Style       =>
                (if Run.Italic then Textrender.Italic else Textrender.Regular));
      begin
         case Glyph_Status is
            when Textrender.Success | Textrender.Glyph_Missing =>
               if Glyph_Status = Textrender.Glyph_Missing then
                  R.Missing_Glyph_Count := R.Missing_Glyph_Count + 1;
               end if;

               if Metric.W > 0 and then Metric.H > 0 then
                  declare
                     Baseline_Y : constant Float :=
                       Run.Y + Textrender.Ascent (R.Text);
                     Placement  : Textrender.Glyph_Placement :=
                       (X => Glyph_X + Glyph.X_Offset + Metric.Bearing_X,
                        Y =>
                          Baseline_Y
                          - Metric.Bearing_Y
                          - Glyph.Y_Offset);
                  begin
                     Add_Glyph
                       (R,
                        Placement => Placement,
                        Metric    => Metric,
                        Color     => Run.Color,
                        Codepoint => Glyph.Codepoint);
                     if Run.Bold then
                        Placement.X := Placement.X + 1.0;
                        Add_Glyph
                          (R,
                           Placement => Placement,
                           Metric    => Metric,
                           Color     => Run.Color,
                           Codepoint => Glyph.Codepoint);
                     end if;
                  end;
               end if;
            when others =>
               Status := Glyph_Load_Failed;
               return;
         end case;

         if Run.Direction = RM.Direction_Right_To_Left then
            Pen_X := Glyph_X;
         else
            Pen_X := Pen_X + Step_X;
         end if;
      end;
   end loop;

   Status := Ok;
end Draw_Shaped_Run;

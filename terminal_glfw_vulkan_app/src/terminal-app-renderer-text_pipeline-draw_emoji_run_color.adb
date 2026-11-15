separate (Terminal.App.Renderer.Text_Pipeline)
function Draw_Emoji_Run_Color
  (R   : in out Renderer;
   Run : RM.Text_Run_Command)
   return Boolean
is
   Pen_X  : Float := Run.X;
   Drawn  : Natural := 0;
   Missed : Natural := 0;
begin
   if Run.Script /= RM.Script_Emoji then
      return False;
   end if;

   for I in 1 .. Run.Codepoint_Count loop
      declare
         C : constant Terminal.Common.Code_Point :=
           Terminal.Common.Code_Point (Run.Codepoints (I));
      begin
         if Is_Emoji_Scalar (C) then
            if Drawing_Commands.Add_Colour_Glyph (R, C, Pen_X, Run.Y) then
               R.Text_State.Color_Glyph_Count := R.Text_State.Color_Glyph_Count + 1;
               Drawn := Drawn + 1;
               Pen_X := Pen_X + Float (R.Text_State.CW * 2);
            else
               Missed := Missed + 1;
            end if;
         end if;
      end;
   end loop;

   R.Text_State.Color_Emoji_Fallback_Count :=
     R.Text_State.Color_Emoji_Fallback_Count + Missed;
   return Drawn > 0;
end Draw_Emoji_Run_Color;

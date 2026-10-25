separate (Terminal.App.Renderer)
procedure Reorder_Mixed_Bidi_Row
  (R     : in out Renderer;
   First : Positive;
   Last  : Natural;
   Right : Float)
is
   Base : RM.Text_Run_Direction := RM.Direction_Left_To_Right;
begin
   if Last < First then
      return;
   end if;

   for I in First .. Last loop
      if R.Text_Runs (I).Direction /= RM.Direction_Neutral then
         Base := R.Text_Runs (I).Direction;
         exit;
      end if;
   end loop;

   if Base = RM.Direction_Right_To_Left then
      declare
         Cursor : Float := Right;
      begin
         for I in First .. Last loop
            declare
               Width : constant Float :=
                 R.Text_Runs (I).Cell_Width
                 * Float (R.Text_Runs (I).Cell_Span);
            begin
               Cursor := Cursor - Width;
               R.Text_Runs (I).X := Cursor;
            end;
         end loop;
      end;
   else
      declare
         I : Natural := First;
      begin
         while I <= Last loop
            if R.Text_Runs (I).Direction = RM.Direction_Right_To_Left then
               declare
                  J : Natural := I;
                  Span_Left  : constant Float := R.Text_Runs (I).X;
                  Span_Right : Float := R.Text_Runs (I).X;
                  Cursor     : Float;
               begin
                  while J <= Last
                    and then R.Text_Runs (J).Direction =
                      RM.Direction_Right_To_Left
                  loop
                     Span_Right := R.Text_Runs (J).X
                       + R.Text_Runs (J).Cell_Width
                         * Float (R.Text_Runs (J).Cell_Span);
                     J := J + 1;
                  end loop;

                  Cursor := Span_Right;
                  for K in I .. J - 1 loop
                     declare
                        Width : constant Float :=
                          R.Text_Runs (K).Cell_Width
                          * Float (R.Text_Runs (K).Cell_Span);
                     begin
                        Cursor := Cursor - Width;
                        R.Text_Runs (K).X := Cursor;
                     end;
                  end loop;

                  if Cursor < Span_Left then
                     for K in I .. J - 1 loop
                        R.Text_Runs (K).X :=
                          R.Text_Runs (K).X + (Span_Left - Cursor);
                     end loop;
                  end if;

                  I := J;
               end;
            else
               I := I + 1;
            end if;
         end loop;
      end;
   end if;
end Reorder_Mixed_Bidi_Row;

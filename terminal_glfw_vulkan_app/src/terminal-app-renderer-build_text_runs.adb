separate (Terminal.App.Renderer)
procedure Build_Text_Runs
  (R        : in out Renderer;
   Snapshot : Terminal.Core.Render_Snapshot)
is
begin
   for Row in 1 .. Snapshot.Rows loop
      declare
         Col : Positive := 1;
         Row_Has_LTR : Boolean := False;
         Row_Has_RTL : Boolean := False;
         Row_Run_First : constant Positive := R.Text_Run_Count + 1;
      begin
         while Col <= Snapshot.Cols loop
            declare
               Cell : constant Terminal.Core.Cell :=
                 Terminal.Core.Cell_At (Snapshot, Row, Col);
               First : constant Positive := Col;
               Last  : Natural := Col;
            begin
               if Is_Drawable (Cell)
                 and then not Cell.Style.Conceal
                 and then Cell.Kind /= Terminal.Core.Wide_Continuation
               then
                  if Cell.Text.Width = Terminal.Core.Width_One
                    and then Cell.Text.Attachment_Count = 0
                    and then not Is_Block_Cursor (Snapshot, Row, Col)
                  then
                     declare
                        Run_Direction : RM.Text_Run_Direction;
                        Run_Script    : RM.Text_Run_Script;
                     begin
                        Cell_Properties (Cell, Run_Direction, Run_Script);
                        while Last < Snapshot.Cols
                          and then Last - First + 1
                                   < RM.Max_Text_Run_Codepoints
                          and then Cell_Joins_Run
                            (Snapshot, Row, Positive (Last + 1),
                             Cell, Run_Direction, Run_Script)
                        loop
                           Last := Last + 1;
                        end loop;
                     end;
                  end if;

                  Add_Text_Run
                    (R,
                     Snapshot  => Snapshot,
                     Row       => Row,
                     First_Col => First,
                     Last_Col  => Positive (Last),
                     X         =>
                       Float (Origin_X (R) + (First - 1) * R.CW),
                     Y         =>
                       Float (Origin_Y (R) + (Row - 1) * R.CH),
                     Width     => Float (R.CW),
                     Height    => Float (R.CH),
                     Color     =>
                       (if Is_Block_Cursor (Snapshot, Row, First)
                        then R.Color_Theme.Cursor_FG
                        else Foreground (R, Cell)));

                  if R.Text_Run_Count > 0 then
                     case R.Text_Runs (R.Text_Run_Count).Direction is
                        when RM.Direction_Left_To_Right =>
                           Row_Has_LTR := True;
                        when RM.Direction_Right_To_Left =>
                           Row_Has_RTL := True;
                        when RM.Direction_Neutral =>
                           null;
                     end case;
                  end if;

                  if Last + Cell_Column_Span (Cell) > Snapshot.Cols then
                     exit;
                  else
                     Col := Positive (Last + Cell_Column_Span (Cell));
                  end if;
               elsif Col = Snapshot.Cols then
                  exit;
               else
                  Col := Col + 1;
               end if;
            end;
         end loop;

         if Row_Has_LTR and then Row_Has_RTL then
            Reorder_Mixed_Bidi_Row
              (R,
               First => Row_Run_First,
               Last  => R.Text_Run_Count,
               Right =>
                 Float (Origin_X (R) + Snapshot.Cols * R.CW));
         end if;
      end;
   end loop;
end Build_Text_Runs;

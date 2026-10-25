separate (Terminal.App.Renderer)
procedure Synchronize_Graphics_Scroll
  (R        : in out Renderer;
   Snapshot : Terminal.Core.Render_Snapshot;
   Through  : Terminal.Core.Graphics_Scroll_Sequence)
is
   Previous : Conventional_Placement_Access := null;
   Current  : Conventional_Placement_Access := R.Conventional_Placements;
begin
   while Current /= null loop
      declare
         Next : constant Conventional_Placement_Access := Current.Next;
         Applies : constant Boolean :=
           Current.Stream_ID = Snapshot.Graphics_Stream
           and then Current.Alternate_Screen = Snapshot.Alternate_Screen
           and then Current.Screen_Generation = Snapshot.Screen_Generation;
         Delete_Current : Boolean := False;
      begin
         if Applies then
            if Current.Scroll_Sequence < Through
              and then Snapshot.Graphics_Scroll_Count =
                 Terminal.Core.Max_Graphics_Scroll_Events
              and then Current.Scroll_Sequence + 1 <
                Snapshot.Graphics_Scroll_Oldest
            then
               --  The renderer missed more mutations than the bounded core
               --  journal retains. Dropping the placement is deterministic
               --  and avoids drawing it at a silently incorrect location.
               Delete_Current := True;
            elsif Snapshot.Graphics_Scroll_Events /= null then
               for I in 1 .. Snapshot.Graphics_Scroll_Count loop
                  declare
                     Mutation : constant Terminal.Core.Graphics_Scroll_Event :=
                       Snapshot.Graphics_Scroll_Events (I);
                     Row_Last : constant Long_Long_Integer :=
                       Long_Long_Integer (Current.Row)
                       + Long_Long_Integer (Current.Rows) - 1;
                     Full_Primary : constant Boolean :=
                       not Snapshot.Alternate_Screen
                       and then Mutation.Top = 1
                       and then Mutation.Bottom = Snapshot.Rows;
                     Same_Clip : constant Boolean :=
                       Current.Clip_Top = Mutation.Top
                       and then Current.Clip_Bottom = Mutation.Bottom;
                     Entirely_Inside : constant Boolean :=
                       Current.Row >= Mutation.Top
                       and then Row_Last <=
                         Long_Long_Integer (Mutation.Bottom);
                     Move : constant Boolean :=
                       Current.Parent_Image_ID = 0
                       and then
                         (Entirely_Inside
                          or else Same_Clip
                          or else
                            (Full_Primary
                             and then Current.History_Attached
                             and then Mutation.Direction =
                               Terminal.Core.Graphics_Scroll_Up));
                  begin
                     if Mutation.Sequence > Current.Scroll_Sequence
                       and then Mutation.Sequence <= Through
                       and then Move
                     then
                        if Mutation.Direction =
                          Terminal.Core.Graphics_Scroll_Up
                        then
                           Current.Row := Current.Row - Mutation.Count;
                           if Full_Primary then
                              Current.History_Attached := True;
                           end if;
                        else
                           Current.Row := Current.Row + Mutation.Count;
                        end if;
                        if Mutation.Top /= 1
                          or else Mutation.Bottom /= Snapshot.Rows
                        then
                           Current.Clip_Top := Mutation.Top;
                           Current.Clip_Bottom := Mutation.Bottom;
                        end if;
                     end if;
                     if Mutation.Sequence > Current.Scroll_Sequence
                       and then Mutation.Sequence <= Through
                     then
                        Current.Scroll_Sequence := Mutation.Sequence;
                     end if;
                  end;
               end loop;
            end if;

            if not Delete_Current then
               declare
                  Row_Last : constant Long_Long_Integer :=
                    Long_Long_Integer (Current.Row)
                    + Long_Long_Integer (Current.Rows) - 1;
               begin
                  if Current.Clip_Top > 0
                    and then
                      (Row_Last < Long_Long_Integer (Current.Clip_Top)
                       or else Current.Row > Current.Clip_Bottom)
                  then
                     Delete_Current := True;
                  elsif Current.History_Attached
                    and then Row_Last <
                      1 - Long_Long_Integer (Snapshot.Scrollback_Rows)
                  then
                     Delete_Current := True;
                  elsif Snapshot.Alternate_Screen
                    and then
                      (Row_Last < 1 or else Current.Row > Snapshot.Rows)
                  then
                     Delete_Current := True;
                  end if;
               end;
            end if;
         end if;

         if Delete_Current then
            if Previous = null then
               R.Conventional_Placements := Next;
            else
               Previous.Next := Next;
            end if;
            Free_Conventional_Placement (Current);
            R.Kitty_Placement_Count := R.Kitty_Placement_Count - 1;
            R.Placement_Index_Dirty := True;
         else
            Previous := Current;
         end if;
         Current := Next;
      end;
   end loop;
   Delete_Orphaned_Relative_Placements (R, Snapshot.Graphics_Stream);
end Synchronize_Graphics_Scroll;

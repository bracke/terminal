with Terminal.App.Renderer.Image_Objects;
with Terminal.App.Renderer.Placement_Operations;
with Terminal.App.Renderer.Placement_State;
with Terminal.Common.Modular_Ordering;

package body Terminal.App.Renderer.Graphics_Synchronization is
   package Placements renames Terminal.App.Renderer.Placement_State;
   package Scroll_Order is new Terminal.Common.Modular_Ordering
     (Terminal.Core.Graphics_Scroll_Sequence);

   use type Terminal.Core.Graphics_ID;
   use type Terminal.Core.Graphics_Screen_Generation;
   use type Terminal.Core.Graphics_Scroll_Direction;
   use type Terminal.Core.Graphics_Scroll_Sequence;
   use type Terminal.Core.Graphics_Stream_ID;

   function Next_Scroll_Sequence
     (Value : Terminal.Core.Graphics_Scroll_Sequence)
      return Terminal.Core.Graphics_Scroll_Sequence
   is
      Candidate : constant Terminal.Core.Graphics_Scroll_Sequence := Value + 1;
   begin
      --  Zero is the uninitialized sentinel, so the core skips it at rollover.
      return (if Candidate = 0 then 1 else Candidate);
   end Next_Scroll_Sequence;

   procedure Delete_Orphaned_Relative_Placements
     (R                 : in out Renderer;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Preserve_Image_ID : Terminal.Core.Graphics_ID := 0;
      Delete_Data       : Boolean := False)
   is
      Removed : Boolean;
   begin
      loop
         Removed := False;
         declare
            Position : Placements.Conventional_Cursor :=
              Placements.First_Conventional (R);
         begin
            while Placements.Has_Element (Position) loop
               declare
                  Current : constant Conventional_Placement_State :=
                    Placements.Element (Position);
               begin
                  if Current.Stream_ID = Stream_ID
                    and then Current.Parent_Image_ID /= 0
                    and then not Placements.Parent_Placement_Exists
                      (R,
                       Stream_ID,
                       Current.Alternate_Screen,
                       Current.Screen_Generation,
                       Current.Parent_Image_ID,
                       Current.Parent_Placement_ID)
                  then
                     declare
                        Child_Image_ID : constant Terminal.Core.Graphics_ID :=
                          Current.Image_ID;
                     begin
                        Placements.Delete (R, Position);
                        if Delete_Data
                          and then Child_Image_ID /= Preserve_Image_ID
                          and then not Placements.Has_Image_Placement
                            (R, Stream_ID, Child_Image_ID)
                        then
                           Image_Objects.Delete_Object
                             (R, Stream_ID, Child_Image_ID);
                        end if;
                        Removed := True;
                        exit;
                     end;
                  end if;
                  Placements.Advance (Position);
               end;
            end loop;
         end;
         exit when not Removed;
      end loop;
   end Delete_Orphaned_Relative_Placements;

   procedure Synchronize_Screen
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot)
   is
      Position : Placements.Conventional_Cursor :=
        Placements.First_Conventional (R);

      procedure Advance_Virtual
        (Placement : in out Virtual_Placement_State) is
      begin
         if Placement.Stream_ID = Snapshot.Graphics_Stream
           and then Placement.Alternate_Screen = Snapshot.Alternate_Screen
           and then Placement.Screen_Generation /= Snapshot.Screen_Generation
         then
            Placement.Screen_Generation := Snapshot.Screen_Generation;
         end if;
      end Advance_Virtual;

      procedure Advance_Conventional
        (Placement : in out Conventional_Placement_State) is
      begin
         if Placement.Stream_ID = Snapshot.Graphics_Stream
           and then Placement.Alternate_Screen = Snapshot.Alternate_Screen
           and then Placement.Screen_Generation /= Snapshot.Screen_Generation
         then
            Placement.Screen_Generation := Snapshot.Screen_Generation;
         end if;
      end Advance_Conventional;
   begin
      Placements.Update_All (R, Advance_Virtual'Access);
      while Placements.Has_Element (Position) loop
         declare
            Current : constant Conventional_Placement_State :=
              Placements.Element (Position);
            Stale : constant Boolean :=
              Current.Stream_ID = Snapshot.Graphics_Stream
              and then Current.Alternate_Screen = Snapshot.Alternate_Screen
              and then Current.Screen_Generation /= Snapshot.Screen_Generation;
         begin
            if Stale then
               declare
                  Origin_Row : Integer := 0;
                  Origin_Col : Integer := 0;
                  Resolved : constant Boolean :=
                    Placement_Operations.Resolve_Conventional_Placement_Origin
                      (R, Snapshot, Current, Origin_Row, Origin_Col);
                  Row_Last : constant Long_Long_Integer :=
                    Long_Long_Integer (Origin_Row)
                    + Long_Long_Integer (Current.Rows) - 1;
                  Col_Last : constant Long_Long_Integer :=
                    Long_Long_Integer (Origin_Col)
                    + Long_Long_Integer (Current.Columns) - 1;
                  Visible : constant Boolean :=
                    Resolved
                    and then Origin_Row <= Snapshot.Rows
                    and then Origin_Col <= Snapshot.Cols
                    and then Row_Last >= 1
                    and then Col_Last >= 1;
               begin
                  if Visible then
                     Placements.Delete (R, Position);
                  else
                     Placements.Advance (Position);
                  end if;
               end;
            else
               Placements.Advance (Position);
            end if;
         end;
      end loop;
      Placements.Update_All (R, Advance_Conventional'Access);
   end Synchronize_Screen;

   procedure Synchronize_Scroll
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot;
      Through  : Terminal.Core.Graphics_Scroll_Sequence)
   is
      Position : Placements.Conventional_Cursor :=
        Placements.First_Conventional (R);
   begin
      while Placements.Has_Element (Position) loop
         declare
            Current : constant Conventional_Placement_State :=
              Placements.Element (Position);
            Applies : constant Boolean :=
              Current.Stream_ID = Snapshot.Graphics_Stream
              and then Current.Alternate_Screen = Snapshot.Alternate_Screen
              and then Current.Screen_Generation = Snapshot.Screen_Generation;
            Delete_Current : Boolean := False;

            procedure Apply_Mutations
              (Placement : in out Conventional_Placement_State) is
            begin
               for I in 1 .. Snapshot.Graphics_Scroll_Count loop
                  declare
                     Mutation : constant Terminal.Core.Graphics_Scroll_Event :=
                       Terminal.Core.Graphics_Scroll_Event_At (Snapshot, I);
                     Row_Last : constant Long_Long_Integer :=
                       Long_Long_Integer (Placement.Row)
                       + Long_Long_Integer (Placement.Rows) - 1;
                     Full_Primary : constant Boolean :=
                       not Snapshot.Alternate_Screen
                       and then Mutation.Top = 1
                       and then Mutation.Bottom = Snapshot.Rows;
                     Same_Clip : constant Boolean :=
                       Placement.Clip_Top = Mutation.Top
                       and then Placement.Clip_Bottom = Mutation.Bottom;
                     Entirely_Inside : constant Boolean :=
                       Placement.Row >= Mutation.Top
                       and then Row_Last <= Long_Long_Integer (Mutation.Bottom);
                     Move : constant Boolean :=
                       Placement.Parent_Image_ID = 0
                       and then
                         (Entirely_Inside
                          or else Same_Clip
                          or else
                            (Full_Primary
                             and then Placement.History_Attached
                             and then Mutation.Direction =
                               Terminal.Core.Graphics_Scroll_Up));
                  begin
                     if Scroll_Order.After
                       (Mutation.Sequence, Placement.Scroll_Sequence)
                       and then Scroll_Order.At_Or_Before
                         (Mutation.Sequence, Through)
                       and then Move
                     then
                        if Mutation.Direction = Terminal.Core.Graphics_Scroll_Up
                        then
                           Placement.Row := Placement.Row - Mutation.Count;
                           if Full_Primary then
                              Placement.History_Attached := True;
                           end if;
                        else
                           Placement.Row := Placement.Row + Mutation.Count;
                        end if;
                        if Mutation.Top /= 1
                          or else Mutation.Bottom /= Snapshot.Rows
                        then
                           Placement.Clip_Top := Mutation.Top;
                           Placement.Clip_Bottom := Mutation.Bottom;
                        end if;
                     end if;
                     if Scroll_Order.After
                       (Mutation.Sequence, Placement.Scroll_Sequence)
                       and then Scroll_Order.At_Or_Before
                         (Mutation.Sequence, Through)
                     then
                        Placement.Scroll_Sequence := Mutation.Sequence;
                     end if;
                  end;
               end loop;
            end Apply_Mutations;
         begin
            if Applies then
               if Scroll_Order.After (Through, Current.Scroll_Sequence)
                 and then Snapshot.Graphics_Scroll_Count =
                   Terminal.Core.Max_Graphics_Scroll_Events
                 and then Scroll_Order.After
                   (Snapshot.Graphics_Scroll_Oldest,
                    Next_Scroll_Sequence (Current.Scroll_Sequence))
               then
                  Delete_Current := True;
               elsif Terminal.Core.Has_Graphics_Scroll_Events (Snapshot) then
                  Placements.Update (R, Position, Apply_Mutations'Access);
               end if;
               if not Delete_Current then
                  declare
                     Updated : constant Conventional_Placement_State :=
                       Placements.Element (Position);
                     Row_Last : constant Long_Long_Integer :=
                       Long_Long_Integer (Updated.Row)
                       + Long_Long_Integer (Updated.Rows) - 1;
                  begin
                     if Updated.Clip_Top > 0
                       and then
                         (Row_Last < Long_Long_Integer (Updated.Clip_Top)
                          or else Updated.Row > Updated.Clip_Bottom)
                     then
                        Delete_Current := True;
                     elsif Updated.History_Attached
                       and then Row_Last <
                         1 - Long_Long_Integer (Snapshot.Scrollback_Rows)
                     then
                        Delete_Current := True;
                     elsif Snapshot.Alternate_Screen
                       and then
                         (Row_Last < 1 or else Updated.Row > Snapshot.Rows)
                     then
                        Delete_Current := True;
                     end if;
                  end;
               end if;
            end if;
            if Delete_Current then
               Placements.Delete (R, Position);
            else
               Placements.Advance (Position);
            end if;
         end;
      end loop;
      Delete_Orphaned_Relative_Placements (R, Snapshot.Graphics_Stream);
   end Synchronize_Scroll;
end Terminal.App.Renderer.Graphics_Synchronization;

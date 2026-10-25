separate (Terminal.App.Renderer)
procedure Synchronize_Graphics_Screen
  (R        : in out Renderer;
   Snapshot : Terminal.Core.Render_Snapshot)
is
   Virtual_Previous : Virtual_Placement_Access := null;
   Virtual_Current  : Virtual_Placement_Access := R.Virtual_Placements;
   Conventional_Previous : Conventional_Placement_Access := null;
   Conventional_Current  : Conventional_Placement_Access :=
     R.Conventional_Placements;
begin
   --  The core advances this generation whenever a full-screen clear or
   --  entry into the alternate buffer clears that buffer. Retire only the
   --  placements belonging to that logical screen; image data remains
   --  available for later placement commands.
   while Virtual_Current /= null loop
      declare
         Next : constant Virtual_Placement_Access := Virtual_Current.Next;
         Stale : constant Boolean :=
           Virtual_Current.Stream_ID = Snapshot.Graphics_Stream
           and then Virtual_Current.Alternate_Screen =
             Snapshot.Alternate_Screen
           and then Virtual_Current.Screen_Generation /=
             Snapshot.Screen_Generation;
      begin
         if Stale then
            --  Virtual placements are invisible prototypes.  Clearing the
            --  viewport removes their placeholder cells, but prototypes
            --  must remain available to placeholder cells retained in
            --  scrollback.
            Virtual_Current.Screen_Generation := Snapshot.Screen_Generation;
            R.Placement_Index_Dirty := True;
         end if;
         Virtual_Previous := Virtual_Current;
         Virtual_Current := Next;
      end;
   end loop;

   while Conventional_Current /= null loop
      declare
         Next : constant Conventional_Placement_Access :=
           Conventional_Current.Next;
         Stale : constant Boolean :=
           Conventional_Current.Stream_ID = Snapshot.Graphics_Stream
           and then Conventional_Current.Alternate_Screen =
             Snapshot.Alternate_Screen
           and then Conventional_Current.Screen_Generation /=
             Snapshot.Screen_Generation;
      begin
         if Stale then
            declare
               Origin_Row : Integer := 0;
               Origin_Col : Integer := 0;
               Resolved : constant Boolean :=
                 Resolve_Conventional_Placement_Origin
                   (R,
                    Snapshot,
                    Conventional_Current,
                    Origin_Row,
                    Origin_Col);
               Row_Last : constant Long_Long_Integer :=
                 Long_Long_Integer (Origin_Row)
                 + Long_Long_Integer (Conventional_Current.Rows) - 1;
               Col_Last : constant Long_Long_Integer :=
                 Long_Long_Integer (Origin_Col)
                 + Long_Long_Integer (Conventional_Current.Columns) - 1;
               Visible : constant Boolean :=
                 Resolved
                 and then Origin_Row <= Snapshot.Rows
                 and then Origin_Col <= Snapshot.Cols
                 and then Row_Last >= 1
                 and then Col_Last >= 1;
            begin
               if Visible then
                  if Conventional_Previous = null then
                     R.Conventional_Placements := Next;
                  else
                     Conventional_Previous.Next := Next;
                  end if;
                  Free_Conventional_Placement (Conventional_Current);
                  R.Kitty_Placement_Count := R.Kitty_Placement_Count - 1;
                  R.Placement_Index_Dirty := True;
               else
                  --  A screen clear has no effect on history that is no
                  --  longer visible.  Carry that placement into the new
                  --  generation so scrollback snapshots can still resolve
                  --  it.
                  Conventional_Current.Screen_Generation :=
                    Snapshot.Screen_Generation;
                  R.Placement_Index_Dirty := True;
                  Conventional_Previous := Conventional_Current;
               end if;
            end;
         else
            Conventional_Previous := Conventional_Current;
         end if;
         Conventional_Current := Next;
      end;
   end loop;
end Synchronize_Graphics_Screen;

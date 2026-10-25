separate (Terminal.App.Renderer.Apply_Image_Event)
procedure Apply_Deletion is
   Selector : constant Character :=
     (if Header.Kitty_Delete = ASCII.NUL
      then 'a'
      else Header.Kitty_Delete);
   Delete_Data : constant Boolean := Selector in 'A' .. 'Z';
begin
   case Selector is
      when 'a' | 'A' =>
         Delete_Visible_Conventional_Placements
           (R, Snapshot, Delete_Data);
      when 'i' | 'I' =>
         if Header.Kitty_ID > 0 then
            Delete_Virtual_Placements
              (R,
               Event.Stream_ID,
               Header.Kitty_ID,
               Header.Kitty_Placement_ID,
               Header.Kitty_Placement_ID > 0);
            Delete_Conventional_Placements
              (R,
               Event.Stream_ID,
               Header.Kitty_ID,
               Header.Kitty_Placement_ID,
               Header.Kitty_Placement_ID > 0);
            if Delete_Data
              and then not Has_Image_Placement
                (R, Event.Stream_ID, Header.Kitty_ID)
            then
               Delete_Image_Object
                 (R, Event.Stream_ID, Header.Kitty_ID);
            end if;
         end if;
      when 'n' | 'N' =>
         if Header.Kitty_ID > 0 then
            Delete_Virtual_Placements
              (R,
               Event.Stream_ID,
               Header.Kitty_ID,
               Header.Kitty_Placement_ID,
               Header.Kitty_Placement_ID > 0);
            Delete_Conventional_Placements
              (R,
               Event.Stream_ID,
               Header.Kitty_ID,
               Header.Kitty_Placement_ID,
               Header.Kitty_Placement_ID > 0);
            if Delete_Data
              and then not Has_Image_Placement
                (R, Event.Stream_ID, Header.Kitty_ID)
            then
               Delete_Image_Object
                 (R, Event.Stream_ID, Header.Kitty_ID);
            end if;
         end if;
      when 'z' | 'Z' =>
         Delete_Conventional_Placements_By_Z
           (R,
            Event.Stream_ID,
            Header.Kitty_Z_Index,
            Event.Alternate_Screen,
            Event.Screen_Generation,
            Delete_Data);
      when 'c' | 'C' =>
         Delete_Conventional_Placements_Intersecting
           (R,
            Event.Stream_ID,
            Event.Row,
            Event.Col,
            Match_Screen => True,
            Alternate_Screen => Event.Alternate_Screen,
            Screen_Generation => Event.Screen_Generation,
            Snapshot => Snapshot,
            Delete_Data => Delete_Data);
      when 'p' | 'P' | 'q' | 'Q' =>
         if Header.Kitty_Source_X > 0
           and then Header.Kitty_Source_Y > 0
         then
            Delete_Conventional_Placements_Intersecting
              (R,
               Event.Stream_ID,
               Positive (Header.Kitty_Source_Y),
               Positive (Header.Kitty_Source_X),
               Match_Z => Selector in 'q' | 'Q',
               Z_Index => Header.Kitty_Z_Index,
               Match_Screen => True,
               Alternate_Screen => Event.Alternate_Screen,
               Screen_Generation => Event.Screen_Generation,
               Snapshot => Snapshot,
               Delete_Data => Delete_Data);
         end if;
      when 'x' | 'X' =>
         if Header.Kitty_Source_X > 0 then
            Delete_Conventional_Placements_Intersecting
              (R,
               Stream_ID => Event.Stream_ID,
               Row       => 1,
               Col       => Positive (Header.Kitty_Source_X),
               Match_Row => False,
               Match_Screen => True,
               Alternate_Screen => Event.Alternate_Screen,
               Screen_Generation => Event.Screen_Generation,
               Snapshot => Snapshot,
               Delete_Data => Delete_Data);
         end if;
      when 'y' | 'Y' =>
         if Header.Kitty_Source_Y > 0 then
            Delete_Conventional_Placements_Intersecting
              (R,
               Stream_ID => Event.Stream_ID,
               Row       => Positive (Header.Kitty_Source_Y),
               Col       => 1,
               Match_Col => False,
               Match_Screen => True,
               Alternate_Screen => Event.Alternate_Screen,
               Screen_Generation => Event.Screen_Generation,
               Snapshot => Snapshot,
               Delete_Data => Delete_Data);
         end if;
      when 'r' | 'R' =>
         Delete_Image_ID_Range
           (R,
            Event.Stream_ID,
            Header.Kitty_Delete_Range_First,
            Header.Kitty_Delete_Range_Last,
            Delete_Data);
      when 'f' | 'F' =>
         if Header.Kitty_ID > 0 then
            declare
               Object : constant Image_Object_Access :=
                 Find_Image_Object
                   (R, Event.Stream_ID, Header.Kitty_ID);
            begin
               Delete_Animation_Frames (R, Object);
            end;
         end if;
      when others =>
         null;
   end case;
   Delete_Orphaned_Relative_Placements
     (R, Event.Stream_ID, Delete_Data => Delete_Data);
end Apply_Deletion;

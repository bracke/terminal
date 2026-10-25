separate (Terminal.App.Renderer)
procedure Delete_Orphaned_Relative_Placements
  (R                 : in out Renderer;
   Stream_ID         : Terminal.Core.Graphics_Stream_ID;
   Preserve_Image_ID : Terminal.Core.Graphics_ID := 0;
   Delete_Data       : Boolean := False)
is
   Removed : Boolean;
begin
   --  Removing a parent recursively removes its relative descendants.
   --  Process one orphan at a time because deleting its now-unreferenced
   --  image object can also unlink placements elsewhere in the list.
   loop
      Removed := False;
      declare
         Previous : Conventional_Placement_Access := null;
         Current  : Conventional_Placement_Access :=
           R.Conventional_Placements;
      begin
         while Current /= null loop
            if Current.Stream_ID = Stream_ID
              and then Current.Parent_Image_ID /= 0
              and then not Parent_Placement_Exists
                (R,
                 Stream_ID,
                 Current.Alternate_Screen,
                 Current.Screen_Generation,
                 Current.Parent_Image_ID,
                 Current.Parent_Placement_ID)
            then
               declare
                  Next : constant Conventional_Placement_Access :=
                    Current.Next;
                  Child_Image_ID : constant Terminal.Core.Graphics_ID :=
                    Current.Image_ID;
               begin
                  if Previous = null then
                     R.Conventional_Placements := Next;
                  else
                     Previous.Next := Next;
                  end if;
                  Free_Conventional_Placement (Current);
                  R.Kitty_Placement_Count := R.Kitty_Placement_Count - 1;
                  if Delete_Data
                    and then Child_Image_ID /= Preserve_Image_ID
                    and then not Has_Image_Placement
                      (R, Stream_ID, Child_Image_ID)
                  then
                     Delete_Image_Object (R, Stream_ID, Child_Image_ID);
                  end if;
                  Removed := True;
                  exit;
               end;
            end if;
            Previous := Current;
            Current := Current.Next;
         end loop;
      end;
      exit when not Removed;
   end loop;
end Delete_Orphaned_Relative_Placements;

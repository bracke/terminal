separate (Terminal.App.Renderer)
procedure Delete_Image_ID_Range
  (R           : in out Renderer;
   Stream_ID   : Terminal.Core.Graphics_Stream_ID;
   First_ID    : Terminal.Core.Graphics_ID;
   Last_ID     : Terminal.Core.Graphics_ID;
   Delete_Data : Boolean)
is
   Virtual_Previous : Virtual_Placement_Access := null;
   Virtual_Current  : Virtual_Placement_Access := R.Virtual_Placements;
   Conventional_Previous : Conventional_Placement_Access := null;
   Conventional_Current  : Conventional_Placement_Access :=
     R.Conventional_Placements;
   Object_Current : Image_Object_Access :=
     Terminal.App.Image_Store.First (R.Image_Objects);
begin
   if Last_ID < First_ID then
      return;
   end if;

   while Virtual_Current /= null loop
      declare
         Next : constant Virtual_Placement_Access := Virtual_Current.Next;
         ID : constant Terminal.Core.Graphics_ID :=
           Virtual_Current.Image_ID;
      begin
         if Virtual_Current.Stream_ID = Stream_ID
           and then ID >= First_ID and then ID <= Last_ID
         then
            if Virtual_Previous = null then
               R.Virtual_Placements := Next;
            else
               Virtual_Previous.Next := Next;
            end if;
            Free_Virtual_Placement (Virtual_Current);
            R.Kitty_Placement_Count := R.Kitty_Placement_Count - 1;
         else
            Virtual_Previous := Virtual_Current;
         end if;
         Virtual_Current := Next;
      end;
   end loop;

   while Conventional_Current /= null loop
      declare
         Next : constant Conventional_Placement_Access :=
           Conventional_Current.Next;
         ID : constant Terminal.Core.Graphics_ID :=
           Conventional_Current.Image_ID;
      begin
         if Conventional_Current.Stream_ID = Stream_ID
           and then Conventional_Current.Protocol = RM.Image_Kitty
           and then ID >= First_ID and then ID <= Last_ID
         then
            if Conventional_Previous = null then
               R.Conventional_Placements := Next;
            else
               Conventional_Previous.Next := Next;
            end if;
            Free_Conventional_Placement (Conventional_Current);
            R.Kitty_Placement_Count := R.Kitty_Placement_Count - 1;
         else
            Conventional_Previous := Conventional_Current;
         end if;
         Conventional_Current := Next;
      end;
   end loop;

   if Delete_Data then
      while Object_Current /= null loop
         declare
            Next : constant Image_Object_Access :=
              Terminal.App.Image_Store.Next_Object
                (Object_Current);
            ID : constant Terminal.Core.Graphics_ID := Object_Current.ID;
         begin
            if Object_Current.Stream_ID = Stream_ID
              and then Object_Current.Protocol = RM.Image_Kitty
              and then ID >= First_ID and then ID <= Last_ID
            then
               Delete_Image_Object_By_Storage_Order
                 (R, Stream_ID, Object_Current.Storage_Order);
            end if;
            Object_Current := Next;
         end;
      end loop;
   end if;
end Delete_Image_ID_Range;

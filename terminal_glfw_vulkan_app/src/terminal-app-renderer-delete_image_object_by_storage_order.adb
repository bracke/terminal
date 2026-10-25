separate (Terminal.App.Renderer)
procedure Delete_Image_Object_By_Storage_Order
  (R             : in out Renderer;
   Stream_ID     : Terminal.Core.Graphics_Stream_ID;
   Storage_Order : Interfaces.Unsigned_64;
   Counted       : Boolean := True)
is
   Current  : Image_Object_Access :=
     Terminal.App.Image_Store.First (R.Image_Objects);
   Virtual_Previous : Virtual_Placement_Access := null;
   Virtual_Current : Virtual_Placement_Access := R.Virtual_Placements;
   Conventional_Previous : Conventional_Placement_Access := null;
   Conventional_Current : Conventional_Placement_Access :=
     R.Conventional_Placements;
begin
   if Storage_Order = 0 then
      return;
   end if;

   while Current /= null loop
      exit when Current.Stream_ID = Stream_ID
        and then Current.Storage_Order = Storage_Order;
      Current :=
        Terminal.App.Image_Store.Next_Object (Current);
   end loop;
   if Current = null then
      return;
   end if;

   while Virtual_Current /= null loop
      declare
         Next : constant Virtual_Placement_Access := Virtual_Current.Next;
      begin
         if Virtual_Current.Stream_ID = Stream_ID
           and then Virtual_Current.Image_Storage_Order = Storage_Order
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
      begin
         if Conventional_Current.Stream_ID = Stream_ID
           and then Conventional_Current.Image_Storage_Order = Storage_Order
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
   if Counted then
      Terminal.App.Image_Store.Delete_Object (R.Image_Objects, Current);
   else
      Terminal.App.Image_Store.Delete_Replacement
        (R.Image_Objects, Current);
   end if;
end Delete_Image_Object_By_Storage_Order;

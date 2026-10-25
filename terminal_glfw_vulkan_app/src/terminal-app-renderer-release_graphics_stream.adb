separate (Terminal.App.Renderer)
procedure Release_Graphics_Stream
  (R         : in out Renderer;
   Stream_ID : Terminal.Core.Graphics_Stream_ID)
is
   Object_Current : Image_Object_Access :=
     Terminal.App.Image_Store.First (R.Image_Objects);
   Object_Next : Image_Object_Access;
   Palette_Previous : Sixel_Palette_Entry_Access := null;
   Palette_Current : Sixel_Palette_Entry_Access := R.Sixel_Palettes;
   Staged_Previous : Staged_Graphics_Event_Access := null;
   Staged_Current : Staged_Graphics_Event_Access :=
     R.Staged_Graphics_Events;
begin
   --  Image commands borrow decoded storage from retained image objects.
   --  Invalidate the current frame before releasing any object owned by
   --  this stream so diagnostics and callers cannot dereference stale
   --  preview pointers between stream teardown and the next render.
   Reset_Frame (R);
   R.Placement_Index_Dirty := True;

   Delete_Virtual_Placements (R, Stream_ID, 0);
   Delete_Conventional_Placements
     (R, Stream_ID, 0, Match_Protocol => False);

   while Object_Current /= null loop
      Object_Next :=
        Terminal.App.Image_Store.Next_Object
          (Object_Current);
      if Object_Current.Stream_ID = Stream_ID then
         Delete_Image_Object_By_Storage_Order
           (R, Stream_ID, Object_Current.Storage_Order);
      end if;
      Object_Current := Object_Next;
   end loop;

   declare
      Kept : Natural := 0;
   begin
      for I in 1 .. R.Processed_Graphics_Event_Count loop
         if R.Processed_Graphics_Events (I).Stream_ID /= Stream_ID then
            Kept := Kept + 1;
            if Kept /= I then
               R.Processed_Graphics_Events (Kept) :=
                 R.Processed_Graphics_Events (I);
            end if;
         end if;
      end loop;
      for I in Kept + 1 .. R.Processed_Graphics_Event_Count loop
         R.Processed_Graphics_Events (I) := (others => <>);
      end loop;
      R.Processed_Graphics_Event_Count := Kept;
   end;

   while Palette_Current /= null loop
      declare
         Palette_Next : constant Sixel_Palette_Entry_Access :=
           Palette_Current.Next;
      begin
         if Palette_Current.Stream_ID = Stream_ID then
            if Palette_Previous = null then
               R.Sixel_Palettes := Palette_Next;
            else
               Palette_Previous.Next := Palette_Next;
            end if;
            Free_Sixel_Palette_Entry (Palette_Current);
         else
            Palette_Previous := Palette_Current;
         end if;
         Palette_Current := Palette_Next;
      end;
   end loop;

   while Staged_Current /= null loop
      declare
         Staged_Next : constant Staged_Graphics_Event_Access :=
           Staged_Current.Next;
      begin
         if Staged_Current.Stream_ID = Stream_ID then
            if Staged_Previous = null then
               R.Staged_Graphics_Events := Staged_Next;
            else
               Staged_Previous.Next := Staged_Next;
            end if;
            if Staged_Current.Payload /= null then
               Free_String (Staged_Current.Payload);
            end if;
            Free_Staged_Graphics_Event (Staged_Current);
         else
            Staged_Previous := Staged_Current;
         end if;
         Staged_Current := Staged_Next;
      end;
   end loop;
end Release_Graphics_Stream;

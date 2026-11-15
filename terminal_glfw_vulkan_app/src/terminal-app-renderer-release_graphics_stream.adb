separate (Terminal.App.Renderer)
procedure Release_Graphics_Stream
  (R         : in out Renderer;
   Stream_ID : Terminal.Core.Graphics_Stream_ID)
is
   Object_Current : Image_Object_Access :=
     Terminal.App.Image_Store.First (R.Graphics_State.Resources.Image_Objects);
   Object_Next : Image_Object_Access;
   Palette_Previous : Sixel_Palette_Entry_Access := null;
   Palette_Current : Sixel_Palette_Entry_Access := R.Graphics_State.Resources.Sixel_Palettes;
begin
   --  Image commands borrow decoded storage from retained image objects.
   --  Invalidate the current frame before releasing any object owned by
   --  this stream so diagnostics and callers cannot dereference stale
   --  preview pointers between stream teardown and the next render.
   Frame_Lifecycle.Reset (R);
   Placements_State.Invalidate_Placement_Index (R);

   Placements_State.Delete_Virtual_Placements (R, Stream_ID, 0);
   Placements_State.Delete_Conventional_Placements
     (R, Stream_ID, 0, Match_Protocol => False);

   while Object_Current /= null loop
      Object_Next :=
        Terminal.App.Image_Store.Next_Object
          (Object_Current);
      if Object_Current.Stream_ID = Stream_ID then
         Image_Objects.Delete_By_Storage_Order
           (R, Stream_ID, Object_Current.Storage_Order);
      end if;
      Object_Current := Object_Next;
   end loop;

   Event_Tracking.Remove
     (R, Stream_ID, 0, Match_Sequence => False);

   while Palette_Current /= null loop
      declare
         Palette_Next : constant Sixel_Palette_Entry_Access :=
           Palette_Current.Next;
      begin
         if Palette_Current.Stream_ID = Stream_ID then
            if Palette_Previous = null then
               R.Graphics_State.Resources.Sixel_Palettes := Palette_Next;
            else
               Palette_Previous.Next := Palette_Next;
            end if;
            Graphics_Lifecycle.Release (Palette_Current);
         else
            Palette_Previous := Palette_Current;
         end if;
         Palette_Current := Palette_Next;
      end;
   end loop;

end Release_Graphics_Stream;

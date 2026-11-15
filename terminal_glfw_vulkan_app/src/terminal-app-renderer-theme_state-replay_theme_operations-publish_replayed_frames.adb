separate (Terminal.App.Renderer.Theme_State.Replay_Theme_Operations)
procedure Publish_Replayed_Frames
  (Context : in out Replay_Context;
   R       : in out Renderer;
   Object  : Image_Object_Access)
is
   Current : Replay_Storage.Cursor :=
     Replay_Storage.First (Context.Archived_Frames);
begin
   while Replay_Storage.Has_Element (Current) loop
      declare
         Number : constant Positive := Replay_Storage.Frame_Number (Current);
         Bytes : constant access Terminal.App.Owned_Image_Data.Owner :=
           Replay_Storage.Frame_Data (Current);
      begin
         if Number = 1 then
            Terminal.App.Image_Store.Replace_Root_RGBA
              (R.Graphics_State.Resources.Image_Objects, Object, Bytes.all,
               Preserve_Indexed => True);
         elsif Animation_State.Frame_Exists (Object, Number) then
            Frames.Replace_Data
              (R.Graphics_State.Resources.Image_Objects, Object, Number,
               Bytes.all);
         end if;
         --  Frames retained only as dependencies of later operations are not
         --  republished after deletion from the live animation.
         Replay_Storage.Next (Current);
      end;
   end loop;
end Publish_Replayed_Frames;

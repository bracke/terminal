separate (Terminal.App.Renderer)
function Evict_One_Unplaced_Image
  (R                 : in out Renderer;
   Preserve_Stream   : Terminal.Core.Graphics_Stream_ID;
   Preserve_Image_ID : Terminal.Core.Graphics_ID) return Boolean
is
   Current   : Image_Object_Access :=
     Terminal.App.Image_Store.First (R.Image_Objects);
   Candidate : Image_Object_Access := null;
begin
   while Current /= null loop
      if not
        (Preserve_Image_ID /= 0
         and then Current.Stream_ID = Preserve_Stream
         and then Current.ID = Preserve_Image_ID)
        and then not Has_Image_Placement (R, Current)
        and then
          (Candidate = null
           or else
             (Current.Usage_Hint = 1
              and then Candidate.Usage_Hint /= 1)
           or else
             (Current.Usage_Hint = Candidate.Usage_Hint
              and then Current.Storage_Order < Candidate.Storage_Order))
      then
         Candidate := Current;
      end if;
      Current :=
        Terminal.App.Image_Store.Next_Object (Current);
   end loop;

   if Candidate = null then
      return False;
   end if;
   Delete_Image_Object_By_Storage_Order
     (R, Candidate.Stream_ID, Candidate.Storage_Order);
   R.Image_Eviction_Count := R.Image_Eviction_Count + 1;
   return True;
end Evict_One_Unplaced_Image;

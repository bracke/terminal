separate (Terminal.App.Renderer)
procedure Delete_Selected_Unplaced_Image_Objects
  (R         : in out Renderer;
   Stream_ID : Terminal.Core.Graphics_Stream_ID;
   Orders    : Image_Storage_Order_List;
   Count     : Natural)
is
begin
   for I in 1 .. Count loop
      declare
         Object : constant Image_Object_Access :=
           Find_Image_Object_By_Storage_Order
             (R, Stream_ID, Orders (I));
      begin
         if Object /= null and then not Has_Image_Placement (R, Object) then
            Delete_Image_Object_By_Storage_Order
              (R, Stream_ID, Orders (I));
         end if;
      end;
   end loop;
end Delete_Selected_Unplaced_Image_Objects;

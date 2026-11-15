with Terminal.App.Image_Data;

package body Terminal.App.Owned_Image_Data.Unsafe is
   use type Terminal.App.Image_Data.Image_Data_Access;
   procedure Adopt
     (Item : in out Owner;
      Data : in out Terminal.App.Image_Data.Image_Data_Access) is
   begin
      if not Is_Empty (Item) then
         raise Program_Error with "test image-data owner is populated";
      elsif Data = null then
         return;
      end if;
      Item.Value := Image_Data_Access (Data);
      Data := null;
   end Adopt;

   procedure Take
     (Item : in out Owner;
      Data : out Terminal.App.Image_Data.Image_Data_Access) is
   begin
      Data := Terminal.App.Image_Data.Image_Data_Access (Item.Value);
      Item.Value := null;
   end Take;
end Terminal.App.Owned_Image_Data.Unsafe;

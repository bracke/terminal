with Terminal.App.Cleanup_Diagnostics;
with Terminal.App.Owned_Image_Data;

package body Terminal.App.Image_Store.Frame_Borrows is
   use type Image_Object_Access;
   use type Terminal.App.Render_Model.Image_Data_View;

   procedure Acquire
     (Item   : in out Token;
      Object : Image_Object_Access) is
   begin
      if Item.Hold.Object /= null then
         raise Program_Error with "image frame-borrow token is already active";
      end if;
      Acquire_Frame_Borrow (Object, Item.Hold);
   end Acquire;

   procedure Acquire_Frame
     (Item   : in out Token;
      Object : Image_Object_Access;
      Number : Positive;
      Data   : out Terminal.App.Render_Model.Image_Data_View)
   is
      Frame : Image_Frame_Access;
   begin
      Data := null;
      Acquire (Item, Object);
      if Object = null then
         return;
      elsif Number = 1 then
         Data := Root_Data (Object);
      elsif Number <= Object.State.Frame_Count
        and then Object.State.Frame_Index /= null
        and then Number <= Object.State.Frame_Index'Last
      then
         Frame := Object.State.Frame_Index (Number);
         if Frame /= null then
            Data := Terminal.App.Owned_Image_Data.Unsafe_View (Frame.Bytes);
         end if;
      end if;
      if Data = null then
         Release (Item);
      end if;
   exception
      when others =>
         Release (Item);
         raise;
   end Acquire_Frame;

   procedure Release (Item : in out Token) is
   begin
      Release_Frame_Borrow (Item.Hold);
   end Release;

   procedure Move (Source, Target : in out Token) is
   begin
      Move_Frame_Borrow (Source.Hold, Target.Hold);
   end Move;

   overriding procedure Finalize (Item : in out Token) is
   begin
      Release (Item);
   exception
      when E : others =>
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Frame_Image_Storage,
            E,
            "release image-frame borrow");
   end Finalize;
end Terminal.App.Image_Store.Frame_Borrows;

with Terminal.App.Owned_Image_Data;

package body Terminal.App.Image_Store.Data_Borrows is
   use type Interfaces.Unsigned_64;
   use type Terminal.App.Render_Model.Image_Data_View;

   procedure Acquire
     (Item   : in out Data_Borrow;
      Object : Image_Object_Access) is
   begin
      if Item.Hold.Object /= null then
         raise Program_Error with "image-data borrow is already active";
      elsif Object = null then
         Item.Hold.Token := 0;
         return;
      end if;
      Acquire_Frame_Borrow (Object, Item.Hold);
      Object.State.Borrow_Epoch := Object.State.Borrow_Epoch + 1;
      if Object.State.Borrow_Epoch = 0 then
         Object.State.Borrow_Epoch := 1;
      end if;
      Item.Hold.Token := Object.State.Borrow_Epoch;
   end Acquire;

   procedure Release (Item : in out Data_Borrow) is
   begin
      Release_Frame_Borrow (Item.Hold);
   end Release;

   function Root_Length (Item : Data_Borrow) return Natural is
     (Root_Data_Length (Item.Hold.Object));

   function Indexed_Length (Item : Data_Borrow) return Natural is
     (Indexed_Data_Allocation_Length (Item.Hold.Object));

   function Frame_Data
     (Item   : Data_Borrow;
      Number : Positive) return Terminal.App.Render_Model.Image_Data_View
   is
      Frame : Image_Frame_Access;
   begin
      if Item.Hold.Object = null then
         return null;
      elsif Number = 1 then
         return Root_Data (Item.Hold.Object);
      end if;
      if Number <= Item.Hold.Object.State.Frame_Count
        and then Item.Hold.Object.State.Frame_Index /= null
        and then Number <= Item.Hold.Object.State.Frame_Index'Last
      then
         Frame := Item.Hold.Object.State.Frame_Index (Number);
         if Frame /= null then
            return Terminal.App.Owned_Image_Data.Unsafe_View (Frame.Bytes);
         end if;
      end if;
      return null;
   end Frame_Data;

   procedure Copy_Root
     (Item   : Data_Borrow;
      Target : out Terminal.Common.Bytes.Byte_Array)
   is
      Source : constant Terminal.App.Render_Model.Image_Data_View :=
        Root_Data (Item.Hold.Object);
   begin
      if Source = null or else Target'Length /= Source'Length then
         raise Constraint_Error with "root image-data copy length mismatch";
      end if;
      Target := Source.all;
   end Copy_Root;

   procedure Copy_Indexed
     (Item   : Data_Borrow;
      Target : out Terminal.Common.Bytes.Byte_Array)
   is
      Source : constant Terminal.App.Render_Model.Image_Data_View :=
        Indexed_Data (Item.Hold.Object);
   begin
      if Source = null or else Target'Length /= Source'Length then
         raise Constraint_Error with "indexed image-data copy length mismatch";
      end if;
      Target := Source.all;
   end Copy_Indexed;
end Terminal.App.Image_Store.Data_Borrows;

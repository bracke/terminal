private package Terminal.App.Image_Store.Data_Borrows is
   procedure Acquire
     (Item   : in out Data_Borrow;
      Object : Image_Object_Access);
   procedure Release (Item : in out Data_Borrow);
   function Root_Length (Item : Data_Borrow) return Natural;
   function Indexed_Length (Item : Data_Borrow) return Natural;
   function Frame_Data
     (Item   : Data_Borrow;
      Number : Positive) return Terminal.App.Render_Model.Image_Data_View;
   procedure Copy_Root
     (Item   : Data_Borrow;
      Target : out Terminal.Common.Bytes.Byte_Array);
   procedure Copy_Indexed
     (Item   : Data_Borrow;
      Target : out Terminal.Common.Bytes.Byte_Array);
end Terminal.App.Image_Store.Data_Borrows;

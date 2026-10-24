with Ada.Unchecked_Deallocation;
with Terminal.Common.Bytes;

package body Terminal.App.Image_Store is
   use type Interfaces.Unsigned_64;
   use type Terminal.App.Render_Model.Image_Data_Access;
   use type Terminal.Core.Graphics_ID;
   use type Terminal.Core.Graphics_Stream_ID;

   procedure Free_Image_Data is new Ada.Unchecked_Deallocation
     (Terminal.Common.Bytes.Byte_Array,
      Terminal.App.Render_Model.Image_Data_Access);
   procedure Free_Image_Frame is new Ada.Unchecked_Deallocation
     (Image_Frame, Image_Frame_Access);
   procedure Free_Theme_Operation is new Ada.Unchecked_Deallocation
     (Theme_Operation, Theme_Operation_Access);

   function Find_By_ID
     (Head      : Image_Object_Access;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      ID        : Terminal.Core.Graphics_ID) return Image_Object_Access
   is
      Current : Image_Object_Access := Head;
   begin
      if ID = 0 then
         return null;
      end if;
      while Current /= null loop
         if Current.Stream_ID = Stream_ID and then Current.ID = ID then
            return Current;
         end if;
         Current := Current.Next;
      end loop;
      return null;
   end Find_By_ID;

   function Find_By_Number
     (Head      : Image_Object_Access;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Number    : Terminal.Core.Graphics_ID) return Image_Object_Access
   is
      Current : Image_Object_Access := Head;
   begin
      if Number = 0 then
         return null;
      end if;
      while Current /= null loop
         if Current.Stream_ID = Stream_ID and then Current.Number = Number then
            return Current;
         end if;
         Current := Current.Next;
      end loop;
      return null;
   end Find_By_Number;

   function Find_By_Storage_Order
     (Head          : Image_Object_Access;
      Stream_ID     : Terminal.Core.Graphics_Stream_ID;
      Storage_Order : Interfaces.Unsigned_64) return Image_Object_Access
   is
      Current : Image_Object_Access := Head;
   begin
      if Storage_Order = 0 then
         return null;
      end if;
      while Current /= null loop
         if Current.Stream_ID = Stream_ID
           and then Current.Storage_Order = Storage_Order
         then
            return Current;
         end if;
         Current := Current.Next;
      end loop;
      return null;
   end Find_By_Storage_Order;

   function Owned_Bytes (Object : Image_Object) return Natural is
     (Object.Decoded_Length
      + Object.Indexed_Length
      + Object.Frame_Bytes
      + Object.Theme_Operation_Bytes);

   procedure Release_Contents (Object : in out Image_Object) is
      Frame : Image_Frame_Access := Object.Frames;
      Operation : Theme_Operation_Access := Object.Theme_Operations;
   begin
      while Frame /= null loop
         declare
            Next : constant Image_Frame_Access := Frame.Next;
         begin
            if Frame.Bytes /= null then
               Free_Image_Data (Frame.Bytes);
            end if;
            Free_Image_Frame (Frame);
            Frame := Next;
         end;
      end loop;
      while Operation /= null loop
         declare
            Next : constant Theme_Operation_Access := Operation.Next;
         begin
            if Operation.Bytes /= null then
               Free_Image_Data (Operation.Bytes);
            end if;
            Free_Theme_Operation (Operation);
            Operation := Next;
         end;
      end loop;
      if Object.Bytes /= null then
         Free_Image_Data (Object.Bytes);
      end if;
      if Object.Indexed_Bytes /= null then
         Free_Image_Data (Object.Indexed_Bytes);
      end if;
      Object := (others => <>);
   end Release_Contents;

   procedure Fail_Allocation_After
     (Control  : in out Allocation_Control;
      Attempts : Natural) is
   begin
      Control.Remaining_Attempts := Attempts;
   end Fail_Allocation_After;

   function Allocation_Allowed
     (Control : in out Allocation_Control) return Boolean is
   begin
      if Control.Remaining_Attempts = 0 then
         return True;
      end if;
      Control.Remaining_Attempts := Control.Remaining_Attempts - 1;
      return Control.Remaining_Attempts /= 0;
   end Allocation_Allowed;

   procedure Record_Install
     (Transaction   : in out Install_Transaction;
      Storage_Order : Interfaces.Unsigned_64) is
   begin
      Transaction.Storage_Order := Storage_Order;
   end Record_Install;

   procedure Commit (Transaction : in out Install_Transaction) is
   begin
      Transaction.Storage_Order := 0;
   end Commit;

   procedure Take_Rollback_Order
     (Transaction   : in out Install_Transaction;
      Storage_Order : out Interfaces.Unsigned_64) is
   begin
      Storage_Order := Transaction.Storage_Order;
      Transaction.Storage_Order := 0;
   end Take_Rollback_Order;
end Terminal.App.Image_Store;

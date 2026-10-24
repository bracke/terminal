package body Terminal.App.Image_Store is
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

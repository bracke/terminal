package body Terminal.App.Image_Store.Testing is
   procedure Fail_Allocation_After
     (Control  : in out Allocation_Control;
      Attempts : Natural) is
   begin
      Control.Remaining_Attempts := Attempts;
   end Fail_Allocation_After;
end Terminal.App.Image_Store.Testing;

package Terminal.App.Image_Store.Testing is
   --  Zero disables injection; one rejects the next guarded allocation.
   procedure Fail_Allocation_After
     (Control  : in out Allocation_Control;
      Attempts : Natural);
end Terminal.App.Image_Store.Testing;

package Terminal.App.Image_Store.Testing is
   --  Zero disables injection; one rejects the next guarded allocation.
   procedure Fail_Allocation_After
     (Control  : in out Allocation_Control;
      Attempts : Natural);

   procedure Quarantine_Theme_Transaction
     (Object : Image_Object_Access);

   procedure Set_ID_Index_Previous
     (Object   : not null Image_Object_Access;
      Previous : Image_Object_Access);
   procedure Set_Number_Index_Previous
     (Object   : not null Image_Object_Access;
      Previous : Image_Object_Access);

   procedure Verify_Stale_Delete_Preparation;
end Terminal.App.Image_Store.Testing;

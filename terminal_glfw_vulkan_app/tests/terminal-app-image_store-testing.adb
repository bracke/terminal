with AUnit.Assertions;

package body Terminal.App.Image_Store.Testing is
   procedure Fail_Allocation_After
     (Control  : in out Allocation_Control;
      Attempts : Natural) is
   begin
      Control.Remaining_Attempts := Attempts;
   end Fail_Allocation_After;

   procedure Quarantine_Theme_Transaction
     (Object : Image_Object_Access) is
   begin
      if Object = null then
         raise Constraint_Error with "cannot quarantine a null image object";
      end if;
      Object.State.Theme_Transaction_Active := True;
      Object.State.Theme_Transaction_Quarantined := True;
   end Quarantine_Theme_Transaction;

   procedure Set_ID_Index_Previous
     (Object   : not null Image_Object_Access;
      Previous : Image_Object_Access) is
   begin
      Object.ID_Index_Previous := Previous;
   end Set_ID_Index_Previous;

   procedure Set_Number_Index_Previous
     (Object   : not null Image_Object_Access;
      Previous : Image_Object_Access) is
   begin
      Object.Number_Index_Previous := Previous;
   end Set_Number_Index_Previous;

   procedure Verify_Stale_Delete_Preparation is
      use AUnit.Assertions;

      Container : Store;
      First_Item : Image_Object_Access := null;
      Later_Item : Image_Object_Access := null;
      Preparation : Delete_Preparation;
      Rejected : Boolean := False;
   begin
      Create_Object (First_Item);
      Link_New (Container, First_Item);
      Prepare_Delete_Object (Container, First_Item, Preparation);

      Create_Object (Later_Item);
      Link_New (Container, Later_Item);
      begin
         Delete_Object (Container, First_Item, Preparation);
      exception
         when Program_Error =>
            Rejected := True;
      end;

      Assert
        (Rejected
         and then First (Container) = Later_Item
         and then Next_Object (Later_Item) = First_Item
         and then Object_Count (Container) = 2,
         "stale deletion preparation cannot mutate a changed store");

      Delete_Object (Container, Later_Item);
      Delete_Object (Container, First_Item);
   end Verify_Stale_Delete_Preparation;
end Terminal.App.Image_Store.Testing;

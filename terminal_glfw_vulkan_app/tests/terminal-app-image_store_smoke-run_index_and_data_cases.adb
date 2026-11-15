separate (Terminal.App.Image_Store_Smoke)
procedure Run_Index_And_Data_Cases is
   Container : aliased Store.Store;
   Valid     : Boolean;
begin
   Store_Testing.Verify_Stale_Delete_Preparation;
   declare
      Collision_Store : Store.Store;
      type Object_Array is array (Positive range <>) of
        Store.Image_Object_Access;
      Objects : Object_Array (1 .. 3) := (others => null);
   begin
      for I in Objects'Range loop
         declare
            Data : Terminal.App.Image_Data.Image_Data_Access :=
              new Terminal.Common.Bytes.Byte_Array'
                (1 .. 4 => Terminal.Common.Bytes.Byte (I));
         begin
            Store.Create_Object (Objects (I));
            Store.Link_New (Collision_Store, Objects (I));
            Install_Root
              (Collision_Store, Objects (I),
               Stream_ID => 17, ID => 71, Number => 81,
               Protocol => Terminal.App.Render_Model.Image_Kitty,
               Raw_Format => 32, Pixel_Width => 1, Pixel_Height => 1,
               Decoded_Length => 4, Row_Stride => 4, Usage_Hint => 0,
               Data => Data);
         end;
      end loop;
      Assert
        (Store.Find_By_ID (Collision_Store, 17, 71) = Objects (3)
         and then Store.Find_By_Number (Collision_Store, 17, 81) = Objects (3),
         "colliding image indexes resolve to the newest object");
      declare
         ID_Rejected : Boolean := False;
         Number_Rejected : Boolean := False;
      begin
         Store_Testing.Set_ID_Index_Previous (Objects (1), Objects (3));
         begin
            declare
               Preparation : Store.Delete_Preparation;
            begin
               Store.Prepare_Delete_Object
                 (Collision_Store, Objects (3), Preparation);
            end;
         exception
            when Program_Error => ID_Rejected := True;
         end;
         Store_Testing.Set_ID_Index_Previous (Objects (1), Objects (2));
         Store_Testing.Set_Number_Index_Previous (Objects (1), Objects (3));
         begin
            declare
               Preparation : Store.Delete_Preparation;
            begin
               Store.Prepare_Delete_Object
                 (Collision_Store, Objects (3), Preparation);
            end;
         exception
            when Program_Error => Number_Rejected := True;
         end;
         Store_Testing.Set_Number_Index_Previous (Objects (1), Objects (2));
         Assert
           (ID_Rejected and then Number_Rejected
            and then Store.Find_By_ID (Collision_Store, 17, 71) = Objects (3)
            and then Store.Find_By_Number (Collision_Store, 17, 81) = Objects (3),
            "deep collision-chain forks are rejected without mutation");
      end;
      Store.Delete_Object (Collision_Store, Objects (2));
      Assert
        (Store.Find_By_ID (Collision_Store, 17, 71) = Objects (3)
         and then Store.Find_By_Number (Collision_Store, 17, 81) = Objects (3),
         "removing a collision-chain middle preserves its head");
      Store.Delete_Object (Collision_Store, Objects (3));
      Assert
        (Store.Find_By_ID (Collision_Store, 17, 71) = Objects (1)
         and then Store.Find_By_Number (Collision_Store, 17, 81) = Objects (1),
         "removing a collision-chain head promotes its successor");
      Store.Delete_Object (Collision_Store, Objects (1));
      Assert
        (Store.Find_By_ID (Collision_Store, 17, 71) = null
         and then Store.Find_By_Number (Collision_Store, 17, 81) = null,
         "removing a collision-chain tail clears both indexes");
   end;
   declare
      Reinstall_Store : Store.Store;
      Reinstalled : Store.Image_Object_Access := null;
      Replacement_Object : Store.Image_Object_Access := null;
      First_Data : Terminal.App.Image_Data.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 1);
      Second_Data : Terminal.App.Image_Data.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 2);
      Index_Control : aliased Store.Allocation_Control;
      Rejected : Boolean := False;
   begin
      Store.Create_Object (Reinstalled);
      Store.Link_New (Reinstall_Store, Reinstalled);
      Install_Root
        (Reinstall_Store, Reinstalled,
         Stream_ID => 7, ID => 31, Number => 41,
         Protocol => Terminal.App.Render_Model.Image_Kitty,
         Raw_Format => 32, Pixel_Width => 1, Pixel_Height => 1,
         Decoded_Length => 4, Row_Stride => 4, Usage_Hint => 0,
         Data => First_Data);
      Store.Create_Object (Replacement_Object);
      Store.Link_Replacement
        (Reinstall_Store, Replacement_Object, Reinstalled);
      --  The third checkpoint fires after the ID map has already been
      --  replaced, exercising rollback of a partially published index set.
      Store_Testing.Fail_Allocation_After (Index_Control, 3);
      begin
         Install_Root
           (Reinstall_Store, Replacement_Object,
            Stream_ID => 7, ID => 31, Number => 41,
            Protocol => Terminal.App.Render_Model.Image_Kitty,
            Raw_Format => 32, Pixel_Width => 1, Pixel_Height => 1,
            Decoded_Length => 4, Row_Stride => 4, Usage_Hint => 0,
            Data => Second_Data,
            Index_Control => Index_Control'Access);
      exception
         when Storage_Error =>
            Rejected := True;
      end;
      Assert
        (Rejected
         and then Second_Data /= null
         and then Store.Find_By_ID (Reinstall_Store, 7, 31) = Reinstalled
         and then Store.Find_By_Number (Reinstall_Store, 7, 41) = Reinstalled
         and then Store.Byte_Count (Reinstall_Store) = 4,
         "failed replacement preserves the committed object and its indexes");
      Store.Delete_Replacement (Reinstall_Store, Replacement_Object);

      Store.Create_Object (Replacement_Object);
      Store.Link_Replacement
        (Reinstall_Store, Replacement_Object, Reinstalled);
      Install_Root
        (Reinstall_Store, Replacement_Object,
         Stream_ID => 7, ID => 31, Number => 41,
         Protocol => Terminal.App.Render_Model.Image_Kitty,
         Raw_Format => 32, Pixel_Width => 1, Pixel_Height => 1,
         Decoded_Length => 4, Row_Stride => 4, Usage_Hint => 0,
         Data => Second_Data);
      Store.Delete_Replacement (Reinstall_Store, Reinstalled);
      Assert
        (Reinstalled = null
         and then Store.Find_By_ID (Reinstall_Store, 7, 31) =
           Replacement_Object
         and then Store.Find_By_Number (Reinstall_Store, 7, 41) =
           Replacement_Object
         and then Store.Byte_Count (Reinstall_Store) = 4,
         "successful replacement atomically publishes its new indexes");
      Store.Delete_Object (Reinstall_Store, Replacement_Object);
   end;
   declare
      Recovery_Store : Store.Store;
      Recovery_Object : Store.Image_Object_Access := null;
      Recovery_Data : Terminal.App.Image_Data.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 0);
   begin
      Store.Create_Object (Recovery_Object);
      Store.Link_New (Recovery_Store, Recovery_Object);
      Install_Root
        (Recovery_Store, Recovery_Object,
         Stream_ID => 0, ID => 91, Number => 0,
         Protocol => Terminal.App.Render_Model.Image_Kitty,
         Raw_Format => 32, Pixel_Width => 1, Pixel_Height => 1,
         Decoded_Length => 4, Row_Stride => 4, Usage_Hint => 0,
         Data => Recovery_Data);
      Store_Testing.Quarantine_Theme_Transaction (Recovery_Object);
      Store.Delete_Object (Recovery_Store, Recovery_Object);
      Assert
        (Recovery_Object = null
         and then Store.Object_Count (Recovery_Store) = 0,
         "quarantined theme transactions permit explicit object recovery");
   end;
   declare
      Empty_Borrow : Store.Data_Borrow;
      Empty_Target : Terminal.Common.Bytes.Byte_Array (1 .. 4);
   begin
      Store.Borrow (Empty_Borrow, null);
      Frames.Copy_To_RGBA (null, 1, Empty_Target, Valid);
      Assert
        (Frames.Count (null) = 0
         and then Store.Borrowed_Root_Length (Empty_Borrow) = 0
         and then not Valid,
         "null image objects have no frames and are safe to inspect");
   end;
   declare
      Object_Rejected : Boolean := False;
      Frame_Rejected  : Boolean := False;
   begin
      begin
         Store.Set_Usage_Hint
           (Container, Store.Image_Object_Access'(null), 1);
      exception
         when Program_Error => Object_Rejected := True;
      end;
      Frame_Rejected := not Frames.Set_Usage_Hint (Container, null, 1, 1);
      Assert
        (Object_Rejected and then Frame_Rejected,
         "usage-hint mutation rejects missing owners");
   end;
   declare
      Padded_Store : Store.Store;
      Padded_RGBA : Store.Image_Object_Access := null;
      Padded_RGB : Store.Image_Object_Access := null;
      RGBA_Data : Terminal.App.Image_Data.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'
          (1, 2, 3, 4, 16#EE#, 16#EF#,
           5, 6, 7, 8);
      RGB_Data : Terminal.App.Image_Data.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'
          (9, 10, 11, 16#EE#, 16#EF#,
           12, 13, 14);
      Output : Terminal.Common.Bytes.Byte_Array (1 .. 8);
   begin
      Store.Create_Object (Padded_RGBA);
      Store.Link_New (Padded_Store, Padded_RGBA);
      Install_Root
        (Padded_Store, Padded_RGBA,
         Stream_ID => 1, ID => 10, Number => 0,
         Protocol => Terminal.App.Render_Model.Image_Kitty,
         Raw_Format => 32, Pixel_Width => 1, Pixel_Height => 2,
         Decoded_Length => 10, Row_Stride => 6, Usage_Hint => 0,
         Data => RGBA_Data);
      Frames.Copy_To_RGBA (Padded_RGBA, 1, Output, Valid);
      Assert
        (Valid and then Output = (1, 2, 3, 4, 5, 6, 7, 8),
         "RGBA frame copying accepts no padding after the final row");

      Store.Create_Object (Padded_RGB);
      Store.Link_New (Padded_Store, Padded_RGB);
      Install_Root
        (Padded_Store, Padded_RGB,
         Stream_ID => 1, ID => 11, Number => 0,
         Protocol => Terminal.App.Render_Model.Image_Kitty,
         Raw_Format => 24, Pixel_Width => 1, Pixel_Height => 2,
         Decoded_Length => 8, Row_Stride => 5, Usage_Hint => 0,
         Data => RGB_Data);
      Frames.Copy_To_RGBA (Padded_RGB, 1, Output, Valid);
      Assert
        (Valid
         and then Output = (9, 10, 11, 255, 12, 13, 14, 255),
         "RGB frame copying accepts no padding after the final row");
      Store.Delete_Object (Padded_Store, Padded_RGBA);
      Store.Delete_Object (Padded_Store, Padded_RGB);
   end;
   declare
      Indexed_Container : aliased Store.Store;
      Indexed_Object : Store.Image_Object_Access := null;
      Indexed_Data : Terminal.App.Owned_Image_Data.Owner;
      Root_Data : Terminal.App.Image_Data.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 0);
   begin
      Terminal.App.Owned_Image_Data.Allocate (Indexed_Data, 1);
      Terminal.App.Owned_Image_Data.Replace_Element (Indexed_Data, 1, 7);
      Store.Create_Object (Indexed_Object);
      Store.Link_New (Indexed_Container, Indexed_Object);
      Install_Root
        (Indexed_Container, Indexed_Object,
         Stream_ID => 1, ID => 1, Number => 0,
         Protocol => Terminal.App.Render_Model.Image_Kitty,
         Raw_Format => 32, Pixel_Width => 1, Pixel_Height => 1,
         Decoded_Length => 4, Row_Stride => 4, Usage_Hint => 0,
         Data => Root_Data);
      declare
         Borrow : Store.Data_Borrow;
      begin
         Store.Borrow (Borrow, Indexed_Object);
         Assert
           (Store.Borrowed_Root_Length (Borrow) = 4,
            "installed root data is available through a bounded borrow");
      end;
      Store.Adopt_Indexed_Data
        (Indexed_Container, Indexed_Object, 8, 1, Indexed_Data);
      Assert
        (Terminal.App.Owned_Image_Data.Is_Empty (Indexed_Data)
         and then Store.Indexed_Data_Length (Indexed_Object) = 1
         and then Store.Byte_Count (Indexed_Container) = 5,
         "indexed adoption transfers ownership and updates accounting");
      declare
         Borrow : Store.Data_Borrow;
      begin
         Store.Borrow (Borrow, Indexed_Object);
         Assert
           (Store.Borrowed_Indexed_Length (Borrow) = 1,
            "indexed data is available through a bounded borrow");
      end;
      Store.Delete_Object (Indexed_Container, Indexed_Object);
   end;

end Run_Index_And_Data_Cases;

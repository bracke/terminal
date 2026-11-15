package body Terminal.App.Image_Placements.Testing is
   function Key_Of
     (Placement : not null Conventional_Placement_Access)
      return Placement_Key is
     (Stream_ID         => Placement.State.Stream_ID,
      Alternate_Screen  => Placement.State.Alternate_Screen,
      Screen_Generation => Placement.State.Screen_Generation,
      Image_ID          => Placement.State.Image_ID,
      Placement_ID      => Placement.State.Placement_ID);

   procedure Remove_Conventional_Key
     (Container : in out Store;
      Placement : not null Conventional_Placement_Access) is
   begin
      Container.Conventional_By_Key.Delete (Key_Of (Placement));
   end Remove_Conventional_Key;

   procedure Restore_Conventional_Key
     (Container : in out Store;
      Placement : not null Conventional_Placement_Access) is
   begin
      Container.Conventional_By_Key.Insert (Key_Of (Placement), Placement);
   end Restore_Conventional_Key;

   function Removal_Preflight_Is_Atomic return Boolean is
      Container : Store;
      Placement : Virtual_Placement_Access := new Virtual_Placement;
      Current : Virtual_Placement_Access;
      Following : Virtual_Placement_Access;
      Key : constant Image_Key := (Stream_ID => 23, Image_ID => 47);
      Rejected : Boolean := False;

      procedure Configure (Item : in out Virtual_Placement_State) is
      begin
         Item.Stream_ID := Key.Stream_ID;
         Item.Image_ID := Key.Image_ID;
         Item.Placement_ID := 1;
      end Configure;
   begin
      Configure_Unlinked (Placement, Configure'Access);
      Prepend (Container, Placement);
      Current := Placement;
      Container.Virtual_Image_Counts.Delete (Key);
      begin
         Remove (Container, null, Current, Following);
      exception
         when Program_Error =>
            Rejected := True;
      end;
      declare
         Preserved : constant Boolean :=
           Rejected
           and then Current = Placement
           and then Count (Container) = 1
           and then First_Virtual (Container) = Placement
           and then Next (Placement) = null
           and then Find_Virtual
             (Container, 23, False, 0, 47, 1) = Placement
           and then Find_Addressed_Virtual
             (Container, 23, 47, 1) = Placement;
      begin
         Container.Virtual_Image_Counts.Insert (Key, 1);
         Release (Container);
         return Preserved;
      end;
   exception
      when others =>
         if not Container.Virtual_Image_Counts.Contains (Key) then
            Container.Virtual_Image_Counts.Insert (Key, 1);
         end if;
         Release (Container);
         raise;
   end Removal_Preflight_Is_Atomic;
end Terminal.App.Image_Placements.Testing;

with AUnit.Assertions;
with Terminal.App.Graphics;
with Terminal.App.Image_Placements;
with Terminal.App.Image_Placements.Testing;
with Terminal.App.Image_Store;
with Terminal.App.Owned_Image_Data;
with Terminal.App.Placeholder_Index;
with Terminal.App.Renderer.Placement_State;
with Terminal.Core;
with Terminal.Core.Snapshot_Editing;
with Terminal.Core.Snapshot_Testing;

package body Terminal.App.Renderer.Testing.Placement_Invariants is
   procedure Verify_Image_Placement_Invariants is
      use AUnit.Assertions;
      package Placements renames Terminal.App.Image_Placements;
      use type Placements.Virtual_Placement_Access;
      use type Placements.Conventional_Placement_Access;
      use type Terminal.App.Image_Store.Image_Object_Access;
      use type Terminal.Core.Graphics_Screen_Generation;
      use type Terminal.Core.Initialize_Status;

      Header : Terminal.App.Graphics.Graphics_Header :=
        (Kitty_Columns_Specified => True,
         Kitty_Rows_Specified    => True,
         Placeholder_Cols       => 2,
         Placeholder_Rows       => 2,
         others                 => <>);
      Geometry : Placements.Geometry := Placements.Resolve
        (Cell_Width   => 10,
         Cell_Height  => 10,
         Pixel_Width  => 20,
         Pixel_Height => 30,
         Header       => Header);
      Container : Placements.Store;
      Virtual_1 : Placements.Virtual_Placement_Access :=
        new Placements.Virtual_Placement;
      Virtual_2 : Placements.Virtual_Placement_Access :=
        new Placements.Virtual_Placement;
      Child : Placements.Conventional_Placement_Access :=
        new Placements.Conventional_Placement;
      Grandchild : Placements.Conventional_Placement_Access :=
        new Placements.Conventional_Placement;
      Indexed : Placements.Conventional_Placement_Access :=
        new Placements.Conventional_Placement;
      Current_Virtual : Placements.Virtual_Placement_Access;
      Next_Virtual : Placements.Virtual_Placement_Access;
      Count_Before_Removal : Natural;

      procedure Set_State
        (Placement : not null Placements.Virtual_Placement_Access;
         Value     : Placements.Virtual_Placement_State)
      is
         procedure Apply (Item : in out Placements.Virtual_Placement_State) is
         begin
            Item := Value;
         end Apply;
      begin
         Placements.Configure_Unlinked (Placement, Apply'Access);
      end Set_State;

      procedure Set_State
        (Placement : not null Placements.Conventional_Placement_Access;
         Value     : Placements.Conventional_Placement_State)
      is
         procedure Apply
           (Item : in out Placements.Conventional_Placement_State) is
         begin
            Item := Value;
         end Apply;
      begin
         Placements.Configure_Unlinked (Placement, Apply'Access);
      end Set_State;
   begin
      Assert
        (Terminal.App.Image_Placements.Testing.Removal_Preflight_Is_Atomic,
         "placement removal preflight preserves every index and list link");
      Assert
        (Geometry.Valid
         and then Geometry.Columns = 2
         and then Geometry.Rows = 2
         and then Geometry.Draw_Width = 13
         and then Geometry.Draw_Height = 20,
         "placement geometry preserves aspect ratio");

      Header.Kitty_Source_X := 20;
      Geometry := Placements.Resolve
        (Cell_Width   => 10,
         Cell_Height  => 10,
         Pixel_Width  => 20,
         Pixel_Height => 30,
         Header       => Header);
      Assert (not Geometry.Valid, "invalid placement crop is rejected");

      Set_State
        (Virtual_1,
         (Stream_ID => 9, Image_ID => 7, Placement_ID => 1,
          Image_Storage_Order => 1, others => <>));
      Set_State
        (Virtual_2,
         (Stream_ID => 9, Image_ID => 7, Placement_ID => 2,
          Image_Storage_Order => 1, others => <>));
      Placements.Prepend (Container, Virtual_1);
      Placements.Prepend (Container, Virtual_2);
      Assert
        (Placements.Count (Container) = 2
         and then Placements.First_Virtual (Container) = Virtual_2
         and then Placements.Next (Virtual_2) = Virtual_1
         and then Placements.Find_Virtual
           (Container, 9, False, 0, 7, 2) = Virtual_2
         and then Placements.Find_Addressed_Virtual
           (Container, 9, 7, 1) = Virtual_1
         and then Placements.Has_Virtual (Container, 9, 7),
         "placement store owns traversal and count");

      declare
         Rejected : Boolean := False;
      begin
         begin
            Placements.Prepend (Container, Virtual_2);
         exception
            when Program_Error =>
               Rejected := True;
         end;
         Assert
           (Rejected and then Placements.Count (Container) = 2,
            "duplicate linkage is rejected atomically");
      end;

      Set_State
        (Indexed,
         (Stream_ID => 9, Image_ID => 7, Placement_ID => 4,
          Image_Storage_Order => 1, others => <>));
      Placements.Prepend (Container, Indexed);
      Assert
        (Placements.Find_Conventional
           (Container, 9, False, 0, 7, 4) = Indexed
         and then Placements.Find_Addressed_Conventional
           (Container, 9, 7, 4) = Indexed
         and then Placements.Has_Conventional (Container, 9, 7),
         "placement store maintains keyed lookup indexes");
      declare
         package Store renames Terminal.App.Image_Store;
         Images : Store.Store;
         Object : Store.Image_Object_Access;
         Data : Terminal.App.Owned_Image_Data.Owner;
         Index : Terminal.App.Placeholder_Index.Index;
      begin
         Terminal.App.Owned_Image_Data.Allocate (Data, 4);
         Terminal.App.Owned_Image_Data.Fill (Data, 0);
         Store.Create_Object (Object);
         Store.Link_New (Images, Object);
         Store.Install_Root
           (Images,
            Object,
            Stream_ID       => 9,
            ID              => 7,
            Number          => 0,
            Protocol        => Terminal.App.Render_Model.Image_Kitty,
            Raw_Format      => 32,
            Pixel_Width     => 1,
            Pixel_Height    => 1,
            Decoded_Length  => 4,
            Row_Stride      => 4,
            Usage_Hint      => 0,
            Data            => Data);
         Terminal.App.Placeholder_Index.Build
           (Index,
            Placements.First_Virtual (Container),
            Placements.First_Conventional (Container),
            Images);
         Assert
           (Terminal.App.Placeholder_Index.Find_Placement
              (Index, 9, False, 0, 7, 2) = Virtual_2
            and then Terminal.App.Placeholder_Index.Find_Placement
              (Index, 9, False, 0, 7, 1) = Virtual_1
            and then Terminal.App.Placeholder_Index.Find_Conventional
              (Index, 9, False, 0, 7, 4) = Indexed
            and then Terminal.App.Placeholder_Index.Find_Object
              (Index, 9, 1) = Object
            and then Terminal.App.Placeholder_Index.Has_Object_Placement
              (Index, 9, 1)
            and then not Terminal.App.Placeholder_Index.Has_Object_Placement
              (Index, 9, 2),
            "placeholder indexes preserve placement and object identity");

         declare
            Snapshot : Terminal.Core.Render_Snapshot;
            Core : Terminal.Core.Terminal;
            Init : Terminal.Core.Initialize_Status;
            Row : Integer;
            Col : Integer;
         begin
            Terminal.Core.Initialize (Core, 2, 2, 0, Init);
            Assert (Init = Terminal.Core.Ok, "placeholder core initialize");
            Terminal.Core.Snapshot (Core, Snapshot);
            Terminal.Core.Snapshot_Testing.Set_Presentation_Context
              (Snapshot,
               Stream => 9,
               Transaction => Snapshot.Graphics_Transaction,
               Alternate => Snapshot.Alternate_Screen,
               Screen_Generation => 0);
            Terminal.Core.Snapshot_Editing.Set_Cell
              (Snapshot,
               2,
               (Includes_Link => True,
                Image =>
                  (Is_Placeholder => True,
                   Image_ID_Valid => True,
                   Image_ID       => 7,
                   Placement_ID   => 2,
                   others         => <>),
                others => <>));
            Terminal.App.Placeholder_Index.Index_Cells (Index, Snapshot);
            Assert
              (Terminal.App.Placeholder_Index.Find_Origin
                 (Index, 9, False, 0, 7, 2, Row, Col)
               and then Row = 1
               and then Col = 2,
               "placeholder origins are indexed from snapshot cells");
            Terminal.Core.Snapshot_Editing.Set_Cell
              (Snapshot, 2, (Includes_Link => True, others => <>));
            Terminal.App.Placeholder_Index.Index_Cells (Index, Snapshot);
            Assert
              (not Terminal.App.Placeholder_Index.Find_Origin
                 (Index, 9, False, 0, 7, 2, Row, Col),
               "empty placeholder snapshots expire indexed origins");
            Terminal.Core.Release (Snapshot);
            Terminal.Core.Finalize (Core);
         end;
      end;

      Set_State
        (Child,
         (Stream_ID => 9, Image_ID => 11, Placement_ID => 1,
          Parent_Image_ID => 10, Parent_Placement_ID => 1,
          others => <>));
      Set_State
        (Grandchild,
         (Stream_ID => 9, Image_ID => 12, Placement_ID => 1,
          Parent_Image_ID => 11, Parent_Placement_ID => 1,
          others => <>));
      Placements.Prepend (Container, Grandchild);
      Placements.Prepend (Container, Child);
      Placements.Move_Relative_Descendants
        (Container           => Container,
         Stream_ID           => 9,
         Parent_Image_ID     => 10,
         Parent_Placement_ID => 1,
         Alternate_Screen    => True,
         Screen_Generation   => 42,
         Maximum_Depth       => 8);
      Assert
        (Terminal.App.Image_Placements.State (Child).Alternate_Screen
         and then Terminal.App.Image_Placements.State (Child).Screen_Generation = 42
         and then Terminal.App.Image_Placements.State (Grandchild).Alternate_Screen
         and then Terminal.App.Image_Placements.State (Grandchild).Screen_Generation = 42,
         "relative descendant discovery reaches multiple generations");

      --  Exercise the batch reindex path with enough distinct keys to expose
      --  an accidental per-descendant list scan.
      for I in 1 .. 1_024 loop
         declare
            Sibling : Placements.Conventional_Placement_Access :=
              new Placements.Conventional_Placement;
         begin
            Set_State
              (Sibling,
               (Stream_ID => 9,
                Image_ID => Terminal.Core.Graphics_ID (1_000 + I),
                Placement_ID => 1,
                Parent_Image_ID => 10,
                Parent_Placement_ID => 1,
                others => <>));
            Placements.Prepend (Container, Sibling);
         end;
      end loop;
      Placements.Move_Relative_Descendants
        (Container           => Container,
         Stream_ID           => 9,
         Parent_Image_ID     => 10,
         Parent_Placement_ID => 1,
         Alternate_Screen    => False,
         Screen_Generation   => 43,
         Maximum_Depth       => 8);
      Assert
        (Placements.Find_Conventional
           (Container, 9, False, 43, 1_001, 1) /= null,
         "relative descendant batch rebuilds keyed lookup indexes");

      Count_Before_Removal := Placements.Count (Container);
      Current_Virtual := Virtual_2;
      Placements.Remove
        (Container, null, Current_Virtual, Next_Virtual);
      Assert
        (Current_Virtual = null
         and then Next_Virtual = Virtual_1
         and then Placements.Count (Container) = Count_Before_Removal - 1
         and then Placements.Find_Addressed_Virtual
           (Container, 9, 7, 2) = null
         and then Placements.Find_Addressed_Virtual
           (Container, 9, 7, 1) = Virtual_1,
         "placement removal preserves store invariants");
   end Verify_Image_Placement_Invariants;

   procedure Verify_Placement_Update_Invalidation is
      use AUnit.Assertions;
      use type Conventional_Placement_Access;
      package State renames Terminal.App.Renderer.Placement_State;

      R : Renderer;
      Placement : Conventional_Placement_Access :=
        new Conventional_Placement;
      Position : State.Conventional_Cursor;
      Callback_Raised : Boolean := False;

      procedure Mutate_Then_Fail (Item : in out Conventional_Placement_State) is
      begin
         Item.Row := 2;
         raise Constraint_Error with "intentional placement callback failure";
      end Mutate_Then_Fail;
      procedure Configure (Item : in out Conventional_Placement_State) is
      begin
         Item.Stream_ID := 1;
         Item.Image_ID := 1;
         Item.Placement_ID := 1;
      end Configure;
   begin
      Terminal.App.Image_Placements.Configure_Unlinked
        (Placement, Configure'Access);
      State.Prepend_Conventional_Placement (R, Placement);
      Assert (Placement = null, "placement ownership transfers to renderer");
      State.Rebuild_Placement_Index (R);
      Assert
        (not R.Frame_State.Placement_Index_Dirty,
         "placement index starts clean");
      Position := State.First_Conventional (R);
      begin
         State.Update (R, Position, Mutate_Then_Fail'Access);
      exception
         when Constraint_Error =>
            Callback_Raised := True;
      end;
      Assert (Callback_Raised, "failing placement callback is observed");
      Assert
        (R.Frame_State.Placement_Index_Dirty,
         "placement index is invalidated before a mutating callback");
      Assert
        (State.Element (Position).Row = 1,
         "failing placement callback does not commit partial mutation");
      Assert
        (State.Find_Addressed_Conventional_Placement (R, 1, 1, 1).Exists,
         "failing placement callback preserves keyed lookup");
      State.Release_All (R);
   end Verify_Placement_Update_Invalidation;
end Terminal.App.Renderer.Testing.Placement_Invariants;

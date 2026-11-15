with AUnit.Assertions;
with Interfaces;
with Terminal.App.Image_Placements;
with Terminal.App.Image_Placements.Testing;
with Terminal.App.Image_Store;
with Terminal.App.Image_Store.Testing;
with Terminal.App.Image_Store.Themes;
with Terminal.App.Owned_Image_Data;
with Terminal.App.Renderer.Frame_Lifecycle;
with Terminal.App.Renderer.Image_Objects;
with Terminal.App.Renderer.Placement_State;
with Terminal.Core;

package body Terminal.App.Renderer.Testing.Image_Transactions is
   procedure Verify_Index_Failure_Preserves_Placements
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Image_ID  : Terminal.Core.Graphics_ID)
   is
      use AUnit.Assertions;
      use type Terminal.App.Image_Store.Image_Object_Access;
      use type Terminal.App.Image_Placements.Conventional_Placement_Access;
      use type Terminal.App.Image_Placements.Virtual_Placement_Access;
      use type Terminal.App.Image_Placements.Conventional_Placement_State;
      use type Interfaces.Unsigned_64;

      package Store renames Terminal.App.Image_Store;

      Original : constant Image_Object_Access :=
        Terminal.App.Renderer.Image_Objects.Find (R, Stream_ID, Image_ID);
      Original_Order : Interfaces.Unsigned_64;
      Original_Bytes : Natural;
      Original_Placements : Natural;
      Original_Conventional :
        Terminal.App.Image_Placements.Conventional_Placement_Access;
      Original_Virtual :
        Terminal.App.Image_Placements.Virtual_Placement_Access;
      Original_Placement_State :
        Terminal.App.Image_Placements.Conventional_Placement_State;
      Replacement_Data : Terminal.App.Owned_Image_Data.Owner;
      Stored : Image_Object_Access;
      Control : aliased Store.Allocation_Control;
      Saved_Transactional : constant Boolean :=
        R.Graphics_State.Transaction.Transactional_Image_Install;
      Saved_Failed : constant Boolean :=
        R.Graphics_State.Transaction.Image_Store_Allocation_Failed;
      Saved_Last_Order : constant Interfaces.Unsigned_64 :=
        R.Graphics_State.Transaction.Last_Stored_Image_Order;
      Saved_Last_Serial : constant Interfaces.Unsigned_64 :=
        R.Graphics_State.Transaction.Last_Stored_Image_Content_Serial;
      Saved_Replaced_Order : constant Interfaces.Unsigned_64 :=
        R.Graphics_State.Transaction.Replaced_Image_Order;

      procedure Restore_Transaction_State is
      begin
         R.Graphics_State.Transaction.Transactional_Image_Install :=
           Saved_Transactional;
         R.Graphics_State.Transaction.Image_Store_Allocation_Failed :=
           Saved_Failed;
         R.Graphics_State.Transaction.Last_Stored_Image_Order :=
           Saved_Last_Order;
         R.Graphics_State.Transaction.Last_Stored_Image_Content_Serial :=
           Saved_Last_Serial;
         R.Graphics_State.Transaction.Replaced_Image_Order :=
           Saved_Replaced_Order;
      end Restore_Transaction_State;
   begin
      Assert (Original /= null, "index-failure test image exists");
      Original_Order := Store.Storage_Order (Original.all);
      Original_Bytes := Store.Byte_Count
        (R.Graphics_State.Resources.Image_Objects);
      Original_Placements := Terminal.App.Image_Placements.Count
        (R.Graphics_State.Resources.Placements);
      Original_Conventional := Terminal.App.Image_Placements.First_Conventional
        (R.Graphics_State.Resources.Placements);
      Original_Virtual := Terminal.App.Image_Placements.First_Virtual
        (R.Graphics_State.Resources.Placements);
      Assert
        (Original_Placements = 1
         and then Original_Conventional /= null
         and then Original_Virtual = null,
         "index-failure test has one conventional placement to preserve");
      Original_Placement_State :=
        Terminal.App.Image_Placements.State (Original_Conventional);
      Assert
        (Original_Placement_State.Image_Storage_Order = Original_Order,
         "index-failure test placement references the original image");

      Terminal.App.Owned_Image_Data.Allocate
        (Replacement_Data, Store.Decoded_Length (Original.all));
      Terminal.App.Owned_Image_Data.Fill (Replacement_Data, 16#A5#);
      Store.Testing.Fail_Allocation_After (Control, 3);
      R.Graphics_State.Transaction.Transactional_Image_Install := False;
      R.Graphics_State.Transaction.Image_Store_Allocation_Failed := False;

      Take_Image_Object
        (R,
         Stream_ID,
         Image_ID,
         Store.Number (Original.all),
         Store.Usage_Hint (Original.all),
         Store.Protocol (Original.all),
         Store.Raw_Format (Original.all),
         Store.Pixel_Width (Original.all),
         Store.Pixel_Height (Original.all),
         Store.Decoded_Length (Original.all),
         Store.Decoded_Row_Stride_Bytes (Original.all),
         Replacement_Data,
         Stored,
         Index_Control => Control'Access);

      Assert
        (Stored = null
         and then R.Graphics_State.Transaction.Image_Store_Allocation_Failed,
         "renderer reports the injected image-index allocation failure");
      Assert
        (Terminal.App.Renderer.Image_Objects.Find
           (R, Stream_ID, Image_ID) = Original
         and then Store.Storage_Order (Original.all) = Original_Order
         and then Store.Byte_Count
           (R.Graphics_State.Resources.Image_Objects) = Original_Bytes,
         "index failure preserves the original renderer image");
      Assert
        (Terminal.App.Image_Placements.Count
           (R.Graphics_State.Resources.Placements) = Original_Placements
         and then Terminal.App.Image_Placements.First_Conventional
           (R.Graphics_State.Resources.Placements) = Original_Conventional
         and then Terminal.App.Image_Placements.First_Virtual
           (R.Graphics_State.Resources.Placements) = Original_Virtual
         and then Terminal.App.Image_Placements.State
           (Original_Conventional) = Original_Placement_State,
         "index failure preserves renderer placement identity and state");
      Assert
        (not Terminal.App.Owned_Image_Data.Is_Empty (Replacement_Data),
         "index failure returns replacement storage to its caller");

      Restore_Transaction_State;
   exception
      when others =>
         Restore_Transaction_State;
         raise;
   end Verify_Index_Failure_Preserves_Placements;

   procedure Verify_Delete_Rejection_Preserves_Placements
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Image_ID  : Terminal.Core.Graphics_ID)
   is
      use AUnit.Assertions;
      use type Terminal.App.Image_Placements.Conventional_Placement_Access;
      use type Terminal.App.Image_Store.Image_Object_Access;
      use type Terminal.Core.Graphics_ID;
      use type Terminal.Core.Graphics_Stream_ID;

      package Store renames Terminal.App.Image_Store;
      package Themes renames Terminal.App.Image_Store.Themes;

      Object : constant Store.Image_Object_Access :=
        Terminal.App.Renderer.Image_Objects.Find (R, Stream_ID, Image_ID);
      Placement : constant
        Terminal.App.Image_Placements.Conventional_Placement_Access :=
          Terminal.App.Image_Placements.First_Conventional
            (R.Graphics_State.Resources.Placements);
      Placement_Count : constant Natural :=
        Terminal.App.Image_Placements.Count
          (R.Graphics_State.Resources.Placements);
      Operation : Store.Theme_Operation_Access;
      Data : Terminal.App.Owned_Image_Data.Owner;
      Rejected : Boolean := False;
   begin
      Terminal.App.Renderer.Frame_Lifecycle.Reset (R);
      Assert
        (Object /= null and then Placement /= null,
         "delete-rejection fixture has an image placement");
      Themes.Create
        ((Is_Composition => True,
          Source_Frame => 1,
          Region_Width => 1,
          Region_Height => 1,
          others => <>),
         Data,
         Operation);
      declare
         Transaction : Themes.Append_Transaction
           (R.Graphics_State.Resources.Image_Objects'Access);
      begin
         Themes.Start (Transaction, Object, Operation);
         begin
            Terminal.App.Renderer.Image_Objects.Delete_By_Storage_Order
              (R, Stream_ID, Store.Storage_Order (Object.all));
         exception
            when Program_Error =>
               Rejected := True;
         end;
         Assert
           (Rejected
            and then Terminal.App.Renderer.Image_Objects.Find
              (R, Stream_ID, Image_ID) = Object
            and then Terminal.App.Image_Placements.Count
              (R.Graphics_State.Resources.Placements) = Placement_Count
            and then Terminal.App.Image_Placements.First_Conventional
              (R.Graphics_State.Resources.Placements) = Placement,
            "rejected image deletion preserves placements and object");
         Themes.Rollback (Transaction);
      end;
   end Verify_Delete_Rejection_Preserves_Placements;

   procedure Verify_Placement_Preflight_Preserves_All
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Image_ID  : Terminal.Core.Graphics_ID)
   is
      use AUnit.Assertions;
      use type Terminal.App.Image_Placements.Conventional_Placement_Access;
      use type Terminal.App.Image_Store.Image_Object_Access;
      use type Terminal.Core.Graphics_ID;
      use type Terminal.Core.Graphics_Stream_ID;

      package Placements renames Terminal.App.Image_Placements;
      package Placement_Testing renames
        Terminal.App.Image_Placements.Testing;
      package State renames Terminal.App.Renderer.Placement_State;
      package Store renames Terminal.App.Image_Store;

      Object : constant Store.Image_Object_Access :=
        Terminal.App.Renderer.Image_Objects.Find (R, Stream_ID, Image_ID);
      Original : Placements.Conventional_Placement_Access :=
        Placements.First_Conventional
          (R.Graphics_State.Resources.Placements);
      Candidate : Placements.Conventional_Placement_Access :=
        new Placements.Conventional_Placement;
      Added : Placements.Conventional_Placement_Access;
      Original_Count : Natural;
      Key_Removed : Boolean := False;
      Rejected : Boolean := False;
      Callback_Rejected : Boolean := False;

      procedure Configure
        (Item : in out Placements.Conventional_Placement_State) is
      begin
         Item.Stream_ID := Stream_ID;
         Item.Image_ID := Image_ID;
         Item.Image_Storage_Order := Store.Storage_Order (Object.all);
         Item.Placement_ID := Terminal.Core.Graphics_ID'Last;
      end Configure;

      function Matches
        (Item : Conventional_Placement_State) return Boolean is
        (Item.Stream_ID = Stream_ID and then Item.Image_ID = Image_ID);

      procedure Reject_Preparation
        (Item : Conventional_Placement_State) is
         pragma Unreferenced (Item);
      begin
         raise Constraint_Error with "injected delete preparation failure";
      end Reject_Preparation;

      procedure Remove_Added is
         Position : State.Conventional_Cursor;
      begin
         if Added /= null
           and then Placements.First_Conventional
             (R.Graphics_State.Resources.Placements) = Added
         then
            Position := State.First_Conventional (R);
            State.Delete (R, Position);
            Added := null;
         elsif Candidate /= null then
            Placements.Release_Unowned (Candidate);
         end if;
      end Remove_Added;
   begin
      Assert
        (Object /= null and then Original /= null,
         "placement-preflight fixture has an image and placement");
      Original_Count := Placements.Count
        (R.Graphics_State.Resources.Placements);
      Placements.Configure_Unlinked (Candidate, Configure'Access);
      State.Prepend_Conventional_Placement (R, Candidate);
      Added := Placements.First_Conventional
        (R.Graphics_State.Resources.Placements);
      Assert
        (Candidate = null and then Added /= Original
         and then Placements.Next (Added) = Original,
         "placement-preflight fixture adds a leading placement");

      Placement_Testing.Remove_Conventional_Key
        (R.Graphics_State.Resources.Placements, Original);
      Key_Removed := True;
      begin
         State.Delete_Conventional_Placements
           (R,
            Stream_ID,
            Image_ID,
            Match_Protocol => False);
      exception
         when Program_Error =>
            Rejected := True;
      end;
      Placement_Testing.Restore_Conventional_Key
        (R.Graphics_State.Resources.Placements, Original);
      Key_Removed := False;

      Assert
        (Rejected
         and then Terminal.App.Renderer.Image_Objects.Find
           (R, Stream_ID, Image_ID) = Object
         and then Placements.Count
           (R.Graphics_State.Resources.Placements) = Original_Count + 1
         and then Placements.First_Conventional
           (R.Graphics_State.Resources.Placements) = Added
         and then Placements.Next (Added) = Original,
         "placement preflight rejects before deleting any matching placement");

      begin
         State.Delete_Conventional_If
           (R, Matches'Access, Reject_Preparation'Access);
      exception
         when Constraint_Error =>
            Callback_Rejected := True;
      end;
      Assert
        (Callback_Rejected
         and then Placements.Count
           (R.Graphics_State.Resources.Placements) = Original_Count + 1
         and then Placements.First_Conventional
           (R.Graphics_State.Resources.Placements) = Added
         and then Placements.Next (Added) = Original,
         "placement preparation failure precedes every removal");
      Remove_Added;
   exception
      when others =>
         if Key_Removed then
            Placement_Testing.Restore_Conventional_Key
              (R.Graphics_State.Resources.Placements, Original);
         end if;
         Remove_Added;
         raise;
   end Verify_Placement_Preflight_Preserves_All;
end Terminal.App.Renderer.Testing.Image_Transactions;

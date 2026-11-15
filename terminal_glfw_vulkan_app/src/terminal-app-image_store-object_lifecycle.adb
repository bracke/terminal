with Ada.Unchecked_Deallocation;
with System;

package body Terminal.App.Image_Store.Object_Lifecycle is
   use type System.Address;

   procedure Free is new Ada.Unchecked_Deallocation
     (Image_Object, Image_Object_Access);

   procedure Create (Object : out Image_Object_Access) is
   begin
      Object := new Image_Object;
   end Create;

   procedure Release_Unowned (Object : in out Image_Object_Access) is
   begin
      if Object = null then
         return;
      elsif Object.Owner /= System.Null_Address
        or else Object.Next /= null
        or else Object.Counted
        or else Object.Replaces /= null
      then
         raise Program_Error with "cannot release an owned image object";
      end if;
      Release_Contents (Object.all);
      Free (Object);
   end Release_Unowned;

   procedure Link_New
     (Container : in out Store;
      Object    : Image_Object_Access) is
   begin
      if Object = null then
         raise Constraint_Error with "cannot link a null image object";
      elsif Object.Owner /= System.Null_Address then
         raise Program_Error with "image object is already owned";
      elsif Owned_Bytes (Object.all) /= 0
        or else Object.State.Frames /= null
        or else Object.State.Theme_Operations /= null
      then
         raise Program_Error with "new image object must not own data";
      elsif Container.Objects = Natural'Last then
         raise Storage_Error with "image object count overflow";
      end if;
      declare
         Accounted_Bytes : constant Natural := Owned_Bytes (Object.all);
         Accounted_Frames : constant Natural := Object.State.Frame_Count - 1;
         New_Bytes : constant Natural :=
           Checked_Total (Container.Bytes, Accounted_Bytes);
         New_Frames : constant Natural :=
           Checked_Total (Container.Animation_Frames, Accounted_Frames);
      begin
         Object.Counted := True;
         Object.Replaces := null;
         Object.Owner := Container'Address;
         Object.Accounted_Bytes := Accounted_Bytes;
         Object.Accounted_Frames := Accounted_Frames;
         Container.Bytes := New_Bytes;
         Container.Animation_Frames := New_Frames;
         Object.Previous := null;
         Object.Next := Container.Head;
         if Container.Head /= null then
            Container.Head.Previous := Object;
         end if;
         Container.Head := Object;
         Container.Objects := Container.Objects + 1;
         Advance_Mutation_Epoch (Container);
      end;
   end Link_New;

   procedure Link_Replacement
     (Container : in out Store;
      Object    : Image_Object_Access;
      Replaced  : Image_Object_Access) is
   begin
      if Object = null then
         raise Constraint_Error with "cannot link a null image object";
      elsif Object.Owner /= System.Null_Address then
         raise Program_Error with "image object is already owned";
      elsif Owned_Bytes (Object.all) /= 0
        or else Object.State.Frames /= null
        or else Object.State.Theme_Operations /= null
      then
         raise Program_Error with "replacement image object must not own data";
      elsif Replaced = null
        or else not Is_Owned (Container, Replaced)
        or else not Replaced.Counted
      then
         raise Program_Error with "replacement target is not committed";
      elsif Replaced.Pending_Replacement /= null then
         raise Program_Error with "replacement is already pending";
      end if;
      declare
         Accounted_Bytes : constant Natural := Owned_Bytes (Object.all);
         Accounted_Frames : constant Natural := Object.State.Frame_Count - 1;
         New_Bytes : constant Natural :=
           Checked_Total (Container.Bytes, Accounted_Bytes);
         New_Frames : constant Natural :=
           Checked_Total (Container.Animation_Frames, Accounted_Frames);
      begin
         Object.Counted := False;
         Object.Replaces := Replaced;
         Object.Owner := Container'Address;
         Object.Accounted_Bytes := Accounted_Bytes;
         Object.Accounted_Frames := Accounted_Frames;
         Container.Bytes := New_Bytes;
         Container.Animation_Frames := New_Frames;
         Object.Previous := null;
         Object.Next := Container.Head;
         if Container.Head /= null then
            Container.Head.Previous := Object;
         end if;
         Container.Head := Object;
         Replaced.Pending_Replacement := Object;
         Advance_Mutation_Epoch (Container);
      end;
   end Link_Replacement;
end Terminal.App.Image_Store.Object_Lifecycle;

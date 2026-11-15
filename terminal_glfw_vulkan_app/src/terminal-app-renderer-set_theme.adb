with Ada.Containers;
with Ada.Containers.Hashed_Sets;
with Ada.Unchecked_Deallocation;

separate (Terminal.App.Renderer)
procedure Set_Theme
  (R      : in out Renderer;
   T      : Terminal.App.Theme.Theme;
   Status : out Theme_Update_Status)
is
   type Backup;
   type Backup_Access is access Backup;
   type Backup is limited record
      Object : Image_Object_Access := null;
      Frame  : Positive := 1;
      Data   : Terminal.App.Owned_Image_Data.Owner;
      Next   : Backup_Access := null;
   end record;
   procedure Free_Backup is new Ada.Unchecked_Deallocation
     (Backup, Backup_Access);

   Head : Backup_Access := null;
   Object : Image_Object_Access;
   Previous_Theme : constant Terminal.App.Theme.Theme := R.View_State.Color_Theme;
   Outcome : Theme_Update_Status := Theme_Ok;
   Theme_Changed : Boolean := False;
   Rollback_Failed : Boolean := False;

   function Hash_Frame (Value : Positive) return Ada.Containers.Hash_Type is
     (Ada.Containers.Hash_Type'Mod (Value));
   package Frame_Sets is new Ada.Containers.Hashed_Sets
     (Element_Type        => Positive,
      Hash                => Hash_Frame,
      Equivalent_Elements => "=");

   function Is_Theme_Sensitive (Item : Image_Object_Access) return Boolean is
     (Item /= null
      and then
        (Themes.Count (Item) > 0
         or else
           (Terminal.App.Image_Store.Indexed_Data_Format (Item) in 8 | 16
            and then Image_Objects.Has_Stored_Indexed (Item)
            and then Image_Objects.Has_Stored_Root (Item))));

   procedure Add_Bounded
     (Total  : in out Natural;
      Amount : Natural) is
   begin
      if Amount > R.Graphics_State.Policy.Limits.Theme_Transaction_Bytes
        or else Total > R.Graphics_State.Policy.Limits.Theme_Transaction_Bytes - Amount
      then
         raise Storage_Error with "theme transaction scratch quota exceeded";
      end if;
      Total := Total + Amount;
   end Add_Bounded;

   procedure Check_Scratch_Reservation is
      Backup_Bytes : Natural := 0;
      Maximum_Working_Bytes : Natural := 0;
      Item : Image_Object_Access :=
        Terminal.App.Image_Store.First (R.Graphics_State.Resources.Image_Objects);
   begin
      while Item /= null loop
         if Is_Theme_Sensitive (Item) then
            declare
               Borrow : Terminal.App.Image_Store.Data_Borrow;
               Position : Frames.Cursor;
            begin
               Terminal.App.Image_Store.Borrow (Borrow, Item);
               Position := Frames.First (Borrow);
               while Frames.Has_Element (Position) loop
                  declare
                     Found : Boolean := False;
                     procedure Charge
                       (Source : Terminal.Common.Bytes.Byte_Array) is
                     begin
                        Add_Bounded (Backup_Bytes, Source'Length);
                        Found := True;
                     end Charge;
                  begin
                     Found := Frames.Visit_Data
                       (Borrow, Position, Charge'Access);
                     if not Found then
                        raise Constraint_Error with
                          "theme backup frame is unavailable";
                     end if;
                  end;
                  Frames.Next (Borrow, Position);
               end loop;
            end;

            declare
               Pixel_Count : Natural;
               Canvas_Bytes : Natural;
               Working_Bytes : Natural := 0;
               Seen : Frame_Sets.Set;

               procedure Charge_If_First
                 (Frame : Natural)
               is
               begin
                  if Frame > 0
                    and then not Seen.Contains (Positive (Frame))
                  then
                     Seen.Insert (Positive (Frame));
                     Add_Bounded (Working_Bytes, Canvas_Bytes);
                  end if;
               end Charge_If_First;

               Borrow : Terminal.App.Image_Store.Data_Borrow;
               Position : Themes.Cursor;
            begin
               if Item.Pixel_Width = 0
                 or else Item.Pixel_Height = 0
                 or else Item.Pixel_Width > Natural'Last / Item.Pixel_Height
                 or else Item.Pixel_Width * Item.Pixel_Height > Natural'Last / 4
               then
                  raise Constraint_Error with
                    "theme image dimensions are invalid";
               end if;
               Pixel_Count := Item.Pixel_Width * Item.Pixel_Height;
               Canvas_Bytes := Pixel_Count * 4;
               if Themes.Count (Item) = 0
               then
                  --  Indexed recoloring builds an RGBA canvas while retaining
                  --  a private copy of the indexed source under a controlled
                  --  store borrow.  Both allocations are transient parts of
                  --  the same theme transaction.
                  Working_Bytes := Canvas_Bytes;
                  Add_Bounded
                    (Working_Bytes,
                     Terminal.App.Image_Store
                       .Indexed_Data_Allocation_Length (Item));
               else
                  --  Replay owns two work canvases plus one private canvas
                  --  for each distinct frame named by retained history.  An
                  --  exact count avoids rejecting long histories that edit
                  --  the same small set of frames repeatedly.
                  Add_Bounded (Working_Bytes, Canvas_Bytes);
                  Add_Bounded (Working_Bytes, Canvas_Bytes);
                  Terminal.App.Image_Store.Borrow (Borrow, Item);
                  Position := Themes.First (Borrow);
                  while Themes.Has_Element (Position) loop
                     declare
                        Operation : constant
                          Terminal.App.Image_Store.Theme_Operation_Descriptor :=
                          Themes.Descriptor (Borrow, Position);
                     begin
                        Charge_If_First (Operation.Target_Frame);
                        if Operation.Is_Composition then
                           Charge_If_First (Operation.Source_Frame);
                        elsif Operation.New_Frame then
                           Charge_If_First (Operation.Base_Frame);
                        end if;
                     end;
                     Themes.Next (Borrow, Position);
                  end loop;
               end if;
               Maximum_Working_Bytes := Natural'Max
                 (Maximum_Working_Bytes, Working_Bytes);
            end;
         end if;
         Item := Terminal.App.Image_Store.Next_Object (Item);
      end loop;
      Add_Bounded (Backup_Bytes, Maximum_Working_Bytes);
   end Check_Scratch_Reservation;

   procedure Save
     (Item : Image_Object_Access;
      Frame : Positive;
      Source : Terminal.Common.Bytes.Byte_Array)
   is
      Node : Backup_Access := null;
      Data : Terminal.App.Owned_Image_Data.Owner;
   begin
      if not Terminal.App.Image_Store.Allocation_Allowed
        (R.Graphics_State.Resources.Allocation_Control)
      then
         raise Storage_Error with "theme backup allocation rejected";
      end if;
      Terminal.App.Owned_Image_Data.Allocate (Data, Source'Length);
      Terminal.App.Owned_Image_Data.Copy (Data, Source);
      Node := new Backup;
      Node.Object := Item;
      Node.Frame := Frame;
      Node.Next := Head;
      Terminal.App.Owned_Image_Data.Move (Data, Node.Data);
      Head := Node;
   exception
      when others =>
         if Node /= null then
            Free_Backup (Node);
         end if;
         raise;
   end Save;

   procedure Release_Backups is
      Current : Backup_Access := Head;
   begin
      Head := null;
      while Current /= null loop
         declare
            Next : constant Backup_Access := Current.Next;
         begin
            Free_Backup (Current);
            Current := Next;
         end;
      end loop;
   end Release_Backups;

   procedure Restore is
      Current : Backup_Access;
   begin
      R.View_State.Color_Theme := Previous_Theme;
      while Head /= null loop
         Current := Head;
         if Current.Frame = 1 then
            Terminal.App.Image_Store.Replace_Root_RGBA
              (R.Graphics_State.Resources.Image_Objects, Current.Object, Current.Data,
               Preserve_Indexed => True);
         else
            Frames.Replace_Data
              (R.Graphics_State.Resources.Image_Objects, Current.Object, Current.Frame, Current.Data);
         end if;
         Touch_Image_Object (R, Current.Object);
         --  Consume each successfully restored node immediately.  If a later
         --  restore fails, cleanup sees only the still-owned remainder and no
         --  already-transferred buffer can be applied twice.
         Head := Current.Next;
         Free_Backup (Current);
      end loop;
      R.Text_State.Atlas_Dirty := True;
   end Restore;

   procedure Roll_Back_Once is
   begin
      if not Theme_Changed then
         return;
      end if;
      --  Clear the guard before entering fallible store operations.  A
      --  rollback exception must propagate, not recursively retry with
      --  buffers that earlier iterations may already have transferred.
      Theme_Changed := False;
      Restore;
   exception
      when others =>
         Rollback_Failed := True;
         Release_Backups;
         raise;
   end Roll_Back_Once;

   function Recolor_Indexed
     (Item : Image_Object_Access) return Theme_Update_Status
   is
      Target : Terminal.App.Owned_Image_Data.Owner;
      Length : Natural;
      Success : Boolean := False;
   begin
      if Item = null
        or else Item.Pixel_Width = 0
        or else Item.Pixel_Height = 0
        or else Item.Pixel_Width > Natural'Last / Item.Pixel_Height
        or else Item.Pixel_Width * Item.Pixel_Height > Natural'Last / 4
      then
         return Theme_Replay_Failed;
      end if;
      Length := Item.Pixel_Width * Item.Pixel_Height * 4;
      if not Terminal.App.Image_Store.Allocation_Allowed
        (R.Graphics_State.Resources.Allocation_Control)
      then
         return Theme_Allocation_Failed;
      end if;
      Terminal.App.Owned_Image_Data.Allocate (Target, Length);
      declare
         Borrow : Terminal.App.Image_Store.Data_Borrow;
         Source : Terminal.App.Owned_Image_Data.Owner;
      begin
         Terminal.App.Image_Store.Borrow (Borrow, Item);
         declare
            Source_Length : constant Natural :=
              Terminal.App.Image_Store.Borrowed_Indexed_Length (Borrow);
         begin
            if Source_Length = 0 then
               return Theme_Replay_Failed;
            elsif not Terminal.App.Image_Store.Allocation_Allowed
              (R.Graphics_State.Resources.Allocation_Control)
            then
               return Theme_Allocation_Failed;
            end if;
            Terminal.App.Owned_Image_Data.Allocate (Source, Source_Length);
         end;
         declare
            procedure Copy_Source
              (Bytes : in out Terminal.Common.Bytes.Byte_Array) is
            begin
               Terminal.App.Image_Store.Copy_Indexed_Data (Borrow, Bytes);
            end Copy_Source;
            procedure Expand_Target
              (Target_Bytes : in out Terminal.Common.Bytes.Byte_Array) is
               procedure Expand_Source
                 (Source_Bytes : Terminal.Common.Bytes.Byte_Array) is
               begin
                  Success := Style.Expand_Kitty_Indexed
                    (R,
                     Terminal.App.Image_Store.Indexed_Data_Format (Item),
                     Item.Pixel_Width,
                     Item.Pixel_Height,
                     Source_Bytes,
                     Target_Bytes);
               end Expand_Source;
            begin
               Terminal.App.Owned_Image_Data.Read
                 (Source, Expand_Source'Access);
            end Expand_Target;
         begin
            Terminal.App.Owned_Image_Data.Modify
              (Source, Copy_Source'Access);
            Terminal.App.Owned_Image_Data.Modify
              (Target, Expand_Target'Access);
         end;
      end;
      if Success then
         Terminal.App.Image_Store.Replace_Root_RGBA
           (R.Graphics_State.Resources.Image_Objects, Item, Target, Preserve_Indexed => True);
         return Theme_Ok;
      else
         return Theme_Replay_Failed;
      end if;
   exception
      when Storage_Error =>
         return Theme_Allocation_Failed;
   end Recolor_Indexed;
begin
   if R.Lifecycle.Closed then
      Status := Theme_Closed;
      return;
   end if;

   Check_Scratch_Reservation;

   --  Snapshot all affected pixels before changing either the theme or any
   --  object.  This makes a multi-image theme switch transactional.
   Object := Terminal.App.Image_Store.First (R.Graphics_State.Resources.Image_Objects);
   while Object /= null loop
      if Is_Theme_Sensitive (Object) then
         declare
            Borrow : Terminal.App.Image_Store.Data_Borrow;
            Position : Frames.Cursor;
         begin
            Terminal.App.Image_Store.Borrow (Borrow, Object);
            Position := Frames.First (Borrow);
            while Frames.Has_Element (Position) loop
               declare
                  Info : constant Frames.Frame_Descriptor :=
                    Frames.Descriptor (Borrow, Position);
                  Saved : Boolean;
                  procedure Save_Frame
                    (Source : Terminal.Common.Bytes.Byte_Array) is
                  begin
                     Save (Object, Info.Number, Source);
                  end Save_Frame;
               begin
                  Saved := Frames.Visit_Data
                    (Borrow, Position, Save_Frame'Access);
                  if not Saved then
                     raise Constraint_Error with
                       "theme backup frame is unavailable";
                  end if;
               end;
               Frames.Next (Borrow, Position);
            end loop;
         end;
      end if;
      Object := Terminal.App.Image_Store.Next_Object (Object);
   end loop;

   --  Existing frame and submission descriptors borrow the buffers replaced
   --  below.  Invalidate them before publishing any recolored data.
   Frame_Lifecycle.Reset (R);
   R.View_State.Color_Theme := T;
   Theme_Changed := True;
   Object := Terminal.App.Image_Store.First (R.Graphics_State.Resources.Image_Objects);
   while Object /= null and then Outcome = Theme_Ok loop
      if Is_Theme_Sensitive (Object) then
         Outcome :=
           (if Themes.Count (Object) > 0
            then (if Image_Theme_State.Replay_Theme_Operations (R, Object)
                  then Theme_Ok
                  else Theme_Replay_Failed)
            else Recolor_Indexed (Object));
         if Outcome = Theme_Ok then
            Touch_Image_Object (R, Object);
         end if;
      end if;
      Object := Terminal.App.Image_Store.Next_Object (Object);
   end loop;

   if Outcome /= Theme_Ok then
      Roll_Back_Once;
   else
      R.Text_State.Atlas_Dirty := True;
      Text_Pipeline.Invalidate_Caches (R);
   end if;
   Release_Backups;
   Status := Outcome;
exception
   when Storage_Error =>
      if Rollback_Failed then
         --  A failed restore is an invariant failure, not an ordinary
         --  transaction allocation refusal.  Preserve that exception rather
         --  than reporting a clean rollback that did not occur.
         Release_Backups;
         raise;
      end if;
      Roll_Back_Once;
      Release_Backups;
      Status := Theme_Allocation_Failed;
   when others =>
      Roll_Back_Once;
      Release_Backups;
      raise;
end Set_Theme;

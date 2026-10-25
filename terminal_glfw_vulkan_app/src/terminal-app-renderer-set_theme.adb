separate (Terminal.App.Renderer)
procedure Set_Theme
  (R      : in out Renderer;
   T      : Terminal.App.Theme.Theme;
   Status : out Theme_Update_Status)
is
   type Backup;
   type Backup_Access is access Backup;
   type Backup is record
      Object : Image_Object_Access := null;
      Frame  : Positive := 1;
      Data   : RM.Image_Data_Access := null;
      Next   : Backup_Access := null;
   end record;
   procedure Free_Backup is new Ada.Unchecked_Deallocation
     (Backup, Backup_Access);

   Head : Backup_Access := null;
   Object : Image_Object_Access;
   Previous_Theme : constant Terminal.App.Theme.Theme := R.Color_Theme;
   Outcome : Theme_Update_Status := Theme_Ok;
   Theme_Changed : Boolean := False;
   Rollback_Failed : Boolean := False;

   function Is_Theme_Sensitive (Item : Image_Object_Access) return Boolean is
     (Item /= null
      and then
        (Terminal.App.Image_Store.First_Theme_Operation (Item) /= null
         or else
           (Terminal.App.Image_Store.Indexed_Data_Format (Item) in 8 | 16
            and then Terminal.App.Image_Store.Indexed_Data (Item) /= null
            and then Terminal.App.Image_Store.Root_Data (Item) /= null)));

   procedure Add_Bounded
     (Total  : in out Natural;
      Amount : Natural) is
   begin
      if Amount > R.Graphics_Limits.Theme_Transaction_Bytes
        or else Total > R.Graphics_Limits.Theme_Transaction_Bytes - Amount
      then
         raise Storage_Error with "theme transaction scratch quota exceeded";
      end if;
      Total := Total + Amount;
   end Add_Bounded;

   procedure Check_Scratch_Reservation is
      Backup_Bytes : Natural := 0;
      Maximum_Working_Bytes : Natural := 0;
      Item : Image_Object_Access :=
        Terminal.App.Image_Store.First (R.Image_Objects);
   begin
      while Item /= null loop
         if Is_Theme_Sensitive (Item) then
            for Frame in 1 ..
              Terminal.App.Image_Store.Frame_Count_Of (Item)
            loop
               declare
                  Source : constant RM.Image_Data_View :=
                    Terminal.App.Image_Store.Frame_Bytes (Item, Frame);
               begin
                  if Source = null then
                     raise Constraint_Error with
                       "theme backup frame is unavailable";
                  end if;
                  Add_Bounded (Backup_Bytes, Source'Length);
               end;
            end loop;

            declare
               Pixel_Count : Natural;
               Canvas_Bytes : Natural;
               Working_Bytes : Natural := 0;

               function References
                 (Operation : Theme_Operation_Access;
                  Frame     : Positive) return Boolean
               is
               begin
                  return Operation.Target_Frame = Frame
                    or else
                      (Operation.Is_Composition
                       and then Operation.Source_Frame = Frame)
                    or else
                      (Operation.New_Frame
                       and then Operation.Base_Frame = Frame);
               end References;

               function Seen_Before
                 (Stop  : Theme_Operation_Access;
                  Frame : Positive) return Boolean
               is
                  Previous : Theme_Operation_Access :=
                    Terminal.App.Image_Store.First_Theme_Operation (Item);
               begin
                  while Previous /= null and then Previous /= Stop loop
                     if References (Previous, Frame) then
                        return True;
                     end if;
                     Previous :=
                       Terminal.App.Image_Store.Next_Theme_Operation
                         (Previous);
                  end loop;
                  return False;
               end Seen_Before;

               procedure Charge_If_First
                 (Operation : Theme_Operation_Access;
                  Frame     : Natural)
               is
               begin
                  if Frame > 0
                    and then not Seen_Before (Operation, Positive (Frame))
                  then
                     Add_Bounded (Working_Bytes, Canvas_Bytes);
                  end if;
               end Charge_If_First;

               Operation : Theme_Operation_Access;
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
               if Terminal.App.Image_Store.First_Theme_Operation (Item) = null
               then
                  Working_Bytes := Canvas_Bytes;
               else
                  --  Replay owns two work canvases plus one private canvas
                  --  for each distinct frame named by retained history.  An
                  --  exact count avoids rejecting long histories that edit
                  --  the same small set of frames repeatedly.
                  Add_Bounded (Working_Bytes, Canvas_Bytes);
                  Add_Bounded (Working_Bytes, Canvas_Bytes);
                  Operation :=
                    Terminal.App.Image_Store.First_Theme_Operation (Item);
                  while Operation /= null loop
                     Charge_If_First
                       (Operation, Operation.Target_Frame);
                     if Operation.Is_Composition then
                        Charge_If_First
                          (Operation, Operation.Source_Frame);
                     elsif Operation.New_Frame then
                        Charge_If_First
                          (Operation, Operation.Base_Frame);
                     end if;
                     Operation :=
                       Terminal.App.Image_Store.Next_Theme_Operation
                         (Operation);
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
      Frame : Positive)
   is
      Source : constant RM.Image_Data_View :=
        Terminal.App.Image_Store.Frame_Bytes (Item, Frame);
      Node : Backup_Access := null;
      Data : RM.Image_Data_Access := null;
   begin
      if Source = null then
         raise Constraint_Error with "theme backup frame is unavailable";
      elsif not Terminal.App.Image_Store.Allocation_Allowed
        (R.Image_Allocation_Control)
      then
         raise Storage_Error with "theme backup allocation rejected";
      end if;
      Data := new Terminal.Common.Bytes.Byte_Array'(Source.all);
      Node := new Backup'
        (Object => Item,
         Frame  => Frame,
         Data   => Data,
         Next   => Head);
      Data := null;
      Head := Node;
   exception
      when others =>
         Free_Image_Data (Data);
         if Node /= null then
            Free_Image_Data (Node.Data);
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
            Free_Image_Data (Current.Data);
            Free_Backup (Current);
            Current := Next;
         end;
      end loop;
   end Release_Backups;

   procedure Restore is
      Current : Backup_Access;
   begin
      R.Color_Theme := Previous_Theme;
      while Head /= null loop
         Current := Head;
         if Current.Frame = 1 then
            Terminal.App.Image_Store.Replace_Root_RGBA
              (R.Image_Objects, Current.Object, Current.Data,
               Preserve_Indexed => True);
         else
            Terminal.App.Image_Store.Replace_Frame_Data
              (R.Image_Objects, Current.Object, Current.Frame, Current.Data);
         end if;
         Touch_Image_Object (R, Current.Object);
         --  Consume each successfully restored node immediately.  If a later
         --  restore fails, cleanup sees only the still-owned remainder and no
         --  already-transferred buffer can be applied twice.
         Head := Current.Next;
         Free_Image_Data (Current.Data);
         Free_Backup (Current);
      end loop;
      R.Atlas_Dirty := True;
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
      Target : RM.Image_Data_Access := null;
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
        (R.Image_Allocation_Control)
      then
         return Theme_Allocation_Failed;
      end if;
      Target := new Terminal.Common.Bytes.Byte_Array (1 .. Length);
      Success := Expand_Kitty_Indexed
        (R,
         Terminal.App.Image_Store.Indexed_Data_Format (Item),
         Item.Pixel_Width,
         Item.Pixel_Height,
         Terminal.App.Image_Store.Indexed_Data (Item),
         Target);
      if Success then
         Terminal.App.Image_Store.Replace_Root_RGBA
           (R.Image_Objects, Item, Target, Preserve_Indexed => True);
         return Theme_Ok;
      else
         Free_Image_Data (Target);
         return Theme_Replay_Failed;
      end if;
   exception
      when Storage_Error =>
         Free_Image_Data (Target);
         return Theme_Allocation_Failed;
   end Recolor_Indexed;
begin
   if R.Closed then
      Status := Theme_Closed;
      return;
   end if;

   Check_Scratch_Reservation;

   --  Snapshot all affected pixels before changing either the theme or any
   --  object.  This makes a multi-image theme switch transactional.
   Object := Terminal.App.Image_Store.First (R.Image_Objects);
   while Object /= null loop
      if Is_Theme_Sensitive (Object) then
         for Frame in 1 .. Terminal.App.Image_Store.Frame_Count_Of (Object) loop
            Save (Object, Frame);
         end loop;
      end if;
      Object := Terminal.App.Image_Store.Next_Object (Object);
   end loop;

   --  Existing frame and submission descriptors borrow the buffers replaced
   --  below.  Invalidate them before publishing any recolored data.
   Reset_Frame (R);
   R.Color_Theme := T;
   Theme_Changed := True;
   Object := Terminal.App.Image_Store.First (R.Image_Objects);
   while Object /= null and then Outcome = Theme_Ok loop
      if Is_Theme_Sensitive (Object) then
         Outcome :=
           (if Terminal.App.Image_Store.First_Theme_Operation (Object) /= null
            then (if Replay_Theme_Operations (R, Object)
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
      R.Atlas_Dirty := True;
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

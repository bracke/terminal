separate (Terminal.App.Renderer)
procedure Apply_Image_Event
  (R      : in out Renderer;
   Event  : Terminal.Core.Graphics_Event;
   Snapshot : Terminal.Core.Render_Snapshot;
   Placement_Status : out Placement_Store_Status)
is
   Event_Header : constant Terminal.App.Graphics.Graphics_Header :=
     Terminal.App.Graphics.Header (Event);
   Header : Terminal.App.Graphics.Graphics_Header :=
     Event_Header;
   Image_Count_Before : constant Natural := Frame_Image_Count (R);
   Prepared_Virtual : Virtual_Placement_Access := null;
   Prepared_Conventional : Conventional_Placement_Access := null;

   procedure Release_Prepared_Placement is
   begin
      if Prepared_Virtual /= null then
         Free_Virtual_Placement (Prepared_Virtual);
      end if;
      if Prepared_Conventional /= null then
         Free_Conventional_Placement (Prepared_Conventional);
      end if;
   end Release_Prepared_Placement;

   procedure Roll_Back_Combined_Install is
      Object : constant Image_Object_Access :=
        Find_Image_Object_By_Storage_Order
          (R, Event.Stream_ID, R.Last_Stored_Image_Order);
      Released_Bytes : constant Natural :=
        (if Object = null
         then 0
         else Terminal.App.Image_Store.Owned_Bytes (Object.all));
   begin
      if R.Last_Stored_Image_Order = 0 then
         return;
      end if;
      Delete_Image_Object_By_Storage_Order
        (R,
         Event.Stream_ID,
         R.Last_Stored_Image_Order,
         Counted => R.Replaced_Image_Order = 0);
      if R.Image_Install_Count > 0 then
         R.Image_Install_Count := R.Image_Install_Count - 1;
      end if;
      R.Image_Installed_Bytes :=
        R.Image_Installed_Bytes - Interfaces.Unsigned_64 (Released_Bytes);
      R.Last_Stored_Image_Order := 0;
      R.Last_Stored_Image_Content_Serial := 0;
   end Roll_Back_Combined_Install;

   procedure Apply_Deletion is separate;
begin
   Placement_Status := Placement_Not_Requested;
   --  Every accepted graphics event may replace an object or mutate a
   --  placement.  Rebuild the renderer's lookup index once, immediately
   --  before retained images are emitted.
   R.Placement_Index_Dirty := True;
   --  These fields describe only the event currently being applied.  Clear
   --  them before any validation so exception cleanup can never roll back
   --  an object installed by an earlier command.
   R.Last_Stored_Image_Order := 0;
   R.Last_Stored_Image_Content_Serial := 0;
   R.Replaced_Image_Order := 0;
   R.Transactional_Image_Install := False;
   if Event.Protocol = Terminal.Core.Kitty_Graphics
     and then Header.Recognized
     and then Header.Kitty_ID > 0
     and then Header.Kitty_Image_Number > 0
   then
      --  The protocol makes i= and I= mutually exclusive for every
      --  command. Do not let an invalid command mutate either store.
      return;
   end if;

   if Event.Protocol = Terminal.Core.Kitty_Graphics
     and then Header.Recognized
     and then
       (not Header.Kitty_Control_Data_Valid
        or else not Header.Kitty_Action_Controls_Valid
        or else not Header.Kitty_Transmission_Valid
        or else not Header.Kitty_Compression_Valid
        or else
          (Header.Kitty_Transmission in 'f' | 't' | 's'
           and then
             (not Header.Kitty_Data_Size_Valid
              or else not Header.Kitty_Data_Offset_Valid
              or else Header.Kitty_More_Specified)))
   then
      Truncate_Image_Commands (R, Image_Count_Before);
      return;
   end if;

   if Event.Protocol = Terminal.Core.Kitty_Graphics
     and then Header.Recognized
     and then Header.Kitty_Image_Number > 0
   then
      if Header.Kitty_Action in 't' | 'T' and then Header.Has_Data then
         --  Allocate once the complete transmission is available. The
         --  first m=1 chunk is retained without consuming an ID.
         if not Event_Header.Kitty_More then
            Header.Kitty_ID := Allocate_Image_ID (R, Event.Stream_ID);
            if Header.Kitty_ID = 0 then
               return;
            end if;
         end if;
      else
         declare
            Object : constant Image_Object_Access :=
              Find_Image_Object_By_Number
                (R, Event.Stream_ID, Header.Kitty_Image_Number);
         begin
            Header.Kitty_ID :=
              (if Object = null then 0 else Object.ID);
         end;
      end if;
   end if;

   if Event.Protocol = Terminal.Core.Kitty_Graphics
     and then Header.Recognized
     and then Header.Kitty_Action = 'd'
   then
      --  Chunk assembly is core-owned, so a delete reaches the renderer
      --  only after any partial transfer has already been cancelled.
      --  Lowercase selectors retain reusable data; uppercase selectors
      --  may release it once no retained placement references it.
      Apply_Deletion;
      Truncate_Image_Commands (R, Image_Count_Before);
      return;
   end if;

   if Event.Protocol = Terminal.Core.Kitty_Graphics
     and then Header.Recognized
     and then Header.Kitty_Action = 'T'
     and then Header.Has_Data
   then
      --  Allocate the placement before replacing an image object.  Once
      --  image installation begins, combined transmit-and-display commands
      --  have no remaining fallible placement allocation.
      if Header.Kitty_Virtual_Placement
        and then Header.Kitty_Parent_ID /= 0
      then
         Placement_Status := Placement_Rejected;
         return;
      elsif Header.Kitty_Parent_ID /= 0 then
         Placement_Status :=
           To_Placement_Status
             (Validate_Relative_Placement
                (R,
                 Event.Stream_ID,
                 Event.Alternate_Screen,
                 Event.Screen_Generation,
                 Header.Kitty_ID,
                 Header.Kitty_Placement_ID,
                 Header.Kitty_Parent_ID,
                 Header.Kitty_Parent_Placement_ID));
         if Placement_Status /= Placement_Stored then
            return;
         end if;
      end if;

      declare
         Needs_Allocation : constant Boolean :=
           (if Header.Kitty_Virtual_Placement
            then Find_Addressed_Virtual_Placement
              (R,
               Event.Stream_ID,
               Header.Kitty_ID,
               Header.Kitty_Placement_ID) = null
            else Find_Addressed_Conventional_Placement
              (R,
               Event.Stream_ID,
               Header.Kitty_ID,
               Header.Kitty_Placement_ID) = null);
      begin
         if Needs_Allocation
           and then R.Kitty_Placement_Count >=
             R.Graphics_Limits.Placements
         then
            R.Image_Store_Allocation_Failed := True;
            Placement_Status := Placement_No_Space;
            return;
         elsif Needs_Allocation
           and then not Terminal.App.Image_Store.Allocation_Allowed
             (R.Image_Allocation_Control)
         then
            R.Image_Store_Allocation_Failed := True;
            Placement_Status := Placement_No_Space;
            return;
         end if;
         if Needs_Allocation then
            begin
               if Header.Kitty_Virtual_Placement then
                  Prepared_Virtual := new Virtual_Placement;
               else
                  Prepared_Conventional := new Conventional_Placement;
               end if;
            exception
               when Storage_Error =>
                  R.Image_Store_Allocation_Failed := True;
                  Placement_Status := Placement_No_Space;
                  return;
            end;
         end if;
      end;
   end if;

   if Event.Protocol = Terminal.Core.Kitty_Graphics
     and then Header.Recognized
     and then Header.Kitty_Action = 'a'
     and then not Header.Has_Data
   then
      Apply_Animation_Control (R, Event, Header);
      Truncate_Image_Commands (R, Image_Count_Before);
      return;
   elsif Event.Protocol = Terminal.Core.Kitty_Graphics
     and then Header.Recognized
     and then Header.Kitty_Action = 'c'
     and then not Header.Has_Data
   then
      Apply_Animation_Composition (R, Event, Header);
      Truncate_Image_Commands (R, Image_Count_Before);
      return;
   end if;

   if Event.Protocol = Terminal.Core.Kitty_Graphics
     and then Header.Recognized
     and then
       (Header.Kitty_Action not in 't' | 'T' | 'p' | 'f'
        or else
          (Header.Kitty_Action in 't' | 'T' and then not Header.Has_Data)
        or else
          (Header.Kitty_Action = 'p' and then Header.Has_Data)
        or else
          (Header.Kitty_Action = 'f' and then not Header.Has_Data))
   then
      --  Unsupported animation/control actions and invalid action/data
      --  combinations must not accidentally replace an image object or
      --  become visible through the generic image fallback.
      Truncate_Image_Commands (R, Image_Count_Before);
      return;
   end if;

   R.Transactional_Image_Install :=
     Event.Protocol = Terminal.Core.Kitty_Graphics
     and then Header.Recognized
     and then Header.Kitty_Action = 'T'
     and then Header.Has_Data;
   Add_Image_Event
     (R,
      Event,
      Resolved_Image_ID     => Header.Kitty_ID,
      Resolved_Image_Number => Header.Kitty_Image_Number);
   R.Transactional_Image_Install := False;

   if Event.Protocol in
     Terminal.Core.Sixel_Graphics | Terminal.Core.ITerm2_Graphics
     and then R.Last_Stored_Image_Order /= 0
   then
      --  The retained placement is emitted later in this same frame and
      --  on subsequent frames. Drop the decoder's transient command to
      --  avoid drawing the newly installed image twice.
      Truncate_Image_Commands (R, Image_Count_Before);
   end if;

   if Event.Protocol = Terminal.Core.Kitty_Graphics
     and then Header.Recognized
     and then
       (Header.Kitty_Action = 'p'
        or else Header.Kitty_Action = 'T')
   then
      --  Placement commands persist after their APC event is consumed.
      --  U=1 defines an invisible prototype whose cells are supplied by
      --  Unicode placeholders; ordinary placements retain their terminal
      --  cursor anchor and are emitted on every frame.
      if (Header.Kitty_ID > 0
          and then Find_Image_Object
            (R, Event.Stream_ID, Header.Kitty_ID) /= null
          and then
            (Header.Kitty_Action = 'p'
             or else R.Last_Stored_Image_Order /= 0))
        or else
          (Header.Kitty_ID = 0
           and then Header.Kitty_Action = 'T'
           and then Find_Image_Object_By_Storage_Order
             (R, Event.Stream_ID, R.Last_Stored_Image_Order) /= null)
      then
         Truncate_Image_Commands (R, Image_Count_Before);
         if Header.Kitty_Virtual_Placement then
            Placement_Status := Store_Virtual_Placement
              (R, Event, Header, Prepared_Virtual);
         else
            Placement_Status := Store_Conventional_Placement
              (R, Event, Header, Prepared_Conventional);
         end if;
      elsif Header.Kitty_ID > 0 then
         --  An addressed combined command must not leave a transient
         --  fallback drawable behind when object installation failed.
         Truncate_Image_Commands (R, Image_Count_Before);
      end if;
   elsif Event.Protocol = Terminal.Core.Kitty_Graphics
     and then Header.Recognized
     and then Header.Kitty_Action in 't' | 'f'
   then
      --  Transmit-only installs or replaces an image object without
      --  creating a visible placement.
      Truncate_Image_Commands (R, Image_Count_Before);
   end if;

   if Event.Protocol = Terminal.Core.Kitty_Graphics
     and then Header.Recognized
     and then Header.Kitty_Action = 'T'
     and then Header.Has_Data
   then
      if Placement_Status = Placement_Stored then
         if R.Replaced_Image_Order /= 0 then
            Delete_Image_Object_By_Storage_Order
              (R,
               Event.Stream_ID,
               R.Replaced_Image_Order,
               Counted => False);
         end if;
      elsif R.Last_Stored_Image_Order /= 0 then
         --  A combined operation is atomic: a rejected or resource-bound
         --  placement must not publish the newly transmitted image.
         Roll_Back_Combined_Install;
      end if;
      R.Replaced_Image_Order := 0;
   end if;
   Release_Prepared_Placement;
exception
   when others =>
      R.Transactional_Image_Install := False;
      --  Commands borrow image-store and decoder buffers.  Drop every command
      --  emitted by this event before rollback can release either backing
      --  allocation.
      Truncate_Image_Commands (R, Image_Count_Before);
      --  Prepared placements are renderer-owned scratch and do not depend on
      --  the image-store rollback.  Release them first so a rollback failure
      --  cannot leak them while propagating the original invariant failure.
      Release_Prepared_Placement;
      if Event.Protocol = Terminal.Core.Kitty_Graphics
        and then Header.Recognized
        and then Header.Kitty_Action = 'T'
        and then Header.Has_Data
      then
         Roll_Back_Combined_Install;
         R.Replaced_Image_Order := 0;
      end if;
      raise;
end Apply_Image_Event;

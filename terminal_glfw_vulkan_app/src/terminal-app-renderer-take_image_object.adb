separate (Terminal.App.Renderer)
procedure Take_Image_Object
  (R              : in out Renderer;
   Stream_ID      : Terminal.Core.Graphics_Stream_ID;
   ID             : Terminal.Core.Graphics_ID;
   Image_Number   : Terminal.Core.Graphics_ID;
   Usage_Hint     : Natural;
   Protocol       : RM.Image_Protocol;
   Raw_Format     : Natural;
   Pixel_Width    : Natural;
   Pixel_Height   : Natural;
   Decoded_Length : Natural;
   Decoded_Row_Stride_Bytes : Natural;
   Bytes          : in out Terminal.App.Owned_Image_Data.Owner;
   Stored_Object  : out Image_Object_Access;
   Additional_Bytes : Natural := 0;
   Index_Control  : access Terminal.App.Image_Store.Allocation_Control := null)
is
   Object : Image_Object_Access := Image_Objects.Find (R, Stream_ID, ID);
   Stored_Length : Natural := 0;
   Created_Object : Boolean := False;
   Created_Replacement : Boolean := False;
   Replaced_Object : Image_Object_Access := null;
   Commit_Immediately : Boolean := False;

   procedure Roll_Back_New_Object is
   begin
      if Created_Replacement then
         Terminal.App.Image_Store.Delete_Replacement
           (R.Graphics_State.Resources.Image_Objects, Object);
         R.Graphics_State.Transaction.Replaced_Image_Order := 0;
         Created_Replacement := False;
      elsif Created_Object then
         Terminal.App.Image_Store.Delete_Object
           (R.Graphics_State.Resources.Image_Objects, Object);
         Created_Object := False;
      end if;
   end Roll_Back_New_Object;
begin
   Stored_Object := null;
   R.Graphics_State.Transaction.Last_Stored_Image_Order := 0;
   R.Graphics_State.Transaction.Last_Stored_Image_Content_Serial := 0;
   if Terminal.App.Owned_Image_Data.Is_Empty (Bytes)
     or else Decoded_Length = 0
     or else Raw_Format = 0
     or else Pixel_Width = 0
     or else Pixel_Height = 0
   then
      return;
   end if;

   if Additional_Bytes >
     Natural'Last - Terminal.App.Owned_Image_Data.Length (Bytes)
   then
      R.Graphics_State.Transaction.Image_Store_Allocation_Failed := True;
      return;
   end if;
   Stored_Length :=
     Terminal.App.Owned_Image_Data.Length (Bytes) + Additional_Bytes;

   if Stored_Length > R.Graphics_State.Policy.Limits.Image_Bytes then
      R.Graphics_State.Transaction.Image_Store_Allocation_Failed := True;
      return;
   end if;
   if Stored_Length > R.Graphics_State.Policy.Limits.Per_Image_Bytes
     or else Pixel_Width > R.Graphics_State.Policy.Limits.Pixel_Dimension
     or else Pixel_Height > R.Graphics_State.Policy.Limits.Pixel_Dimension
   then
      R.Graphics_State.Transaction.Image_Store_Allocation_Failed := True;
      return;
   end if;

   --  A transactional replacement keeps the old object alive until the new
   --  placement commits.  Account for both live objects here: subtracting the
   --  old object would make the configured resident-memory limit ineffective
   --  during every replacement.
   while Terminal.App.Image_Store.Byte_Count (R.Graphics_State.Resources.Image_Objects) >
       R.Graphics_State.Policy.Limits.Image_Bytes - Stored_Length
     or else
       ((Object = null or else R.Graphics_State.Transaction.Transactional_Image_Install)
        and then Terminal.App.Image_Store.Object_Count (R.Graphics_State.Resources.Image_Objects) >=
          R.Graphics_State.Policy.Limits.Image_Objects)
   loop
      if not Image_Objects.Evict_One_Unplaced (R, Stream_ID, ID) then
         R.Graphics_State.Transaction.Image_Store_Allocation_Failed := True;
         return;
      end if;
      Object := Image_Objects.Find (R, Stream_ID, ID);
   end loop;

   if Object = null then
      declare
         Candidate : Image_Object_Access;
      begin
         Terminal.App.Image_Store.Create_Object (Candidate);
         begin
            Placements_State.Invalidate_Placement_Index (R);
            Terminal.App.Image_Store.Link_New
              (R.Graphics_State.Resources.Image_Objects, Candidate);
         exception
            when others =>
               Terminal.App.Image_Store.Release_Unowned_Object (Candidate);
               raise;
         end;
         Object := Candidate;
         Created_Object := True;
      end;
   else
      --  Every retransmission is installed into a separate object.  A plain
      --  transmit commits it immediately after installation; a combined
      --  transmit-and-display keeps it pending until placement succeeds.
      declare
         Previous_Order : constant Interfaces.Unsigned_64 :=
           Object.Storage_Order;
         Replaced : constant Image_Object_Access := Object;
         Replacement : Image_Object_Access;
      begin
         Terminal.App.Image_Store.Create_Object (Replacement);
         begin
            Placements_State.Invalidate_Placement_Index (R);
            Terminal.App.Image_Store.Link_Replacement
              (R.Graphics_State.Resources.Image_Objects, Replacement, Replaced);
         exception
            when others =>
               Terminal.App.Image_Store.Release_Unowned_Object
                 (Replacement);
               raise;
         end;
         Replaced_Object := Replaced;
         Object := Replacement;
         Commit_Immediately :=
           not R.Graphics_State.Transaction.Transactional_Image_Install;
         if not Commit_Immediately then
            R.Graphics_State.Transaction.Replaced_Image_Order := Previous_Order;
         end if;
         Created_Replacement := True;
      end;
   end if;

   declare
   begin
      Placements_State.Invalidate_Placement_Index (R);
      Terminal.App.Image_Store.Install_Root
        (Container      => R.Graphics_State.Resources.Image_Objects,
         Object         => Object,
         Stream_ID      => Stream_ID,
         ID             => ID,
         Number         => Image_Number,
         Protocol       => Protocol,
         Raw_Format     => Raw_Format,
         Pixel_Width    => Pixel_Width,
         Pixel_Height   => Pixel_Height,
         Decoded_Length => Decoded_Length,
         Row_Stride     => Decoded_Row_Stride_Bytes,
         Usage_Hint     => Usage_Hint,
         Data           => Bytes,
         Index_Control  => Index_Control);
      if Commit_Immediately then
         Terminal.App.Image_Store.Delete_Replacement
           (R.Graphics_State.Resources.Image_Objects, Replaced_Object);
         Created_Replacement := False;
         Placements_State.Delete_Virtual_Placements (R, Stream_ID, ID);
         Placements_State.Delete_Conventional_Placements (R, Stream_ID, ID);
      end if;
      Terminal.Common.Counters.Increment_Saturating
        (R.Graphics_State.Telemetry.Image_Install_Count);
      Terminal.Common.Counters.Add_Saturating
        (R.Graphics_State.Telemetry.Image_Installed_Bytes,
         Interfaces.Unsigned_64 (Stored_Length));
      R.Graphics_State.Transaction.Last_Stored_Image_Order := Object.Storage_Order;
      R.Graphics_State.Transaction.Last_Stored_Image_Content_Serial := Object.Content_Serial;
      Stored_Object := Object;
   end;
   Delete_Orphaned_Relative_Placements
     (R, Stream_ID, Preserve_Image_ID => ID);
exception
   when Storage_Error =>
      Roll_Back_New_Object;
      R.Graphics_State.Transaction.Image_Store_Allocation_Failed := True;
      Stored_Object := null;
   when others =>
      Roll_Back_New_Object;
      raise;
end Take_Image_Object;

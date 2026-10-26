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
   Bytes          : in out RM.Image_Data_Access;
   Stored_Bytes   : out RM.Image_Data_View;
   Additional_Bytes : Natural := 0)
is
   Object : Image_Object_Access := Find_Image_Object (R, Stream_ID, ID);
   Stored_Length : Natural := 0;
   Created_Object : Boolean := False;
   Created_Replacement : Boolean := False;

   procedure Roll_Back_New_Object is
   begin
      if Created_Replacement then
         Terminal.App.Image_Store.Delete_Replacement
           (R.Image_Objects, Object);
         R.Replaced_Image_Order := 0;
         Created_Replacement := False;
      elsif Created_Object then
         Terminal.App.Image_Store.Delete_Object
           (R.Image_Objects, Object);
         Created_Object := False;
      end if;
   end Roll_Back_New_Object;
begin
   Stored_Bytes := null;
   R.Last_Stored_Image_Order := 0;
   R.Last_Stored_Image_Content_Serial := 0;
   if Bytes = null
     or else Decoded_Length = 0
     or else Raw_Format = 0
     or else Pixel_Width = 0
     or else Pixel_Height = 0
   then
      return;
   end if;

   if Additional_Bytes > Natural'Last - Bytes'Length then
      R.Image_Store_Allocation_Failed := True;
      return;
   end if;
   Stored_Length := Bytes'Length + Additional_Bytes;

   if Stored_Length > R.Graphics_Limits.Image_Bytes then
      R.Image_Store_Allocation_Failed := True;
      return;
   end if;
   if Stored_Length > R.Graphics_Limits.Per_Image_Bytes
     or else Pixel_Width > R.Graphics_Limits.Pixel_Dimension
     or else Pixel_Height > R.Graphics_Limits.Pixel_Dimension
   then
      R.Image_Store_Allocation_Failed := True;
      return;
   end if;

   --  A transactional replacement keeps the old object alive until the new
   --  placement commits.  Account for both live objects here: subtracting the
   --  old object would make the configured resident-memory limit ineffective
   --  during every replacement.
   while Terminal.App.Image_Store.Byte_Count (R.Image_Objects) >
       R.Graphics_Limits.Image_Bytes - Stored_Length
     or else
       ((Object = null or else R.Transactional_Image_Install)
        and then Terminal.App.Image_Store.Object_Count (R.Image_Objects) >=
          R.Graphics_Limits.Image_Objects)
   loop
      if not Evict_One_Unplaced_Image (R, Stream_ID, ID) then
         R.Image_Store_Allocation_Failed := True;
         return;
      end if;
      Object := Find_Image_Object (R, Stream_ID, ID);
   end loop;

   if Object = null then
      declare
         Candidate : Image_Object_Access;
      begin
         Terminal.App.Image_Store.Create_Object (Candidate);
         begin
            Terminal.App.Image_Store.Link_New
              (R.Image_Objects, Candidate);
         exception
            when others =>
               Terminal.App.Image_Store.Release_Unowned_Object (Candidate);
               raise;
         end;
         Object := Candidate;
         Created_Object := True;
      end;
   elsif R.Transactional_Image_Install then
      --  Keep the previous object and its placements intact until the
      --  combined transmit-and-display operation has installed its new
      --  placement.  Apply_Image_Event commits or rolls this object back.
      declare
         Previous_Order : constant Interfaces.Unsigned_64 :=
           Object.Storage_Order;
         Replaced : constant Image_Object_Access := Object;
         Replacement : Image_Object_Access;
      begin
         Terminal.App.Image_Store.Create_Object (Replacement);
         begin
            Terminal.App.Image_Store.Link_Replacement
              (R.Image_Objects, Replacement, Replaced);
         exception
            when others =>
               Terminal.App.Image_Store.Release_Unowned_Object
                 (Replacement);
               raise;
         end;
         Object := Replacement;
         R.Replaced_Image_Order := Previous_Order;
         Created_Replacement := True;
      end;
   else
      --  Retransmitting an explicit ID replaces both its data and every
      --  placement made from the previous object.
      Delete_Virtual_Placements (R, Stream_ID, ID);
      Delete_Conventional_Placements (R, Stream_ID, ID);
   end if;

   declare
   begin
      Terminal.App.Image_Store.Install_Root
        (Container      => R.Image_Objects,
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
         Data           => Bytes);
      R.Image_Install_Count := R.Image_Install_Count + 1;
      R.Image_Installed_Bytes :=
        R.Image_Installed_Bytes + Interfaces.Unsigned_64 (Stored_Length);
      R.Last_Stored_Image_Order := Object.Storage_Order;
      R.Last_Stored_Image_Content_Serial := Object.Content_Serial;
      Stored_Bytes := Terminal.App.Image_Store.Root_Data (Object);
   end;
   Delete_Orphaned_Relative_Placements
     (R, Stream_ID, Preserve_Image_ID => ID);
exception
   when Storage_Error =>
      Roll_Back_New_Object;
      R.Image_Store_Allocation_Failed := True;
      Stored_Bytes := null;
   when others =>
      Roll_Back_New_Object;
      raise;
end Take_Image_Object;

separate (Terminal.App.Image_Store)
procedure Install_Root
  (Container        : in out Store;
   Object           : Image_Object_Access;
   Stream_ID        : Terminal.Core.Graphics_Stream_ID;
   ID               : Terminal.Core.Graphics_ID;
   Number           : Terminal.Core.Graphics_ID;
   Protocol         : Terminal.App.Render_Model.Image_Protocol;
   Raw_Format       : Natural;
   Pixel_Width      : Natural;
   Pixel_Height     : Natural;
   Decoded_Length   : Natural;
   Row_Stride       : Natural;
   Usage_Hint       : Natural;
   Data             : in out Terminal.App.Owned_Image_Data.Owner;
   Index_Control    : access Allocation_Control := null)
is
   Storage_Order : Interfaces.Unsigned_64;
   Content_Serial : Interfaces.Unsigned_64;
begin
   if Terminal.App.Owned_Image_Data.Is_Empty (Data) then
      raise Constraint_Error with "cannot install null image data";
   elsif not Is_Owned (Container, Object) then
      raise Program_Error with "image object is not owned by this store";
   elsif Object.State.Storage_Order /= 0 or else Owned_Bytes (Object.all) /= 0
   then
      raise Program_Error with "image root must be installed into a fresh object";
   elsif Owns_Data_View
     (Object, Terminal.App.Owned_Image_Data.Unsafe_View (Data))
   then
      raise Program_Error with "root image data aliases owned storage";
   end if;
   if Decoded_Length /= Terminal.App.Owned_Image_Data.Length (Data) then
      raise Constraint_Error with "decoded length does not match image data";
   end if;
   Validate_Pixel_Data
     (Raw_Format, Pixel_Width, Pixel_Height, Row_Stride,
      Terminal.App.Owned_Image_Data.Length (Data));
   if Container.Bytes < Object.Accounted_Bytes
     or else Decoded_Length >
       Natural'Last - (Container.Bytes - Object.Accounted_Bytes)
   then
      raise Storage_Error with "image store accounting overflow";
   end if;

   Release_Contents (Object.all);
   Synchronize (Container, Object);
   Storage_Order := Allocate_Storage_Order (Container);
   Content_Serial := Allocate_Content_Serial (Container);
   Object.State.Stream_ID := Stream_ID;
   Object.State.ID := ID;
   Object.State.Number := Number;
   Object.State.Protocol := Protocol;
   Object.State.Raw_Format := Raw_Format;
   Object.State.Pixel_Width := Pixel_Width;
   Object.State.Pixel_Height := Pixel_Height;
   Object.State.Decoded_Length := Decoded_Length;
   Object.State.Decoded_Row_Stride_Bytes := Row_Stride;
   Object.State.Usage_Hint := Usage_Hint;
   Object.State.Storage_Order := Storage_Order;
   Object.State.Content_Serial := Content_Serial;
   Terminal.App.Owned_Image_Data.Move (Data, Object.Bytes);
   begin
      Synchronize (Container, Object);
      Terminal.App.Image_Store.Indexes.Install
        (Container, Object, Index_Control);
   exception
      when others =>
         --  Return the transferred allocation to the caller before clearing
         --  the partially installed object.  Dropping Object.Bytes here used
         --  to leak the allocation and left the Owner empty on failure.
         Terminal.App.Owned_Image_Data.Move (Object.Bytes, Data);
         Release_Contents (Object.all);
         Synchronize (Container, Object);
         raise;
   end;
end Install_Root;

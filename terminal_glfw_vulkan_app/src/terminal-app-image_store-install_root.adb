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
   Data             : in out Terminal.App.Render_Model.Image_Data_Access)
is
   Storage_Order : Interfaces.Unsigned_64;
   Content_Serial : Interfaces.Unsigned_64;
begin
   if Data = null then
      raise Constraint_Error with "cannot install null image data";
   elsif not Is_Owned (Container, Object) then
      raise Program_Error with "image object is not owned by this store";
   elsif Owns_Data (Object, Data) then
      raise Program_Error with "root image data aliases owned storage";
   end if;
   if Decoded_Length /= Data'Length then
      raise Constraint_Error with "decoded length does not match image data";
   end if;
   Validate_Pixel_Data
     (Raw_Format, Pixel_Width, Pixel_Height, Row_Stride, Data'Length);

   Release_Contents (Object.all);
   Synchronize (Container, Object);
   Storage_Order := Allocate_Storage_Order (Container);
   Content_Serial := Allocate_Content_Serial (Container);
   Object.Stream_ID := Stream_ID;
   Object.ID := ID;
   Object.Number := Number;
   Object.Protocol := Protocol;
   Object.Raw_Format := Raw_Format;
   Object.Pixel_Width := Pixel_Width;
   Object.Pixel_Height := Pixel_Height;
   Object.Decoded_Length := Decoded_Length;
   Object.Decoded_Row_Stride_Bytes := Row_Stride;
   Object.Usage_Hint := Usage_Hint;
   Object.Storage_Order := Storage_Order;
   Object.Content_Serial := Content_Serial;
   Object.Bytes := Data;
   begin
      Synchronize (Container, Object);
   exception
      when others =>
         Object.Bytes := null;
         Release_Contents (Object.all);
         Synchronize (Container, Object);
         raise;
   end;
   Data := null;
end Install_Root;

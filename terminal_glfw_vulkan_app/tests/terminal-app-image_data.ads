with Terminal.App.Render_Model;
with Terminal.Common.Bytes;

--  Test-only raw allocation adapter.  Production code exposes image storage
--  exclusively through Owned_Image_Data.Owner.
package Terminal.App.Image_Data is
   type Image_Data_Access is access all Terminal.Common.Bytes.Byte_Array;
   function Read_Only
     (Data : Image_Data_Access)
      return Terminal.App.Render_Model.Image_Data_View;
end Terminal.App.Image_Data;

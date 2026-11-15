with Interfaces;
with Terminal.Core;

private package Terminal.App.Renderer.Image_Objects is
   function Find
     (R         : Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      ID        : Terminal.Core.Graphics_ID) return Image_Object_Access;

   function Find_By_Storage_Order
     (R             : Renderer;
      Stream_ID     : Terminal.Core.Graphics_Stream_ID;
      Storage_Order : Interfaces.Unsigned_64) return Image_Object_Access;

   function Find_By_Number
     (R         : Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Number    : Terminal.Core.Graphics_ID) return Image_Object_Access;

   function Stored_Root_Length (Object : Image_Object_Access) return Natural;
   function Stored_Indexed_Length
     (Object : Image_Object_Access) return Natural;
   function Has_Stored_Root (Object : Image_Object_Access) return Boolean;
   function Has_Stored_Indexed (Object : Image_Object_Access) return Boolean;
   function Stored_Bytes (R : Renderer) return Natural;
   function Stored_Animation_Frame_Count (R : Renderer) return Natural;
   function Allocate_ID
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID)
      return Terminal.Core.Graphics_ID;

   procedure Release_All (R : in out Renderer);

   procedure Touch
     (R : in out Renderer; Object : Image_Object_Access);

   procedure Delete_Object
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      ID        : Terminal.Core.Graphics_ID);

   procedure Delete_ID_Range
     (R           : in out Renderer;
      Stream_ID   : Terminal.Core.Graphics_Stream_ID;
      First_ID    : Terminal.Core.Graphics_ID;
      Last_ID     : Terminal.Core.Graphics_ID;
      Delete_Data : Boolean);

   procedure Delete_By_Storage_Order
     (R             : in out Renderer;
      Stream_ID     : Terminal.Core.Graphics_Stream_ID;
      Storage_Order : Interfaces.Unsigned_64;
      Counted       : Boolean := True);

   function Evict_One_Unplaced
     (R                 : in out Renderer;
      Preserve_Stream   : Terminal.Core.Graphics_Stream_ID;
      Preserve_Image_ID : Terminal.Core.Graphics_ID) return Boolean;
end Terminal.App.Renderer.Image_Objects;

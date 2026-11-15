with Interfaces;
with Terminal.App.Owned_Image_Data;

package Terminal.App.Image_Store.Frames is
   procedure Create
     (Number     : Positive;
      Gap_MS     : Integer;
      Usage_Hint : Natural;
      Data       : in out Terminal.App.Owned_Image_Data.Owner;
      Frame      : out Image_Frame_Access);
   procedure Append_Unowned
     (Head, Tail : in out Image_Frame_Access;
      Frame      : in out Image_Frame_Access);
   procedure Release_Unowned (Head : in out Image_Frame_Access);

   type Frame_Descriptor is record
      Number     : Positive;
      Gap_MS     : Integer;
      Usage_Hint : Natural;
      Length     : Natural;
   end record;
   type Cursor is private;
   function First (Borrow : Data_Borrow) return Cursor;
   function Has_Element (Position : Cursor) return Boolean;
   procedure Next (Borrow : Data_Borrow; Position : in out Cursor);
   function Descriptor
     (Borrow   : Data_Borrow;
      Position : Cursor) return Frame_Descriptor;
   function Visit_Data
     (Borrow   : Data_Borrow;
      Position : Cursor;
      Process  : not null access procedure
        (Data : Terminal.Common.Bytes.Byte_Array)) return Boolean;
   function Count (Object : Image_Object_Access) return Natural;
   function Descriptor
     (Object : Image_Object_Access;
      Number : Positive) return Frame_Descriptor;
   function Exists
     (Object : Image_Object_Access;
      Number : Natural) return Boolean;
   function Gap
     (Object : Image_Object_Access;
      Number : Positive) return Integer;
   function Set_Gap
     (Container : in out Store;
      Object    : Image_Object_Access;
      Number    : Positive;
      Gap       : Integer) return Boolean;
   function Set_Usage_Hint
     (Container : in out Store;
      Object    : Image_Object_Access;
      Number    : Positive;
      Value     : Natural) return Boolean;
   procedure Copy_To_RGBA
     (Object : Image_Object_Access;
      Number : Positive;
      Target : in out Terminal.Common.Bytes.Byte_Array;
      Valid  : out Boolean);

   procedure Append
     (Container : in out Store;
      Object    : Image_Object_Access;
      Frame     : in out Image_Frame_Access);
   procedure Adopt
     (Container : in out Store;
      Object    : Image_Object_Access;
      Head      : in out Image_Frame_Access);
   procedure Replace_Data
     (Container : in out Store;
      Object    : Image_Object_Access;
      Number    : Positive;
      Data      : in out Terminal.App.Owned_Image_Data.Owner;
      Set_Gap   : Boolean := False;
      Gap_MS    : Integer := 0;
      Set_Usage : Boolean := False;
      Usage_Hint : Natural := 0);
   procedure Clear
     (Container : in out Store;
      Object    : Image_Object_Access);

private
   type Cursor is record
      Owner   : Image_Object_Access := null;
      Current : Image_Frame_Access := null;
      Is_Root : Boolean := False;
      Active  : Boolean := False;
      Token   : Interfaces.Unsigned_64 := 0;
   end record;
end Terminal.App.Image_Store.Frames;

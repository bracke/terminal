with Ada.Finalization;
with Interfaces;
with Terminal.App.Owned_Image_Data;

package Terminal.App.Image_Store.Themes is
   function Data_Description_Valid
     (Description : Theme_Operation_Descriptor;
      Length      : Natural) return Boolean;
   procedure Create
     (Description : Theme_Operation_Descriptor;
      Data        : in out Terminal.App.Owned_Image_Data.Owner;
      Operation   : out Theme_Operation_Access);
   procedure Append_Unowned
     (Head, Tail : in out Theme_Operation_Access;
      Operation  : in out Theme_Operation_Access);
   procedure Release_Unowned (Head : in out Theme_Operation_Access);
   function Unowned_Length
     (Operation : Theme_Operation_Access) return Natural;
   --  Traversal requires the same active data borrow that created the cursor.
   --  The private cursor advances directly through the list while the borrow
   --  pins its owning image object.
   type Cursor is private;
   function First (Borrow : Data_Borrow) return Cursor;
   function Has_Element (Position : Cursor) return Boolean;
   procedure Next (Borrow : Data_Borrow; Position : in out Cursor);
   function Descriptor
     (Borrow   : Data_Borrow;
      Position : Cursor) return Theme_Operation_Descriptor;
   function Visit_Data
     (Borrow   : Data_Borrow;
      Position : Cursor;
      Process  : not null access procedure
        (Data : Terminal.Common.Bytes.Byte_Array)) return Boolean;
   function Count (Object : Image_Object_Access) return Natural;
   procedure Clear (Container : in out Store; Object : Image_Object_Access);
   procedure Archive_Root
     (Container      : in out Store;
      Object         : Image_Object_Access;
      Max_Operations : Positive);

   --  A prepared theme-history suffix may need to precede the corresponding
   --  pixel mutation so allocation failure cannot publish pixels without
   --  replay history.  The transaction owns the whole appended suffix until
   --  Commit and removes it on Rollback.
   type Append_Transaction
     (Container : not null access Store) is limited private;
   procedure Start
     (Transaction : in out Append_Transaction;
      Object      : Image_Object_Access;
      Operation   : in out Theme_Operation_Access);
   procedure Commit (Transaction : in out Append_Transaction);
   procedure Rollback (Transaction : in out Append_Transaction);

private
   type Cursor is record
      Owner   : Image_Object_Access := null;
      Current : Theme_Operation_Access := null;
      Token   : Interfaces.Unsigned_64 := 0;
   end record;

   type Append_Transaction
     (Container : not null access Store) is
     new Ada.Finalization.Limited_Controlled with record
      Object        : Image_Object_Access := null;
      Previous_Tail : Theme_Operation_Access := null;
      Operation     : Theme_Operation_Access := null;
      Last          : Theme_Operation_Access := null;
      Count         : Natural := 0;
      Bytes         : Natural := 0;
   end record;
   overriding procedure Finalize (Transaction : in out Append_Transaction);
end Terminal.App.Image_Store.Themes;

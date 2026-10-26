with Ada.Finalization;

package Terminal.App.Image_Store.Themes is
   procedure Create
     (Description : Theme_Operation_Descriptor;
      Data        : in out Terminal.App.Render_Model.Image_Data_Access;
      Operation   : out Theme_Operation_Access);
   procedure Append_Unowned
     (Head, Tail : in out Theme_Operation_Access;
      Operation  : in out Theme_Operation_Access);
   procedure Release_Unowned (Head : in out Theme_Operation_Access);
   function First (Object : Image_Object_Access)
     return Theme_Operation_Access;
   function Next (Operation : Theme_Operation_Access)
     return Theme_Operation_Access;
   function Count (Object : Image_Object_Access) return Natural;
   procedure Adopt
     (Container : in out Store;
      Object    : Image_Object_Access;
      Head      : in out Theme_Operation_Access);
   procedure Append
     (Container : in out Store;
      Object    : Image_Object_Access;
      Operation : in out Theme_Operation_Access);
   procedure Clear (Container : in out Store; Object : Image_Object_Access);
   procedure Archive_Root
     (Container      : in out Store;
      Object         : Image_Object_Access;
      Max_Operations : Positive);

   --  A theme append may need to precede the corresponding pixel mutation so
   --  allocation failure cannot publish pixels without replay history.  The
   --  transaction owns the appended operation until Commit and removes it on
   --  Rollback.
   type Append_Transaction
     (Container : not null access Store) is limited private;
   procedure Start
     (Transaction : in out Append_Transaction;
      Object      : Image_Object_Access;
      Operation   : in out Theme_Operation_Access);
   procedure Commit (Transaction : in out Append_Transaction);
   procedure Rollback (Transaction : in out Append_Transaction);

private
   type Append_Transaction
     (Container : not null access Store) is
     new Ada.Finalization.Limited_Controlled with record
      Object        : Image_Object_Access := null;
      Previous_Tail : Theme_Operation_Access := null;
      Operation     : Theme_Operation_Access := null;
   end record;
   overriding procedure Finalize (Transaction : in out Append_Transaction);
end Terminal.App.Image_Store.Themes;

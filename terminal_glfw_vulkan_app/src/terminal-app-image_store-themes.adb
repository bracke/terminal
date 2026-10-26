with Terminal.App.Cleanup_Diagnostics;

package body Terminal.App.Image_Store.Themes is
   use type Terminal.App.Render_Model.Image_Data_Access;

   procedure Create
     (Description : Theme_Operation_Descriptor;
      Data        : in out Terminal.App.Render_Model.Image_Data_Access;
      Operation   : out Theme_Operation_Access) is
   begin
      Terminal.App.Image_Store.Create_Theme_Operation
        (Description, Data, Operation);
   end Create;
   procedure Append_Unowned
     (Head, Tail : in out Theme_Operation_Access;
      Operation  : in out Theme_Operation_Access) is
   begin
      Terminal.App.Image_Store.Append_Unowned_Theme_Operation
        (Head, Tail, Operation);
   end Append_Unowned;
   procedure Release_Unowned (Head : in out Theme_Operation_Access) is
   begin
      Terminal.App.Image_Store.Release_Unowned_Theme_Operations (Head);
   end Release_Unowned;
   function First (Object : Image_Object_Access)
     return Theme_Operation_Access is
     (Terminal.App.Image_Store.First_Theme_Operation (Object));
   function Next (Operation : Theme_Operation_Access)
     return Theme_Operation_Access is
     (Terminal.App.Image_Store.Next_Theme_Operation (Operation));
   function Count (Object : Image_Object_Access) return Natural is
     (Terminal.App.Image_Store.Theme_Operation_Count_Of (Object));
   procedure Adopt
     (Container : in out Store;
      Object    : Image_Object_Access;
      Head      : in out Theme_Operation_Access) is
   begin
      Terminal.App.Image_Store.Adopt_Theme_Operations
        (Container, Object, Head);
   end Adopt;
   procedure Append
     (Container : in out Store;
      Object    : Image_Object_Access;
      Operation : in out Theme_Operation_Access) is
   begin
      Terminal.App.Image_Store.Append_Theme_Operation
        (Container, Object, Operation);
   end Append;
   procedure Clear
     (Container : in out Store; Object : Image_Object_Access) is
   begin
      Terminal.App.Image_Store.Clear_Theme_Operations (Container, Object);
   end Clear;
   procedure Archive_Root
     (Container      : in out Store;
      Object         : Image_Object_Access;
      Max_Operations : Positive) is
   begin
      Terminal.App.Image_Store.Archive_Root_Theme_Operations
        (Container, Object, Max_Operations);
   end Archive_Root;

   procedure Start
     (Transaction : in out Append_Transaction;
      Object      : Image_Object_Access;
      Operation   : in out Theme_Operation_Access)
   is
      Previous : constant Theme_Operation_Access :=
        (if Object = null then null else Object.Theme_Operations_Tail);
   begin
      if Transaction.Operation /= null then
         raise Program_Error with "theme append transaction is already active";
      end if;
      Append_Theme_Operation (Transaction.Container.all, Object, Operation);
      Transaction.Object := Object;
      Transaction.Previous_Tail := Previous;
      Transaction.Operation := Object.Theme_Operations_Tail;
   end Start;

   procedure Commit (Transaction : in out Append_Transaction) is
   begin
      Transaction.Object := null;
      Transaction.Previous_Tail := null;
      Transaction.Operation := null;
   end Commit;

   procedure Rollback (Transaction : in out Append_Transaction) is
      Object : constant Image_Object_Access := Transaction.Object;
      Operation : Theme_Operation_Access := Transaction.Operation;
   begin
      if Operation = null then
         return;
      elsif not Is_Owned (Transaction.Container.all, Object)
        or else Object.Theme_Operations_Tail /= Operation
        or else Operation.Next /= null
      then
         raise Program_Error with "theme append transaction invariant violated";
      end if;

      if Transaction.Previous_Tail = null then
         Object.Theme_Operations := null;
      else
         Transaction.Previous_Tail.Next := null;
      end if;
      Object.Theme_Operations_Tail := Transaction.Previous_Tail;
      Object.Theme_Operation_Count := Object.Theme_Operation_Count - 1;
      Object.Theme_Operation_Bytes :=
        Object.Theme_Operation_Bytes - Operation.Length;
      if Operation.Bytes /= null then
         Object.Theme_Addresses.Delete (Operation.Bytes.all'Address);
      end if;
      Synchronize (Transaction.Container.all, Object);
      Transaction.Object := null;
      Transaction.Previous_Tail := null;
      Transaction.Operation := null;
      Release_Theme_Operation_List (Operation);
   end Rollback;

   overriding procedure Finalize
     (Transaction : in out Append_Transaction) is
   begin
      if Transaction.Operation /= null then
         Rollback (Transaction);
      end if;
   exception
      when others =>
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Theme_Transaction);
   end Finalize;
end Terminal.App.Image_Store.Themes;

with Terminal.Core.Hyperlink_Store;
with Terminal.Core.Storage;

package body Terminal.Core.Snapshot_Cell_Storage is
   procedure Release_Links
     (S     : in out Render_Snapshot;
      Cells : Snapshot_Cell_Array_Access) is
   begin
      if Cells /= null then
         for Item of Cells.all loop
            Hyperlink_Store.Release_Snapshot
              (S.Storage.Hyperlinks, Item.Link);
         end loop;
      end if;
   end Release_Links;

   procedure Release_Batch (S : in out Render_Snapshot) is
   begin
      Release_Links (S, S.Storage.Batch_Cells);
      Storage.Release (S.Storage.Batch_Cells);
   end Release_Batch;

   procedure Acquire_Batch
     (S           : in out Render_Snapshot;
      Count       : Positive;
      Replacement : out Snapshot_Cell_Array_Access) is
   begin
      if S.Storage.Batch_Cells /= null
        and then S.Storage.Batch_Cells'Length = Count
      then
         Replacement := S.Storage.Batch_Cells;
         S.Storage.Batch_Cells := null;
      else
         Release_Batch (S);
         Replacement := new Snapshot_Cell_Array (1 .. Count);
      end if;
      --  This is the sole boundary at which recycled storage is handed to a
      --  producer.  It always starts without owned hyperlink references.
      Release_Links (S, Replacement);
   end Acquire_Batch;

   procedure Abandon_Batch
     (S           : in out Render_Snapshot;
      Replacement : in out Snapshot_Cell_Array_Access) is
   begin
      if Replacement = null then
         return;
      end if;
      Release_Links (S, Replacement);
      Release_Batch (S);
      S.Storage.Batch_Cells := Replacement;
      Replacement := null;
   end Abandon_Batch;

   procedure Commit_Batch
     (S           : in out Render_Snapshot;
      Replacement : in out Snapshot_Cell_Array_Access)
   is
      Previous : Snapshot_Cell_Array_Access;
   begin
      if Replacement = null then
         raise Program_Error with "cannot commit an empty snapshot batch";
      end if;
      Previous := S.Storage.Cells_Data;
      S.Storage.Cells_Data := Replacement;
      Replacement := null;
      Release_Links (S, Previous);
      Release_Batch (S);
      S.Storage.Batch_Cells := Previous;
   end Commit_Batch;
end Terminal.Core.Snapshot_Cell_Storage;

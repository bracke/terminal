private package Terminal.Core.Snapshot_Cell_Storage is
   procedure Release_Links
     (S     : in out Render_Snapshot;
      Cells : Snapshot_Cell_Array_Access);

   procedure Acquire_Batch
     (S           : in out Render_Snapshot;
      Count       : Positive;
      Replacement : out Snapshot_Cell_Array_Access);

   procedure Abandon_Batch
     (S           : in out Render_Snapshot;
      Replacement : in out Snapshot_Cell_Array_Access);

   procedure Commit_Batch
     (S           : in out Render_Snapshot;
      Replacement : in out Snapshot_Cell_Array_Access);
end Terminal.Core.Snapshot_Cell_Storage;

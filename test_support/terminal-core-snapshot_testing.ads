package Terminal.Core.Snapshot_Testing is
   --  Presentation-only override for synthetic snapshots.  The queued
   --  graphics event deliberately retains its original identity.
   procedure Set_Presentation_Context
     (S                 : in out Render_Snapshot;
      Stream            : Graphics_Stream_ID;
      Transaction       : Graphics_Transaction_Generation;
      Alternate         : Boolean;
      Screen_Generation : Graphics_Screen_Generation);

   function Cell_Replacement_Is_Atomic
     (S : in out Render_Snapshot) return Boolean;

   function Batch_Replacement_Is_Atomic
     (S : in out Render_Snapshot) return Boolean;

   function Snapshot_Refresh_Is_Atomic
     (T          : Terminal'Class;
      S          : in out Render_Snapshot;
      Force_Full : Boolean;
      Successful_Interns : Natural) return Boolean;

   function Prepared_Hyperlink_Scratch_Is_Clear
     (S : Render_Snapshot) return Boolean;

   function Cleanup_Diagnostic_Is_Observable return Boolean;
end Terminal.Core.Snapshot_Testing;

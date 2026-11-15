package Terminal.Core.Snapshot_Editing is
   procedure Set_Cursor
     (S : in out Render_Snapshot; Value : Cursor_State);
   procedure Set_Graphics
     (S : in out Render_Snapshot; Value : Graphics_Event);
   procedure Set_Scrollback_Offset
     (S : in out Render_Snapshot; Value : Natural);
   procedure Set_Cell
     (S     : in out Render_Snapshot;
      Index : Positive;
      Value : Cell);
   procedure Replace_All_Cells
     (S           : in out Render_Snapshot;
      Value_At    : not null access function
        (Index : Positive) return Cell);
   procedure Set_Cell_Style
     (S     : in out Render_Snapshot;
      Index : Positive;
      Value : Cell_Style);
   procedure Set_Dirty_Row
     (S     : in out Render_Snapshot;
      Row   : Positive;
      Value : Boolean);
end Terminal.Core.Snapshot_Editing;

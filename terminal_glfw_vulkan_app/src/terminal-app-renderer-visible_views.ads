private package Terminal.App.Renderer.Visible_Views is
   procedure Set_All
     (R : in out Renderer; Snapshots : Snapshot_Array);
   procedure Set_One
     (R : in out Renderer; Snapshot : Terminal.Core.Render_Snapshot);
end Terminal.App.Renderer.Visible_Views;

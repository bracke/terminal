package body Terminal.App.Renderer.Layout is
   procedure Render_App
     (R              : in out Renderer;
      Snapshots      : Snapshot_Array;
      Active_Index   : Positive;
      Tabs           : Terminal.App.Tabs.Tab_Snapshot;
      Splits         : Terminal.App.Splits.Split_Snapshot;
      Status         : out Render_Status) is
   begin
      Terminal.App.Renderer.Render_App
        (R, Snapshots, Active_Index, Tabs, Splits, Status);
   end Render_App;
end Terminal.App.Renderer.Layout;

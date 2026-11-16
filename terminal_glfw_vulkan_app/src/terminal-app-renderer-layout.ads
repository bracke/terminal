with Terminal.App.Splits;
with Terminal.App.Tabs;

package Terminal.App.Renderer.Layout is
   procedure Render_App
     (R              : in out Renderer;
      Snapshots      : Snapshot_Array;
      Active_Index   : Positive;
      Tabs           : Terminal.App.Tabs.Tab_Snapshot;
      Splits         : Terminal.App.Splits.Split_Snapshot;
      Status         : out Render_Status);
   procedure Render_Pane_Layout
     (R              : in out Renderer;
      Snapshots      : Snapshot_Array;
      Active_Index   : Positive;
      Tabs           : Terminal.App.Tabs.Tab_Snapshot;
      Layout         : Terminal.App.Splits.Pane_Layout;
      Status         : out Render_Status);
end Terminal.App.Renderer.Layout;

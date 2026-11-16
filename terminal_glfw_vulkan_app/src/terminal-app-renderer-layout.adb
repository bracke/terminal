package body Terminal.App.Renderer.Layout is
   use type Terminal.Core.Graphics_Stream_ID;
   use type Terminal.App.Splits.Split_Orientation;

   procedure Render_Pane_Layout
     (R              : in out Renderer;
      Snapshots      : Snapshot_Array;
      Active_Index   : Positive;
      Tabs           : Terminal.App.Tabs.Tab_Snapshot;
      Layout         : Terminal.App.Splits.Pane_Layout;
      Status         : out Render_Status) is
   begin
      if Snapshots'Length = 0
        or else Snapshots'First /= 1
        or else Active_Index < Snapshots'First
        or else Active_Index > Snapshots'Last
        or else Snapshots'Length /= Natural (Layout.Count)
        or else not Layout.Rects (Active_Index).Active
        or else
          (Tabs.Count > 0 and then Tabs.Active > Positive (Tabs.Count))
      then
         Set_Render_Status (R, Status, Invalid_Snapshot);
         return;
      end if;
      for I in Snapshots'Range loop
         if Snapshots (I).Rows = 0 or else Snapshots (I).Cols = 0
           or else Layout.Rects (I).Rows = 0 or else Layout.Rects (I).Cols = 0
         then
            Set_Render_Status (R, Status, Invalid_Snapshot);
            return;
         end if;
         if I > Snapshots'First then
            for J in Snapshots'First .. I - 1 loop
               if Snapshots (J).Graphics_Stream = Snapshots (I).Graphics_Stream then
                  Set_Render_Status (R, Status, Invalid_Snapshot);
                  return;
               end if;
            end loop;
         end if;
      end loop;
      Terminal.App.Renderer.Build_App_Frame
        (R, Snapshots, Active_Index, Tabs, Layout, Status);
   end Render_Pane_Layout;

   procedure Render_App
     (R              : in out Renderer;
      Snapshots      : Snapshot_Array;
      Active_Index   : Positive;
      Tabs           : Terminal.App.Tabs.Tab_Snapshot;
      Splits         : Terminal.App.Splits.Split_Snapshot;
      Status         : out Render_Status)
   is
      Layout : Terminal.App.Splits.Pane_Layout :=
        (Count => Splits.Count, others => <>);
      Row, Col : Positive := 1;
   begin
      --  Keep the public compatibility entry point just as defensive as the
      --  pane-tree entry point.  In particular, do not index Pane_Rect_Array
      --  until canonical bounds and split cardinality have been checked.
      if Snapshots'Length = 0
        or else Snapshots'First /= 1
        or else Active_Index < Snapshots'First
        or else Active_Index > Snapshots'Last
        or else Snapshots'Length /= Natural (Splits.Count)
        or else Active_Index /= Positive (Splits.Active)
        or else
          (Tabs.Count > 0 and then Tabs.Active > Positive (Tabs.Count))
      then
         Set_Render_Status (R, Status, Invalid_Snapshot);
         return;
      end if;
      Layout.Dividers (1).Orientation := Splits.Orientation;
      for I in Snapshots'Range loop
         Layout.Rects (I) :=
           (Row => Row, Col => Col,
            Rows => Snapshots (I).Rows, Cols => Snapshots (I).Cols,
            Active => I = Active_Index);
         if Splits.Orientation = Terminal.App.Splits.Vertical then
            Col := Col + Snapshots (I).Cols;
         else
            Row := Row + Snapshots (I).Rows;
         end if;
      end loop;
      Render_Pane_Layout (R, Snapshots, Active_Index, Tabs, Layout, Status);
   end Render_App;
end Terminal.App.Renderer.Layout;

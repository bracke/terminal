package body Terminal.App.Renderer.Layout is
   use type Terminal.Core.Graphics_Stream_ID;

   procedure Render_App
     (R              : in out Renderer;
      Snapshots      : Snapshot_Array;
      Active_Index   : Positive;
      Tabs           : Terminal.App.Tabs.Tab_Snapshot;
      Splits         : Terminal.App.Splits.Split_Snapshot;
      Status         : out Render_Status) is
   begin
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
      for I in Snapshots'Range loop
         if Snapshots (I).Rows = 0 or else Snapshots (I).Cols = 0 then
            Set_Render_Status (R, Status, Invalid_Snapshot);
            return;
         end if;
         --  Frame image commands borrow storage partitioned by graphics
         --  stream.  Processing two panes for the same stream could let the
         --  later pane replace data already borrowed by the earlier pane.
         --  Stream zero is also a real store partition for callers that have
         --  not assigned an application stream yet, so it receives the same
         --  uniqueness enforcement as every nonzero stream.
         if I > Snapshots'First then
            for J in Snapshots'First .. I - 1 loop
               if Snapshots (J).Graphics_Stream =
                 Snapshots (I).Graphics_Stream
               then
                  Set_Render_Status (R, Status, Invalid_Snapshot);
                  return;
               end if;
            end loop;
         end if;
      end loop;
      Terminal.App.Renderer.Build_App_Frame
        (R, Snapshots, Active_Index, Tabs, Splits, Status);
   end Render_App;
end Terminal.App.Renderer.Layout;

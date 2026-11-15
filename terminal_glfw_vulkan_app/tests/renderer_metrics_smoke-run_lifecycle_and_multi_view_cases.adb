with Terminal.Core.Snapshot_Editing;
separate (Renderer_Metrics_Smoke)
procedure Run_Lifecycle_And_Multi_View_Cases (Context : in out Suite_Context) is
   R : Terminal.App.Renderer.Renderer renames Context.Renderer;
   T : Terminal.Core.Terminal renames Context.Core;
   Feed_Status : Terminal.Core.Feed_Status renames Context.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status renames Context.Render_Status;
   Status : Terminal.App.Renderer.Init_Status renames Context.Init_Status;
begin
   Terminal.App.Renderer.Finalize (R);
   Terminal.App.Renderer.Finalize (R);

   declare
      Diag : constant Terminal.App.Renderer.Renderer_Diagnostics :=
        Terminal.App.Renderer.Diagnostics (R);
   begin
      Assert (not Diag.Initialized, "finalized renderer initialized flag");
      Assert (Diag.Last_Rectangle_Count = 0, "finalized rectangle count");
      Assert (Diag.Last_Glyph_Count = 0, "finalized glyph count");
   end;

   Terminal.App.Renderer.Initialize_Headless (R, Status);
   Assert (Status = Terminal.App.Renderer.Ok, "renderer reinitialize failed");


   Terminal.App.Renderer.Finalize (R);
   Terminal.App.Renderer.Initialize_Headless (R, Status);
   Assert
     (Status = Terminal.App.Renderer.Ok,
      "renderer post-retry reinitialize failed");

   declare
      T1 : Terminal.Core.Terminal;
      T2 : Terminal.Core.Terminal;
      Tabs : Terminal.App.Tabs.Tab_State;
      Splits : Terminal.App.Splits.Split_State;
      Tab_Status : Terminal.App.Tabs.Tab_Status;
      Split_Status : Terminal.App.Splits.Split_Status;
      S1 : Terminal.Core.Initialize_Status;
      S2 : Terminal.Core.Initialize_Status;
      F1 : Terminal.Core.Feed_Status;
      F2 : Terminal.Core.Feed_Status;
   begin
      Terminal.Core.Initialize (T1, 1, 8, 10, S1);
      Terminal.Core.Initialize (T2, 1, 8, 10, S2);
      Assert
        (S1 = Terminal.Core.Ok and then S2 = Terminal.Core.Ok,
         "composited render core initialize failed");
      Terminal.Core.Set_Graphics_Stream_ID (T1, 901);
      Terminal.Core.Set_Graphics_Stream_ID (T2, 902);
      Terminal.Core.Feed (T1, To_Bytes ("pane-one"), F1);
      Terminal.Core.Feed (T2, To_Bytes ("pane-two"), F2);
      Assert
        (F1 = Terminal.Core.Ok and then F2 = Terminal.Core.Ok,
         "composited render feed failed");
      Terminal.App.Tabs.Initialize (Tabs);
      Terminal.App.Tabs.Apply (Tabs, Terminal.App.Tabs.New_Tab, Tab_Status);
      Terminal.App.Splits.Initialize (Splits);
      Terminal.App.Splits.Apply
        (Splits, Terminal.App.Splits.Split_Horizontal, Split_Status);
      Assert
        (Tab_Status = Terminal.App.Tabs.Ok
         and then Split_Status = Terminal.App.Splits.Ok,
         "composited render tab/split model failed");

      declare
         Snaps : Terminal.App.Renderer.Snapshot_Array (1 .. 2) :=
           (1 => Terminal.Core.Snapshot (T1),
            2 => Terminal.Core.Snapshot (T2));
      begin
         Terminal.App.Renderer.Layout.Render_App
           (R,
            Snaps,
            2,
            Terminal.App.Tabs.Snapshot (Tabs),
            Terminal.App.Splits.Snapshot (Splits),
            Render_Status);
         Terminal.Core.Release (Snaps (1));
         Terminal.Core.Release (Snaps (2));
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "composited render failed");

      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Frame.Height >=
            3 * Terminal.App.Renderer.Cell_Height (R)
            + Terminal.App.Renderer.Content_Margin * 4,
            "composited render should include tab strip and two panes");
         Assert
           (Frame.Rectangle_Count > 10,
            "composited render should include pane and tab chrome");
         Assert
           (Frame.Glyph_Count >= 16,
            "composited render should draw both pane labels and tab labels");
      end;
   end;

   declare
      T1 : Terminal.Core.Terminal;
      T2 : Terminal.Core.Terminal;
      S1 : Terminal.Core.Initialize_Status;
      S2 : Terminal.Core.Initialize_Status;
      F1 : Terminal.Core.Feed_Status;
      F2 : Terminal.Core.Feed_Status;
      E1 : Terminal.Core.Graphics_Event;
      E2 : Terminal.Core.Graphics_Event;
      Tabs : Terminal.App.Tabs.Tab_State;
      Splits : Terminal.App.Splits.Split_State;
      Tab_Status : Terminal.App.Tabs.Tab_Status;
      Split_Status : Terminal.App.Splits.Split_Status;
      Objects_Before : constant Natural :=
        Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count;
      Placements_Before : constant Natural :=
        Terminal.App.Renderer.Diagnostics (R).Kitty_Placement_Count;

      procedure Render_Pair is
         Snaps : Terminal.App.Renderer.Snapshot_Array (1 .. 2) :=
           (1 => Terminal.Core.Snapshot (T1),
            2 => Terminal.Core.Snapshot (T2));
      begin
         Terminal.Core.Peek_Graphics_Event (T1, E1);
         Terminal.Core.Peek_Graphics_Event (T2, E2);
         Terminal.Core.Snapshot_Editing.Set_Graphics (Snaps (1), E1);
         Terminal.Core.Snapshot_Editing.Set_Graphics (Snaps (2), E2);
         Terminal.App.Renderer.Layout.Render_App
           (R,
            Snaps,
            2,
            Terminal.App.Tabs.Snapshot (Tabs),
            Terminal.App.Splits.Snapshot (Splits),
            Render_Status);
         Terminal.Core.Release (Snaps (1));
         Terminal.Core.Release (Snaps (2));
         Assert
           (Render_Status = Terminal.App.Renderer.Ok,
            "isolated graphics pair render: "
            & Terminal.App.Renderer.Render_Status'Image (Render_Status));
      end Render_Pair;
   begin
      Terminal.Core.Initialize (T1, 1, 4, 10, S1);
      Terminal.Core.Initialize (T2, 1, 4, 10, S2);
      Assert
        (S1 = Terminal.Core.Ok and then S2 = Terminal.Core.Ok,
         "isolated graphics cores initialize");
      Terminal.Core.Set_Graphics_Stream_ID (T1, 1_001);
      Terminal.Core.Set_Graphics_Stream_ID (T2, 1_002);
      Terminal.App.Tabs.Initialize (Tabs);
      Terminal.App.Tabs.Apply (Tabs, Terminal.App.Tabs.New_Tab, Tab_Status);
      Terminal.App.Splits.Initialize (Splits);
      Terminal.App.Splits.Apply
        (Splits, Terminal.App.Splits.Split_Horizontal, Split_Status);
      Assert
        (Tab_Status = Terminal.App.Tabs.Ok
         and then Split_Status = Terminal.App.Splits.Ok,
         "isolated graphics pane model");

      Terminal.Core.Feed
        (T1,
         To_Bytes
           (ASCII.ESC
            & "_Gq=2,a=T,i=55,p=1,f=32,s=1,v=1,c=1,r=1,C=1,m=1;/wAA"
            & ASCII.ESC & "\"),
         F1);
      Terminal.Core.Feed
        (T2,
         To_Bytes
           (ASCII.ESC
            & "_Gq=2,a=T,i=55,p=1,f=32,s=1,v=1,c=1,r=1,C=1,m=1;AP8A"
            & ASCII.ESC & "\"),
         F2);
      Assert
        (F1 = Terminal.Core.Ok and then F2 = Terminal.Core.Ok,
         "isolated first chunks feed");
      Render_Pair;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 0,
         "independent first chunks remain incomplete");
      Terminal.Core.Complete_Graphics_Event
        (T1, E1, Terminal.App.Renderer.Graphics.Result (R, E1));
      Terminal.Core.Complete_Graphics_Event
        (T2, E2, Terminal.App.Renderer.Graphics.Result (R, E2));
      Terminal.App.Renderer.Graphics.Commit_Visible_Events (R);

      Terminal.Core.Feed
        (T1,
         To_Bytes (ASCII.ESC & "_Gq=2,m=0;/w==" & ASCII.ESC & "\"),
         F1);
      Terminal.Core.Feed
        (T2,
         To_Bytes (ASCII.ESC & "_Gq=2,m=0;/w==" & ASCII.ESC & "\"),
         F2);
      Assert
        (F1 = Terminal.Core.Ok and then F2 = Terminal.Core.Ok,
         "isolated final chunks feed");
      Render_Pair;
      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Frame.Image_Count > 0,
            "isolated streams should render at least one image");
         Assert
           (Frame.Image_Count > 1,
            "same image ID coexists in separate streams");
         Assert
           (Frame.Image_Count = 2,
            "isolated streams should not duplicate placements");
         Assert
           (Natural (Frame.Images (1).Image_ID) = 55
            and then Natural (Frame.Images (2).Image_ID) = 55,
            "isolated images retain their protocol ID");
         Assert
           (Terminal.App.Render_Model.Image_Decoded_Row_Byte
              (Frame.Images (1), 0, 0) = 16#FF#
            and then Terminal.App.Render_Model.Image_Decoded_Row_Byte
              (Frame.Images (1), 0, 1) = 16#00#
            and then Terminal.App.Render_Model.Image_Decoded_Row_Byte
              (Frame.Images (2), 0, 0) = 16#00#
            and then Terminal.App.Render_Model.Image_Decoded_Row_Byte
              (Frame.Images (2), 0, 1) = 16#FF#,
            "same-ID stream images retain distinct pixels");
      end;
      Terminal.Core.Complete_Graphics_Event
        (T1, E1, Terminal.App.Renderer.Graphics.Result (R, E1));
      Terminal.Core.Complete_Graphics_Event
        (T2, E2, Terminal.App.Renderer.Graphics.Result (R, E2));
      Terminal.App.Renderer.Graphics.Commit_Visible_Events (R);

      Terminal.Core.Feed
        (T1,
         To_Bytes
           (ASCII.ESC & "_Gq=2,a=d,d=I,i=55" & ASCII.ESC & "\"),
         F1);
      declare
         Snaps : Terminal.App.Renderer.Snapshot_Array (1 .. 2) :=
           (1 => Terminal.Core.Snapshot (T1),
            2 => Terminal.Core.Snapshot (T2));
      begin
         Terminal.Core.Peek_Graphics_Event (T1, E1);
         Terminal.Core.Snapshot_Editing.Set_Graphics (Snaps (1), E1);
         Terminal.Core.Snapshot_Editing.Set_Graphics (Snaps (2), (others => <>));
         Terminal.App.Renderer.Layout.Render_App
           (R,
            Snaps,
            2,
            Terminal.App.Tabs.Snapshot (Tabs),
            Terminal.App.Splits.Snapshot (Splits),
            Render_Status);
         Terminal.Core.Release (Snaps (1));
         Terminal.Core.Release (Snaps (2));
      end;
      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert
           (Render_Status = Terminal.App.Renderer.Ok
            and then Frame.Image_Count = 1
            and then Natural (Frame.Images (1).Image_ID) = 55
            and then Terminal.App.Render_Model.Image_Decoded_Row_Byte
              (Frame.Images (1), 0, 1) = 16#FF#,
            "deleting one stream preserves same-ID image in another");
      end;
      Terminal.Core.Complete_Graphics_Event
        (T1, E1, Terminal.App.Renderer.Graphics.Result (R, E1));
      Terminal.App.Renderer.Graphics.Commit_Visible_Events (R);
      Terminal.App.Renderer.Graphics.Release_Stream (R, 1_001);
      Terminal.App.Renderer.Graphics.Release_Stream (R, 1_002);
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count =
           Objects_Before
         and then
           Terminal.App.Renderer.Diagnostics (R).Kitty_Placement_Count =
             Placements_Before,
         "closing streams releases their graphics resources");
      Terminal.Core.Finalize (T1);
      Terminal.Core.Finalize (T2);
   end;
end Run_Lifecycle_And_Multi_View_Cases;

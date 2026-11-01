separate (Renderer_Metrics_Smoke)
procedure Run_Composition_And_Lifetime_Cases is
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
         Snaps (1).Graphics := E1;
         Snaps (2).Graphics := E2;
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
            "isolated graphics pair render");
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
         Snaps (1).Graphics := E1;
         Snaps (2).Graphics := (others => <>);
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

   declare
      Screen_T : Terminal.Core.Terminal;
      Screen_Init : Terminal.Core.Initialize_Status;
      Screen_Feed : Terminal.Core.Feed_Status;
      Event : Terminal.Core.Graphics_Event;
      Objects_Before : constant Natural :=
        Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count;
      Placements_Before : constant Natural :=
        Terminal.App.Renderer.Diagnostics (R).Kitty_Placement_Count;

      procedure Render_Current is
         Snapshot : Terminal.Core.Render_Snapshot :=
           Terminal.Core.Snapshot (Screen_T);
      begin
         Terminal.Core.Peek_Graphics_Event (Screen_T, Event);
         Snapshot.Graphics := Event;
         Terminal.App.Renderer.Render (R, Snapshot, Render_Status);
         Terminal.Core.Release (Snapshot);
         Assert
           (Render_Status = Terminal.App.Renderer.Ok,
            "screen-owned graphics render");
         if Event.Pending then
            Terminal.Core.Complete_Graphics_Event
              (Screen_T,
               Event,
               Terminal.App.Renderer.Graphics.Result (R, Event));
            Terminal.App.Renderer.Graphics.Commit_Visible_Events (R);
         end if;
      end Render_Current;
   begin
      Terminal.Core.Initialize (Screen_T, 2, 4, 10, Screen_Init);
      Assert (Screen_Init = Terminal.Core.Ok, "screen-owned core initialize");
      Terminal.Core.Set_Graphics_Stream_ID (Screen_T, 2_001);

      Terminal.Core.Feed
        (Screen_T,
         To_Bytes
           (ASCII.ESC
            & "_Gq=2,a=T,i=70,p=1,f=32,s=1,v=1,c=1,r=1,C=1;/wAA/w=="
            & ASCII.ESC & "\"),
         Screen_Feed);
      Assert (Screen_Feed = Terminal.Core.Ok, "primary placement feed");
      Render_Current;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 1,
         "primary placement visible on primary screen");

      Terminal.Core.Feed
        (Screen_T, To_Bytes (ASCII.ESC & "[?1049h"), Screen_Feed);
      Render_Current;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 0,
         "primary placement hidden on alternate screen");

      Terminal.Core.Feed
        (Screen_T,
         To_Bytes
           (ASCII.ESC
            & "_Gq=2,a=T,i=71,p=1,f=32,s=1,v=1,c=1,r=1,C=1;AP8A/w=="
            & ASCII.ESC & "\"),
         Screen_Feed);
      Assert (Screen_Feed = Terminal.Core.Ok, "alternate placement feed");
      Render_Current;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 1
         and then Natural
           (Terminal.App.Renderer.Testing.Last_Frame (R).Images (1).Image_ID) = 71,
         "alternate placement visible only on alternate screen");

      Terminal.Core.Feed
        (Screen_T, To_Bytes (ASCII.ESC & "[?1049l"), Screen_Feed);
      Render_Current;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 1
         and then Natural
           (Terminal.App.Renderer.Testing.Last_Frame (R).Images (1).Image_ID) = 70,
         "leaving alternate restores primary placement");

      Terminal.Core.Feed
        (Screen_T, To_Bytes (ASCII.ESC & "[?1049h"), Screen_Feed);
      Render_Current;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 0,
         "alternate re-entry clears its old placements");

      Terminal.Core.Feed
        (Screen_T,
         To_Bytes (ASCII.ESC & "[?1049l" & ASCII.ESC & "[2J"),
         Screen_Feed);
      Render_Current;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 0,
         "full-screen erase clears primary placements");
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count =
           Objects_Before + 2
         and then
           Terminal.App.Renderer.Diagnostics (R).Kitty_Placement_Count =
             Placements_Before,
         "screen clears retain image data but retire placements");

      Terminal.App.Renderer.Graphics.Release_Stream (R, 2_001);
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Kitty_Image_Object_Count =
           Objects_Before
         and then
           Terminal.App.Renderer.Diagnostics (R).Kitty_Placement_Count =
             Placements_Before,
         "screen-owned stream cleanup releases retained image data");
      Terminal.Core.Finalize (Screen_T);
   end;

   declare
      Scroll_T : Terminal.Core.Terminal;
      Scroll_Init : Terminal.Core.Initialize_Status;
      Scroll_Feed : Terminal.Core.Feed_Status;
      Event : Terminal.Core.Graphics_Event;
      Tabs : Terminal.App.Tabs.Tab_State;
      Splits : Terminal.App.Splits.Split_State;
      Initial_Y : Float := 0.0;

      procedure Render_Event is
         Snaps : Terminal.App.Renderer.Snapshot_Array (1 .. 1);
         Result : Terminal.Core.Kitty_Graphics_Result;
      begin
         Terminal.Core.Peek_Graphics_Event (Scroll_T, Event);
         Terminal.Core.Snapshot (Scroll_T, Snaps (1));
         Snaps (1).Graphics := Event;
         Terminal.App.Renderer.Layout.Render_App
           (R,
            Snaps,
            1,
            Terminal.App.Tabs.Snapshot (Tabs),
            Terminal.App.Splits.Snapshot (Splits),
            Render_Status);
         Assert
           (Render_Status = Terminal.App.Renderer.Ok,
            "scrolling placement event render");
         Result := Terminal.App.Renderer.Graphics.Result (R, Event);
         Assert
           (Result.Code = Terminal.Core.Kitty_OK,
            "scrolling placement event result");
         Terminal.Core.Complete_Graphics_Event (Scroll_T, Event, Result);
         Terminal.App.Renderer.Graphics.Commit_Visible_Events (R);
         Terminal.Core.Release (Snaps (1));
      end Render_Event;

      procedure Render_Live is
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (Scroll_T);
      begin
         Snap.Graphics := (others => <>);
         Terminal.App.Renderer.Render (R, Snap, Render_Status);
         Terminal.Core.Release (Snap);
         Assert
           (Render_Status = Terminal.App.Renderer.Ok,
            "scrolling placement live render");
      end Render_Live;
   begin
      Terminal.Core.Initialize (Scroll_T, 3, 3, 10, Scroll_Init);
      Assert (Scroll_Init = Terminal.Core.Ok, "scroll graphics initialize");
      Terminal.Core.Set_Graphics_Stream_ID (Scroll_T, 2_050);
      Terminal.App.Tabs.Initialize (Tabs);
      Terminal.App.Splits.Initialize (Splits);
      Terminal.Core.Feed
        (Scroll_T,
         To_Bytes
           (ASCII.ESC & "[2;1H"
            & ASCII.ESC
            & "_Gq=2,a=T,i=80,f=32,s=1,v=2,c=1,r=2,C=1;"
            & "/wAA//8AAP8="
            & ASCII.ESC & "\"),
         Scroll_Feed);
      Assert (Scroll_Feed = Terminal.Core.Ok, "scroll graphics placement feed");
      Render_Event;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 1,
         "scrolling placement initially visible");
      Initial_Y := Terminal.App.Renderer.Testing.Last_Frame (R).Images (1).Y;

      Terminal.Core.Feed
        (Scroll_T,
         To_Bytes (ASCII.ESC & "[3;1H" & ASCII.LF),
         Scroll_Feed);
      Render_Live;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 1
         and then Terminal.App.Renderer.Testing.Last_Frame (R).Images (1).Y =
           Initial_Y - Float (Terminal.App.Renderer.Cell_Height (R)),
         "full-screen scroll moves conventional placement with text");

      --  Move the placement wholly into history before exercising clears.
      Terminal.Core.Feed
        (Scroll_T, To_Bytes ("" & ASCII.LF), Scroll_Feed);
      Render_Live;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 1
         and then Terminal.App.Renderer.Testing.Last_Frame (R).Images (1).Y =
           Float (Terminal.App.Renderer.Content_Margin)
         and then Terminal.App.Renderer.Testing.Last_Frame (R).Images (1).Height <
           Float (Terminal.App.Renderer.Cell_Width (R) * 2),
         "placement crossing the viewport edge is clipped");

      declare
         History : Terminal.Core.Render_Snapshot :=
           Terminal.App.Scrollback_View.Snapshot (Scroll_T, 1);
      begin
         History.Graphics := (others => <>);
         Terminal.App.Renderer.Render (R, History, Render_Status);
         Terminal.Core.Release (History);
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok
         and then Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 1
         and then Terminal.App.Renderer.Testing.Last_Frame (R).Images (1).Height =
           Float (Terminal.App.Renderer.Cell_Width (R) * 2),
         "scrollback navigation restores the full retained placement");

      Terminal.Core.Feed
        (Scroll_T, To_Bytes ("" & ASCII.LF), Scroll_Feed);
      Render_Live;
      Assert
        (Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 0,
         "fully scrolled placement leaves the live viewport");

      Terminal.Core.Feed
        (Scroll_T, To_Bytes (ASCII.ESC & "[2J"), Scroll_Feed);
      Render_Live;
      declare
         History : Terminal.Core.Render_Snapshot :=
           Terminal.App.Scrollback_View.Snapshot (Scroll_T, 2);
      begin
         History.Graphics := (others => <>);
         Terminal.App.Renderer.Render (R, History, Render_Status);
         Terminal.Core.Release (History);
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok
         and then Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 1,
         "viewport erase preserves a placement retained in scrollback");

      Terminal.Core.Feed
        (Scroll_T,
         To_Bytes (ASCII.ESC & "_Gq=2,a=d,d=a" & ASCII.ESC & "\"),
         Scroll_Feed);
      Render_Event;
      declare
         History : Terminal.Core.Render_Snapshot :=
           Terminal.App.Scrollback_View.Snapshot (Scroll_T, 2);
      begin
         History.Graphics := (others => <>);
         Terminal.App.Renderer.Render (R, History, Render_Status);
         Terminal.Core.Release (History);
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok
         and then Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 1,
         "d=a preserves placements that are visible only in scrollback");

      declare
         History_Placements : constant Natural :=
           Terminal.App.Renderer.Diagnostics (R).Kitty_Placement_Count;
      begin
         Terminal.Core.Feed
           (Scroll_T,
            To_Bytes
              (ASCII.ESC & "[2;1H"
               & ASCII.ESC & "_Gq=2,a=p,i=80,C=1,c=1,r=1"
               & ASCII.ESC & "\"),
            Scroll_Feed);
         Render_Event;
         Assert
           (Terminal.App.Renderer.Diagnostics (R).Kitty_Placement_Count =
              History_Placements + 1,
            "positional-delete fixture placement is installed");

         Terminal.Core.Feed
           (Scroll_T,
            To_Bytes
              (ASCII.ESC & "[3;1H" & ASCII.LF
               & ASCII.ESC & "_Gq=2,a=d,d=p,x=1,y=1"
               & ASCII.ESC & "\"),
            Scroll_Feed);
         Render_Event;
         Assert
           (Terminal.App.Renderer.Diagnostics (R).Kitty_Placement_Count =
              History_Placements,
            "positional delete observes scrolling preceding its command");
      end;

      Terminal.App.Renderer.Graphics.Release_Stream (R, 2_050);
      Terminal.Core.Finalize (Scroll_T);
   end;

end Run_Composition_And_Lifetime_Cases;

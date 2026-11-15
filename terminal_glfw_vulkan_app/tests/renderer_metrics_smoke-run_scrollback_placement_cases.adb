with Terminal.Core.Snapshot_Editing;
separate (Renderer_Metrics_Smoke)
procedure Run_Scrollback_Placement_Cases (Context : in out Suite_Context) is
   R : Terminal.App.Renderer.Renderer renames Context.Renderer;
   T : Terminal.Core.Terminal renames Context.Core;
   Feed_Status : Terminal.Core.Feed_Status renames Context.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status renames Context.Render_Status;
begin
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
         Terminal.Core.Snapshot_Editing.Set_Graphics (Snapshot, Event);
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
         Result : Terminal.Core.Graphics_Completion;
      begin
         Terminal.Core.Peek_Graphics_Event (Scroll_T, Event);
         Terminal.Core.Snapshot (Scroll_T, Snaps (1));
         Terminal.Core.Snapshot_Editing.Set_Graphics (Snaps (1), Event);
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
           (Result.Code = Terminal.Core.Graphics_OK,
            "scrolling placement event result");
         Terminal.Core.Complete_Graphics_Event (Scroll_T, Event, Result);
         Terminal.App.Renderer.Graphics.Commit_Visible_Events (R);
         Terminal.Core.Release (Snaps (1));
      end Render_Event;

      procedure Render_Live is
         Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (Scroll_T);
      begin
         Terminal.Core.Snapshot_Editing.Set_Graphics (Snap, (others => <>));
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
         Terminal.Core.Snapshot_Editing.Set_Graphics (History, (others => <>));
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
         Terminal.Core.Snapshot_Editing.Set_Graphics (History, (others => <>));
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
         Terminal.Core.Snapshot_Editing.Set_Graphics (History, (others => <>));
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

   declare
      Alternate_T : Terminal.Core.Terminal;
      Alternate_Init : Terminal.Core.Initialize_Status;
      Alternate_Feed : Terminal.Core.Feed_Status;
      Event : Terminal.Core.Graphics_Event;
      Placements_Before : constant Natural :=
        Terminal.App.Renderer.Diagnostics (R).Kitty_Placement_Count;

      procedure Render_Event is
         Snapshot : Terminal.Core.Render_Snapshot :=
           Terminal.Core.Snapshot (Alternate_T);
         Result : Terminal.Core.Graphics_Completion;
      begin
         Terminal.Core.Peek_Graphics_Event (Alternate_T, Event);
         Terminal.Core.Snapshot_Editing.Set_Graphics (Snapshot, Event);
         Terminal.App.Renderer.Render (R, Snapshot, Render_Status);
         Terminal.Core.Release (Snapshot);
         Assert
           (Render_Status = Terminal.App.Renderer.Ok,
            "alternate scroll event render");
         Result := Terminal.App.Renderer.Graphics.Result (R, Event);
         Terminal.Core.Complete_Graphics_Event (Alternate_T, Event, Result);
         Terminal.App.Renderer.Graphics.Commit_Visible_Events (R);
      end Render_Event;

      procedure Render_Live is
         Snapshot : Terminal.Core.Render_Snapshot :=
           Terminal.Core.Snapshot (Alternate_T);
      begin
         Terminal.Core.Snapshot_Editing.Set_Graphics
           (Snapshot, (others => <>));
         Terminal.App.Renderer.Render (R, Snapshot, Render_Status);
         Terminal.Core.Release (Snapshot);
         Assert
           (Render_Status = Terminal.App.Renderer.Ok,
            "alternate scroll live render");
      end Render_Live;
   begin
      Terminal.Core.Initialize
        (Alternate_T, 2, 2, 2, Alternate_Init);
      Assert
        (Alternate_Init = Terminal.Core.Ok,
         "alternate scroll initialize");
      Terminal.Core.Set_Graphics_Stream_ID (Alternate_T, 2_051);
      Terminal.Core.Feed
        (Alternate_T,
         To_Bytes
           (ASCII.ESC & "[?1049h"
            & ASCII.ESC & "[1;1H"
            & ASCII.ESC
            & "_Gq=2,a=T,i=81,f=32,s=1,v=1,c=1,r=1,C=1;"
            & "/wAA/w=="
            & ASCII.ESC & "\"),
         Alternate_Feed);
      Assert
        (Alternate_Feed = Terminal.Core.Ok,
         "alternate scroll placement feed");
      Render_Event;
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Kitty_Placement_Count =
           Placements_Before + 1,
         "alternate placement is installed");

      Terminal.Core.Feed
        (Alternate_T,
         To_Bytes (ASCII.ESC & "[2;1H" & ASCII.LF),
         Alternate_Feed);
      Render_Live;
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Kitty_Placement_Count =
           Placements_Before
         and then Terminal.App.Renderer.Testing.Last_Frame (R).Image_Count = 0,
         "one scroll immediately retires an offscreen alternate placement");

      Terminal.App.Renderer.Graphics.Release_Stream (R, 2_051);
      Terminal.Core.Finalize (Alternate_T);
   end;

end Run_Scrollback_Placement_Cases;

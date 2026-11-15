with Ada.Real_Time;
with AUnit.Assertions;

with Terminal.App.PTY_Write;
with Terminal.App.Render_Model;
with Terminal.App.Renderer;
with Terminal.App.Renderer.Graphics;
with Terminal.App.Renderer.Layout;
with Terminal.App.Renderer.Testing;
with Terminal.App.Session_Graphics;
with Terminal.App.Session_Runtime;
with Terminal.App.Session_Table;
with Terminal.App.Sessions;
with Terminal.App.Splits;
with Terminal.App.Tabs;
with Terminal.App.Queues;
with Terminal.Common.Bytes;
with Terminal.Core;
with Terminal.Core.Snapshot_Testing;

procedure Session_Hardening_Smoke is
   use AUnit.Assertions;
   use type Ada.Real_Time.Time;
   use type Terminal.App.PTY_Write.Write_All_Status;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.App.Renderer.Graphics.Stage_Event_Status;
   use type Terminal.App.Session_Runtime.Runtime_Status;
   use type Terminal.App.Session_Runtime.Start_Status;
   use type Terminal.App.Session_Table.Table_Status;
   use type Terminal.App.Splits.Pane_Count;
   use type Terminal.App.Splits.Split_Status;
   use type Terminal.App.Tabs.Tab_Count;
   use type Terminal.App.Tabs.Tab_Status;
   use type Terminal.Common.Code_Point;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;

   package Runtime renames Terminal.App.Session_Runtime;
   package Tables renames Terminal.App.Session_Table;
   package Splits renames Terminal.App.Splits;
   package Tabs renames Terminal.App.Tabs;

   procedure Set_Stream
     (Snapshot : in out Terminal.Core.Render_Snapshot;
      Stream   : Terminal.Core.Graphics_Stream_ID) is
   begin
      Terminal.Core.Snapshot_Testing.Set_Presentation_Context
        (Snapshot,
         Stream,
         Snapshot.Graphics_Transaction,
         Snapshot.Alternate_Screen,
         Snapshot.Screen_Generation);
   end Set_Stream;

   function Chunk_From_String (Text : String) return Terminal.App.Queues.Byte_Chunk
   is
      Result : Terminal.App.Queues.Byte_Chunk := (others => <>);
   begin
      Result.Length := Text'Length;
      for I in Text'Range loop
         Result.Data (I - Text'First + 1) :=
           Terminal.Common.Bytes.Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end Chunk_From_String;

   function To_Bytes (Text : String) return Terminal.Common.Bytes.Byte_Array is
      Result : Terminal.Common.Bytes.Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) :=
           Terminal.Common.Bytes.Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   procedure Drain_For
     (R      : in out Runtime.Runtime;
      Millis : Natural)
   is
      Feed_Status : Terminal.Core.Feed_Status;
      Deadline : constant Ada.Real_Time.Time :=
        Ada.Real_Time.Clock + Ada.Real_Time.Milliseconds (Millis);
   begin
      while Ada.Real_Time.Clock < Deadline loop
         Runtime.Poll_Output (R, Feed_Status);
         delay 0.01;
      end loop;
   end Drain_For;

   procedure Repeated_Runtime_Start_Close is
      R : Runtime.Runtime;
      Start_Status : Runtime.Start_Status;
   begin
      for I in 1 .. 6 loop
         Runtime.Start (R, 8, 24, 16, Start_Status);
         Assert (Start_Status = Runtime.Ok, "runtime soak start" & Natural'Image (I));
         Assert (Runtime.State (R) = Runtime.Active, "runtime soak active");
         Assert (Runtime.Is_Alive (R), "runtime soak shell alive");
         Drain_For (R, 40);
         Runtime.Close (R);
         Assert (Runtime.State (R) = Runtime.Closed, "runtime soak closed");
         Runtime.Close (R);
         Assert (Runtime.State (R) = Runtime.Closed, "runtime close is idempotent");
      end loop;
   end Repeated_Runtime_Start_Close;

   procedure Runtime_Table_Churn is
      Table : aliased Tables.Runtime_Table;
      Tab_State : Tabs.Tab_State;
      Split_State : Splits.Split_State;
      Status : Tables.Table_Status;
      Write_Status : Terminal.App.PTY_Write.Write_All_Status;
      Feed_Status : Terminal.Core.Feed_Status;
      Output : Tables.Runtime_Output_Set;
      Seen_Output : Tables.Runtime_Output_Set := (others => False);
   begin
      Tabs.Initialize (Tab_State);
      Splits.Initialize (Split_State);
      Tables.Initialize (Table, 8, 32, 32, Status);
      Assert (Status = Tables.Ok, "churn table initializes");

      for I in 2 .. Tabs.Max_Tabs loop
         Tables.New_Tab
           (Table, 8, 32, 32, Status);
         Assert (Status = Tables.Ok, "churn new tab" & Natural'Image (I));
      end loop;
      Assert (Tables.Count (Table) = Tabs.Max_Tabs, "churn reaches tab capacity");
      Tables.New_Tab
        (Table, 8, 32, 32, Status);
      Assert (Status = Tables.At_Capacity, "churn tab capacity guarded");

      for I in 1 .. Tables.Count (Table) loop
         declare
            Borrow : constant Tables.Runtime_Borrow :=
              Tables.Runtime_At
                (Table, Terminal.App.Sessions.Session_Index (I));
         begin
            Tables.Write
              (Borrow,
               Chunk_From_String
                 ("printf tab-" & Natural'Image (I) & ASCII.LF),
               Write_Status);
            Assert
              (Write_Status = Terminal.App.PTY_Write.Ok,
               "churn runtime write" & Natural'Image (I));
         end;
      end loop;
      declare
         Deadline : constant Ada.Real_Time.Time :=
           Ada.Real_Time.Clock + Ada.Real_Time.Milliseconds (300);
      begin
         while Ada.Real_Time.Clock < Deadline loop
            Tables.Poll_Output
              (Table, Output, Feed_Status, Write_Status);
            for I in 1 .. Tables.Count (Table) loop
               Seen_Output (I) := Seen_Output (I) or else Output (I);
            end loop;
            exit when
              (for all I in 1 .. Tables.Count (Table) => Seen_Output (I));
            delay 0.01;
         end loop;
      end;
      Assert
        (Feed_Status = Terminal.Core.Ok,
         "all runtime output feeds remain valid");
      Assert
        (Write_Status = Terminal.App.PTY_Write.Ok,
         "all runtime responses use their owning PTY");
      for I in 1 .. Tables.Count (Table) loop
         Assert
           (Seen_Output (I),
            "table polling consumes background runtime" & Natural'Image (I));
      end loop;

      while Tables.Count (Table) > 1 loop
         Tables.Close_Tab (Table, Status);
         Assert (Status = Tables.Ok, "churn close tab");
      end loop;
      Tables.Close_Tab (Table, Status);
      Assert (Status = Tables.Last_Session, "churn last tab guarded");
      Assert
        (Tables.State (Tables.Active_Runtime (Table)) = Runtime.Active,
         "churn last runtime survives");
      Tables.Close_All (Table);

      Tabs.Initialize (Tab_State);
      Splits.Initialize (Split_State);
      Tables.Initialize (Table, 12, 48, 32, Status);
      Assert (Status = Tables.Ok, "split churn table initializes");
      for I in 2 .. Splits.Max_Panes loop
         Tables.Split_Pane
           (Table,
         Splits.Split_Vertical,
            12,
            48,
            32,
            Status);
         Assert (Status = Tables.Ok, "churn split pane" & Natural'Image (I));
      end loop;
      Assert
        (Splits.Count (Tables.Splits (Table)) = Splits.Max_Panes,
         "churn reaches split capacity");
      Tables.Split_Pane
        (Table,
         Splits.Split_Vertical,
         12,
         48,
         32,
         Status);
      Assert (Status = Tables.At_Capacity, "churn split capacity guarded");
      while Tables.Count (Table) > 1 loop
         Tables.Close_Pane (Table, Status);
         Assert (Status = Tables.Ok, "churn close pane");
      end loop;
      Tables.Close_Pane (Table, Status);
      Assert (Status = Tables.Last_Session, "churn last pane guarded");
      Tables.Close_All (Table);
   end Runtime_Table_Churn;

   procedure Renderer_Composition_Churn is
      R : Terminal.App.Renderer.Renderer;
      Init_Status : Terminal.App.Renderer.Init_Status;
      Render_Status : Terminal.App.Renderer.Render_Status;
      T1 : Terminal.Core.Terminal;
      T2 : Terminal.Core.Terminal;
      T3 : Terminal.Core.Terminal;
      Core_Status : Terminal.Core.Initialize_Status;
      Feed_Status : Terminal.Core.Feed_Status;
      Tab_State : Tabs.Tab_State;
      Split_State : Splits.Split_State;
      Tab_Status : Tabs.Tab_Status;
      Split_Status : Splits.Split_Status;
   begin
      Terminal.App.Renderer.Initialize_Headless (R, Init_Status);
      Assert (Init_Status = Terminal.App.Renderer.Ok, "composition renderer init");
      Terminal.Core.Initialize (T1, 2, 10, 16, Core_Status);
      Assert (Core_Status = Terminal.Core.Ok, "composition core 1");
      Terminal.Core.Initialize (T2, 2, 10, 16, Core_Status);
      Assert (Core_Status = Terminal.Core.Ok, "composition core 2");
      Terminal.Core.Initialize (T3, 2, 10, 16, Core_Status);
      Assert (Core_Status = Terminal.Core.Ok, "composition core 3");
      Terminal.Core.Set_Graphics_Stream_ID (T1, 501);
      Terminal.Core.Set_Graphics_Stream_ID (T2, 502);
      Terminal.Core.Set_Graphics_Stream_ID (T3, 503);
      Terminal.Core.Feed (T1, To_Bytes ("one"), Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "composition feed 1");
      Terminal.Core.Feed (T2, To_Bytes ("two"), Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "composition feed 2");
      Terminal.Core.Feed (T3, To_Bytes ("three"), Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "composition feed 3");

      Tabs.Initialize (Tab_State);
      Tabs.Apply (Tab_State, Tabs.New_Tab, Tab_Status);
      Assert (Tab_Status = Tabs.Ok, "composition tab 2");
      Tabs.Apply (Tab_State, Tabs.New_Tab, Tab_Status);
      Assert (Tab_Status = Tabs.Ok, "composition tab 3");
      Splits.Initialize (Split_State);
      Splits.Apply (Split_State, Splits.Split_Vertical, Split_Status);
      Assert (Split_Status = Splits.Ok, "composition split 2");
      Splits.Apply (Split_State, Splits.Split_Vertical, Split_Status);
      Assert (Split_Status = Splits.Ok, "composition split 3");

      declare
         Snaps : Terminal.App.Renderer.Snapshot_Array (1 .. 3) :=
           (1 => Terminal.Core.Snapshot (T1),
            2 => Terminal.Core.Snapshot (T2),
            3 => Terminal.Core.Snapshot (T3));
      begin
         Terminal.App.Renderer.Layout.Render_App
           (R,
            Snaps,
            3,
            Tabs.Snapshot (Tab_State),
            Splits.Snapshot (Split_State),
            Render_Status);
         Terminal.Core.Release (Snaps (1));
         Terminal.Core.Release (Snaps (2));
         Terminal.Core.Release (Snaps (3));
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "composition render succeeds");
      Assert
        (Terminal.App.Renderer.Diagnostics (R).Last_Dirty_Rows = 6,
         "composition diagnostics count dirty rows across every pane");

      Terminal.Core.Clear_Damage (T1);
      Terminal.Core.Clear_Damage (T2);
      Terminal.Core.Clear_Damage (T3);
      declare
         Snaps : Terminal.App.Renderer.Snapshot_Array (1 .. 3) :=
           (1 => Terminal.Core.Snapshot (T1),
            2 => Terminal.Core.Snapshot (T2),
            3 => Terminal.Core.Snapshot (T3));
      begin
         Terminal.App.Renderer.Layout.Render_App
           (R,
            Snaps,
            3,
            Tabs.Snapshot (Tab_State),
            Splits.Snapshot (Split_State),
            Render_Status);
         Terminal.Core.Release (Snaps (1));
         Terminal.Core.Release (Snaps (2));
         Terminal.Core.Release (Snaps (3));
      end;
      Assert
        (Render_Status = Terminal.App.Renderer.Ok
         and then Terminal.App.Renderer.Diagnostics (R).Last_Cached_Rows = 6,
         "clean composition reuses every pane row");

      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Testing.Last_Frame (R);
      begin
         Assert (Frame.Rectangle_Count > 18, "composition chrome rectangles");
         Assert (Frame.Glyph_Count >= 16, "composition draws all visible labels");
         Assert
           (Frame.Width >=
            3 * (10 * Terminal.App.Renderer.Cell_Width (R)
                 + Terminal.App.Renderer.Content_Margin * 2),
            "composition vertical panes widen frame");
      end;

      declare
         Tiny : Terminal.Core.Terminal;
         Tiny_Tabs : Tabs.Tab_State;
         Tiny_Splits : Splits.Split_State;
      begin
         Terminal.Core.Initialize (Tiny, 1, 1, 0, Core_Status);
         Assert (Core_Status = Terminal.Core.Ok, "tiny composition core");
         Tabs.Initialize (Tiny_Tabs);
         for I in 2 .. Tabs.Max_Tabs loop
            Tabs.Apply (Tiny_Tabs, Tabs.New_Tab, Tab_Status);
            Assert (Tab_Status = Tabs.Ok, "tiny tab fill" & Natural'Image (I));
         end loop;
         Splits.Initialize (Tiny_Splits);
         declare
            Snaps : Terminal.App.Renderer.Snapshot_Array (1 .. 1) :=
              (1 => Terminal.Core.Snapshot (Tiny));
         begin
            Render_Status := Terminal.App.Renderer.Invalid_Snapshot;
            Terminal.App.Renderer.Layout.Render_App
              (R,
               Snaps,
               1,
               Tabs.Snapshot (Tiny_Tabs),
               Splits.Snapshot (Tiny_Splits),
               Render_Status);
            Assert
              (Render_Status = Terminal.App.Renderer.Ok,
               "narrow frame safely divides a full tab bar");
            Render_Status := Terminal.App.Renderer.Invalid_Snapshot;
            Terminal.App.Renderer.Layout.Render_App
              (R,
               Snaps,
               1,
               (others => <>),
               Splits.Snapshot (Tiny_Splits),
               Render_Status);
            Assert
              (Render_Status = Terminal.App.Renderer.Ok,
               "empty tab snapshot does not read an unassigned status");
            Terminal.App.Renderer.Layout.Render_App
              (R,
               Snaps,
               2,
               Tabs.Snapshot (Tiny_Tabs),
               Splits.Snapshot (Tiny_Splits),
               Render_Status);
            Assert
              (Render_Status = Terminal.App.Renderer.Invalid_Snapshot
               and then Terminal.App.Renderer.Diagnostics (R).Last_Render_Status =
                 Terminal.App.Renderer.Invalid_Snapshot,
               "layout rejection updates renderer diagnostics");
            Terminal.App.Renderer.Layout.Render_App
              (R,
               Snaps,
               1,
               Tabs.Snapshot (Tiny_Tabs),
               (Count       => 1,
                Active      => 2,
                Orientation => Splits.Horizontal),
               Render_Status);
            Assert
              (Render_Status = Terminal.App.Renderer.Invalid_Snapshot,
               "layout rejects a split snapshot with a different active pane");
            Terminal.Core.Release (Snaps (1));
         end;
         declare
            Snaps : Terminal.App.Renderer.Snapshot_Array (1 .. 2) :=
              (1 => Terminal.Core.Snapshot (Tiny),
               2 => Terminal.Core.Snapshot (Tiny));
         begin
            Set_Stream (Snaps (1), 98);
            Set_Stream (Snaps (2), 99);
            Terminal.App.Renderer.Layout.Render_App
              (R,
               Snaps,
               1,
               Tabs.Snapshot (Tiny_Tabs),
               Splits.Snapshot (Tiny_Splits),
               Render_Status);
            Assert
              (Render_Status = Terminal.App.Renderer.Invalid_Snapshot,
               "layout rejects snapshot and split-count disagreement");
            Set_Stream (Snaps (1), 0);
            Set_Stream (Snaps (2), 0);
            Terminal.App.Renderer.Layout.Render_App
              (R,
               Snaps,
               1,
               Tabs.Snapshot (Tiny_Tabs),
               (Count       => 2,
                Active      => 1,
                Orientation => Splits.Horizontal),
               Render_Status);
            Assert
              (Render_Status = Terminal.App.Renderer.Invalid_Snapshot,
               "zero-valued graphics streams still require pane isolation");
            Set_Stream (Snaps (1), 99);
            Set_Stream (Snaps (2), 99);
            Terminal.App.Renderer.Layout.Render_App
              (R,
               Snaps,
               1,
               Tabs.Snapshot (Tiny_Tabs),
               (Count       => 2,
                Active      => 1,
                Orientation => Splits.Horizontal),
               Render_Status);
            Assert
              (Render_Status = Terminal.App.Renderer.Invalid_Snapshot,
               "composite panes cannot share borrowed graphics storage");
            Terminal.Core.Release (Snaps (1));
            Terminal.Core.Release (Snaps (2));
         end;
         declare
            Snaps : Terminal.App.Renderer.Snapshot_Array (2 .. 3) :=
              (2 => Terminal.Core.Snapshot (Tiny),
               3 => Terminal.Core.Snapshot (Tiny));
         begin
            Set_Stream (Snaps (2), 98);
            Set_Stream (Snaps (3), 99);
            Terminal.App.Renderer.Layout.Render_App
              (R,
               Snaps,
               2,
               Tabs.Snapshot (Tiny_Tabs),
               (Count       => 2,
                Active      => 2,
                Orientation => Splits.Horizontal),
               Render_Status);
            Assert
              (Render_Status = Terminal.App.Renderer.Invalid_Snapshot,
               "layout rejects noncanonical snapshot bounds");
            Terminal.Core.Release (Snaps (2));
            Terminal.Core.Release (Snaps (3));
         end;
         declare
            Snaps : Terminal.App.Renderer.Snapshot_Array (1 .. 1) :=
              (1 => Terminal.Core.Snapshot (Tiny));
            Invalid_Tabs : Tabs.Tab_Snapshot := Tabs.Snapshot (Tiny_Tabs);
         begin
            Invalid_Tabs.Count := 2;
            Invalid_Tabs.Active := 3;
            Terminal.App.Renderer.Layout.Render_App
              (R,
               Snaps,
               1,
               Invalid_Tabs,
               Splits.Snapshot (Tiny_Splits),
               Render_Status);
            Assert
              (Render_Status = Terminal.App.Renderer.Invalid_Snapshot,
               "layout rejects an active tab outside the visible tab count");
            Terminal.Core.Release (Snaps (1));
         end;
         declare
            Snaps : Terminal.App.Renderer.Snapshot_Array (1 .. 1) :=
              (1 => Terminal.Core.Snapshot (Tiny));
            Empty_Labels : Tabs.Tab_Snapshot :=
              (Count  => 2,
               Active => 1,
               Labels => (others => <>));
         begin
            Terminal.App.Renderer.Layout.Render_App
              (R,
               Snaps,
               1,
               Empty_Labels,
               Splits.Snapshot (Tiny_Splits),
               Render_Status);
            Assert
              (Render_Status = Terminal.App.Renderer.Ok,
               "layout safely omits empty public tab labels");
            Terminal.Core.Release (Snaps (1));
         end;
         Terminal.Core.Finalize (Tiny);
      end;

      Terminal.App.Renderer.Finalize (R);
   end Renderer_Composition_Churn;

   procedure Background_Graphics_Progress is
      Table : aliased Tables.Runtime_Table;
      Tab_State : Tabs.Tab_State;
      Split_State : Splits.Split_State;
      Table_Status : Tables.Table_Status;
      R : Terminal.App.Renderer.Renderer;
      Init_Status : Terminal.App.Renderer.Init_Status;
      Render_Status : Terminal.App.Renderer.Render_Status;
      Write_Status : Terminal.App.PTY_Write.Write_All_Status;
      Feed_Status : Terminal.Core.Feed_Status;
      Processed : Boolean;
      Retained_Visible_Event : constant Terminal.Core.Graphics_Event :=
        (Pending        => True,
         Stream_ID      => 99_001,
         Sequence       => 1,
         Payload_Length => 1,
         others         => <>);
      Command : constant String :=
        ASCII.ESC & "_Ga=q,f=32,i=501,s=1,v=1;/wAA/w=="
        & ASCII.ESC & "\";
   begin
      Tabs.Initialize (Tab_State);
      Splits.Initialize (Split_State);
      Tables.Initialize (Table, 4, 12, 16, Table_Status);
      Assert (Table_Status = Tables.Ok, "background table initialize");
      Tables.New_Tab
        (Table, 4, 12, 16, Table_Status);
      Assert (Table_Status = Tables.Ok, "background tab initialize");
      declare
         Hidden_Borrow : constant Tables.Runtime_Borrow :=
           Tables.Runtime_At (Table, 1);
         Visible_Borrow : constant Tables.Runtime_Borrow :=
           Tables.Runtime_At (Table, 2);
         Hidden_Core : constant Runtime.Core_Borrow :=
           Tables.Core (Hidden_Borrow);
         Visible_Core : constant Runtime.Core_Borrow :=
           Tables.Core (Visible_Borrow);
         Hidden_Pending : Natural := 0;
         Visible_Pending : Natural := 0;
         procedure Feed_Hidden (Core : in out Terminal.Core.Terminal) is
         begin
            Terminal.Core.Feed
              (Core, To_Bytes (Command & "Z"), Feed_Status);
         end Feed_Hidden;
         procedure Feed_Visible (Core : in out Terminal.Core.Terminal) is
         begin
            Terminal.Core.Feed (Core, To_Bytes (Command), Feed_Status);
         end Feed_Visible;
         procedure Inspect_Hidden (Core : in out Terminal.Core.Terminal) is
            Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (Core);
         begin
            Hidden_Pending := Terminal.Core.Pending_Graphics_Event_Count (Core);
            Assert
              (Terminal.Core.Cell_At (Snap, 1, 1).Text.Code_Point =
                 Character'Pos ('Z'),
               "hidden graphics completion resumes deferred terminal input");
            Terminal.Core.Release (Snap);
         exception
            when others =>
               Terminal.Core.Release (Snap);
               raise;
         end Inspect_Hidden;
         procedure Inspect_Visible (Core : in out Terminal.Core.Terminal) is
         begin
            Visible_Pending := Terminal.Core.Pending_Graphics_Event_Count (Core);
         end Inspect_Visible;
      begin
         Runtime.With_Core (Hidden_Core, Feed_Hidden'Access);
         Assert (Feed_Status = Terminal.Core.Ok, "hidden graphics feed");
         Runtime.With_Core (Visible_Core, Feed_Visible'Access);
         Assert (Feed_Status = Terminal.Core.Ok, "visible graphics feed");

      Terminal.App.Renderer.Initialize_Headless (R, Init_Status);
      Assert (Init_Status = Terminal.App.Renderer.Ok, "background renderer init");
      Assert
        (Terminal.App.Renderer.Graphics.Stage_Event
           (R, Retained_Visible_Event, "v") =
             Terminal.App.Renderer.Graphics.Stage_Stored,
         "visible retry transaction staged");
      Terminal.App.Session_Graphics.Process_Hidden
        (Table,
         R,
         Processed,
         Render_Status,
         Write_Status);
      Assert (Processed, "hidden graphics command processed");
      Assert
        (Render_Status = Terminal.App.Renderer.Ok,
         "hidden graphics render succeeds");
      Assert
        (Write_Status in
           Terminal.App.PTY_Write.Ok | Terminal.App.PTY_Write.Incomplete,
         "hidden graphics response is retained or written");
      Runtime.With_Core (Hidden_Core, Inspect_Hidden'Access);
      Runtime.With_Core (Visible_Core, Inspect_Visible'Access);
      Assert
        (Hidden_Pending = 0,
         "hidden graphics queue advances");
      Assert
        (Visible_Pending = 1,
         "visible graphics remains on presentation path");
      Assert
        (Terminal.App.Renderer.Graphics.Stage_Event
           (R, Retained_Visible_Event, "v") =
             Terminal.App.Renderer.Graphics.Stage_Already_Stored,
         "hidden progress preserves the visible retry transaction");
         Terminal.App.Renderer.Graphics.Commit_Visible_Events (R);
         Terminal.App.Renderer.Finalize (R);
      end;
      Tables.Close_All (Table);
   end Background_Graphics_Progress;

   procedure Background_Runtime_Exit_Is_Isolated is
      Table : aliased Tables.Runtime_Table;
      Tab_State : Tabs.Tab_State;
      Split_State : Splits.Split_State;
      Table_Status : Tables.Table_Status;
      Write_Status : Terminal.App.PTY_Write.Write_All_Status;
      Feed_Status : Terminal.Core.Feed_Status;
      Had_Output : Tables.Runtime_Output_Set;
      Deadline : constant Ada.Real_Time.Time :=
        Ada.Real_Time.Clock + Ada.Real_Time.Seconds (2);
   begin
      Tabs.Initialize (Tab_State);
      Splits.Initialize (Split_State);
      Tables.Initialize (Table, 4, 12, 16, Table_Status);
      Assert (Table_Status = Tables.Ok, "exit isolation table initialize");
      Tables.New_Tab
        (Table, 4, 12, 16, Table_Status);
      Assert (Table_Status = Tables.Ok, "exit isolation second tab");
      declare
         Hidden_Borrow : constant Tables.Runtime_Borrow :=
           Tables.Runtime_At (Table, 1);
         Visible_Borrow : constant Tables.Runtime_Borrow :=
           Tables.Runtime_At (Table, 2);
      begin
         Tables.Write
           (Hidden_Borrow,
            Chunk_From_String ("exit" & ASCII.LF),
            Write_Status);
         Assert
           (Write_Status = Terminal.App.PTY_Write.Ok,
            "background runtime accepts exit command");
         while Tables.State (Hidden_Borrow) = Runtime.Active
           and then Ada.Real_Time.Clock < Deadline
         loop
            Tables.Poll_Output
              (Table, Had_Output, Feed_Status, Write_Status);
            delay 0.01;
         end loop;
         Assert
           (Tables.State (Hidden_Borrow) = Runtime.Exited,
            "background runtime records its own exit");
         Assert
           (Tables.State (Visible_Borrow) = Runtime.Active,
            "background exit leaves active runtime running");
      end;
      Tables.Close_All (Table);
   end Background_Runtime_Exit_Is_Isolated;
begin
   Repeated_Runtime_Start_Close;
   Runtime_Table_Churn;
   Renderer_Composition_Churn;
   Background_Graphics_Progress;
   Background_Runtime_Exit_Is_Isolated;
end Session_Hardening_Smoke;

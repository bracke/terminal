with Ada.Real_Time;
with AUnit.Assertions;

with Terminal.App.PTY_Write;
with Terminal.App.Render_Model;
with Terminal.App.Renderer;
with Terminal.App.Session_Graphics;
with Terminal.App.Session_Runtime;
with Terminal.App.Session_Table;
with Terminal.App.Sessions;
with Terminal.App.Splits;
with Terminal.App.Tabs;
with Terminal.App.Queues;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Session_Hardening_Smoke is
   use AUnit.Assertions;
   use type Ada.Real_Time.Time;
   use type Terminal.App.PTY_Write.Write_All_Status;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Render_Status;
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
      Table : Tables.Runtime_Table;
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
           (Table, Tab_State, Split_State, 8, 32, 32, Status);
         Assert (Status = Tables.Ok, "churn new tab" & Natural'Image (I));
      end loop;
      Assert (Tables.Count (Table) = Tabs.Max_Tabs, "churn reaches tab capacity");
      Tables.New_Tab
        (Table, Tab_State, Split_State, 8, 32, 32, Status);
      Assert (Status = Tables.At_Capacity, "churn tab capacity guarded");

      for I in 1 .. Tables.Count (Table) loop
         declare
            R : constant access Runtime.Runtime :=
              Tables.Runtime_At
                (Table, Terminal.App.Sessions.Session_Index (I));
         begin
            Assert (R /= null, "churn runtime present" & Natural'Image (I));
            Runtime.Write
              (R.all,
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
         Tables.Close_Tab (Table, Tab_State, Status);
         Assert (Status = Tables.Ok, "churn close tab");
      end loop;
      Tables.Close_Tab (Table, Tab_State, Status);
      Assert (Status = Tables.Last_Session, "churn last tab guarded");
      Assert
        (Runtime.State (Tables.Active_Runtime (Table).all) = Runtime.Active,
         "churn last runtime survives");
      Tables.Close_All (Table);

      Tabs.Initialize (Tab_State);
      Splits.Initialize (Split_State);
      Tables.Initialize (Table, 12, 48, 32, Status);
      Assert (Status = Tables.Ok, "split churn table initializes");
      for I in 2 .. Splits.Max_Panes loop
         Tables.Split_Pane
           (Table,
            Tab_State,
            Split_State,
            Splits.Split_Vertical,
            12,
            48,
            32,
            Status);
         Assert (Status = Tables.Ok, "churn split pane" & Natural'Image (I));
      end loop;
      Assert
        (Splits.Count (Split_State) = Splits.Max_Panes,
         "churn reaches split capacity");
      Tables.Split_Pane
        (Table,
         Tab_State,
         Split_State,
         Splits.Split_Vertical,
         12,
         48,
         32,
         Status);
      Assert (Status = Tables.At_Capacity, "churn split capacity guarded");
      while Tables.Count (Table) > 1 loop
         Tables.Close_Pane (Table, Split_State, Status);
         Assert (Status = Tables.Ok, "churn close pane");
      end loop;
      Tables.Close_Pane (Table, Split_State, Status);
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
         Terminal.App.Renderer.Render_App
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

      declare
         Frame : constant Terminal.App.Render_Model.Frame_Commands :=
           Terminal.App.Renderer.Last_Frame (R);
      begin
         Assert (Frame.Rectangle_Count > 18, "composition chrome rectangles");
         Assert (Frame.Glyph_Count >= 16, "composition draws all visible labels");
         Assert
           (Frame.Width >=
            3 * (10 * Terminal.App.Renderer.Cell_Width (R)
                 + Terminal.App.Renderer.Content_Margin * 2),
            "composition vertical panes widen frame");
      end;

      Terminal.App.Renderer.Finalize (R);
   end Renderer_Composition_Churn;

   procedure Background_Graphics_Progress is
      Table : Tables.Runtime_Table;
      Tab_State : Tabs.Tab_State;
      Split_State : Splits.Split_State;
      Table_Status : Tables.Table_Status;
      R : Terminal.App.Renderer.Renderer;
      Init_Status : Terminal.App.Renderer.Init_Status;
      Render_Status : Terminal.App.Renderer.Render_Status;
      Write_Status : Terminal.App.PTY_Write.Write_All_Status;
      Feed_Status : Terminal.Core.Feed_Status;
      Processed : Boolean;
      Hidden : access Runtime.Runtime;
      Visible : access Runtime.Runtime;
      Command : constant String :=
        ASCII.ESC & "_Ga=q,f=32,i=501,s=1,v=1;/wAA/w=="
        & ASCII.ESC & "\";
   begin
      Tabs.Initialize (Tab_State);
      Splits.Initialize (Split_State);
      Tables.Initialize (Table, 4, 12, 16, Table_Status);
      Assert (Table_Status = Tables.Ok, "background table initialize");
      Tables.New_Tab
        (Table, Tab_State, Split_State, 4, 12, 16, Table_Status);
      Assert (Table_Status = Tables.Ok, "background tab initialize");
      Hidden := Tables.Runtime_At (Table, 1);
      Visible := Tables.Runtime_At (Table, 2);
      Assert (Hidden /= null and then Visible /= null, "background runtimes");

      Terminal.Core.Feed
        (Runtime.Core (Hidden.all).all, To_Bytes (Command & "Z"), Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "hidden graphics feed");
      Terminal.Core.Feed
        (Runtime.Core (Visible.all).all, To_Bytes (Command), Feed_Status);
      Assert (Feed_Status = Terminal.Core.Ok, "visible graphics feed");

      Terminal.App.Renderer.Initialize_Headless (R, Init_Status);
      Assert (Init_Status = Terminal.App.Renderer.Ok, "background renderer init");
      Terminal.App.Session_Graphics.Process_Hidden
        (Table,
         Split_State,
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
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count
           (Runtime.Core (Hidden.all).all) = 0,
         "hidden graphics queue advances");
      Assert
        (Terminal.Core.Pending_Graphics_Event_Count
           (Runtime.Core (Visible.all).all) = 1,
         "visible graphics remains on presentation path");
      declare
         Snap : Terminal.Core.Render_Snapshot :=
           Terminal.Core.Snapshot (Runtime.Core (Hidden.all).all);
      begin
         Assert
           (Terminal.Core.Cell_At (Snap, 1, 1).Text.Code_Point =
              Character'Pos ('Z'),
            "hidden graphics completion resumes deferred terminal input");
         Terminal.Core.Release (Snap);
      end;

      Terminal.App.Renderer.Finalize (R);
      Tables.Close_All (Table);
   end Background_Graphics_Progress;
begin
   Repeated_Runtime_Start_Close;
   Runtime_Table_Churn;
   Renderer_Composition_Churn;
   Background_Graphics_Progress;
end Session_Hardening_Smoke;

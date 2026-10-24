with AUnit.Assertions;

with Terminal.App.Session_Runtime;
with Terminal.App.Session_Table;
with Terminal.App.Splits;
with Terminal.App.Tabs;

procedure Session_Table_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Session_Runtime.Runtime_Status;
   use type Terminal.App.Session_Table.Table_Status;
   use type Terminal.App.Splits.Pane_Count;
   use type Terminal.App.Tabs.Tab_Count;

   package Runtime renames Terminal.App.Session_Runtime;
   package Tables renames Terminal.App.Session_Table;
   package Splits renames Terminal.App.Splits;
   package Tabs renames Terminal.App.Tabs;

   Table : Tables.Runtime_Table;
   Tab_State : Tabs.Tab_State;
   Split_State : Splits.Split_State;
   Status : Tables.Table_Status;
begin
   Tabs.Initialize (Tab_State);
   Splits.Initialize (Split_State);
   Tables.Initialize (Table, 24, 80, 100, Status);
   Assert (Status = Tables.Ok, "runtime table starts first session");
   Assert (Tables.Count (Table) = 1, "runtime table initial count");
   Assert (Tables.Active (Table) = 1, "runtime table initial active");
   Assert
     (Runtime.State (Tables.Active_Runtime (Table).all) = Runtime.Active,
      "runtime table active runtime state");

   Tables.New_Tab
     (Table, Tab_State, Split_State, 24, 80, 100, Status);
   Assert (Status = Tables.Ok, "runtime table new tab");
   Assert (Tables.Count (Table) = 2, "runtime table tab session count");
   Assert (Tabs.Count (Tab_State) = 2, "runtime table tab model count");
   Assert (Tables.Active (Table) = 2, "runtime table new tab active");

   Tables.Split_Pane
     (Table,
      Tab_State,
      Split_State,
      Splits.Split_Horizontal,
      24,
      80,
      100,
      Status);
   Assert
     (Status = Tables.Layout_Conflict,
      "split layout is rejected while tabs are active");
   Assert (Tables.Count (Table) = 2, "layout conflict preserves sessions");

   Tables.Activate (Table, 1, Status);
   Assert (Status = Tables.Ok, "runtime table activate first");
   Assert (Tables.Active (Table) = 1, "runtime table active first");

   Tables.Close_Tab (Table, Tab_State, Status);
   Assert (Status = Tables.Ok, "runtime table close tab");
   Assert (Tables.Count (Table) = 1, "runtime table close tab count");
   Assert (Tabs.Count (Tab_State) = 1, "runtime table close tab model count");

   Tables.Split_Pane
     (Table,
      Tab_State,
      Split_State,
      Splits.Split_Horizontal,
      24,
      80,
      100,
      Status);
   Assert (Status = Tables.Ok, "runtime table split pane");
   Assert (Tables.Count (Table) = 2, "runtime table split count");
   Assert (Splits.Count (Split_State) = 2, "runtime table split model count");

   Tables.New_Tab
     (Table, Tab_State, Split_State, 24, 80, 100, Status);
   Assert
     (Status = Tables.Layout_Conflict,
      "tab layout is rejected while splits are active");
   Assert (Tables.Count (Table) = 2, "reverse conflict preserves sessions");

   Tables.Close_Pane (Table, Split_State, Status);
   Assert (Status = Tables.Ok, "runtime table close pane");
   Assert (Tables.Count (Table) = 1, "runtime table close pane count");
   Assert (Splits.Count (Split_State) = 1, "runtime table close pane model count");

   Tables.Close_Tab (Table, Tab_State, Status);
   Assert (Status = Tables.Last_Session, "runtime table last session guarded");
   Assert
     (Tables.Count (Table) = 1,
      "runtime table last session guard keeps count");
   Assert
     (Runtime.State (Tables.Active_Runtime (Table).all) = Runtime.Active,
      "runtime table last session guard keeps runtime active");
   Tables.Close_All (Table);

   Tabs.Initialize (Tab_State);
   Splits.Initialize (Split_State);
   Tables.Initialize (Table, 24, 80, 100, Status);
   Assert (Status = Tables.Ok, "runtime table restart for capacity guard");
   for I in 2 .. Splits.Max_Panes loop
      Tables.Split_Pane
        (Table,
         Tab_State,
         Split_State,
         Splits.Split_Vertical,
         24,
         80,
         100,
         Status);
      Assert (Status = Tables.Ok, "runtime table fill split" & Natural'Image (I));
   end loop;
   Tables.Split_Pane
     (Table,
      Tab_State,
      Split_State,
      Splits.Split_Vertical,
      24,
      80,
      100,
      Status);
   Assert
     (Status = Tables.At_Capacity,
      "runtime table split capacity rejected before spawn");
   Assert
     (Tables.Count (Table) = Splits.Max_Panes,
      "runtime table split capacity preserves count");
   Tables.Close_All (Table);

   Tabs.Initialize (Tab_State);
   Splits.Initialize (Split_State);
   Tables.Initialize (Table, 1, 1, 10, Status);
   Assert (Status = Tables.Ok, "tiny runtime table initialize");
   Tables.Split_Pane
     (Table,
      Tab_State,
      Split_State,
      Splits.Split_Horizontal,
      1,
      1,
      10,
      Status);
   Assert
     (Status = Tables.Insufficient_Space,
      "horizontal split rejects a one-row grid");
   Tables.Split_Pane
     (Table,
      Tab_State,
      Split_State,
      Splits.Split_Vertical,
      1,
      1,
      10,
      Status);
   Assert
     (Status = Tables.Insufficient_Space,
      "vertical split rejects a one-column grid");
   Assert (Tables.Count (Table) = 1, "tiny split guard preserves session");
   Tables.Close_All (Table);
end Session_Table_Smoke;

with AUnit.Assertions;

with Terminal.App.Sessions;
with Terminal.App.Splits;
with Terminal.App.Tabs;

procedure Sessions_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Sessions.Session_Lifecycle;
   use type Terminal.App.Sessions.Session_Status;
   use type Terminal.App.Tabs.Tab_Status;
   use type Terminal.App.Splits.Split_Status;

   package Sessions renames Terminal.App.Sessions;
   package Splits renames Terminal.App.Splits;
   package Tabs renames Terminal.App.Tabs;

   Table : Sessions.Session_Table;
   Status : Sessions.Session_Status;
   Tab_State : Tabs.Tab_State;
   Tab_Status : Tabs.Tab_Status;
   Split_State : Splits.Split_State;
   Split_Status : Splits.Split_Status;
begin
   Sessions.Initialize (Table);
   Tabs.Initialize (Tab_State);
   Splits.Initialize (Split_State);

   Assert (Sessions.Count (Table) = 1, "initial session count");
   Assert (Sessions.Active (Table) = 1, "initial active session");
   Assert
     (Sessions.Lifecycle (Table, 1) = Sessions.Live,
      "initial session should be live");
   Assert
     (Sessions.Status_Label (Table) = "Single live session",
      "single session status label");
   Assert
     (Sessions.Status_Label (Table)'Length <= Sessions.Max_Status_Label_Length,
      "session status label should be bounded");

   Sessions.New_Session (Table, Status);
   Tabs.Apply (Tab_State, Tabs.New_Tab, Tab_Status);
   Splits.Apply (Split_State, Splits.Split_Horizontal, Split_Status);
   Assert (Status = Sessions.Ok, "new session status");
   Assert (Tab_Status = Tabs.Ok, "matching new tab status");
   Assert (Split_Status = Splits.Ok, "matching new split status");
   Assert (Sessions.Count (Table) = 2, "new session count");
   Assert (Sessions.Active (Table) = 2, "new session active");
   Assert
     (Sessions.Status_Label (Table) = "Live sessions=2 active=2",
      "multi-session status label");

   Sessions.Activate_Tab (Table, Tab_State, 1, Status);
   Assert (Status = Sessions.Ok, "activate first tab session");
   Assert (Sessions.Active (Table) = 1, "active session after tab activate");
   Assert (Tabs.Active (Tab_State) = 1, "active tab after session activate");

   Sessions.Activate_Pane (Table, Split_State, 2, Status);
   Assert (Status = Sessions.Ok, "activate second pane session");
   Assert (Sessions.Active (Table) = 2, "active session after pane activate");
   Assert (Splits.Active (Split_State) = 2, "active pane after session activate");

   Sessions.Activate (Table, 3, Status);
   Assert (Status = Sessions.Invalid_Index, "invalid session activate");
   Assert (Sessions.Active (Table) = 2, "invalid activate preserves active");

   Sessions.Close_Active (Table, Status);
   Assert (Status = Sessions.Ok, "close active session");
   Assert (Sessions.Count (Table) = 1, "close active session count");
   Assert (Sessions.Active (Table) = 1, "close active session active");
   Assert
     (Sessions.Lifecycle (Table, 2) = Sessions.Unused,
      "closed slot should become unused");

   Sessions.Close_Active (Table, Status);
   Assert (Status = Sessions.Last_Session, "last session close rejected");

   for I in 2 .. Sessions.Max_Sessions loop
      Sessions.New_Session (Table, Status);
      Assert (Status = Sessions.Ok, "fill session" & Natural'Image (I));
   end loop;
   Sessions.New_Session (Table, Status);
   Assert (Status = Sessions.At_Capacity, "session capacity bounded");
end Sessions_Smoke;

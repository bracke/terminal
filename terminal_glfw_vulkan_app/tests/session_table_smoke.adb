with AUnit.Assertions;

with Terminal.App.Session_Runtime;
with Terminal.App.Session_Runtime.Deferred_Cleanup.Testing;
with Terminal.App.Session_Table;
with Terminal.App.Session_Table.Testing;
with Terminal.App.PTY_Write;
with Terminal.App.Sessions;
with Terminal.App.Splits;
with Terminal.App.Tabs;
with Terminal.Core;

procedure Session_Table_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Session_Runtime.Runtime_Status;
   use type Terminal.App.Session_Table.Table_Status;
   use type Terminal.App.Session_Table.Runtime_Output_Set;
   use type Terminal.App.Splits.Pane_Count;
   use type Terminal.App.Tabs.Tab_Count;
   use type Terminal.App.PTY_Write.Write_All_Status;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Graphics_Stream_ID;

   package Runtime renames Terminal.App.Session_Runtime;
   package Tables renames Terminal.App.Session_Table;
   package Splits renames Terminal.App.Splits;
   package Tabs renames Terminal.App.Tabs;

   Table : aliased Tables.Runtime_Table;
   Tab_State : Tabs.Tab_State;
   Split_State : Splits.Split_State;
   Status : Tables.Table_Status;

   protected Foreign_Result is
      procedure Note_Rejection;
      function Rejected return Boolean;
   private
      Was_Rejected : Boolean := False;
   end Foreign_Result;

   protected body Foreign_Result is
      procedure Note_Rejection is
      begin
         Was_Rejected := True;
      end Note_Rejection;

      function Rejected return Boolean is (Was_Rejected);
   end Foreign_Result;

   task type Foreign_Reader
     (Target : not null access Tables.Runtime_Table);

   task body Foreign_Reader is
      Ignored : Terminal.App.Sessions.Session_Count;
      pragma Unreferenced (Ignored);
   begin
      Ignored := Tables.Count (Target.all);
   exception
      when Program_Error =>
         Foreign_Result.Note_Rejection;
   end Foreign_Reader;
begin
   Terminal.App.Session_Runtime.Deferred_Cleanup.Testing
     .Verify_Retry_Schedule;
   Terminal.App.Session_Runtime.Deferred_Cleanup.Testing
     .Verify_Bounded_Release;
   Terminal.App.Session_Runtime.Deferred_Cleanup.Testing.Verify_Fair_Retry;
   Terminal.App.Session_Runtime.Deferred_Cleanup.Testing
     .Verify_Abort_And_Concurrent_Drain;
   Terminal.App.Session_Runtime.Deferred_Cleanup.Testing
     .Verify_Invalid_State_Rejection;
   Terminal.App.Session_Table.Testing.Verify_Deferred_Feed_Status_Merge;
   Terminal.App.Session_Table.Testing.Verify_Close_All_Deallocation_Rollback;
   Terminal.App.Session_Table.Testing.Verify_Finalizer_Deallocation_Quarantine;
   Tabs.Initialize (Tab_State);
   Splits.Initialize (Split_State);
   Tables.Initialize (Table, 24, 80, 100, Status);
   Assert (Status = Tables.Ok, "runtime table starts first session");
   Assert (Tables.Count (Table) = 1, "runtime table initial count");
   Assert (Tables.Active (Table) = 1, "runtime table initial active");
   declare
      Reader : Foreign_Reader (Table'Access);
   begin
      null;
   end;
   Assert
     (Foreign_Result.Rejected,
      "runtime table rejects access from a non-owner task");
   Assert
     (Tables.State (Tables.Active_Runtime (Table)) = Runtime.Active,
      "runtime table active runtime state");

   Tables.New_Tab
     (Table, 24, 80, 100, Status);
   Assert (Status = Tables.Ok, "runtime table new tab");
   Assert (Tables.Count (Table) = 2, "runtime table tab session count");
   Assert (Tabs.Count (Tables.Tabs (Table)) = 2, "runtime table tab model count");
   Assert (Tables.Active (Table) = 2, "runtime table new tab active");

   declare
      Borrow : constant Tables.Runtime_Borrow := Tables.Active_Runtime (Table);
   begin
      Assert
        (Tables.State (Borrow) = Runtime.Active,
         "active runtime borrow is valid");
      declare
         Rejected : Boolean := False;
      begin
         begin
            Tables.Close_All (Table);
         exception
            when Program_Error => Rejected := True;
         end;
         Assert
           (Rejected and then Tables.Count (Table) = 2,
            "whole-table cleanup rejects outstanding runtime borrows");
      end;
      Tables.Close_Tab (Table, Status);
      Assert
        (Status = Tables.Runtime_In_Use and then Tables.Count (Table) = 2,
         "a borrowed runtime cannot be removed from its table");
   end;

   declare
      Core : constant Runtime.Core_Borrow :=
        Tables.Core (Tables.Active_Runtime (Table));
      Close_Failed : Boolean := False;
      Reborrow_Rejected : Boolean := False;
      Had_Output : Tables.Runtime_Output_Set;
      Feed_Status : Terminal.Core.Feed_Status;
      Write_Status : Terminal.App.PTY_Write.Write_All_Status;
      pragma Unreferenced (Core);
   begin
      begin
         Tables.Close_Tab (Table, Status);
      exception
         when Program_Error => Close_Failed := True;
      end;
      begin
         declare
            Borrow : constant Tables.Runtime_Borrow :=
              Tables.Active_Runtime (Table);
            pragma Unreferenced (Borrow);
         begin
            null;
         end;
      exception
         when Tables.Runtime_Unavailable => Reborrow_Rejected := True;
      end;
      Tables.Apply_Tab_Navigation (Table, Tabs.Previous_Tab, Status);
      Assert
        (Status = Tables.Runtime_In_Use and then Tables.Active (Table) = 2,
         "navigation cannot strand a closing runtime");
      Tables.New_Tab (Table, 24, 80, 100, Status);
      Assert
        (Status = Tables.Runtime_In_Use and then Tables.Count (Table) = 2,
         "session creation is blocked while cleanup is pending");
      Tables.Poll_Output
        (Table, Had_Output, Feed_Status, Write_Status);
      Assert
        (Feed_Status = Terminal.Core.Invalid_State
         and then Write_Status = Terminal.App.PTY_Write.Session_Closed
         and then Had_Output = Tables.Runtime_Output_Set'(others => False),
         "output polling does not touch a closing runtime");
      Assert
        (Close_Failed and then Reborrow_Rejected,
         "incomplete runtime cleanup remains exclusively closing");
   end;
   Tables.Close_Tab (Table, Status);
   Assert
     (Status = Tables.Ok and then Tables.Count (Table) = 1,
      "runtime close retries after the nested core borrow is released");
   Tables.New_Tab (Table, 24, 80, 100, Status);
   Assert
     (Status = Tables.Ok and then Tables.Count (Table) = 2,
      "runtime table remains usable after a cleanup retry");

   Tables.Apply_Tab_Navigation (Table, Tabs.Previous_Tab, Status);
   Assert (Status = Tables.Ok, "runtime table previous tab");
   Assert
     (Tables.Active (Table) = 1
      and then Tabs.Active (Tables.Tabs (Table)) = 1,
      "tab and session activation remain synchronized");
   Tables.Apply_Tab_Navigation (Table, Tabs.Next_Tab, Status);
   Assert (Status = Tables.Ok, "runtime table next tab");
   declare
      Held_First : constant Tables.Runtime_Borrow := Tables.Runtime_At (Table, 1);
      First_Stream : constant Terminal.Core.Graphics_Stream_ID :=
        Tables.Graphics_Stream_ID (Held_First);
      Second_Stream : constant Terminal.Core.Graphics_Stream_ID :=
        Tables.Graphics_Stream_ID (Tables.Runtime_At (Table, 2));
   begin
      Tables.Reorder_Tab (Table, 2, 1, Status);
      Assert
        (Status = Tables.Ok and then Tables.Active (Table) = 1
         and then Tables.Graphics_Stream_ID (Tables.Runtime_At (Table, 1)) =
           Second_Stream
         and then Tables.Graphics_Stream_ID (Tables.Runtime_At (Table, 2)) =
           First_Stream,
         "borrowed runtime tab reorder moves ownership and activates destination");
      Tables.Reorder_Tab (Table, 1, 2, Status);
      Assert (Status = Tables.Ok, "runtime tab reorder restore");
   end;

   Tables.Split_Pane
     (Table,
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
   Assert
     (Tables.Active (Table) = 1
      and then Tabs.Active (Tables.Tabs (Table)) = 1,
      "runtime table active first synchronizes tab model");

   Tables.Close_Tab (Table, Status);
   Assert (Status = Tables.Ok, "runtime table close tab");
   Assert (Tables.Count (Table) = 1, "runtime table close tab count");
   Assert (Tabs.Count (Tables.Tabs (Table)) = 1, "runtime table close tab model count");

   Tables.Split_Pane
     (Table,
         Splits.Split_Horizontal,
      24,
      80,
      100,
      Status);
   Assert (Status = Tables.Ok, "runtime table split pane");
   Assert (Tables.Count (Table) = 2, "runtime table split count");
   Assert (Splits.Count (Tables.Splits (Table)) = 2, "runtime table split model count");

   Tables.Apply_Pane_Navigation (Table, Splits.Next_Pane, Status);
   Assert (Status = Tables.Ok, "runtime table next pane");
   Assert
     (Tables.Active (Table) = 1
      and then Splits.Active (Tables.Splits (Table)) = 1,
      "pane and session activation remain synchronized");
   declare
      Held_First : constant Tables.Runtime_Borrow := Tables.Runtime_At (Table, 1);
      First_Stream : constant Terminal.Core.Graphics_Stream_ID :=
        Tables.Graphics_Stream_ID (Held_First);
      Second_Stream : constant Terminal.Core.Graphics_Stream_ID :=
        Tables.Graphics_Stream_ID (Tables.Runtime_At (Table, 2));
   begin
      Tables.Move_Active_Pane (Table, Status);
      Assert
        (Status = Tables.Ok
         and then Tables.Active (Table) = 2
         and then Tables.Graphics_Stream_ID (Tables.Runtime_At (Table, 1)) =
           Second_Stream
         and then Tables.Graphics_Stream_ID (Tables.Runtime_At (Table, 2)) =
           First_Stream,
         "moving a borrowed pane preserves runtime ownership and follows focus");
      Tables.Move_Active_Pane (Table, Status);
      Assert
        (Status = Tables.Ok and then Tables.Active (Table) = 1,
         "moving the final pane wraps to the first position");
   end;

   Tables.New_Tab
     (Table, 24, 80, 100, Status);
   Assert
     (Status = Tables.Layout_Conflict,
      "tab layout is rejected while splits are active");
   Assert (Tables.Count (Table) = 2, "reverse conflict preserves sessions");

   Tables.Close_Pane (Table, Status);
   Assert (Status = Tables.Ok, "runtime table close pane");
   Assert (Tables.Count (Table) = 1, "runtime table close pane count");
   Assert (Splits.Count (Tables.Splits (Table)) = 1, "runtime table close pane model count");

   Tables.Close_Tab (Table, Status);
   Assert (Status = Tables.Last_Session, "runtime table last session guarded");
   Assert
     (Tables.Count (Table) = 1,
      "runtime table last session guard keeps count");
   Assert
     (Tables.State (Tables.Active_Runtime (Table)) = Runtime.Active,
      "runtime table last session guard keeps runtime active");
   Tables.Close_All (Table);
   Assert (Tables.Count (Table) = 0, "closed runtime table has no sessions");
   Assert (Tabs.Count (Tables.Tabs (Table)) = 0, "closed runtime table has no tabs");
   Assert
     (Splits.Count (Tables.Splits (Table)) = 0,
      "closed runtime table has no panes");
   declare
      Rejected : Boolean := False;
      Had_Output : Tables.Runtime_Output_Set;
      Feed_Status : Terminal.Core.Feed_Status;
      Write_Status : Terminal.App.PTY_Write.Write_All_Status;
   begin
      begin
         declare
            Ignored : constant Terminal.App.Sessions.Session_Index :=
              Tables.Active (Table);
            pragma Unreferenced (Ignored);
         begin
            null;
         end;
      exception
         when Tables.Runtime_Unavailable =>
            Rejected := True;
      end;
      Assert (Rejected, "closed runtime table rejects active lookup");
      Tables.New_Tab (Table, 24, 80, 100, Status);
      Assert
        (Status = Tables.Not_Initialized,
         "closed runtime table mutation returns a status");
      Tables.Poll_Output
        (Table, Had_Output, Feed_Status, Write_Status);
      Assert
        (Had_Output = Tables.Runtime_Output_Set'(others => False)
         and then Feed_Status = Terminal.Core.Invalid_State
         and then Write_Status = Terminal.App.PTY_Write.Session_Closed,
         "closed runtime table polling initializes every result");
   end;

   Tabs.Initialize (Tab_State);
   Splits.Initialize (Split_State);
   Tables.Initialize (Table, 24, 80, 100, Status);
   Assert (Status = Tables.Ok, "runtime table restart for capacity guard");
   for I in 2 .. Splits.Max_Panes loop
      Tables.Split_Pane
        (Table,
         Splits.Split_Vertical,
         24,
         80,
         100,
         Status);
      Assert (Status = Tables.Ok, "runtime table fill split" & Natural'Image (I));
   end loop;
   Tables.Split_Pane
     (Table,
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

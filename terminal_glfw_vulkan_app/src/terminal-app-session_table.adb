with Ada.Exceptions;
with Ada.Task_Identification;
with Ada.Unchecked_Deallocation;
with Terminal.App.Cleanup_Diagnostics;
with Terminal.App.Graphics_Profile;
with Terminal.App.PTY_Write;
with Terminal.Common.Status;

package body Terminal.App.Session_Table is
   use type Terminal.App.PTY_Write.Write_All_Status;
   use type Terminal.App.Session_Runtime.Runtime_Status;
   use type Terminal.App.Session_Runtime.Start_Status;
   use type Terminal.App.Sessions.Session_Status;
   use type Terminal.App.Splits.Split_Command;
   use type Terminal.App.Splits.Split_Status;
   use type Terminal.App.Tabs.Tab_Status;
   use type Ada.Task_Identification.Task_Id;

   procedure Free_Runtime is new Ada.Unchecked_Deallocation
     (Terminal.App.Session_Runtime.Runtime,
      Runtime_Access);

   procedure Retain_Deferred_Runtime is new
     Terminal.App.Session_Runtime.Deferred_Cleanup.Retain (Runtime_Access);

   function Quarantined_Runtime_Count return Natural is
     (Terminal.App.Session_Runtime.Deferred_Cleanup.Runtime_Count);

   procedure Claim_Owner (Table : in out Runtime_Table) is
      Current : constant Ada.Task_Identification.Task_Id :=
        Ada.Task_Identification.Current_Task;
   begin
      if Table.Owner_Task = Ada.Task_Identification.Null_Task_Id then
         Table.Owner_Task := Current;
      elsif Table.Owner_Task /= Current then
         raise Program_Error with
           "session table may only be used by its owning task";
      end if;
   end Claim_Owner;

   procedure Check_Owner (Table : Runtime_Table) is
   begin
      if Table.Owner_Task /= Ada.Task_Identification.Null_Task_Id
        and then Table.Owner_Task /= Ada.Task_Identification.Current_Task
      then
         raise Program_Error with
           "session table may only be used by its owning task";
      end if;
   end Check_Owner;

   procedure Require_Open (Table : Runtime_Table) is
   begin
      if not Table.Open then
         raise Runtime_Unavailable with "session table is not initialized";
      end if;
   end Require_Open;

   function Is_Open
     (Table  : Runtime_Table;
      Status : out Table_Status) return Boolean is
   begin
      if Table.Open then
         return True;
      end if;
      Status := Not_Initialized;
      return False;
   end Is_Open;

   procedure Merge_Feed_Status
     (Candidate : Terminal.Core.Feed_Status;
      Aggregate : in out Terminal.Core.Feed_Status) is
   begin
      if Feed_Rank (Candidate) > Feed_Rank (Aggregate) then
         Aggregate := Candidate;
      end if;
   end Merge_Feed_Status;

   protected body Runtime_Borrow_Registry is separate;

   overriding procedure Finalize (Guard : in out Runtime_Borrow_Guard) is
   begin
      if Guard.Hold.Active then
         Guard.Owner.Borrows.Release (Guard.Hold.Item);
         Guard.Hold.Active := False;
         Guard.Hold.Item := null;
      end if;
   exception
      when E : others =>
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Session_Table,
            E,
            "release runtime borrow");
   end Finalize;

   procedure Release_Runtime (Slot : in out Runtime_Access) is
   begin
      if Slot /= null then
         Terminal.App.Session_Runtime.Close (Slot.all);
         if Terminal.App.Session_Runtime.State (Slot.all) /=
           Terminal.App.Session_Runtime.Closed
         then
            raise Program_Error with "session runtime cleanup is incomplete";
         end if;
         Free_Runtime (Slot);
      end if;
   end Release_Runtime;

   procedure Release_Or_Retain
     (Table : in out Runtime_Table;
      Slot  : in out Runtime_Access) is
   begin
      Release_Runtime (Slot);
   exception
      when E : others =>
         if Table.Pending_Start /= null then
            raise Program_Error with
              "session table already owns a pending startup runtime";
         end if;
         --  Transfer the still-live pointer before propagating the cleanup
         --  error.  Close_All and the next startup attempt can retry it.
         Table.Pending_Start := Slot;
         Slot := null;
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Session_Table,
            E,
            "retain unregistered session runtime for cleanup retry");
   end Release_Or_Retain;

   procedure Close_All_Internal
     (Table        : in out Runtime_Table;
      Raise_Errors : Boolean;
      Deallocate   : Runtime_Deallocator := null)
   is separate;

   function Convert
     (Status : Terminal.App.Sessions.Session_Status) return Table_Status is
   begin
      case Status is
         when Terminal.App.Sessions.Ok =>
            return Ok;
         when Terminal.App.Sessions.At_Capacity =>
            return At_Capacity;
         when Terminal.App.Sessions.Last_Session =>
            return Last_Session;
         when Terminal.App.Sessions.Invalid_Index =>
            return Invalid_Index;
      end case;
   end Convert;

   procedure Start_Runtime
     (Table            : in out Runtime_Table;
      Slot             : out Runtime_Access;
      Rows             : Positive;
      Cols             : Positive;
      Scrollback_Limit : Natural;
      Graphics_Profile : Terminal.Core.Graphics_Capability_Profile;
      Status           : out Table_Status;
      Start_Status     : out Terminal.App.Session_Runtime.Start_Status)
   is separate;

   procedure Start_And_Register
     (Table            : in out Runtime_Table;
      Index            : Terminal.App.Sessions.Session_Index;
      Rows             : Positive;
      Cols             : Positive;
      Scrollback_Limit : Natural;
      Status           : out Table_Status)
   is
      Item : Runtime_Access := null;
   begin
      Start_Runtime
        (Table, Item, Rows, Cols, Scrollback_Limit, Table.Graphics_Profile,
         Status, Table.Last_Start);
      if Status /= Ok then
         return;
      end if;

      begin
         Table.Borrows.Register (Index, Item);
      exception
         when others =>
            Status := Start_Failed;
            Release_Or_Retain (Table, Item);
            raise;
      end;
   end Start_And_Register;

   procedure Remove_Runtime_Transaction
     (Table   : in out Runtime_Table;
      Index   : Terminal.App.Sessions.Session_Index;
      Prepare : not null access procedure (Status : out Table_Status);
      Status  : out Table_Status)
   is
      Item          : Runtime_Access;
      Reserved      : Boolean := False;
      Retrying      : Boolean := False;
      Close_Started : Boolean := False;
   begin
      Table.Borrows.Begin_Remove (Index, Item, Reserved, Retrying);
      if not Reserved then
         Status := Runtime_In_Use;
         return;
      end if;

      Prepare (Status);
      if Status /= Ok then
         if not Retrying then
            Table.Borrows.Cancel_Remove (Index);
         end if;
         Reserved := False;
         return;
      end if;

      if Item /= null then
         Close_Started := True;
         Terminal.App.Session_Runtime.Close (Item.all);
         if Terminal.App.Session_Runtime.State (Item.all) /=
           Terminal.App.Session_Runtime.Closed
         then
            raise Program_Error with "session runtime cleanup is incomplete";
         end if;
      end if;
      Table.Borrows.Complete_Remove
        (Index,
         Shift_Left => Index < Terminal.App.Sessions.Session_Index'Last,
         Item       => Item);
      Reserved := False;
      Free_Runtime (Item);
      Status := Ok;
   exception
      when others =>
         if Reserved and then not Retrying and then not Close_Started then
            Table.Borrows.Cancel_Remove (Index);
         end if;
         raise;
   end Remove_Runtime_Transaction;

   procedure Initialize
     (Table            : in out Runtime_Table;
      Rows             : Positive;
      Cols             : Positive;
      Scrollback_Limit : Natural;
      Status           : out Table_Status;
      Graphics_Profile : Terminal.Core.Graphics_Capability_Profile :=
        Terminal.App.Graphics_Profile.Core_Capabilities
          (Terminal.App.Graphics_Profile.Default))
   is
      Item : Runtime_Access := null;
      Starting : Boolean := False;
   begin
      Claim_Owner (Table);
      Close_All_Internal (Table, Raise_Errors => True);
      Starting := True;
      Table.Graphics_Profile := Graphics_Profile;
      Terminal.App.Sessions.Initialize (Table.Sessions);
      Terminal.App.Tabs.Initialize (Table.Tabs);
      Terminal.App.Splits.Initialize (Table.Splits);
      Start_Runtime
        (Table,
         Item,
         Rows,
         Cols,
         Scrollback_Limit,
         Table.Graphics_Profile,
         Status,
         Table.Last_Start);
      if Status = Ok then
         begin
            Table.Borrows.Register (1, Item);
            Table.Open := True;
         exception
            when others =>
               Status := Start_Failed;
               Release_Or_Retain (Table, Item);
               Terminal.App.Sessions.Clear (Table.Sessions);
               Terminal.App.Tabs.Clear (Table.Tabs);
               Terminal.App.Splits.Clear (Table.Splits);
               raise;
         end;
      else
         Terminal.App.Sessions.Clear (Table.Sessions);
         Terminal.App.Tabs.Clear (Table.Tabs);
         Terminal.App.Splits.Clear (Table.Splits);
      end if;
   exception
      when others =>
         if Starting then
            Table.Open := False;
            Terminal.App.Sessions.Clear (Table.Sessions);
            Terminal.App.Tabs.Clear (Table.Tabs);
            Terminal.App.Splits.Clear (Table.Splits);
         end if;
         raise;
   end Initialize;

   procedure New_Tab
     (Table            : in out Runtime_Table;
      Rows             : Positive;
      Cols             : Positive;
      Scrollback_Limit : Natural;
      Status           : out Table_Status)
   is
      Session_Status : Terminal.App.Sessions.Session_Status;
      Tab_Status : Terminal.App.Tabs.Tab_Status;
      New_Index : Terminal.App.Sessions.Session_Index;
      Next_Sessions : Terminal.App.Sessions.Session_Table;
      Next_Tabs : Terminal.App.Tabs.Tab_State;
   begin
      Check_Owner (Table);
      if not Is_Open (Table, Status) then
         return;
      end if;
      if Table.Borrows.Is_Closing then
         Status := Runtime_In_Use;
         return;
      end if;
      Next_Sessions := Table.Sessions;
      Next_Tabs := Table.Tabs;
      if Terminal.App.Splits.Count (Table.Splits) > 1 then
         Status := Layout_Conflict;
         return;
      end if;
      Terminal.App.Tabs.Apply
        (Next_Tabs, Terminal.App.Tabs.New_Tab, Tab_Status);
      if Tab_Status /= Terminal.App.Tabs.Ok then
         Status :=
           (if Tab_Status = Terminal.App.Tabs.At_Capacity
            then At_Capacity else Invalid_Index);
         return;
      end if;
      Terminal.App.Sessions.New_Session (Next_Sessions, Session_Status);
      if Session_Status /= Terminal.App.Sessions.Ok then
         Status := Convert (Session_Status);
         return;
      end if;

      New_Index := Terminal.App.Sessions.Active (Next_Sessions);
      Start_And_Register
        (Table, New_Index, Rows, Cols, Scrollback_Limit, Status);
      if Status /= Ok then
         return;
      end if;
      Table.Sessions := Next_Sessions;
      Table.Tabs := Next_Tabs;
   end New_Tab;

   procedure Close_Tab
     (Table  : in out Runtime_Table;
      Status : out Table_Status)
   is
      Index : Terminal.App.Sessions.Session_Index;
      Session_Status : Terminal.App.Sessions.Session_Status;
      Tab_Status : Terminal.App.Tabs.Tab_Status;
      Next_Sessions : Terminal.App.Sessions.Session_Table;
      Next_Tabs : Terminal.App.Tabs.Tab_State;
      procedure Prepare (Prepare_Status : out Table_Status) is
      begin
         Terminal.App.Sessions.Close_Active
           (Next_Sessions, Session_Status);
         if Session_Status /= Terminal.App.Sessions.Ok then
            Prepare_Status := Convert (Session_Status);
            return;
         end if;
         Terminal.App.Tabs.Apply
           (Next_Tabs, Terminal.App.Tabs.Close_Tab, Tab_Status);
         Prepare_Status :=
           (if Tab_Status = Terminal.App.Tabs.Ok then Ok else Invalid_Index);
      end Prepare;
   begin
      Check_Owner (Table);
      if not Is_Open (Table, Status) then
         return;
      end if;
      Index := Terminal.App.Sessions.Active (Table.Sessions);
      Next_Sessions := Table.Sessions;
      Next_Tabs := Table.Tabs;
      if Terminal.App.Sessions.Count (Table.Sessions) <= 1 then
         Status := Last_Session;
         return;
      end if;

      Remove_Runtime_Transaction (Table, Index, Prepare'Access, Status);
      if Status /= Ok then
         return;
      end if;
      Table.Sessions := Next_Sessions;
      Table.Tabs := Next_Tabs;
   end Close_Tab;

   procedure Split_Pane
     (Table            : in out Runtime_Table;
      Command          : Terminal.App.Splits.Split_Command;
      Rows             : Positive;
      Cols             : Positive;
      Scrollback_Limit : Natural;
      Status           : out Table_Status)
   is
      Session_Status : Terminal.App.Sessions.Session_Status;
      Split_Status : Terminal.App.Splits.Split_Status;
      New_Index : Terminal.App.Sessions.Session_Index;
      Next_Sessions : Terminal.App.Sessions.Session_Table;
      Next_Splits : Terminal.App.Splits.Split_State;
   begin
      Check_Owner (Table);
      if not Is_Open (Table, Status) then
         return;
      end if;
      if Table.Borrows.Is_Closing then
         Status := Runtime_In_Use;
         return;
      end if;
      Next_Sessions := Table.Sessions;
      Next_Splits := Table.Splits;
      if Terminal.App.Tabs.Count (Table.Tabs) > 1 then
         Status := Layout_Conflict;
         return;
      end if;
      if Command /= Terminal.App.Splits.Split_Horizontal
        and then Command /= Terminal.App.Splits.Split_Vertical
      then
         Status := Invalid_Index;
         return;
      end if;

      if (Command = Terminal.App.Splits.Split_Horizontal
          and then Rows <= Positive (Terminal.App.Splits.Count (Table.Splits)))
        or else
          (Command = Terminal.App.Splits.Split_Vertical
           and then Cols <= Positive (Terminal.App.Splits.Count (Table.Splits)))
      then
         Status := Insufficient_Space;
         return;
      end if;

      if Terminal.App.Splits.Count (Table.Splits) >= Terminal.App.Splits.Max_Panes then
         Status := At_Capacity;
         return;
      end if;

      Terminal.App.Splits.Apply (Next_Splits, Command, Split_Status);
      if Split_Status /= Terminal.App.Splits.Ok then
         Status :=
           (if Split_Status = Terminal.App.Splits.At_Capacity
            then At_Capacity else Invalid_Index);
         return;
      end if;
      Terminal.App.Sessions.New_Session (Next_Sessions, Session_Status);
      if Session_Status /= Terminal.App.Sessions.Ok then
         Status := Convert (Session_Status);
         return;
      end if;

      New_Index := Terminal.App.Sessions.Active (Next_Sessions);
      Start_And_Register
        (Table, New_Index, Rows, Cols, Scrollback_Limit, Status);
      if Status /= Ok then
         return;
      end if;
      Table.Sessions := Next_Sessions;
      Table.Splits := Next_Splits;
   end Split_Pane;

   procedure Close_Pane
     (Table  : in out Runtime_Table;
      Status : out Table_Status)
   is
      Index : Terminal.App.Sessions.Session_Index;
      Session_Status : Terminal.App.Sessions.Session_Status;
      Split_Status : Terminal.App.Splits.Split_Status;
      Next_Sessions : Terminal.App.Sessions.Session_Table;
      Next_Splits : Terminal.App.Splits.Split_State;
      procedure Prepare (Prepare_Status : out Table_Status) is
      begin
         Terminal.App.Sessions.Close_Active
           (Next_Sessions, Session_Status);
         if Session_Status /= Terminal.App.Sessions.Ok then
            Prepare_Status := Convert (Session_Status);
            return;
         end if;
         Terminal.App.Splits.Apply
           (Next_Splits, Terminal.App.Splits.Close_Pane, Split_Status);
         Prepare_Status :=
           (if Split_Status = Terminal.App.Splits.Ok then Ok else Invalid_Index);
      end Prepare;
   begin
      Check_Owner (Table);
      if not Is_Open (Table, Status) then
         return;
      end if;
      Index := Terminal.App.Sessions.Active (Table.Sessions);
      Next_Sessions := Table.Sessions;
      Next_Splits := Table.Splits;
      if Terminal.App.Sessions.Count (Table.Sessions) <= 1 then
         Status := Last_Session;
         return;
      end if;

      Remove_Runtime_Transaction (Table, Index, Prepare'Access, Status);
      if Status /= Ok then
         return;
      end if;
      Table.Sessions := Next_Sessions;
      Table.Splits := Next_Splits;
   end Close_Pane;

   procedure Apply_Tab_Navigation
     (Table   : in out Runtime_Table;
      Command : Terminal.App.Tabs.Tab_Command;
      Status  : out Table_Status)
   is
      Next_Tabs : Terminal.App.Tabs.Tab_State;
      Tab_Status : Terminal.App.Tabs.Tab_Status;
      Session_Status : Terminal.App.Sessions.Session_Status;
      Next_Sessions : Terminal.App.Sessions.Session_Table;
   begin
      Check_Owner (Table);
      if not Is_Open (Table, Status) then
         return;
      end if;
      if Table.Borrows.Is_Closing then
         Status := Runtime_In_Use;
         return;
      end if;
      Next_Tabs := Table.Tabs;
      Next_Sessions := Table.Sessions;
      if Command not in
        Terminal.App.Tabs.Next_Tab | Terminal.App.Tabs.Previous_Tab
      then
         Status := Invalid_Index;
         return;
      end if;
      Terminal.App.Tabs.Apply (Next_Tabs, Command, Tab_Status);
      if Tab_Status /= Terminal.App.Tabs.Ok then
         Status := Invalid_Index;
         return;
      end if;
      Terminal.App.Sessions.Activate
        (Next_Sessions,
         Terminal.App.Sessions.Session_Index
           (Terminal.App.Tabs.Active (Next_Tabs)),
         Session_Status);
      if Session_Status /= Terminal.App.Sessions.Ok then
         Status := Convert (Session_Status);
         return;
      end if;
      Table.Sessions := Next_Sessions;
      Table.Tabs := Next_Tabs;
      Status := Ok;
   end Apply_Tab_Navigation;

   procedure Reorder_Tab
     (Table  : in out Runtime_Table;
      From   : Terminal.App.Tabs.Tab_Index;
      To     : Terminal.App.Tabs.Tab_Index;
      Status : out Table_Status)
   is
      Next_Tabs : Terminal.App.Tabs.Tab_State;
      Tab_Status : Terminal.App.Tabs.Tab_Status;
      Session_Status : Terminal.App.Sessions.Session_Status;
      Moved : Boolean;
   begin
      Check_Owner (Table);
      if not Is_Open (Table, Status) then
         return;
      elsif Terminal.App.Tabs.Count (Table.Tabs) <= 1
        or else From > Terminal.App.Tabs.Count (Table.Tabs)
        or else To > Terminal.App.Tabs.Count (Table.Tabs)
      then
         Status := Invalid_Index;
         return;
      end if;

      Next_Tabs := Table.Tabs;
      Terminal.App.Tabs.Move (Next_Tabs, From, To, Tab_Status);
      if Tab_Status /= Terminal.App.Tabs.Ok then
         Status := Invalid_Index;
         return;
      end if;
      Table.Borrows.Move
        (Terminal.App.Sessions.Session_Index (From),
         Terminal.App.Sessions.Session_Index (To),
         Moved);
      if not Moved then
         Status := Runtime_In_Use;
         return;
      end if;
      Terminal.App.Sessions.Activate
        (Table.Sessions,
         Terminal.App.Sessions.Session_Index (To),
         Session_Status);
      if Session_Status /= Terminal.App.Sessions.Ok then
         raise Program_Error with "reordered runtime has no live session slot";
      end if;
      Table.Tabs := Next_Tabs;
      Status := Ok;
   end Reorder_Tab;

   procedure Apply_Pane_Navigation
     (Table   : in out Runtime_Table;
      Command : Terminal.App.Splits.Split_Command;
      Status  : out Table_Status)
   is
      Next_Splits : Terminal.App.Splits.Split_State;
      Split_Status : Terminal.App.Splits.Split_Status;
      Session_Status : Terminal.App.Sessions.Session_Status;
      Next_Sessions : Terminal.App.Sessions.Session_Table;
   begin
      Check_Owner (Table);
      if not Is_Open (Table, Status) then
         return;
      end if;
      if Table.Borrows.Is_Closing then
         Status := Runtime_In_Use;
         return;
      end if;
      Next_Splits := Table.Splits;
      Next_Sessions := Table.Sessions;
      if Command /= Terminal.App.Splits.Next_Pane then
         Status := Invalid_Index;
         return;
      end if;
      Terminal.App.Splits.Apply (Next_Splits, Command, Split_Status);
      if Split_Status /= Terminal.App.Splits.Ok then
         Status := Invalid_Index;
         return;
      end if;
      Terminal.App.Sessions.Activate
        (Next_Sessions,
         Terminal.App.Sessions.Session_Index
           (Terminal.App.Splits.Active (Next_Splits)),
         Session_Status);
      if Session_Status /= Terminal.App.Sessions.Ok then
         Status := Convert (Session_Status);
         return;
      end if;
      Table.Sessions := Next_Sessions;
      Table.Splits := Next_Splits;
      Status := Ok;
   end Apply_Pane_Navigation;

   procedure Move_Active_Pane
     (Table  : in out Runtime_Table;
      Status : out Table_Status)
   is
      From : Terminal.App.Splits.Pane_Index;
      To : Terminal.App.Splits.Pane_Index;
      Moved : Boolean;
      Split_Status : Terminal.App.Splits.Split_Status;
      Session_Status : Terminal.App.Sessions.Session_Status;
   begin
      Check_Owner (Table);
      if not Is_Open (Table, Status) then
         return;
      elsif Terminal.App.Splits.Count (Table.Splits) <= 1 then
         Status := Layout_Conflict;
         return;
      end if;
      From := Terminal.App.Splits.Active (Table.Splits);
      To :=
        (if From = Terminal.App.Splits.Count (Table.Splits)
         then 1 else From + 1);
      Table.Borrows.Move
        (Terminal.App.Sessions.Session_Index (From),
         Terminal.App.Sessions.Session_Index (To),
         Moved);
      if not Moved then
         Status := Runtime_In_Use;
         return;
      end if;
      Terminal.App.Splits.Activate (Table.Splits, To, Split_Status);
      Terminal.App.Sessions.Activate
        (Table.Sessions,
         Terminal.App.Sessions.Session_Index (To), Session_Status);
      if Split_Status /= Terminal.App.Splits.Ok
        or else Session_Status /= Terminal.App.Sessions.Ok
      then
         raise Program_Error with "moved pane could not be activated";
      end if;
      Status := Ok;
   end Move_Active_Pane;

   procedure Move_Pane_Divider
     (Table   : in out Runtime_Table;
      Layout  : Terminal.App.Splits.Pane_Layout;
      Divider : Terminal.App.Splits.Divider_Index;
      Row     : Positive;
      Col     : Positive;
      Status  : out Table_Status)
   is
      Next_Splits : Terminal.App.Splits.Split_State;
      Split_Status : Terminal.App.Splits.Split_Status;
   begin
      Check_Owner (Table);
      if not Is_Open (Table, Status) then
         return;
      end if;
      Next_Splits := Table.Splits;
      Terminal.App.Splits.Move_Divider
        (Next_Splits, Layout, Divider, Row, Col, Split_Status);
      if Split_Status = Terminal.App.Splits.Ok then
         Table.Splits := Next_Splits;
         Status := Ok;
      else
         Status := Invalid_Index;
      end if;
   end Move_Pane_Divider;

   procedure Set_Active_Tab_Label
     (Table  : in out Runtime_Table;
      Label  : String;
      Status : out Table_Status)
   is
      Tab_Status : Terminal.App.Tabs.Tab_Status;
   begin
      Check_Owner (Table);
      if not Is_Open (Table, Status) then
         return;
      end if;
      if Table.Borrows.Is_Closing then
         Status := Runtime_In_Use;
         return;
      end if;
      Terminal.App.Tabs.Set_Label
        (Table.Tabs,
         Terminal.App.Tabs.Active (Table.Tabs),
         Label,
         Tab_Status);
      Status := (if Tab_Status = Terminal.App.Tabs.Ok then Ok else Invalid_Index);
   end Set_Active_Tab_Label;

   procedure Activate
     (Table  : in out Runtime_Table;
      Index  : Terminal.App.Sessions.Session_Index;
      Status : out Table_Status)
   is
      Session_Status : Terminal.App.Sessions.Session_Status;
      Tab_Status : Terminal.App.Tabs.Tab_Status;
      Split_Status : Terminal.App.Splits.Split_Status;
      Next_Sessions : Terminal.App.Sessions.Session_Table;
      Next_Tabs : Terminal.App.Tabs.Tab_State;
      Next_Splits : Terminal.App.Splits.Split_State;
   begin
      Check_Owner (Table);
      if not Is_Open (Table, Status) then
         return;
      end if;
      if Table.Borrows.Is_Closing then
         Status := Runtime_In_Use;
         return;
      end if;
      Next_Sessions := Table.Sessions;
      Next_Tabs := Table.Tabs;
      Next_Splits := Table.Splits;
      Terminal.App.Sessions.Activate (Next_Sessions, Index, Session_Status);
      if Session_Status /= Terminal.App.Sessions.Ok then
         Status := Convert (Session_Status);
         return;
      end if;
      if Terminal.App.Tabs.Count (Next_Tabs) > 1 then
         Terminal.App.Tabs.Activate
           (Next_Tabs, Terminal.App.Tabs.Tab_Index (Index), Tab_Status);
         if Tab_Status /= Terminal.App.Tabs.Ok then
            Status := Invalid_Index;
            return;
         end if;
      elsif Terminal.App.Splits.Count (Next_Splits) > 1 then
         Terminal.App.Splits.Activate
           (Next_Splits, Terminal.App.Splits.Pane_Index (Index), Split_Status);
         if Split_Status /= Terminal.App.Splits.Ok then
            Status := Invalid_Index;
            return;
         end if;
      end if;
      Table.Sessions := Next_Sessions;
      Table.Tabs := Next_Tabs;
      Table.Splits := Next_Splits;
      Status := Ok;
   end Activate;

   function Count
     (Table : Runtime_Table) return Terminal.App.Sessions.Session_Count is
   begin
      Check_Owner (Table);
      return Terminal.App.Sessions.Count (Table.Sessions);
   end Count;

   function Active
     (Table : Runtime_Table) return Terminal.App.Sessions.Session_Index is
   begin
      Check_Owner (Table);
      Require_Open (Table);
      return Terminal.App.Sessions.Active (Table.Sessions);
   end Active;

   function Tabs
     (Table : Runtime_Table) return Terminal.App.Tabs.Tab_State is
   begin
      Check_Owner (Table);
      return Table.Tabs;
   end Tabs;

   function Splits
     (Table : Runtime_Table) return Terminal.App.Splits.Split_State is
   begin
      Check_Owner (Table);
      return Table.Splits;
   end Splits;

   function Active_Runtime
     (Table : aliased in out Runtime_Table) return Runtime_Borrow
   is
      Index : Terminal.App.Sessions.Session_Index;
   begin
      Check_Owner (Table);
      Require_Open (Table);
      Index := Terminal.App.Sessions.Active (Table.Sessions);
      return Result : Runtime_Borrow (Table'Access) do
         Table.Borrows.Acquire (Index, Result.Guard.Hold);
         Result.Item := Result.Guard.Hold.Item;
         if not Result.Guard.Hold.Active then
            if Result.Item = null then
               raise Program_Error with "active runtime is not available";
            else
               raise Runtime_Unavailable with "runtime borrow is unavailable";
            end if;
         end if;
      end return;
   end Active_Runtime;

   function Runtime_At
     (Table : aliased in out Runtime_Table;
      Index : Terminal.App.Sessions.Session_Index) return Runtime_Borrow
   is
   begin
      Check_Owner (Table);
      Require_Open (Table);
      return Result : Runtime_Borrow (Table'Access) do
         Table.Borrows.Acquire (Index, Result.Guard.Hold);
         Result.Item := Result.Guard.Hold.Item;
         if not Result.Guard.Hold.Active then
            if Result.Item = null then
               raise Program_Error with "runtime slot is not available";
            else
               raise Runtime_Unavailable with "runtime borrow is unavailable";
            end if;
         end if;
      end return;
   end Runtime_At;

   function Core
     (Borrow : Runtime_Borrow)
      return Terminal.App.Session_Runtime.Core_Borrow is
   begin
      Check_Owner (Borrow.Owner.all);
      if Borrow.Item = null then
         raise Program_Error with "runtime borrow is empty";
      end if;
      return Terminal.App.Session_Runtime.Core (Borrow.Item.all);
   end Core;

   function PTY_Queue
     (Borrow : Runtime_Borrow)
      return Terminal.App.Session_Runtime.PTY_Queue_Borrow is
   begin
      Check_Owner (Borrow.Owner.all);
      if Borrow.Item = null then
         raise Program_Error with "runtime borrow is empty";
      end if;
      return Terminal.App.Session_Runtime.PTY_Queue (Borrow.Item.all);
   end PTY_Queue;

   function State
     (Borrow : Runtime_Borrow)
      return Terminal.App.Session_Runtime.Runtime_Status is
   begin
      Check_Owner (Borrow.Owner.all);
      if Borrow.Item = null then
         raise Program_Error with "runtime borrow is empty";
      end if;
      return Terminal.App.Session_Runtime.State (Borrow.Item.all);
   end State;

   function Graphics_Stream_ID
     (Borrow : Runtime_Borrow) return Terminal.Core.Graphics_Stream_ID is
   begin
      Check_Owner (Borrow.Owner.all);
      if Borrow.Item = null then
         raise Program_Error with "runtime borrow is empty";
      end if;
      return Terminal.App.Session_Runtime.Graphics_Stream_ID (Borrow.Item.all);
   end Graphics_Stream_ID;

   function Has_Pending_Write (Borrow : Runtime_Borrow) return Boolean is
   begin
      Check_Owner (Borrow.Owner.all);
      if Borrow.Item = null then
         raise Program_Error with "runtime borrow is empty";
      end if;
      return Terminal.App.Session_Runtime.Has_Pending_Write (Borrow.Item.all);
   end Has_Pending_Write;

   procedure Write
     (Borrow : Runtime_Borrow;
      Chunk  : Terminal.App.Queues.Byte_Chunk;
      Status : out Terminal.App.PTY_Write.Write_All_Status) is
   begin
      Check_Owner (Borrow.Owner.all);
      if Borrow.Item = null then
         raise Program_Error with "runtime borrow is empty";
      end if;
      Terminal.App.Session_Runtime.Write (Borrow.Item.all, Chunk, Status);
   end Write;

   procedure Write_Paste
     (Borrow    : Runtime_Borrow;
      Text      : String;
      Bracketed : Boolean;
      Status    : out Terminal.App.PTY_Write.Write_All_Status) is
   begin
      Check_Owner (Borrow.Owner.all);
      if Borrow.Item = null then
         raise Program_Error with "runtime borrow is empty";
      end if;
      Terminal.App.Session_Runtime.Write_Paste
        (Borrow.Item.all, Text, Bracketed, Status);
   end Write_Paste;

   procedure With_Runtime
     (Borrow  : Runtime_Borrow;
      Process : not null access procedure
        (Item : in out Terminal.App.Session_Runtime.Runtime)) is
   begin
      Check_Owner (Borrow.Owner.all);
      if Borrow.Item = null then
         raise Program_Error with "runtime borrow is empty";
      end if;
      Process (Borrow.Item.all);
   end With_Runtime;

   procedure Poll_Output
     (Table        : in out Runtime_Table;
      Had_Output   : out Runtime_Output_Set;
      Feed_Status  : out Terminal.Core.Feed_Status;
      Write_Status : out Terminal.App.PTY_Write.Write_All_Status;
      Observer     : access procedure
        (Index : Terminal.App.Sessions.Session_Index;
         Chunk : Terminal.App.Queues.Byte_Chunk) := null)
   is
      Runtime_Feed   : Terminal.Core.Feed_Status;
      Runtime_Write  : Terminal.App.PTY_Write.Write_All_Status;
      Runtime_Output : Boolean;
      Item           : Runtime_Access;
   begin
      Check_Owner (Table);
      Had_Output := (others => False);
      Feed_Status := Terminal.Core.Ok;
      Write_Status := Terminal.App.PTY_Write.Ok;
      if not Table.Open then
         Feed_Status := Terminal.Core.Invalid_State;
         Write_Status := Terminal.App.PTY_Write.Session_Closed;
         return;
      end if;
      if Table.Borrows.Is_Closing then
         Feed_Status := Terminal.Core.Invalid_State;
         Write_Status := Terminal.App.PTY_Write.Session_Closed;
         return;
      end if;
      for I in 1 .. Count (Table) loop
         Item := Table.Borrows.Item_At (I);
         if Item /= null then
            declare
               procedure Forward (Chunk : Terminal.App.Queues.Byte_Chunk) is
               begin
                  if Observer /= null then
                     Observer
                       (Terminal.App.Sessions.Session_Index (I), Chunk);
                  end if;
               end Forward;
            begin
               Terminal.App.Session_Runtime.Poll_Output
                 (Item.all,
                  Runtime_Feed,
                  Runtime_Write,
                  Runtime_Output,
                  Forward'Access);
            end;
            Had_Output (I) := Runtime_Output;
            --  Deferred graphics input is resumed by event acknowledgement,
            --  outside the PTY queue.  Its parser status is therefore
            --  meaningful even when this runtime produced no new PTY chunk.
            Merge_Feed_Status (Runtime_Feed, Feed_Status);
            if Runtime_Write in
              Terminal.App.PTY_Write.Failed
                | Terminal.App.PTY_Write.Session_Closed
            then
               Write_Status := Runtime_Write;
            elsif Runtime_Write = Terminal.App.PTY_Write.Incomplete
              and then Write_Status = Terminal.App.PTY_Write.Ok
            then
               Write_Status := Runtime_Write;
            end if;
         end if;
      end loop;
   end Poll_Output;

   function Status_Label (Table : Runtime_Table) return String is
   begin
      Check_Owner (Table);
      if Table.Borrows.Is_Closing then
         return "Runtime table closing";
      end if;
      if Count (Table) = 0 then
         return "Runtime table inactive";
      else
         return
           "Runtime table sessions="
           & Terminal.Common.Status.Trimmed_Natural (Count (Table))
           & " active="
           & Terminal.Common.Status.Trimmed_Natural (Active (Table));
      end if;
   end Status_Label;

   procedure Close_All (Table : in out Runtime_Table) is
   begin
      Check_Owner (Table);
      Close_All_Internal (Table, Raise_Errors => True);
   end Close_All;

   overriding procedure Finalize (Table : in out Runtime_Table) is
   begin
      Close_All_Internal (Table, Raise_Errors => False);
      if Table.Borrows.Has_Items then
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Session_Table,
            "session table retained a live runtime");
      end if;
      if Table.Pending_Start /= null then
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Session_Table,
            "session table retained a failed startup runtime");
      end if;
   exception
      --  A finalizer is a last-resort cleanup path and must not mask the
      --  exception that caused its enclosing scope to unwind.
      when E : others =>
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Session_Table,
            E,
            "finalize session table");
   end Finalize;
end Terminal.App.Session_Table;

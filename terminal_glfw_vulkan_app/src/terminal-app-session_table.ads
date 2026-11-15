with Ada.Finalization;
with Ada.Task_Identification;
with Terminal.App.PTY_Write;
with Terminal.App.Queues;
with Terminal.App.Graphics_Profile;
with Terminal.App.Session_Runtime;
private with Terminal.App.Session_Runtime.Deferred_Cleanup;
with Terminal.App.Sessions;
with Terminal.App.Splits;
with Terminal.App.Tabs;
with Terminal.Core;

package Terminal.App.Session_Table is
   Max_Status_Label_Length : constant := 96;
   Runtime_Unavailable : exception;

   type Table_Status is
     (Ok,
      Not_Initialized,
      Start_Failed,
      At_Capacity,
      Last_Session,
      Invalid_Index,
      Layout_Conflict,
      Insufficient_Space,
      Runtime_In_Use);

   --  Runtime tables are task-confined owners.  Initialize claims the calling
   --  task; every public lookup and mutation thereafter rejects use from a
   --  different task.  Borrow protection governs nested lifetimes within that
   --  owner task and is not a substitute for cross-task table serialization.
   type Runtime_Table is limited private;
   type Runtime_Borrow (<>) is limited private;
   type Runtime_Output_Set is
     array (Terminal.App.Sessions.Session_Index) of Boolean;

   procedure Initialize
     (Table            : in out Runtime_Table;
      Rows             : Positive;
      Cols             : Positive;
      Scrollback_Limit : Natural;
      Status           : out Table_Status;
      Graphics_Profile : Terminal.Core.Graphics_Capability_Profile :=
        Terminal.App.Graphics_Profile.Core_Capabilities
          (Terminal.App.Graphics_Profile.Default));

   procedure New_Tab
     (Table            : in out Runtime_Table;
      Rows             : Positive;
      Cols             : Positive;
      Scrollback_Limit : Natural;
      Status           : out Table_Status);

   procedure Close_Tab
     (Table  : in out Runtime_Table;
      Status : out Table_Status);

   procedure Split_Pane
     (Table            : in out Runtime_Table;
      Command          : Terminal.App.Splits.Split_Command;
      Rows             : Positive;
      Cols             : Positive;
      Scrollback_Limit : Natural;
      Status           : out Table_Status);

   procedure Close_Pane
     (Table  : in out Runtime_Table;
      Status : out Table_Status);

   procedure Apply_Tab_Navigation
     (Table   : in out Runtime_Table;
      Command : Terminal.App.Tabs.Tab_Command;
      Status  : out Table_Status);

   procedure Reorder_Tab
     (Table  : in out Runtime_Table;
      From   : Terminal.App.Tabs.Tab_Index;
      To     : Terminal.App.Tabs.Tab_Index;
      Status : out Table_Status);

   procedure Apply_Pane_Navigation
     (Table   : in out Runtime_Table;
      Command : Terminal.App.Splits.Split_Command;
      Status  : out Table_Status);

   procedure Move_Pane_Divider
     (Table   : in out Runtime_Table;
      Layout  : Terminal.App.Splits.Pane_Layout;
      Divider : Terminal.App.Splits.Divider_Index;
      Row     : Positive;
      Col     : Positive;
      Status  : out Table_Status);

   procedure Set_Active_Tab_Label
     (Table  : in out Runtime_Table;
      Label  : String;
      Status : out Table_Status);
   procedure Move_Active_Pane
     (Table  : in out Runtime_Table;
      Status : out Table_Status);

   procedure Activate
     (Table  : in out Runtime_Table;
      Index  : Terminal.App.Sessions.Session_Index;
      Status : out Table_Status);

   function Count (Table : Runtime_Table) return Terminal.App.Sessions.Session_Count;
   function Active (Table : Runtime_Table) return Terminal.App.Sessions.Session_Index;
   function Tabs
     (Table : Runtime_Table) return Terminal.App.Tabs.Tab_State;
   function Splits
     (Table : Runtime_Table) return Terminal.App.Splits.Split_State;
   function Active_Runtime
     (Table : aliased in out Runtime_Table) return Runtime_Borrow;
   function Runtime_At
     (Table : aliased in out Runtime_Table;
      Index : Terminal.App.Sessions.Session_Index) return Runtime_Borrow;
   function Core
     (Borrow : Runtime_Borrow)
      return Terminal.App.Session_Runtime.Core_Borrow;
   function PTY_Queue
     (Borrow : Runtime_Borrow)
      return Terminal.App.Session_Runtime.PTY_Queue_Borrow;
   function State
     (Borrow : Runtime_Borrow)
      return Terminal.App.Session_Runtime.Runtime_Status;
   function Graphics_Stream_ID
     (Borrow : Runtime_Borrow) return Terminal.Core.Graphics_Stream_ID;
   function Has_Pending_Write (Borrow : Runtime_Borrow) return Boolean;
   procedure Write
     (Borrow : Runtime_Borrow;
      Chunk  : Terminal.App.Queues.Byte_Chunk;
      Status : out Terminal.App.PTY_Write.Write_All_Status);
   procedure Write_Paste
     (Borrow    : Runtime_Borrow;
      Text      : String;
      Bracketed : Boolean;
      Status    : out Terminal.App.PTY_Write.Write_All_Status);
   procedure With_Runtime
     (Borrow  : Runtime_Borrow;
      Process : not null access procedure
        (Item : in out Terminal.App.Session_Runtime.Runtime));
   procedure Poll_Output
     (Table        : in out Runtime_Table;
      Had_Output   : out Runtime_Output_Set;
      Feed_Status  : out Terminal.Core.Feed_Status;
      Write_Status : out Terminal.App.PTY_Write.Write_All_Status;
      Observer     : access procedure
        (Index : Terminal.App.Sessions.Session_Index;
         Chunk : Terminal.App.Queues.Byte_Chunk) := null);
   function Status_Label (Table : Runtime_Table) return String;

   procedure Close_All (Table : in out Runtime_Table);

private
   procedure Merge_Feed_Status
     (Candidate : Terminal.Core.Feed_Status;
      Aggregate : in out Terminal.Core.Feed_Status);
   function Quarantined_Runtime_Count return Natural;

   type Runtime_Access is access all Terminal.App.Session_Runtime.Runtime;
   type Runtime_Deallocator is access procedure (Item : in out Runtime_Access);
   type Runtime_Array is
     array (Terminal.App.Sessions.Session_Index) of Runtime_Access;

   type Runtime_Borrow_Entry is record
      Item  : Runtime_Access := null;
      Count : Natural := 0;
      Closing : Boolean := False;
   end record;
   type Runtime_Borrow_Entry_Array is
     array (Terminal.App.Sessions.Session_Index) of Runtime_Borrow_Entry;

   type Runtime_Borrow_Hold is limited record
      Item   : Runtime_Access := null;
      Active : Boolean := False;
   end record;

   protected type Runtime_Borrow_Registry is
      procedure Register
        (Index : Terminal.App.Sessions.Session_Index;
         Item  : in out Runtime_Access);
      function Item_At
        (Index : Terminal.App.Sessions.Session_Index) return Runtime_Access;
      procedure Acquire
        (Index   : Terminal.App.Sessions.Session_Index;
         Hold    : in out Runtime_Borrow_Hold);
      procedure Release (Item : Runtime_Access);
      procedure Begin_Remove
        (Index   : Terminal.App.Sessions.Session_Index;
         Item    : out Runtime_Access;
         Granted : out Boolean;
         Retrying : out Boolean);
      procedure Cancel_Remove
        (Token : Terminal.App.Sessions.Session_Index);
      procedure Move
        (From  : Terminal.App.Sessions.Session_Index;
         To    : Terminal.App.Sessions.Session_Index;
         Moved : out Boolean);
      procedure Complete_Remove
        (Token      : Terminal.App.Sessions.Session_Index;
         Shift_Left : Boolean;
         Item       : out Runtime_Access);
      procedure Begin_Close_All (Granted : out Boolean);
      procedure Complete_Close_All (Items : out Runtime_Array);
      procedure Finish_Close_All;
      procedure Restore_Close_All (Items : in out Runtime_Array);
      function Has_Items return Boolean;
      function Is_Closing return Boolean;
   private
      Entries : Runtime_Borrow_Entry_Array := (others => (others => <>));
      Closing_All : Boolean := False;
   end Runtime_Borrow_Registry;

   type Runtime_Table is new Ada.Finalization.Limited_Controlled with record
      Sessions : Terminal.App.Sessions.Session_Table;
      Tabs     : Terminal.App.Tabs.Tab_State;
      Splits   : Terminal.App.Splits.Split_State;
      Graphics_Profile : Terminal.Core.Graphics_Capability_Profile :=
        Terminal.App.Graphics_Profile.Core_Capabilities
          (Terminal.App.Graphics_Profile.Default);
      Last_Start : Terminal.App.Session_Runtime.Start_Status :=
        Terminal.App.Session_Runtime.Allocation_Failed;
      Owner_Task : Ada.Task_Identification.Task_Id :=
        Ada.Task_Identification.Null_Task_Id;
      --  A runtime whose startup failed can still own resources when teardown
      --  is temporarily unable to finish.  Keep that object under the table's
      --  ownership until a later operation or Close_All can retry cleanup.
      Pending_Start : Runtime_Access := null;
      Borrows : Runtime_Borrow_Registry;
      Open : Boolean := False;
   end record;

   procedure Close_All_Internal
     (Table        : in out Runtime_Table;
      Raise_Errors : Boolean;
      Deallocate   : Runtime_Deallocator := null);

   overriding procedure Finalize (Table : in out Runtime_Table);

   type Runtime_Borrow_Guard
     (Owner : not null access Runtime_Table) is
     new Ada.Finalization.Limited_Controlled with record
      Hold : Runtime_Borrow_Hold;
   end record;
   overriding procedure Finalize (Guard : in out Runtime_Borrow_Guard);

   type Runtime_Borrow
     (Owner : not null access Runtime_Table) is limited record
      Item  : Runtime_Access := null;
      Guard : Runtime_Borrow_Guard (Owner);
   end record;
end Terminal.App.Session_Table;

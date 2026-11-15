with Ada.Finalization;
with Ada.Real_Time;
with Ada.Strings.Unbounded;
with Terminal.App.PTY_Reader;
with Terminal.App.PTY_Write;
with Terminal.App.Queues;
with Terminal.App.Graphics_Profile;
with Terminal.Core;
with Terminal.PTY.Backend;

package Terminal.App.Session_Runtime is
   Max_Status_Label_Length : constant := 96;

   type Start_Status is
     (Ok,
      Core_Init_Failed,
      Spawn_Failed,
      Allocation_Failed,
      Cleanup_Failed);

   type Runtime_Status is
     (Inactive,
      Active,
      Exited,
      Cleanup_Pending,
      Closed);

   type Runtime is limited private;
   type Core_Borrow (<>) is limited private;
   type PTY_Queue_Borrow (<>) is limited private;

   procedure Start
     (R                : in out Runtime;
      Rows             : Positive;
      Cols             : Positive;
      Scrollback_Limit : Natural;
      Status           : out Start_Status;
      Graphics_Profile : Terminal.Core.Graphics_Capability_Profile :=
        Terminal.App.Graphics_Profile.Core_Capabilities
          (Terminal.App.Graphics_Profile.Default));

   procedure Poll_Output
     (R      : in out Runtime;
      Status : out Terminal.Core.Feed_Status);

   procedure Poll_Output
     (R            : in out Runtime;
      Status       : out Terminal.Core.Feed_Status;
      Write_Status : out Terminal.App.PTY_Write.Write_All_Status;
      Had_Output   : out Boolean;
      Observer     : access procedure
        (Chunk : Terminal.App.Queues.Byte_Chunk) := null);

   procedure Write
     (R      : in out Runtime;
      Chunk  : Terminal.App.Queues.Byte_Chunk;
      Status : out Terminal.App.PTY_Write.Write_All_Status);
   procedure Write_Paste
     (R         : in out Runtime;
      Text      : String;
      Bracketed : Boolean;
      Status    : out Terminal.App.PTY_Write.Write_All_Status);
   procedure Flush_Write
     (R      : in out Runtime;
      Status : out Terminal.App.PTY_Write.Write_All_Status);
   function Has_Pending_Write (R : Runtime) return Boolean;

   procedure Resize
     (R          : in out Runtime;
      Rows       : Positive;
      Cols       : Positive;
      Core_Status : out Terminal.Core.Resize_Status;
      PTY_Status  : out Terminal.PTY.Backend.Resize_Status);

   procedure Close (R : in out Runtime);

   function State (R : Runtime) return Runtime_Status;
   function Graphics_Stream_ID
     (R : Runtime) return Terminal.Core.Graphics_Stream_ID;
   function Core (R : aliased in out Runtime) return Core_Borrow;
   procedure With_Core
     (Borrow  : Core_Borrow;
      Process : not null access procedure
        (Item : in out Terminal.Core.Terminal));
   function Modes (Borrow : Core_Borrow) return Terminal.Core.Mode_Snapshot;
   function PTY_Queue
     (R : aliased in out Runtime) return PTY_Queue_Borrow;
   procedure With_PTY_Queue
     (Borrow  : PTY_Queue_Borrow;
      Process : not null access procedure
        (Item : in out Terminal.App.Queues.PTY_Output_Queue));
   function Is_Alive (R : in out Runtime) return Boolean;
   function Status_Label (R : Runtime) return String;

private
   type Paste_Builder_Access is access procedure
     (Pending   : out Ada.Strings.Unbounded.Unbounded_String;
      Text      : String;
      Bracketed : Boolean);

   procedure Write_Paste_With_Builder
     (R         : in out Runtime;
      Text      : String;
      Bracketed : Boolean;
      Status    : out Terminal.App.PTY_Write.Write_All_Status;
      Builder   : not null Paste_Builder_Access);

   type Core_Access is access all Terminal.Core.Terminal;
   type Session_Access is access all Terminal.PTY.Backend.Session;
   type PTY_Queue_Access is access all Terminal.App.Queues.PTY_Output_Queue;
   type Reader_Access is access Terminal.App.PTY_Reader.Reader;

   type Runtime_Access is access all Runtime;
   type Deferred_Resource_Set;
   type Deferred_Resource_Set_Access is access Deferred_Resource_Set;
   function Has_Direct_Resources (R : Runtime) return Boolean;
   function Has_Resources (R : Runtime) return Boolean;
   procedure Retain_Deferred_Runtime
     (Item     : in out Runtime_Access;
      Accepted : out Boolean);
   procedure Stop_Deferred_Owner_Admission;
   procedure Drain_Deferred_Owners
     (Timeout_Milliseconds : Natural;
      Complete             : out Boolean);
   generic
      with procedure Release_Runtime (Item : in out Runtime_Access);
      with procedure Retry_Resources
        (Item        : in out Deferred_Resource_Set_Access;
         Retry_After : out Ada.Real_Time.Time);
   procedure Drain_Deferred_Owners_With
     (Timeout_Milliseconds : Natural;
      Complete             : out Boolean);
   function Deferred_Runtime_Owner_Count return Natural;
   function Deferred_Runtime_Retry_Delayed return Boolean;

   type Deferred_Retry_State is record
      Failure_Reported : Boolean := False;
      Delay_Milliseconds : Natural := 0;
      Retry_After : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
   end record;
   function Deferred_Retry_Due (State : Deferred_Retry_State) return Boolean;
   procedure Schedule_Deferred_Retry (State : in out Deferred_Retry_State);
   type Deferred_Resource_Failures is record
      Reader  : Boolean := False;
      Session : Boolean := False;
      Queue   : Boolean := False;
      Core    : Boolean := False;
   end record;
   type Deferred_Resource_Set is record
      T      : Core_Access := null;
      S      : Session_Access := null;
      Q      : PTY_Queue_Access := null;
      Reader : Reader_Access := null;
      Next   : Deferred_Resource_Set_Access := null;
      Retry  : Deferred_Retry_State;
      Failures : Deferred_Resource_Failures;
   end record;
   procedure Retry_Deferred_Resources
     (Item        : in out Deferred_Resource_Set_Access;
      Retry_After : out Ada.Real_Time.Time);
   procedure Retain_Deferred_Resources
     (Item     : in out Deferred_Resource_Set_Access;
      Accepted : out Boolean);
   function Deferred_Resource_Owner_Count return Natural;

   type Borrow_Hold is limited record
      Active : Boolean := False;
   end record;

   protected type Resource_Leases is
      procedure Open;
      procedure Begin_Close (Core_Busy, Queue_Busy : out Boolean);
      procedure Acquire_Core (Hold : in out Borrow_Hold);
      procedure Release_Core;
      procedure Acquire_Queue (Hold : in out Borrow_Hold);
      procedure Release_Queue;
   private
      Closing       : Boolean := True;
      Core_Borrows  : Natural := 0;
      Queue_Borrows : Natural := 0;
   end Resource_Leases;
   type Runtime is new Ada.Finalization.Limited_Controlled with record
      Current_State : Runtime_Status := Inactive;
      T             : Core_Access := null;
      S             : Session_Access := null;
      Q             : PTY_Queue_Access := null;
      Reader        : Reader_Access := null;
      Stream_ID     : Terminal.Core.Graphics_Stream_ID := 0;
      Rows          : Positive := 1;
      Cols          : Positive := 1;
      Size_Known    : Boolean := False;
      Last_Start    : Start_Status := Allocation_Failed;
      Last_Spawn    : Terminal.PTY.Backend.Spawn_Status :=
        Terminal.PTY.Backend.Fork_Failed;
      Pending_Write : Terminal.App.Queues.Byte_Chunk := (others => <>);
      Pending_Write_Offset : Positive := 1;
      Pending_Write_Data : Ada.Strings.Unbounded.Unbounded_String;
      Pending_Write_Data_Offset : Positive := 1;
      Leases        : Resource_Leases;
      Cleanup_Ticket : Deferred_Resource_Set_Access := null;
      Deferred_Next  : Runtime_Access := null;
      Deferred_Admitted : Boolean := False;
      Cleanup_Producer_Registered : Boolean := False;
      Deferred_Retry : Deferred_Retry_State;
   end record;
   overriding procedure Initialize (R : in out Runtime);
   overriding procedure Finalize (R : in out Runtime);

   type Core_Borrow_Guard (Owner : not null access Runtime) is
     new Ada.Finalization.Limited_Controlled with record
      Hold : Borrow_Hold;
   end record;
   overriding procedure Finalize (Guard : in out Core_Borrow_Guard);
   type Core_Borrow (Owner : not null access Runtime) is limited record
      Item  : Core_Access := null;
      Guard : Core_Borrow_Guard (Owner);
   end record;

   type PTY_Queue_Borrow_Guard (Owner : not null access Runtime) is
     new Ada.Finalization.Limited_Controlled with record
      Hold : Borrow_Hold;
   end record;
   overriding procedure Finalize (Guard : in out PTY_Queue_Borrow_Guard);
   type PTY_Queue_Borrow (Owner : not null access Runtime) is limited record
      Item  : PTY_Queue_Access := null;
      Guard : PTY_Queue_Borrow_Guard (Owner);
   end record;
end Terminal.App.Session_Runtime;

with Ada.Unchecked_Deallocation;
with Ada.Strings.Unbounded;
with Ada.Real_Time;
with Ada.Finalization;
with Terminal.App.Cleanup_Diagnostics;
with Terminal.App.Graphics_Profile;
with Terminal.Common.Bytes;
with Terminal.Common.Status;
package body Terminal.App.Session_Runtime is
   package Unbounded renames Ada.Strings.Unbounded;
   use type Ada.Real_Time.Time;
   use type Terminal.App.PTY_Write.Write_All_Status;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.Core.Resize_Status;
   use type Terminal.Core.Graphics_Stream_ID;
   use type Terminal.PTY.Backend.Resize_Status;
   use type Terminal.PTY.Backend.Spawn_Status;

   procedure Free_Core is new Ada.Unchecked_Deallocation
     (Terminal.Core.Terminal,
      Core_Access);
   procedure Free_Session is new Ada.Unchecked_Deallocation
     (Terminal.PTY.Backend.Session,
      Session_Access);
   procedure Free_Queue is new Ada.Unchecked_Deallocation
     (Terminal.App.Queues.PTY_Output_Queue,
      PTY_Queue_Access);
   procedure Free_Reader is new Ada.Unchecked_Deallocation
     (Terminal.App.PTY_Reader.Reader,
      Reader_Access);
   procedure Free_Resource_Set is new Ada.Unchecked_Deallocation
     (Deferred_Resource_Set,
      Deferred_Resource_Set_Access);
   procedure Free_Deferred_Runtime is new Ada.Unchecked_Deallocation
     (Runtime,
      Runtime_Access);

   function Empty (Item : Deferred_Resource_Set) return Boolean is
     (Item.T = null and then Item.S = null and then Item.Q = null
      and then Item.Reader = null);

   Max_Deferred_Backoff_Milliseconds : constant := 1_000;

   function Deferred_Retry_Due (State : Deferred_Retry_State) return Boolean is
     (Ada.Real_Time.Clock >= State.Retry_After);

   procedure Schedule_Deferred_Retry (State : in out Deferred_Retry_State) is
      use type Ada.Real_Time.Time;
   begin
      State.Delay_Milliseconds :=
        (if State.Delay_Milliseconds = 0
         then 10
         elsif State.Delay_Milliseconds
           >= Max_Deferred_Backoff_Milliseconds / 2
         then Max_Deferred_Backoff_Milliseconds
         else State.Delay_Milliseconds * 2);
      State.Retry_After :=
        Ada.Real_Time.Clock
        + Ada.Real_Time.Milliseconds (State.Delay_Milliseconds);
   end Schedule_Deferred_Retry;

   type Deferred_Runtime_Lease is
     new Ada.Finalization.Limited_Controlled with record
      Item   : Runtime_Access := null;
      Active : Boolean := False;
   end record;
   overriding procedure Finalize (Lease : in out Deferred_Runtime_Lease);

   type Deferred_Resource_Lease is
     new Ada.Finalization.Limited_Controlled with record
      Item   : Deferred_Resource_Set_Access := null;
      Active : Boolean := False;
   end record;
   overriding procedure Finalize (Lease : in out Deferred_Resource_Lease);

   type Deferred_Drain_Guard is
     new Ada.Finalization.Limited_Controlled with record
      Active : Boolean := False;
   end record;
   overriding procedure Finalize (Guard : in out Deferred_Drain_Guard);

   protected Deferred_Owners is
      procedure Admit_Resources
        (Item     : in out Deferred_Resource_Set_Access;
         Accepted : out Boolean);
      procedure Retain_Resources (Item : in out Deferred_Resource_Set_Access);
      procedure Take_Resources (Lease : in out Deferred_Resource_Lease);
      procedure Admit_Runtime
        (Item     : in out Runtime_Access;
         Accepted : out Boolean);
      procedure Retain_Runtime (Item : in out Runtime_Access);
      procedure Take_Runtime (Lease : in out Deferred_Runtime_Lease);
      procedure Try_Begin_Drain (Acquired : out Boolean);
      procedure Finish_Owner;
      procedure End_Drain;
      procedure Register_Producer (Registered : out Boolean);
      procedure Finish_Producer;
      procedure Stop_Accepting;
      function Complete return Boolean;
      function Resource_Count return Natural;
      function Runtime_Count return Natural;
      function Runtime_Retry_Delayed return Boolean;
   private
      Resource_Head : Deferred_Resource_Set_Access := null;
      Resource_Tail : Deferred_Resource_Set_Access := null;
      Runtime_Head  : Runtime_Access := null;
      Runtime_Tail  : Runtime_Access := null;
      Resources     : Natural := 0;
      Runtimes      : Natural := 0;
      In_Flight     : Natural := 0;
      Producers     : Natural := 0;
      Draining      : Boolean := False;
      Accepting     : Boolean := True;
   end Deferred_Owners;

   protected body Deferred_Owners is separate;

   procedure Retry_Deferred_Resources
     (Item        : in out Deferred_Resource_Set_Access;
      Retry_After : out Ada.Real_Time.Time) is separate;

   procedure Finish_Lease (Lease : in out Deferred_Runtime_Lease) is
   begin
      if Lease.Active then
         Deferred_Owners.Finish_Owner;
         Lease.Active := False;
         Lease.Item := null;
      end if;
   end Finish_Lease;

   overriding procedure Finalize
     (Lease : in out Deferred_Runtime_Lease) is
   begin
      if Lease.Active then
         if Lease.Item /= null then
            Deferred_Owners.Retain_Runtime (Lease.Item);
         end if;
         Finish_Lease (Lease);
      end if;
   end Finalize;

   procedure Finish_Lease (Lease : in out Deferred_Resource_Lease) is
   begin
      if Lease.Active then
         Deferred_Owners.Finish_Owner;
         Lease.Active := False;
         Lease.Item := null;
      end if;
   end Finish_Lease;

   overriding procedure Finalize
     (Lease : in out Deferred_Resource_Lease) is
   begin
      if Lease.Active then
         if Lease.Item /= null then
            Deferred_Owners.Retain_Resources (Lease.Item);
         end if;
         Finish_Lease (Lease);
      end if;
   end Finalize;

   procedure Finish_Drain (Guard : in out Deferred_Drain_Guard) is
   begin
      if Guard.Active then
         Deferred_Owners.End_Drain;
         Guard.Active := False;
      end if;
   end Finish_Drain;

   overriding procedure Finalize (Guard : in out Deferred_Drain_Guard) is
   begin
      Finish_Drain (Guard);
   end Finalize;

   procedure Retain_Deferred_Runtime
     (Item     : in out Runtime_Access;
      Accepted : out Boolean)
   is
      Was_Admitted : Boolean := False;
   begin
      if Item /= null then
         Was_Admitted := Item.Deferred_Admitted;
         Item.Deferred_Admitted := True;
      end if;
      begin
         Deferred_Owners.Admit_Runtime (Item, Accepted);
      exception
         when others =>
            if Item /= null then
               Item.Deferred_Admitted := Was_Admitted;
            end if;
            raise;
      end;
      if not Accepted and then Item /= null then
         Item.Deferred_Admitted := Was_Admitted;
      end if;
   end Retain_Deferred_Runtime;

   procedure Retain_Deferred_Resources
     (Item     : in out Deferred_Resource_Set_Access;
      Accepted : out Boolean) is
   begin
      Deferred_Owners.Admit_Resources (Item, Accepted);
   end Retain_Deferred_Resources;

   procedure Stop_Deferred_Owner_Admission is
   begin
      Deferred_Owners.Stop_Accepting;
   end Stop_Deferred_Owner_Admission;

   function Deferred_Runtime_Owner_Count return Natural is
     (Deferred_Owners.Runtime_Count);

   function Deferred_Runtime_Retry_Delayed return Boolean is
     (Deferred_Owners.Runtime_Retry_Delayed);

   function Deferred_Resource_Owner_Count return Natural is
     (Deferred_Owners.Resource_Count);

   overriding procedure Initialize (R : in out Runtime) is
   begin
      Deferred_Owners.Register_Producer
        (R.Cleanup_Producer_Registered);
   end Initialize;

   procedure Finish_Cleanup_Producer (R : in out Runtime) is
   begin
      if R.Cleanup_Producer_Registered then
         R.Cleanup_Producer_Registered := False;
         Deferred_Owners.Finish_Producer;
      end if;
   exception
      when E : others =>
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Session_Runtime,
            E,
            "finish session cleanup producer");
   end Finish_Cleanup_Producer;

   protected Graphics_Stream_IDs is
      procedure Allocate (Result : out Terminal.Core.Graphics_Stream_ID);
   private
      Next_ID : Terminal.Core.Graphics_Stream_ID := 1;
   end Graphics_Stream_IDs;

   protected body Graphics_Stream_IDs is
      procedure Allocate (Result : out Terminal.Core.Graphics_Stream_ID) is
      begin
         Result := Next_ID;
         Next_ID := Next_ID + 1;
         if Next_ID = 0 then
            Next_ID := 1;
         end if;
      end Allocate;
   end Graphics_Stream_IDs;

   protected body Resource_Leases is
      procedure Open is
      begin
         if Core_Borrows /= 0 or else Queue_Borrows /= 0 then
            raise Program_Error with "cannot reopen borrowed session resources";
         end if;
         Closing := False;
      end Open;

      procedure Begin_Close (Core_Busy, Queue_Busy : out Boolean) is
      begin
         Closing := True;
         Core_Busy := Core_Borrows /= 0;
         Queue_Busy := Queue_Borrows /= 0;
      end Begin_Close;

      procedure Acquire_Core (Hold : in out Borrow_Hold) is
      begin
         Hold.Active := not Closing and then Core_Borrows < Natural'Last;
         if Hold.Active then
            Core_Borrows := Core_Borrows + 1;
         end if;
      end Acquire_Core;

      procedure Release_Core is
      begin
         if Core_Borrows = 0 then
            raise Program_Error with "core borrow count underflow";
         end if;
         Core_Borrows := Core_Borrows - 1;
      end Release_Core;

      procedure Acquire_Queue (Hold : in out Borrow_Hold) is
      begin
         Hold.Active := not Closing and then Queue_Borrows < Natural'Last;
         if Hold.Active then
            Queue_Borrows := Queue_Borrows + 1;
         end if;
      end Acquire_Queue;

      procedure Release_Queue is
      begin
         if Queue_Borrows = 0 then
            raise Program_Error with "PTY queue borrow count underflow";
         end if;
         Queue_Borrows := Queue_Borrows - 1;
      end Release_Queue;
   end Resource_Leases;

   overriding procedure Finalize (Guard : in out Core_Borrow_Guard) is
   begin
      if Guard.Hold.Active then
         Guard.Owner.Leases.Release_Core;
         Guard.Hold.Active := False;
      end if;
   exception
      when E : others =>
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Session_Runtime,
            E,
            "release terminal core borrow");
   end Finalize;

   overriding procedure Finalize (Guard : in out PTY_Queue_Borrow_Guard) is
   begin
      if Guard.Hold.Active then
         Guard.Owner.Leases.Release_Queue;
         Guard.Hold.Active := False;
      end if;
   exception
      when E : others =>
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Session_Runtime,
            E,
            "release PTY queue borrow");
   end Finalize;

   function Has_Direct_Resources (R : Runtime) return Boolean is
     (R.T /= null or else R.S /= null or else R.Q /= null
      or else R.Reader /= null);

   function Has_Resources (R : Runtime) return Boolean is
     (Has_Direct_Resources (R)
      or else
        (R.Cleanup_Ticket /= null
         and then not Empty (R.Cleanup_Ticket.all)));

   procedure Stop_Reader
     (R       : in out Runtime;
      Success : out Boolean)
   is
   begin
      Success := True;
      if R.Reader /= null then
         begin
            R.Reader.Stop;
         exception
            when Tasking_Error =>
               null;
            when E : others =>
               Success := False;
               Terminal.App.Cleanup_Diagnostics.Note_Failure
                 (Terminal.App.Cleanup_Diagnostics.Session_Runtime,
                  E,
                  "stop PTY reader task");
               return;
         end;
         begin
            Free_Reader (R.Reader);
         exception
            when E : others =>
               Success := False;
               Terminal.App.Cleanup_Diagnostics.Note_Failure
                 (Terminal.App.Cleanup_Diagnostics.Session_Runtime,
                  E,
                  "release PTY reader task");
         end;
      end if;
   end Stop_Reader;

   procedure Close (R : in out Runtime) is
      Queue_Closed    : Boolean := True;
      Session_Closed  : Boolean := True;
      Reader_Stopped  : Boolean := True;
      Core_Busy       : Boolean;
      Queue_Busy      : Boolean;
   begin
      R.Leases.Begin_Close (Core_Busy, Queue_Busy);
      if R.Q /= null then
         begin
            R.Q.Shut_Down;
         exception
            when E : others =>
               Queue_Closed := False;
               Terminal.App.Cleanup_Diagnostics.Note_Failure
                 (Terminal.App.Cleanup_Diagnostics.Session_Runtime,
                  E,
                  "shut down session input queue");
         end;
      end if;
      --  Shut_Down releases a reader blocked on a full queue. Stop_Reader then
      --  joins the task, so no backend operation can overlap session teardown.
      Stop_Reader (R, Reader_Stopped);
      if R.S /= null and then Reader_Stopped then
         begin
            Terminal.PTY.Backend.Close (R.S.all);
         exception
            when E : others =>
               Session_Closed := False;
               Terminal.App.Cleanup_Diagnostics.Note_Failure
                 (Terminal.App.Cleanup_Diagnostics.Session_Runtime,
                  E,
                  "close PTY session");
         end;
      elsif R.S /= null then
         Session_Closed := False;
      end if;
      --  Reader carries an access discriminant designating the session. Retain
      --  the session object until the task has definitely stopped and released
      --  that discriminant, regardless of whether backend close succeeded.
      if R.S /= null and then Session_Closed and then Reader_Stopped then
         begin
            Free_Session (R.S);
         exception
            when E : others =>
               Session_Closed := False;
               Terminal.App.Cleanup_Diagnostics.Note_Failure
                 (Terminal.App.Cleanup_Diagnostics.Session_Runtime,
                  E,
                  "release PTY session");
         end;
      end if;
      if R.Q /= null
        and then Queue_Closed
        and then Reader_Stopped
        and then not Queue_Busy
      then
         begin
            Free_Queue (R.Q);
         exception
            when E : others =>
               Queue_Closed := False;
               Terminal.App.Cleanup_Diagnostics.Note_Failure
                 (Terminal.App.Cleanup_Diagnostics.Session_Runtime,
                  E,
                  "release session input queue");
         end;
      end if;
      if R.T /= null and then not Core_Busy then
         begin
            --  Unchecked_Deallocation finalizes a controlled designated
            --  object.  Let it be the single owner of terminal finalization.
            Free_Core (R.T);
         exception
            when E : others =>
               Terminal.App.Cleanup_Diagnostics.Note_Failure
                 (Terminal.App.Cleanup_Diagnostics.Session_Runtime,
                  E,
                  "release terminal core");
         end;
      end if;
      if R.Q /= null and then Queue_Busy then
         Queue_Closed := False;
      end if;
      R.Size_Known := False;
      R.Pending_Write := (others => <>);
      R.Pending_Write_Offset := 1;
      Unbounded.Set_Unbounded_String (R.Pending_Write_Data, "");
      R.Pending_Write_Data_Offset := 1;
      R.Current_State :=
        (if Has_Resources (R) then Cleanup_Pending else Closed);
   end Close;

   procedure Force_Finalize_Resources (R : in out Runtime) is separate;

   procedure Drain_Deferred_Owners_With
     (Timeout_Milliseconds : Natural;
      Complete             : out Boolean) is separate;

   procedure Release_Deferred_Runtime (Item : in out Runtime_Access) is
   begin
      if Item /= null
        and then
          (Item.Current_State not in Inactive | Closed
           or else Has_Direct_Resources (Item.all))
      then
         raise Program_Error with
           "deferred runtime release cannot own live resources";
      end if;
      if Item /= null
        and then Item.Cleanup_Ticket /= null
        and then not Empty (Item.Cleanup_Ticket.all)
      then
         --  The runtime was already admitted, so its subordinate ticket is
         --  part of the same ownership chain and does not reopen admission.
         Deferred_Owners.Retain_Resources (Item.Cleanup_Ticket);
      end if;
      Free_Deferred_Runtime (Item);
   end Release_Deferred_Runtime;

   procedure Drain_Default is new Drain_Deferred_Owners_With
     (Release_Runtime => Release_Deferred_Runtime,
      Retry_Resources => Retry_Deferred_Resources);

   procedure Drain_Deferred_Owners
     (Timeout_Milliseconds : Natural;
      Complete             : out Boolean) is
   begin
      Drain_Default (Timeout_Milliseconds, Complete);
   end Drain_Deferred_Owners;

   overriding procedure Finalize (R : in out Runtime) is
   begin
      if Has_Resources (R) then
         begin
            Close (R);
         exception
            when E : others =>
               Terminal.App.Cleanup_Diagnostics.Note_Failure
                 (Terminal.App.Cleanup_Diagnostics.Session_Runtime,
                  E,
                  "close session runtime during finalization");
         end;
         if Has_Resources (R) then
            Force_Finalize_Resources (R);
         end if;
      end if;
      if R.Cleanup_Ticket /= null
        and then Empty (R.Cleanup_Ticket.all)
      then
         Free_Resource_Set (R.Cleanup_Ticket);
      end if;
      if Has_Resources (R) then
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Session_Runtime,
            "session runtime cleanup remained pending");
      end if;
      Finish_Cleanup_Producer (R);
   exception
      --  Finalization must never replace an active exception during scope
      --  unwinding.  Explicit Close leaves Cleanup_Pending observable to
      --  callers that need to report an incomplete teardown.
      when E : others =>
         Finish_Cleanup_Producer (R);
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Session_Runtime,
            E,
            "finalize session runtime");
   end Finalize;

   procedure Start
     (R                : in out Runtime;
      Rows             : Positive;
      Cols             : Positive;
      Scrollback_Limit : Natural;
      Status           : out Start_Status;
      Graphics_Profile : Terminal.Core.Graphics_Capability_Profile :=
        Terminal.App.Graphics_Profile.Core_Capabilities
          (Terminal.App.Graphics_Profile.Default))
   is
      Core_Status : Terminal.Core.Initialize_Status;
      Spawn_Status : Terminal.PTY.Backend.Spawn_Status;
   begin
      if not R.Cleanup_Producer_Registered then
         Status := Cleanup_Failed;
         R.Last_Start := Status;
         return;
      end if;
      if Has_Resources (R) then
         Close (R);
      end if;

      if Has_Resources (R) then
         R.Current_State := Cleanup_Pending;
         Status := Cleanup_Failed;
         R.Last_Start := Status;
         return;
      end if;

      if R.Cleanup_Ticket = null then
         R.Cleanup_Ticket := new Deferred_Resource_Set;
      end if;

      R.Leases.Open;

      R.T := new Terminal.Core.Terminal;
      R.S := new Terminal.PTY.Backend.Session;
      R.Q := new Terminal.App.Queues.PTY_Output_Queue;

      Terminal.Core.Initialize
        (R.T.all, Rows, Cols, Scrollback_Limit, Core_Status);
      if Core_Status /= Terminal.Core.Ok then
         Status := Core_Init_Failed;
         R.Last_Start := Status;
         Close (R);
         return;
      end if;

      Terminal.Core.Set_Graphics_Capabilities
        (R.T.all, Graphics_Profile);
      Graphics_Stream_IDs.Allocate (R.Stream_ID);
      Terminal.Core.Set_Graphics_Stream_ID (R.T.all, R.Stream_ID);

      Terminal.PTY.Backend.Spawn_Default_Shell
        (R.S.all,
         Rows,
         Cols,
         Spawn_Status,
         Terminal.App.Graphics_Feature_Report (Graphics_Profile));
      R.Last_Spawn := Spawn_Status;
      if Spawn_Status /= Terminal.PTY.Backend.Ok then
         Status := Spawn_Failed;
         R.Last_Start := Status;
         Close (R);
         return;
      end if;

      R.Reader :=
        new Terminal.App.PTY_Reader.Reader
          (R.S.all'Unchecked_Access, R.Q.all'Unchecked_Access);
      R.Rows := Rows;
      R.Cols := Cols;
      R.Size_Known := True;
      R.Pending_Write := (others => <>);
      R.Pending_Write_Offset := 1;
      Unbounded.Set_Unbounded_String (R.Pending_Write_Data, "");
      R.Pending_Write_Data_Offset := 1;
      R.Current_State := Active;
      Status := Ok;
      R.Last_Start := Status;
   exception
      when Storage_Error =>
         Status := Allocation_Failed;
         R.Last_Start := Status;
         Close (R);
      when others =>
         --  Backend and task creation calls are not permitted to strand
         --  partially initialized resources in the owning runtime table.
         Close (R);
         raise;
   end Start;

   procedure Poll_Output
     (R      : in out Runtime;
      Status : out Terminal.Core.Feed_Status)
   is
      Write_Status : Terminal.App.PTY_Write.Write_All_Status;
      Had_Output   : Boolean;
   begin
      Poll_Output (R, Status, Write_Status, Had_Output, null);
   end Poll_Output;

   procedure Poll_Output
     (R            : in out Runtime;
      Status       : out Terminal.Core.Feed_Status;
      Write_Status : out Terminal.App.PTY_Write.Write_All_Status;
      Had_Output   : out Boolean;
      Observer     : access procedure
        (Chunk : Terminal.App.Queues.Byte_Chunk) := null)
   is
      Chunk : Terminal.App.Queues.Byte_Chunk;
      Has_Chunk : Boolean;
      Feed : Terminal.Core.Feed_Status := Terminal.Core.Ok;
   begin
      Status := Terminal.Core.Ok;
      Write_Status := Terminal.App.PTY_Write.Ok;
      Had_Output := False;
      if R.Current_State = Exited then
         return;
      elsif R.Current_State /= Active or else R.T = null or else R.Q = null then
         Status := Terminal.Core.Invalid_State;
         return;
      end if;

      Feed := Terminal.Core.Take_Deferred_Feed_Status (R.T.all);
      if Feed_Rank (Feed) > Feed_Rank (Status) then
         Status := Feed;
      end if;

      Flush_Write (R, Write_Status);
      if Write_Status in
        Terminal.App.PTY_Write.Failed | Terminal.App.PTY_Write.Session_Closed
      then
         return;
      end if;

      loop
         R.Q.Pop (Chunk, Has_Chunk);
         exit when not Has_Chunk;
         if Chunk.Length > 0 then
            Had_Output := True;
            if Observer /= null then Observer (Chunk); end if;
            Terminal.Core.Feed (R.T.all, Chunk.Data (1 .. Chunk.Length), Feed);
            if Feed_Rank (Feed) > Feed_Rank (Status) then
               Status := Feed;
            end if;
         end if;
      end loop;

      Feed := Terminal.Core.Take_Deferred_Feed_Status (R.T.all);
      if Feed_Rank (Feed) > Feed_Rank (Status) then
         Status := Feed;
      end if;

      while not Has_Pending_Write (R)
        and then Terminal.Core.Pending_Response_Length (R.T.all) > 0
      loop
         Chunk := (others => <>);
         Terminal.Core.Read_Response (R.T.all, Chunk.Data, Chunk.Length);
         exit when Chunk.Length = 0;
         Write (R, Chunk, Write_Status);
         exit when Write_Status /= Terminal.App.PTY_Write.Ok;
      end loop;

      if R.Reader /= null and then R.Reader.all'Terminated then
         R.Current_State := Exited;
      end if;
   end Poll_Output;

   procedure Write
     (R      : in out Runtime;
      Chunk  : Terminal.App.Queues.Byte_Chunk;
      Status : out Terminal.App.PTY_Write.Write_All_Status)
   is
   begin
      if R.Current_State /= Active or else R.S = null then
         Status := Terminal.App.PTY_Write.Session_Closed;
      elsif Has_Pending_Write (R) then
         Status := Terminal.App.PTY_Write.Incomplete;
      else
         if Chunk.Length > 0 then
            declare
               Text : String (1 .. Chunk.Length);
            begin
               for I in Text'Range loop
                  Text (I) := Character'Val (Natural (Chunk.Data (I)));
               end loop;
               Unbounded.Set_Unbounded_String (R.Pending_Write_Data, Text);
            end;
         end if;
         R.Pending_Write_Data_Offset := 1;
         Flush_Write (R, Status);
      end if;
   end Write;

   procedure Build_Paste
     (Pending   : out Unbounded.Unbounded_String;
      Text      : String;
      Bracketed : Boolean)
   is
      Opening : constant String := ASCII.ESC & "[200~";
      Closing : constant String := ASCII.ESC & "[201~";
   begin
      Unbounded.Set_Unbounded_String
        (Pending, (if Bracketed then Opening else ""));
      Unbounded.Append (Pending, Text);
      if Bracketed then
         Unbounded.Append (Pending, Closing);
      end if;
   end Build_Paste;

   procedure Write_Paste_With_Builder
     (R         : in out Runtime;
      Text      : String;
      Bracketed : Boolean;
      Status    : out Terminal.App.PTY_Write.Write_All_Status;
      Builder   : not null Paste_Builder_Access)
   is
   begin
      if R.Current_State /= Active or else R.S = null then
         Status := Terminal.App.PTY_Write.Session_Closed;
      elsif Has_Pending_Write (R) then
         Status := Terminal.App.PTY_Write.Incomplete;
      else
         declare
            Pending : Unbounded.Unbounded_String;
         begin
            Builder (Pending, Text, Bracketed);
            R.Pending_Write_Data := Pending;
         exception
            when others =>
               --  A later Poll_Output must never observe a partial bracketed
               --  paste after construction or assignment failed.
               Unbounded.Set_Unbounded_String (R.Pending_Write_Data, "");
               R.Pending_Write_Data_Offset := 1;
               raise;
         end;
         R.Pending_Write_Data_Offset := 1;
         Flush_Write (R, Status);
      end if;
   end Write_Paste_With_Builder;

   procedure Write_Paste
     (R         : in out Runtime;
      Text      : String;
      Bracketed : Boolean;
      Status    : out Terminal.App.PTY_Write.Write_All_Status)
   is
   begin
      Write_Paste_With_Builder
        (R, Text, Bracketed, Status, Build_Paste'Access);
   end Write_Paste;

   procedure Flush_Write
     (R      : in out Runtime;
      Status : out Terminal.App.PTY_Write.Write_All_Status) is
   begin
      if R.Current_State /= Active or else R.S = null then
         Status := Terminal.App.PTY_Write.Session_Closed;
      elsif not Has_Pending_Write (R) then
         Status := Terminal.App.PTY_Write.Ok;
      else
         if R.Pending_Write.Length = 0 then
            declare
               Available : constant Natural :=
                 Unbounded.Length (R.Pending_Write_Data);
               Count : constant Natural :=
                 Natural'Min
                   (Terminal.App.Queues.Max_Chunk_Length,
                    Available - R.Pending_Write_Data_Offset + 1);
            begin
               R.Pending_Write := (others => <>);
               R.Pending_Write.Length := Count;
               for I in 1 .. Count loop
                  R.Pending_Write.Data (I) :=
                    Terminal.Common.Bytes.Byte
                      (Character'Pos
                         (Unbounded.Element
                            (R.Pending_Write_Data,
                             R.Pending_Write_Data_Offset + I - 1)));
               end loop;
               R.Pending_Write_Data_Offset :=
                 R.Pending_Write_Data_Offset + Count;
               R.Pending_Write_Offset := 1;
            end;
         end if;
         Terminal.App.PTY_Write.Write_Remaining
           (R.S.all, R.Pending_Write, R.Pending_Write_Offset, Status);
         if Status = Terminal.App.PTY_Write.Ok then
            R.Pending_Write := (others => <>);
            R.Pending_Write_Offset := 1;
            if R.Pending_Write_Data_Offset >
              Unbounded.Length (R.Pending_Write_Data)
            then
               Unbounded.Set_Unbounded_String (R.Pending_Write_Data, "");
               R.Pending_Write_Data_Offset := 1;
            else
               Status := Terminal.App.PTY_Write.Incomplete;
            end if;
         elsif Status in
           Terminal.App.PTY_Write.Failed | Terminal.App.PTY_Write.Session_Closed
         then
            R.Current_State := Exited;
         end if;
      end if;
   end Flush_Write;

   function Has_Pending_Write (R : Runtime) return Boolean is
     (R.Pending_Write.Length > 0
      or else Unbounded.Length (R.Pending_Write_Data) > 0);

   procedure Resize
     (R          : in out Runtime;
      Rows       : Positive;
      Cols       : Positive;
      Core_Status : out Terminal.Core.Resize_Status;
      PTY_Status  : out Terminal.PTY.Backend.Resize_Status)
   is
   begin
      if R.Current_State /= Active or else R.T = null or else R.S = null then
         Core_Status := Terminal.Core.Invalid_Size;
         PTY_Status := Terminal.PTY.Backend.Session_Closed;
      elsif R.Size_Known and then R.Rows = Rows and then R.Cols = Cols then
         Core_Status := Terminal.Core.Ok;
         PTY_Status := Terminal.PTY.Backend.Ok;
      else
         --  Resize the kernel endpoint first because it is cheap to roll back
         --  to the previously committed dimensions when the core cannot
         --  allocate its replacement grid.
         Terminal.PTY.Backend.Resize (R.S.all, Rows, Cols, PTY_Status);
         if PTY_Status /= Terminal.PTY.Backend.Ok then
            Core_Status := Terminal.Core.Ok;
            return;
         end if;

         Terminal.Core.Resize (R.T.all, Rows, Cols, Core_Status);
         if Core_Status = Terminal.Core.Ok then
            R.Rows := Rows;
            R.Cols := Cols;
            R.Size_Known := True;
         else
            declare
               Rollback_Status : Terminal.PTY.Backend.Resize_Status;
            begin
               Terminal.PTY.Backend.Resize
                 (R.S.all, R.Rows, R.Cols, Rollback_Status);
               if Rollback_Status /= Terminal.PTY.Backend.Ok then
                  PTY_Status := Rollback_Status;
                  R.Size_Known := False;
               end if;
            end;
         end if;
      end if;
   end Resize;

   function State (R : Runtime) return Runtime_Status is
     (R.Current_State);

   function Graphics_Stream_ID
     (R : Runtime) return Terminal.Core.Graphics_Stream_ID is
     (R.Stream_ID);

   function Core (R : aliased in out Runtime) return Core_Borrow is
   begin
      return Result : Core_Borrow (R'Access) do
         R.Leases.Acquire_Core (Result.Guard.Hold);
         if not Result.Guard.Hold.Active then
            raise Program_Error with "terminal core is closing";
         elsif R.T = null then
            raise Program_Error with "terminal core is not available";
         end if;
         Result.Item := R.T;
      end return;
   end Core;

   procedure With_Core
     (Borrow  : Core_Borrow;
      Process : not null access procedure
        (Item : in out Terminal.Core.Terminal)) is
   begin
      if Borrow.Item = null then
         raise Program_Error with "terminal core borrow is empty";
      end if;
      Process (Borrow.Item.all);
   end With_Core;

   function Modes (Borrow : Core_Borrow) return Terminal.Core.Mode_Snapshot is
   begin
      if Borrow.Item = null then
         raise Program_Error with "terminal core borrow is empty";
      end if;
      return Terminal.Core.Modes (Borrow.Item.all);
   end Modes;

   function PTY_Queue
     (R : aliased in out Runtime) return PTY_Queue_Borrow
   is
   begin
      return Result : PTY_Queue_Borrow (R'Access) do
         R.Leases.Acquire_Queue (Result.Guard.Hold);
         if not Result.Guard.Hold.Active then
            raise Program_Error with "PTY queue is closing";
         elsif R.Q = null then
            raise Program_Error with "PTY queue is not available";
         end if;
         Result.Item := R.Q;
      end return;
   end PTY_Queue;

   procedure With_PTY_Queue
     (Borrow  : PTY_Queue_Borrow;
      Process : not null access procedure
        (Item : in out Terminal.App.Queues.PTY_Output_Queue)) is
   begin
      if Borrow.Item = null then
         raise Program_Error with "PTY queue borrow is empty";
      end if;
      Process (Borrow.Item.all);
   end With_PTY_Queue;

   function Is_Alive (R : in out Runtime) return Boolean is
   begin
      if R.Current_State /= Active or else R.S = null then
         return False;
      elsif Terminal.PTY.Backend.Is_Alive (R.S.all) then
         return True;
      else
         R.Current_State := Exited;
         return False;
      end if;
   end Is_Alive;

   function Status_Label (R : Runtime) return String is
   begin
      case R.Current_State is
         when Inactive =>
            return "Session runtime inactive";
         when Active =>
            return
              "Session runtime active; queued="
              & (if R.Q = null
                 then "0"
                 else Terminal.Common.Status.Trimmed_Natural (R.Q.Length));
         when Exited =>
            return "Session runtime exited";
         when Cleanup_Pending =>
            return "Session runtime cleanup pending";
         when Closed =>
            return "Session runtime closed";
      end case;
   end Status_Label;
end Terminal.App.Session_Runtime;

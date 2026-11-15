with Ada.Finalization;
with System;
with Interfaces;
use type Interfaces.Unsigned_32;

with Terminal.Common.Bytes;
with Terminal.Common.Identity;

--  Platform-neutral PTY/session contract. The project selects exactly one
--  backend body; callers and status handling compile against this single spec.
package Terminal.PTY.Backend is
   Max_Status_Label_Length : constant := 96;

   type Session is new Ada.Finalization.Limited_Controlled with private;

   Term_Name : constant String := "xterm-256color";
   Color_Term : constant String := "truecolor";
   Term_Program : constant String := Terminal.Common.Identity.Program_Name;
   Term_Program_Version : constant String :=
     Terminal.Common.Identity.Program_Version;
   Term_Features : constant String := "Sx";

   type Backend_Capabilities is record
      POSIX_PTY        : Boolean := False;
      Windows_ConPTY   : Boolean := False;
      Resize           : Boolean := False;
      Terminal_Env     : Boolean := False;
      Nonblocking_Read : Boolean := False;
   end record;

   function Capabilities return Backend_Capabilities;
   function Backend_Status_Label
     (Capabilities : Backend_Capabilities) return String;
   function ConPTY_Status_Label
     (Capabilities : Backend_Capabilities) return String;

   type Spawn_Status is
     (Ok,
      Open_PTY_Failed,
      GrantPT_Failed,
      UnlockPT_Failed,
      PTSName_Failed,
      Fork_Failed,
      Child_Setup_Failed,
      Exec_Failed,
      Nonblocking_Failed,
      Cleanup_Shutdown,
      Invalid_Size);

   procedure Spawn_Default_Shell
     (S        : out Session;
      Rows     : Positive;
      Cols     : Positive;
      Status   : out Spawn_Status;
      Features : String := Term_Features);

   type Read_Status is
     (Ok,
      Would_Block,
      End_Of_File,
      Interrupted,
      Failed,
      Session_Closed);

   --  Count is the number of bytes transferred, independent of the array's
   --  lower bound.
   procedure Read
     (S      : in out Session;
      Buffer : out Terminal.Common.Bytes.Byte_Array;
      Count  : out Natural;
      Status : out Read_Status);

   type Write_Status is
     (Ok,
      Partial,
      Interrupted,
      Failed,
      Session_Closed);

   procedure Write
     (S      : in out Session;
      Data   : Terminal.Common.Bytes.Byte_Array;
      Count  : out Natural;
      Status : out Write_Status);

   type Resize_Status is
     (Ok,
      Invalid_Size,
      Ioctl_Failed,
      Session_Closed);

   procedure Resize
     (S      : in out Session;
      Rows   : Positive;
      Cols   : Positive;
      Status : out Resize_Status);

   function Is_Alive (S : in out Session) return Boolean;

   type Exit_State is
     (Still_Running,
      Exited,
      Signaled,
      Unknown);

   function Child_State (S : in out Session) return Exit_State;
   --  A normally exited child reports its process exit code. POSIX signal
   --  termination reports the negated signal number rather than raw wait bits.
   function Child_Status (S : Session) return Integer;

   procedure Close (S : in out Session);
   --  Withdraw native ownership and hand it to the process cleanup service
   --  without waiting for child termination.  The session is closed on normal
   --  return. If the service cannot accept ownership, the session retains the
   --  remaining native owner and Deferred_Cleanup_Unavailable is raised.
   Deferred_Cleanup_Unavailable : exception;
   procedure Defer_Close (S : in out Session);

   function Deferred_Cleanup_Pending return Natural;
   function Deferred_Cleanup_Quarantined return Natural;
   --  Cumulative count of ownership markers abandoned after a native release
   --  could no longer be completed safely. This value never decreases.
   function Deferred_Cleanup_Abandoned_Count return Natural;
   function Cleanup_Failure_Count return Natural;
   --  Drain work already accepted by the deferred cleanup service. Callers
   --  requiring a final barrier must first stop producers or use Shutdown.
   procedure Drain_Deferred_Cleanup
     (Timeout_Milliseconds : Natural;
      Complete             : out Boolean);
   --  Irreversibly stop new ownership handoffs without waiting for work that
   --  was already accepted.  This is exposed separately so callers can retain
   --  proof of the transition even if the following drain fails.
   procedure Stop_Deferred_Cleanup_Admission;
   --  Drain and join the cleanup service after admission has already closed.
   --  This does not repeat the irreversible admission transition.
   procedure Drain_Closed_Deferred_Cleanup
     (Timeout_Milliseconds : Natural;
      Complete             : out Boolean);
   --  Atomically stop new ownership handoffs, then drain accepted work. This
   --  transition is irreversible; later spawns return Cleanup_Shutdown.
   procedure Shutdown_Deferred_Cleanup
     (Timeout_Milliseconds : Natural;
      Complete             : out Boolean);

private
   type Native_Allocation_State is
     (Not_Allocated, Allocated, Initialized);

   function Native_Needs_Deletion
     (State : Native_Allocation_State) return Boolean is
     (State = Initialized);

   function Windows_Signed_Exit_Status
     (Code : Interfaces.Unsigned_32) return Integer is
     (if Code <= 16#7FFF_FFFF#
      then Integer (Code)
      else -1 - Integer (Interfaces.Unsigned_32'Last - Code));

   type Backend_Spawn_Trace is record
      Pipes_Made      : Boolean := False;
      Console_Made    : Boolean := False;
      Attributes_Made : Boolean := False;
      Process_Made    : Boolean := False;
      Last_Error      : Natural := 0;
      Startup_Size    : Natural := 0;
      Attribute_Size  : Natural := 0;
   end record;

   type Backend_Read_Trace is record
      Polls       : Natural := 0;
      Poll_Failed : Natural := 0;
      Poll_Error  : Natural := 0;
      Bytes_Seen  : Natural := 0;
   end record;

   --  The selected body uses one half of this platform-state superset. Keeping
   --  the representation private avoids duplicating the public contract merely
   --  to vary a handful of native fields.
   type Session is new Ada.Finalization.Limited_Controlled with record
      Master_FD   : Integer := -1;
      Child_PID   : Integer := -1;
      Console     : System.Address := System.Null_Address;
      Input_Write : System.Address := System.Null_Address;
      Output_Read : System.Address := System.Null_Address;
      Read_Context : System.Address := System.Null_Address;
      Process     : System.Address := System.Null_Address;
      Thread      : System.Address := System.Null_Address;
      Attributes  : System.Address := System.Null_Address;
      Attribute_State : Native_Allocation_State := Not_Allocated;
      Closed      : Boolean := True;
      Last_Status : Integer := 0;
      Last_State  : Exit_State := Unknown;
      Spawn_Debug : Backend_Spawn_Trace;
      Read_Debug  : Backend_Read_Trace;
   end record;
   overriding procedure Finalize (S : in out Session);
end Terminal.PTY.Backend;

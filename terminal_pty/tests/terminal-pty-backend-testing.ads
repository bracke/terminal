with Interfaces;

package Terminal.PTY.Backend.Testing is
   type Attribute_List_State is
     (Not_Allocated, Allocated, Initialized);

   function Needs_Deletion (State : Attribute_List_State) return Boolean;
   function Signed_Exit_Status
     (Code : Interfaces.Unsigned_32) return Integer;

   type Spawn_Trace is record
      Pipes_Made      : Boolean := False;
      Console_Made    : Boolean := False;
      Attributes_Made : Boolean := False;
      Process_Made    : Boolean := False;
      Last_Error      : Natural := 0;
      Startup_Size    : Natural := 0;
      Attribute_Size  : Natural := 0;
   end record;

   type Read_Trace is record
      Polls       : Natural := 0;
      Poll_Failed : Natural := 0;
      Poll_Error  : Natural := 0;
      Bytes_Seen  : Natural := 0;
   end record;

   function Spawn_Diagnostics (S : Session) return Spawn_Trace;
   function Read_Diagnostics (S : Session) return Read_Trace;

   function Cleanup_Failure_Count return Natural;
   function Exercise_POSIX_Cleanup_Diagnostic return Boolean;
   function Exercise_POSIX_Deferred_Cleanup return Boolean;
   function Exercise_Close_Failure return Boolean;
   function Exercise_Failed_Reaper return Boolean;
   function Exercise_Reader_Handoff return Boolean;
   function Enter_Quarantine return Boolean;
   function Enter_Quarantine_Batch return Boolean;
   function Release_Quarantine return Boolean;
   procedure Reset_Drain_Worker_High_Water;
   function Drain_Worker_High_Water return Natural;
   function Active_Cleanup_Workers return Natural;
   function Exercise_Cleanup_Fault_Injection return Boolean;
   function Exercise_Rejected_Handoff return Boolean;
   function Exercise_Permanent_Release_Failures return Boolean;
end Terminal.PTY.Backend.Testing;

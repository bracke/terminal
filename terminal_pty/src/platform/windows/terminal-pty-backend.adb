with Ada.Finalization;
with Interfaces.C;
with Interfaces.C.Strings;
with Terminal.Common.C_Strings;
with Terminal.Common.Counters;

package body Terminal.PTY.Backend is
   use type Interfaces.C.int;
   use type Interfaces.C.unsigned;
   use type Interfaces.C.unsigned_long;
   use type Interfaces.C.long;
   use type Interfaces.C.size_t;
   use type Interfaces.Unsigned_32;
   use type System.Address;
   use type Interfaces.C.char;

   subtype DWORD is Interfaces.C.unsigned_long;
   subtype BOOL is Interfaces.C.int;
   subtype HANDLE is System.Address;

   Wait_Object_0 : constant DWORD := 0;
   Wait_Timeout  : constant DWORD := 258;

   --  A console size is a COORD: two 16-bit values, and four bytes in total.
   --
   --  Passed as the word it is rather than as a record. A small struct goes by
   --  value in a register in this ABI, and an Ada record handed to a C import
   --  may go by reference instead -- in which case every argument after it
   --  shifts, CreatePseudoConsole still reports success, and the console it
   --  builds writes to whatever the shifted handles happened to be. Which is
   --  precisely the symptom this had: a console that starts, says nothing, and
   --  takes the shell down with it.
   function Console_Size (Rows, Cols : Positive) return Interfaces.Unsigned_32 is
     (Interfaces.Unsigned_32 (Cols)
      or Interfaces.Shift_Left (Interfaces.Unsigned_32 (Rows), 16));

   type STARTUPINFOEX is record
      Size          : DWORD := 0;
      Reserved      : System.Address := System.Null_Address;
      Desktop       : System.Address := System.Null_Address;
      Title         : System.Address := System.Null_Address;
      X             : DWORD := 0;
      Y             : DWORD := 0;
      X_Size        : DWORD := 0;
      Y_Size        : DWORD := 0;
      X_Count_Chars : DWORD := 0;
      Y_Count_Chars : DWORD := 0;
      Fill_Attribute : DWORD := 0;
      Flags         : DWORD := 0;
      Show_Window   : Interfaces.Unsigned_16 := 0;
      Reserved2     : Interfaces.Unsigned_16 := 0;
      Reserved3     : System.Address := System.Null_Address;
      Std_Input     : System.Address := System.Null_Address;
      Std_Output    : System.Address := System.Null_Address;
      Std_Error     : System.Address := System.Null_Address;
      Attributes    : aliased System.Address := System.Null_Address;
   end record
     with Convention => C;

   type PROCESS_INFORMATION is record
      Process    : aliased System.Address := System.Null_Address;
      Thread     : aliased System.Address := System.Null_Address;
      Process_Id : DWORD := 0;
      Thread_Id  : DWORD := 0;
   end record
     with Convention => C;

   Extended_Startupinfo_Present : constant DWORD := 16#0008_0000#;
   Startf_Use_Std_Handles       : constant DWORD := 16#0000_0100#;
   Proc_Thread_Attribute_Pseudoconsole_Handle_List : constant := 16#0002_0016#;

   function Getenv (Name : Interfaces.C.Strings.chars_ptr)
      return Interfaces.C.Strings.chars_ptr
     with Import, Convention => C, External_Name => "getenv";

   --  COMSPEC is what SHELL is on a POSIX host: the command processor the user
   --  has chosen, which is cmd.exe unless something set it otherwise. The POSIX
   --  side has honoured SHELL from the start; this side had cmd.exe written into
   --  it.
   function Shell_Command return String is
      Name  : Terminal.Common.C_Strings.Owner;
      Value : Interfaces.C.Strings.chars_ptr;
   begin
      Terminal.Common.C_Strings.Set (Name, "COMSPEC");
      Value := Getenv (Terminal.Common.C_Strings.Unsafe_Pointer (Name));

      if not Interfaces.C.Strings."=" (Value, Interfaces.C.Strings.Null_Ptr) then
         declare
            Candidate : constant String := Interfaces.C.Strings.Value (Value);
         begin
            if Candidate'Length > 0 then
               return Candidate;
            end if;
         end;
      end if;

      return "cmd.exe";
   end Shell_Command;

   function Create_Pipe
     (Read_Handle  : access HANDLE;
      Write_Handle : access HANDLE;
      Attributes   : System.Address;
      Size         : DWORD) return BOOL
     with Import, Convention => Stdcall, External_Name => "CreatePipe";

   function Create_Overlapped_Output_Pipe
     (Read_Handle  : access HANDLE;
      Write_Handle : access HANDLE) return BOOL
     with Import, Convention => C,
          External_Name => "terminal_pty_create_overlapped_output_pipe";

   function Create_Windows_Reader_Owned
     (Pipe    : HANDLE;
      Context : access System.Address) return Interfaces.C.int
     with Import, Convention => C,
          External_Name => "terminal_pty_create_windows_reader_owned";

   function Free_Windows_Reader_Owned
     (Context : access System.Address) return BOOL
     with Import, Convention => C,
          External_Name => "terminal_pty_free_windows_reader_owned";

   function Abandon_Windows_Reader_Owned
     (Context : access System.Address;
      Pipe    : access HANDLE) return BOOL
     with Import, Convention => C,
          External_Name => "terminal_pty_abandon_windows_reader_owned";

   function Poll_Windows_Reader
     (Context    : System.Address;
      Buffer     : System.Address;
      Capacity   : DWORD;
      Bytes_Read : access DWORD;
      Error_Code : access DWORD) return Interfaces.C.int
     with Import, Convention => C,
          External_Name => "terminal_pty_poll_windows_reader";

   function Close_Handle_Owned (H : access HANDLE) return BOOL
     with Import, Convention => C,
          External_Name => "terminal_pty_close_handle_owned";

   function Create_Pseudo_Console
     (Size       : Interfaces.Unsigned_32;
      Input      : HANDLE;
      Output     : HANDLE;
      Flags      : DWORD;
      Console    : access HANDLE) return Interfaces.C.long
     with Import, Convention => Stdcall, External_Name => "CreatePseudoConsole";

   function Resize_Pseudo_Console
     (Console : HANDLE;
      Size    : Interfaces.Unsigned_32) return Interfaces.C.long
     with Import, Convention => Stdcall, External_Name => "ResizePseudoConsole";

   procedure Close_Pseudo_Console_Owned (Console : access HANDLE)
     with Import, Convention => C,
          External_Name => "terminal_pty_close_pseudo_console_owned";

   function Init_Attribute_List
     (List  : System.Address;
      Count : DWORD;
      Flags : DWORD;
      Size  : access Interfaces.C.size_t) return BOOL
     with Import, Convention => Stdcall,
          External_Name => "InitializeProcThreadAttributeList";

   function Update_Attribute
     (List       : System.Address;
      Flags      : DWORD;
      Attribute  : Interfaces.C.size_t;
      Value      : System.Address;
      Size       : Interfaces.C.size_t;
      Previous   : System.Address;
      Return_Size : System.Address) return BOOL
     with Import, Convention => Stdcall,
          External_Name => "UpdateProcThreadAttribute";

   function Free_Attribute_List_Owned
     (List        : access System.Address;
      Initialized : Interfaces.C.int;
      Still_Initialized : access Interfaces.C.int) return BOOL
     with Import, Convention => C,
          External_Name => "terminal_pty_free_attribute_list_owned";

   function Handoff_Process_Owned (Process : access HANDLE) return BOOL
     with Import, Convention => C,
          External_Name => "terminal_pty_handoff_process_owned";
   function Handoff_Reader_Owned
     (Context : access System.Address;
      Pipe    : access HANDLE) return BOOL
     with Import, Convention => C,
          External_Name => "terminal_pty_handoff_reader_owned";
   procedure Note_Cleanup_Abandoned
     with Import, Convention => C,
          External_Name => "terminal_pty_note_cleanup_abandoned";

   function C_Cleanup_Failure_Count return Interfaces.C.long
     with Import, Convention => C,
          External_Name => "terminal_pty_cleanup_failure_count";
   function C_Cleanup_Pending_Count return Interfaces.C.long
     with Import, Convention => C,
          External_Name => "terminal_pty_cleanup_pending_count";
   function C_Cleanup_Quarantined_Count return Interfaces.C.long
     with Import, Convention => C,
          External_Name => "terminal_pty_cleanup_quarantined_count";
   function C_Cleanup_Abandoned_Count return Interfaces.C.long
     with Import, Convention => C,
          External_Name => "terminal_pty_cleanup_abandoned_count";
   function C_Cleanup_Is_Accepting return BOOL
     with Import, Convention => C,
          External_Name => "terminal_pty_cleanup_is_accepting";
   function C_Cleanup_Drain (Timeout_Milliseconds : DWORD) return BOOL
     with Import, Convention => C,
          External_Name => "terminal_pty_cleanup_drain";
   procedure C_Cleanup_Stop_Accepting
     with Import, Convention => C,
          External_Name => "terminal_pty_cleanup_stop_accepting";
   function C_Cleanup_Drain_Closed
     (Timeout_Milliseconds : DWORD) return BOOL
     with Import, Convention => C,
          External_Name => "terminal_pty_cleanup_drain_closed";
   function C_Cleanup_Shutdown (Timeout_Milliseconds : DWORD) return BOOL
     with Import, Convention => C,
          External_Name => "terminal_pty_cleanup_shutdown";

   function Create_Process
     (Application    : System.Address;
      Command_Line   : Interfaces.C.Strings.chars_ptr;
      Process_Attrs  : System.Address;
      Thread_Attrs   : System.Address;
      Inherit        : BOOL;
      Flags          : DWORD;
      Environment    : System.Address;
      Directory      : System.Address;
      Startup        : System.Address;
      Information    : access PROCESS_INFORMATION) return BOOL
     with Import, Convention => Stdcall, External_Name => "CreateProcessA";

   function Write_File
     (H           : HANDLE;
      Buffer      : System.Address;
      To_Write    : DWORD;
      Written     : access DWORD;
      Overlapped  : System.Address) return BOOL
     with Import, Convention => Stdcall, External_Name => "WriteFile";

   function Get_Exit_Code_Process
     (Process : HANDLE;
      Code    : access DWORD) return BOOL
     with Import, Convention => Stdcall, External_Name => "GetExitCodeProcess";

   function Wait_For_Single_Object (H : HANDLE; Milliseconds : DWORD) return DWORD
     with Import, Convention => Stdcall, External_Name => "WaitForSingleObject";

   function Terminate_Process (Process : HANDLE; Code : Interfaces.C.unsigned)
     return BOOL
     with Import, Convention => Stdcall, External_Name => "TerminateProcess";

   function Allocate_Attribute_List
     (Target : access System.Address;
      Bytes  : Interfaces.C.size_t) return Interfaces.C.int
     with Import, Convention => C,
          External_Name => "terminal_pty_allocate_attribute_list";

   function Get_Last_Error return DWORD
     with Import, Convention => Stdcall, External_Name => "GetLastError";

   type Native_Process_State is
     (Native_Process_Running, Native_Process_Exited, Native_Process_Unknown);

   function Observe_Process
     (Process : HANDLE;
      Code    : out DWORD) return Native_Process_State
   is
      Waited : constant DWORD := Wait_For_Single_Object (Process, 0);
      Value  : aliased DWORD := 0;
   begin
      Code := 0;
      if Waited = Wait_Timeout then
         return Native_Process_Running;
      elsif Waited /= Wait_Object_0
        or else Get_Exit_Code_Process (Process, Value'Access) = 0
      then
         return Native_Process_Unknown;
      end if;

      --  The process handle is signaled, so every DWORD is now an exit code.
      --  In particular, 259 is a valid exit code and must not be confused with
      --  STILL_ACTIVE, whose value is also 259.
      Code := Value;
      return Native_Process_Exited;
   end Observe_Process;

   function Capabilities return Backend_Capabilities is
   begin
      return
        (POSIX_PTY        => False,
         Windows_ConPTY   => True,
         Resize           => True,
         Terminal_Env     => True,
         Nonblocking_Read => True);
   end Capabilities;

   function Backend_Status_Label
     (Capabilities : Backend_Capabilities) return String is
   begin
      --  Phrased as the POSIX side phrases it, and degrading the same way: the
      --  two go to the same diagnostic line, and a reader should not have to
      --  learn which host wrote it.
      if Capabilities.Windows_ConPTY
        and then Capabilities.Resize
        and then Capabilities.Terminal_Env
        and then Capabilities.Nonblocking_Read
      then
         return "Windows ConPTY backend with resize, env, and nonblocking read";
      else
         return "reduced Windows ConPTY backend";
      end if;
   end Backend_Status_Label;

   function ConPTY_Status_Label
     (Capabilities : Backend_Capabilities) return String is
   begin
      if Capabilities.Windows_ConPTY then
         return "Windows ConPTY supported";
      else
         return "Windows ConPTY unsupported by this build";
      end if;
   end ConPTY_Status_Label;

   function Build_Environment_Owned
     (Environment         : access System.Address;
      Term_Assignment     : Interfaces.C.Strings.chars_ptr;
      Color_Assignment    : Interfaces.C.Strings.chars_ptr;
      Program_Assignment  : Interfaces.C.Strings.chars_ptr;
      Version_Assignment  : Interfaces.C.Strings.chars_ptr;
      Features_Assignment : Interfaces.C.Strings.chars_ptr)
      return Interfaces.C.int
     with Import, Convention => C,
          External_Name => "terminal_pty_build_windows_environment_owned";

   procedure Free_Environment_Owned (Environment : access System.Address)
     with Import, Convention => C,
          External_Name => "terminal_pty_free_windows_environment_owned";

   type Spawn_Resources is
     new Ada.Finalization.Limited_Controlled with record
      Input_Read      : aliased HANDLE := System.Null_Address;
      Input_Write     : aliased HANDLE := System.Null_Address;
      Output_Read     : aliased HANDLE := System.Null_Address;
      Output_Write    : aliased HANDLE := System.Null_Address;
      Console         : aliased HANDLE := System.Null_Address;
      Info            : aliased PROCESS_INFORMATION;
      Startup         : aliased STARTUPINFOEX;
      Command         : Terminal.Common.C_Strings.Owner;
      Environment     : aliased System.Address := System.Null_Address;
      Read_Context    : aliased System.Address := System.Null_Address;
      Attribute_State : Native_Allocation_State := Not_Allocated;
   end record;
   overriding procedure Finalize (Resources : in out Spawn_Resources);

   protected Windows_Session_Publication is
      procedure Publish
        (S         : in out Session;
         Resources : in out Spawn_Resources;
         Status    : out Spawn_Status);
      procedure Withdraw
        (S         : in out Session;
         Resources : in out Spawn_Resources);
      procedure Restore
        (S         : in out Session;
         Resources : in out Spawn_Resources);
   end Windows_Session_Publication;

   protected body Windows_Session_Publication is
      procedure Publish
        (S         : in out Session;
         Resources : in out Spawn_Resources;
         Status    : out Spawn_Status) is
      begin
         if Resources.Console = System.Null_Address
           or else Resources.Input_Write = System.Null_Address
           or else Resources.Output_Read = System.Null_Address
           or else Resources.Read_Context = System.Null_Address
           or else Resources.Info.Process = System.Null_Address
           or else Resources.Startup.Attributes = System.Null_Address
         then
            raise Program_Error with "cannot publish an incomplete ConPTY session";
         end if;
         S.Console := Resources.Console;
         S.Input_Write := Resources.Input_Write;
         S.Output_Read := Resources.Output_Read;
         S.Read_Context := Resources.Read_Context;
         S.Process := Resources.Info.Process;
         S.Thread := Resources.Info.Thread;
         S.Attributes := Resources.Startup.Attributes;
         S.Attribute_State := Resources.Attribute_State;
         S.Closed := False;
         S.Last_State := Still_Running;
         Resources.Console := System.Null_Address;
         Resources.Input_Write := System.Null_Address;
         Resources.Output_Read := System.Null_Address;
         Resources.Read_Context := System.Null_Address;
         Resources.Info.Process := System.Null_Address;
         Resources.Info.Thread := System.Null_Address;
         Resources.Startup.Attributes := System.Null_Address;
         Resources.Attribute_State := Not_Allocated;
         Status := Ok;
      end Publish;

      procedure Withdraw
        (S         : in out Session;
         Resources : in out Spawn_Resources) is
      begin
         Resources.Console := S.Console;
         Resources.Input_Write := S.Input_Write;
         Resources.Output_Read := S.Output_Read;
         Resources.Read_Context := S.Read_Context;
         Resources.Info.Process := S.Process;
         Resources.Info.Thread := S.Thread;
         Resources.Startup.Attributes := S.Attributes;
         Resources.Attribute_State := S.Attribute_State;

         S.Console := System.Null_Address;
         S.Input_Write := System.Null_Address;
         S.Output_Read := System.Null_Address;
         S.Read_Context := System.Null_Address;
         S.Process := System.Null_Address;
         S.Thread := System.Null_Address;
         S.Attributes := System.Null_Address;
         S.Attribute_State := Not_Allocated;
         S.Closed := True;
      end Withdraw;

      procedure Restore
        (S         : in out Session;
         Resources : in out Spawn_Resources) is
      begin
         S.Console := Resources.Console;
         S.Input_Write := Resources.Input_Write;
         S.Output_Read := Resources.Output_Read;
         S.Read_Context := Resources.Read_Context;
         S.Process := Resources.Info.Process;
         S.Thread := Resources.Info.Thread;
         S.Attributes := Resources.Startup.Attributes;
         S.Attribute_State := Resources.Attribute_State;
         S.Closed :=
           S.Console = System.Null_Address
           and then S.Input_Write = System.Null_Address
           and then S.Output_Read = System.Null_Address
           and then S.Read_Context = System.Null_Address
           and then S.Process = System.Null_Address
           and then S.Thread = System.Null_Address
           and then S.Attributes = System.Null_Address;

         Resources.Console := System.Null_Address;
         Resources.Input_Write := System.Null_Address;
         Resources.Output_Read := System.Null_Address;
         Resources.Read_Context := System.Null_Address;
         Resources.Info.Process := System.Null_Address;
         Resources.Info.Thread := System.Null_Address;
         Resources.Startup.Attributes := System.Null_Address;
         Resources.Attribute_State := Not_Allocated;
      end Restore;
   end Windows_Session_Publication;

   type Cleanup_Result is record
      Complete         : Boolean := True;
      Process_Observed : Boolean := False;
      Last_Status      : Integer := 0;
      Last_State       : Exit_State := Unknown;
   end record;

   procedure Release_Resources
     (Resources          : in out Spawn_Resources;
      Retain_On_Failure  : Boolean;
      Result             : out Cleanup_Result)
   is
      Ignored            : BOOL;
      Waited             : DWORD;
      Code               : aliased DWORD := 0;
      Process_Releasable : Boolean := False;
      Attribute_Initialized : aliased Interfaces.C.int := 0;
      pragma Unreferenced (Ignored);

      procedure Close_Owned (Item : access HANDLE) is
      begin
         if Close_Handle_Owned (Item) = 0 then
            Result.Complete := False;
         end if;
      end Close_Owned;
   begin
      Result := (others => <>);
      if Resources.Read_Context /= System.Null_Address then
         if Free_Windows_Reader_Owned
              (Resources.Read_Context'Access) = 0
         then
            Result.Complete := False;
         end if;
      end if;
      --  Read_Context retains Output_Read inside its OVERLAPPED state. Never
      --  close the pipe while a failed reader cleanup can still retry against
      --  that numeric handle.
      if Resources.Read_Context = System.Null_Address
        and then Resources.Output_Read /= System.Null_Address
      then
         Close_Owned (Resources.Output_Read'Access);
      end if;
      if Resources.Console /= System.Null_Address then
         Close_Pseudo_Console_Owned (Resources.Console'Access);
      end if;
      if Resources.Info.Process /= System.Null_Address then
         Waited := Wait_For_Single_Object (Resources.Info.Process, 500);
         if Waited = Wait_Timeout then
            Ignored := Terminate_Process (Resources.Info.Process, 1);
            Waited := Wait_For_Single_Object (Resources.Info.Process, 500);
         end if;
         if Waited = Wait_Object_0 then
            Process_Releasable := True;
            Result.Process_Observed := True;
            if Get_Exit_Code_Process
                 (Resources.Info.Process, Code'Access) = 0
            then
               Result.Last_State := Unknown;
            else
               Result.Last_Status :=
                 Windows_Signed_Exit_Status (Interfaces.Unsigned_32 (Code));
               Result.Last_State := Exited;
            end if;
         elsif Waited = Wait_Timeout then
            Result.Complete := False;
         else
            --  WAIT_FAILED is not retryable: a later handle-table reuse could
            --  turn the stale numeric marker into an unrelated process.
            Note_Cleanup_Abandoned;
            Resources.Info.Process := System.Null_Address;
            Result.Complete := False;
         end if;
      end if;
      Close_Owned (Resources.Input_Read'Access);
      Close_Owned (Resources.Input_Write'Access);
      Close_Owned (Resources.Output_Write'Access);
      Close_Owned (Resources.Info.Thread'Access);
      if Process_Releasable then
         Close_Owned (Resources.Info.Process'Access);
      elsif not Retain_On_Failure
        and then Handoff_Process_Owned
          (Resources.Info.Process'Access) = 0
      then
         Result.Complete := False;
      end if;
      if Resources.Startup.Attributes /= System.Null_Address then
         Attribute_Initialized :=
           (if Native_Needs_Deletion
                 (Resources.Attribute_State)
            then 1
            else 0);
         if Free_Attribute_List_Owned
              (Resources.Startup.Attributes'Access,
               Attribute_Initialized,
               Attribute_Initialized'Access) = 0
         then
            Result.Complete := False;
         end if;
         Resources.Attribute_State :=
           (if Resources.Startup.Attributes = System.Null_Address
            then Not_Allocated
            elsif Attribute_Initialized /= 0
            then Initialized
            else Allocated);
      end if;
      if Resources.Environment /= System.Null_Address then
         Free_Environment_Owned (Resources.Environment'Access);
      end if;
   end Release_Resources;

   procedure Transfer_Remaining_Resources
     (Resources                  : in out Spawn_Resources;
      Retain_On_Handoff_Failure : Boolean;
      Complete                   : out Boolean)
   is
      Ignored : BOOL;
      pragma Unreferenced (Ignored);

      procedure Transfer_Handle (Item : access HANDLE) is
      begin
         --  Generic handles are one-shot releases. This is a defensive final
         --  consume for any marker that survived the direct cleanup passes.
         Ignored := Close_Handle_Owned (Item);
      end Transfer_Handle;
   begin
      Complete := True;
      if Resources.Read_Context /= System.Null_Address then
         if Handoff_Reader_Owned
              (Resources.Read_Context'Access,
               Resources.Output_Read'Access) = 0
         then
            Complete := False;
            if not Retain_On_Handoff_Failure then
               Ignored := Abandon_Windows_Reader_Owned
                 (Resources.Read_Context'Access,
                  Resources.Output_Read'Access);
            end if;
         end if;
      else
         Transfer_Handle (Resources.Output_Read'Access);
      end if;
      Transfer_Handle (Resources.Input_Read'Access);
      Transfer_Handle (Resources.Input_Write'Access);
      Transfer_Handle (Resources.Output_Write'Access);
      Transfer_Handle (Resources.Info.Thread'Access);
      if Resources.Console /= System.Null_Address then
         Close_Pseudo_Console_Owned (Resources.Console'Access);
      end if;
      if Handoff_Process_Owned (Resources.Info.Process'Access) = 0
        and then Resources.Info.Process /= System.Null_Address
      then
         Complete := False;
         if not Retain_On_Handoff_Failure then
            Ignored := Terminate_Process (Resources.Info.Process, 1);
            if Close_Handle_Owned (Resources.Info.Process'Access) = 0 then
               Note_Cleanup_Abandoned;
            end if;
         end if;
      end if;
      if Resources.Startup.Attributes /= System.Null_Address then
         --  Attribute release is one-shot: DeleteProcThreadAttributeList is
         --  followed by a consumed LocalFree attempt, never deferred retry.
         if Resources.Attribute_State = Initialized then
            declare
               Still_Initialized : aliased Interfaces.C.int := 1;
            begin
               Ignored := Free_Attribute_List_Owned
                 (Resources.Startup.Attributes'Access,
                  1,
                  Still_Initialized'Access);
               Resources.Attribute_State :=
                 (if Resources.Startup.Attributes = System.Null_Address
                  then Not_Allocated
                  else Allocated);
            end;
         end if;
         if Resources.Startup.Attributes /= System.Null_Address then
            declare
               Not_Initialized : aliased Interfaces.C.int := 0;
            begin
               Ignored := Free_Attribute_List_Owned
                 (Resources.Startup.Attributes'Access,
                  0,
                  Not_Initialized'Access);
            end;
            Resources.Attribute_State :=
              (if Resources.Startup.Attributes = System.Null_Address
               then Not_Allocated
               else Allocated);
         end if;
      end if;
      if Resources.Environment /= System.Null_Address then
         Free_Environment_Owned (Resources.Environment'Access);
      end if;
   end Transfer_Remaining_Resources;

   overriding procedure Finalize (Resources : in out Spawn_Resources) is
      Result : Cleanup_Result;
   begin
      Release_Resources
        (Resources,
         Retain_On_Failure => False,
         Result            => Result);
      if not Result.Complete then
         --  Operations that safely retain ownership get one bounded retry
         --  before finalization transfers them to the shared cleanup path.
         Release_Resources
           (Resources,
            Retain_On_Failure => False,
            Result            => Result);
         if not Result.Complete then
            Transfer_Remaining_Resources
              (Resources,
               Retain_On_Handoff_Failure => False,
               Complete                   => Result.Complete);
         end if;
      end if;
   end Finalize;

   procedure Spawn_Default_Shell
     (S      : out Session;
      Rows   : Positive;
      Cols   : Positive;
      Status : out Spawn_Status;
      Features : String := Term_Features)
   is
      Resources           : Spawn_Resources;
      List_Size           : aliased Interfaces.C.size_t := 0;
      Term_Assignment     : Terminal.Common.C_Strings.Owner;
      Color_Assignment    : Terminal.Common.C_Strings.Owner;
      Program_Assignment  : Terminal.Common.C_Strings.Owner;
      Version_Assignment  : Terminal.Common.C_Strings.Owner;
      Features_Assignment : Terminal.Common.C_Strings.Owner;
      Ignored : BOOL;
      pragma Unreferenced (Ignored);
   begin
      S.Console := System.Null_Address;
      S.Input_Write := System.Null_Address;
      S.Output_Read := System.Null_Address;
      S.Read_Context := System.Null_Address;
      S.Process := System.Null_Address;
      S.Thread := System.Null_Address;
      S.Attributes := System.Null_Address;
      S.Attribute_State := Not_Allocated;
      S.Closed := True;
      S.Last_Status := 0;
      S.Last_State := Unknown;
      S.Spawn_Debug := (others => <>);
      S.Read_Debug := (others => <>);

      if C_Cleanup_Is_Accepting = 0 then
         Status := Cleanup_Shutdown;
         return;
      end if;

      if Rows > Positive (Interfaces.Integer_16'Last)
        or else Cols > Positive (Interfaces.Integer_16'Last)
      then
         Status := Invalid_Size;
         return;
      end if;

      begin
         Terminal.Common.C_Strings.Set (Resources.Command, Shell_Command);
         Terminal.Common.C_Strings.Set
           (Term_Assignment, "TERM=" & Term_Name);
         Terminal.Common.C_Strings.Set
           (Color_Assignment, "COLORTERM=" & Color_Term);
         Terminal.Common.C_Strings.Set
           (Program_Assignment, "TERM_PROGRAM=" & Term_Program);
         Terminal.Common.C_Strings.Set
           (Version_Assignment,
            "TERM_PROGRAM_VERSION=" & Term_Program_Version);
         Terminal.Common.C_Strings.Set
           (Features_Assignment, "TERM_FEATURES=" & Features);
         if Build_Environment_Owned
           (Resources.Environment'Access,
            Terminal.Common.C_Strings.Unsafe_Pointer (Term_Assignment),
            Terminal.Common.C_Strings.Unsafe_Pointer (Color_Assignment),
            Terminal.Common.C_Strings.Unsafe_Pointer (Program_Assignment),
            Terminal.Common.C_Strings.Unsafe_Pointer (Version_Assignment),
            Terminal.Common.C_Strings.Unsafe_Pointer (Features_Assignment)) = 0
         then
            Status := Child_Setup_Failed;
            return;
         end if;
      exception
         when Storage_Error =>
            Status := Child_Setup_Failed;
            return;
      end;

      --  Two pipes: what we write reaches the child's input, what the child
      --  writes comes back on the other. The console owns the ends it is given.
      if Create_Pipe
           (Resources.Input_Read'Access,
            Resources.Input_Write'Access,
            System.Null_Address,
            0) = 0
        or else Create_Overlapped_Output_Pipe
                  (Resources.Output_Read'Access,
                   Resources.Output_Write'Access) = 0
      then
         Status := Open_PTY_Failed;
         return;
      end if;

      if Create_Windows_Reader_Owned
           (Resources.Output_Read, Resources.Read_Context'Access) = 0
      then
         S.Spawn_Debug.Last_Error := Natural (Get_Last_Error);
         Status := Open_PTY_Failed;
         return;
      end if;

      S.Spawn_Debug.Pipes_Made := True;

      if Create_Pseudo_Console
           (Console_Size (Rows, Cols),
            Resources.Input_Read,
            Resources.Output_Write,
            0,
            Resources.Console'Access) /= 0
      then
         S.Spawn_Debug.Last_Error := Natural (Get_Last_Error);
         Status := Open_PTY_Failed;
         return;
      end if;

      S.Spawn_Debug.Console_Made := True;

      --  The console's ends of the pipes stay open until the child exists.
      --
      --  The documentation says the console duplicates them and Microsoft's own
      --  sample closes them here, so this ought not to matter -- but the shell
      --  attaches, sets its title, and then nothing it draws ever comes back,
      --  and this is the one ordering difference left between this and the
      --  implementations that work. Holding them costs two handles for the
      --  length of a CreateProcess call.

      --  A child is attached to a pseudo-console through a process attribute,
      --  not through inherited descriptors, so the attribute list has to be
      --  sized, allocated and filled before CreateProcess sees it.
      Ignored := Init_Attribute_List (System.Null_Address, 1, 0, List_Size'Access);
      if Allocate_Attribute_List
           (Resources.Startup.Attributes'Access, List_Size) = 0
      then
         S.Spawn_Debug.Last_Error := Natural (Get_Last_Error);
         Status := Open_PTY_Failed;
         return;
      end if;
      Resources.Attribute_State := Allocated;

      if Init_Attribute_List
           (Resources.Startup.Attributes, 1, 0, List_Size'Access) = 0
      then
         S.Spawn_Debug.Last_Error := Natural (Get_Last_Error);
         Status := Open_PTY_Failed;
         return;
      end if;
      Resources.Attribute_State := Initialized;

      if Update_Attribute
           (Resources.Startup.Attributes,
            0,
            Proc_Thread_Attribute_Pseudoconsole_Handle_List,

                   --  The console handle itself, not its address. lpValue is
                   --  described as a pointer to the attribute value, and for
                   --  most attributes it is -- but a pseudo-console attribute's
                   --  value IS a handle, already pointer-sized, so Windows wants
                   --  the HPCON where the pointer would go. Microsoft's own
                   --  sample passes hPC, not &hPC. Passing the address of the
                   --  variable attaches the child to whatever that address looks
                   --  like: no error anywhere, a healthy console writing to a
                   --  pipe nobody is connected to, and a shell that gives up.
            Resources.Console,
            Resources.Console'Size / 8,
            System.Null_Address,
            System.Null_Address) = 0
      then
         S.Spawn_Debug.Last_Error := Natural (Get_Last_Error);
         Status := Open_PTY_Failed;
         return;
      end if;

      S.Spawn_Debug.Attributes_Made := True;
      S.Spawn_Debug.Attribute_Size := Natural (List_Size);

      --  Say explicitly that the child gets no standard handles, so that the
      --  pseudo-console is the only thing left for it to use.
      --
      --  Without this the child is handed whatever standard handles this process
      --  has, and when this process is itself redirected -- a pipe rather than a
      --  console, which is what a shell or a CI runner gives us -- those pipes
      --  beat the pseudo-console. Everything still reports success: the console
      --  is created, the attribute takes, the child runs. Its output simply goes
      --  to our pipe rather than through the console, so the console emits its
      --  start-up bytes and nothing further, which is the whole symptom.
      --
      --  The three handles are null by default and are meant to stay that way;
      --  it is the flag that matters. Filling them in with the console's own pipe
      --  ends also delivers the output, but as raw bytes with no console behind
      --  them, which is no use to a shell that expects a screen.
      Resources.Startup.Flags := Startf_Use_Std_Handles;

      --  Object_Size, not Size: for a record the latter is the minimum number of
      --  bits the type needs and may leave off trailing padding, and cb has to be
      --  exactly what C calls sizeof -- 112 here.
      Resources.Startup.Size := DWORD (STARTUPINFOEX'Object_Size / 8);
      S.Spawn_Debug.Startup_Size := Natural (Resources.Startup.Size);

      if Create_Process
           (System.Null_Address,
            Terminal.Common.C_Strings.Unsafe_Pointer (Resources.Command),
            System.Null_Address,
            System.Null_Address,
            0,
            Extended_Startupinfo_Present,
            Resources.Environment,
            System.Null_Address,
            Resources.Startup'Address,
            Resources.Info'Access) = 0
      then
         S.Spawn_Debug.Last_Error := Natural (Get_Last_Error);
         Status := Fork_Failed;
         return;
      end if;

      S.Spawn_Debug.Process_Made := True;
      Windows_Session_Publication.Publish (S, Resources, Status);
   end Spawn_Default_Shell;

   procedure Read
     (S      : in out Session;
      Buffer : out Terminal.Common.Bytes.Byte_Array;
      Count  : out Natural;
      Status : out Read_Status)
   is
      Got        : aliased DWORD := 0;
      Error_Code : aliased DWORD := 0;
      Result     : Interfaces.C.int;
   begin
      Count := 0;

      if S.Closed
        or else S.Output_Read = System.Null_Address
        or else S.Read_Context = System.Null_Address
      then
         Status := Session_Closed;
         return;
      end if;

      if Buffer'Length = 0 then
         Status := Ok;
         return;
      end if;

      Terminal.Common.Counters.Increment_Saturating (S.Read_Debug.Polls);
      Result := Poll_Windows_Reader
        (S.Read_Context,
         Buffer (Buffer'First)'Address,
         DWORD (Buffer'Length),
         Got'Access,
         Error_Code'Access);

      case Result is
         when 1 =>
            Count := Natural (Got);
            Terminal.Common.Counters.Add_Saturating
              (S.Read_Debug.Bytes_Seen, Natural (Got));
            Status := Ok;
         when 0 =>
            Status := Would_Block;
         when 2 =>
            Status := End_Of_File;
         when others =>
            Terminal.Common.Counters.Increment_Saturating
              (S.Read_Debug.Poll_Failed);
            S.Read_Debug.Poll_Error := Natural (Error_Code);
            Status := Failed;
      end case;
   end Read;

   procedure Write
     (S      : in out Session;
      Data   : Terminal.Common.Bytes.Byte_Array;
      Count  : out Natural;
      Status : out Write_Status)
   is
      Written : aliased DWORD := 0;
   begin
      Count := 0;

      if S.Closed or else S.Input_Write = System.Null_Address then
         Status := Session_Closed;
         return;
      end if;

      if Data'Length = 0 then
         Status := Ok;
         return;
      end if;

      if Write_File (S.Input_Write, Data (Data'First)'Address,
                     DWORD (Data'Length), Written'Access, System.Null_Address) = 0
      then
         Status := Failed;
         return;
      end if;

      Count := Natural (Written);
      Status := (if Natural (Written) = Data'Length then Ok else Partial);
   end Write;

   procedure Resize
     (S      : in out Session;
      Rows   : Positive;
      Cols   : Positive;
      Status : out Resize_Status) is
   begin
      if S.Closed or else S.Console = System.Null_Address then
         Status := Session_Closed;
         return;
      end if;

      if Rows > Positive (Interfaces.Integer_16'Last)
        or else Cols > Positive (Interfaces.Integer_16'Last)
      then
         Status := Invalid_Size;
         return;
      end if;

      if Resize_Pseudo_Console
           (S.Console, Console_Size (Rows, Cols)) /= 0
      then
         Status := Ioctl_Failed;
         return;
      end if;

      Status := Ok;
   end Resize;

   function Is_Alive (S : in out Session) return Boolean is
      Code : DWORD := 0;
   begin
      if S.Closed or else S.Process = System.Null_Address then
         return False;
      end if;

      case Observe_Process (S.Process, Code) is
         when Native_Process_Running =>
            return True;
         when Native_Process_Exited =>
            S.Last_Status :=
              Windows_Signed_Exit_Status (Interfaces.Unsigned_32 (Code));
            S.Last_State := Exited;
            return False;
         when Native_Process_Unknown =>
            return False;
      end case;
   end Is_Alive;

   function Has_Foreground_Process (S : in out Session) return Boolean is
   begin
      --  ConPTY does not expose the POSIX foreground-process-group concept.
      --  Treat a live hosted process as requiring confirmation.
      return Is_Alive (S);
   end Has_Foreground_Process;

   function Child_State (S : in out Session) return Exit_State is
      Code : DWORD := 0;
   begin
      if S.Process = System.Null_Address then
         return S.Last_State;
      end if;

      --  Windows reports one exit code and never says a signal ended it, so
      --  Signaled is not reachable from here.
      case Observe_Process (S.Process, Code) is
         when Native_Process_Running =>
            return Still_Running;
         when Native_Process_Exited =>
            S.Last_Status :=
              Windows_Signed_Exit_Status (Interfaces.Unsigned_32 (Code));
            S.Last_State := Exited;
            return Exited;
         when Native_Process_Unknown =>
            return Unknown;
      end case;
   end Child_State;

   function Child_Status (S : Session) return Integer is (S.Last_Status);

   procedure Close (S : in out Session) is
      Resources : Spawn_Resources;
      Result    : Cleanup_Result;
   begin
      if S.Closed then
         return;
      end if;

      --  Withdraw all native owners before a blocking or foreign operation.
      --  Resources is controlled, so cancellation completes whatever remains
      --  without retrying a handle already consumed by an owned C operation.
      Windows_Session_Publication.Withdraw (S, Resources);
      Release_Resources
        (Resources,
         Retain_On_Failure => True,
         Result            => Result);
      if Result.Process_Observed then
         S.Last_Status := Result.Last_Status;
         S.Last_State := Result.Last_State;
      end if;
      if not Result.Complete then
         Windows_Session_Publication.Restore (S, Resources);
         raise Program_Error with "ConPTY session cleanup remained incomplete";
      end if;
   end Close;

   procedure Defer_Close (S : in out Session) is
      Resources : Spawn_Resources;
      Complete  : Boolean;
   begin
      if S.Closed then
         return;
      end if;
      Windows_Session_Publication.Withdraw (S, Resources);
      Transfer_Remaining_Resources
        (Resources,
         Retain_On_Handoff_Failure => True,
         Complete                   => Complete);
      if not Complete then
         Windows_Session_Publication.Restore (S, Resources);
         raise Deferred_Cleanup_Unavailable with
           "ConPTY cleanup service rejected ownership";
      end if;
   end Defer_Close;

   overriding procedure Finalize (S : in out Session) is
      Resources : Spawn_Resources;
      Complete  : Boolean;
   begin
      Close (S);
   exception
      when others =>
         --  Explicit Close restores retryable owners before reporting a
         --  failure. A finalizer has no later retry point, so transfer every
         --  remaining owner to the bounded cleanup service instead.
         if not S.Closed then
            Windows_Session_Publication.Withdraw (S, Resources);
            Transfer_Remaining_Resources
              (Resources,
               Retain_On_Handoff_Failure => False,
               Complete                   => Complete);
         end if;
   end Finalize;

   function Counter_Value (Value : Interfaces.C.long) return Natural is
     (if Value <= 0 then 0
      elsif Value >= Interfaces.C.long (Natural'Last) then Natural'Last
      else Natural (Value));

   function Deferred_Cleanup_Pending return Natural is
     (Counter_Value (C_Cleanup_Pending_Count));

   function Deferred_Cleanup_Quarantined return Natural is
     (Counter_Value (C_Cleanup_Quarantined_Count));

   function Deferred_Cleanup_Abandoned_Count return Natural is
     (Counter_Value (C_Cleanup_Abandoned_Count));

   function Cleanup_Failure_Count return Natural is
     (Counter_Value (C_Cleanup_Failure_Count));

   procedure Drain_Deferred_Cleanup
     (Timeout_Milliseconds : Natural;
      Complete             : out Boolean) is
   begin
      Complete :=
        C_Cleanup_Drain (DWORD (Timeout_Milliseconds)) /= 0;
   end Drain_Deferred_Cleanup;

   procedure Stop_Deferred_Cleanup_Admission is
   begin
      C_Cleanup_Stop_Accepting;
   end Stop_Deferred_Cleanup_Admission;

   procedure Drain_Closed_Deferred_Cleanup
     (Timeout_Milliseconds : Natural;
      Complete             : out Boolean) is
   begin
      Complete :=
        C_Cleanup_Drain_Closed (DWORD (Timeout_Milliseconds)) /= 0;
   end Drain_Closed_Deferred_Cleanup;

   procedure Shutdown_Deferred_Cleanup
     (Timeout_Milliseconds : Natural;
      Complete             : out Boolean) is
   begin
      Complete :=
        C_Cleanup_Shutdown (DWORD (Timeout_Milliseconds)) /= 0;
   end Shutdown_Deferred_Cleanup;
end Terminal.PTY.Backend;

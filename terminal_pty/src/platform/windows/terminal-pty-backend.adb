with Ada.Unchecked_Conversion;

with Interfaces.C;
with Interfaces.C.Strings;

with System.Storage_Elements;

package body Terminal.PTY.Backend is
   use type Interfaces.C.int;
   use type Interfaces.C.unsigned;
   use type Interfaces.C.unsigned_long;
   use type Interfaces.C.long;
   use type Interfaces.C.size_t;
   use type System.Address;

   subtype DWORD is Interfaces.C.unsigned_long;
   subtype BOOL is Interfaces.C.int;
   subtype HANDLE is System.Address;

   --  For the teardown loops, which close several handles in a fixed order.
   type Handle_List is array (Positive range <>) of HANDLE;

   Invalid_Handle : constant HANDLE :=
     System.Storage_Elements.To_Address (System.Storage_Elements.Integer_Address'Last);

   Still_Active : constant DWORD := 259;

   --  Windows exit codes are unsigned and routinely have the top bit set --
   --  0xC000013A is what a process gets when its console goes away -- so they
   --  cannot simply be converted to Integer. Reinterpreted rather than clamped,
   --  which is also how Windows itself prints them: -1073741510.
   function To_Signed is new Ada.Unchecked_Conversion
     (Interfaces.Unsigned_32, Interfaces.Integer_32);

   --  A console is sized in character cells, packed two 16-bit values to a word.
   type COORD is record
      X : Interfaces.Integer_16 := 0;
      Y : Interfaces.Integer_16 := 0;
   end record
     with Convention => C;

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
      Attributes    : System.Address := System.Null_Address;
   end record
     with Convention => C;

   type PROCESS_INFORMATION is record
      Process    : System.Address := System.Null_Address;
      Thread     : System.Address := System.Null_Address;
      Process_Id : DWORD := 0;
      Thread_Id  : DWORD := 0;
   end record
     with Convention => C;

   Extended_Startupinfo_Present : constant DWORD := 16#0008_0000#;
   Proc_Thread_Attribute_Pseudoconsole_Handle_List : constant := 16#0002_0016#;

   function Create_Pipe
     (Read_Handle  : access HANDLE;
      Write_Handle : access HANDLE;
      Attributes   : System.Address;
      Size         : DWORD) return BOOL
     with Import, Convention => Stdcall, External_Name => "CreatePipe";

   function Close_Handle (H : HANDLE) return BOOL
     with Import, Convention => Stdcall, External_Name => "CloseHandle";

   function Create_Pseudo_Console
     (Size       : COORD;
      Input      : HANDLE;
      Output     : HANDLE;
      Flags      : DWORD;
      Console    : access HANDLE) return Interfaces.C.long
     with Import, Convention => Stdcall, External_Name => "CreatePseudoConsole";

   function Resize_Pseudo_Console
     (Console : HANDLE;
      Size    : COORD) return Interfaces.C.long
     with Import, Convention => Stdcall, External_Name => "ResizePseudoConsole";

   procedure Close_Pseudo_Console (Console : HANDLE)
     with Import, Convention => Stdcall, External_Name => "ClosePseudoConsole";

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

   procedure Delete_Attribute_List (List : System.Address)
     with Import, Convention => Stdcall,
          External_Name => "DeleteProcThreadAttributeList";

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

   function Read_File
     (H          : HANDLE;
      Buffer     : System.Address;
      To_Read    : DWORD;
      Read       : access DWORD;
      Overlapped : System.Address) return BOOL
     with Import, Convention => Stdcall, External_Name => "ReadFile";

   function Write_File
     (H           : HANDLE;
      Buffer      : System.Address;
      To_Write    : DWORD;
      Written     : access DWORD;
      Overlapped  : System.Address) return BOOL
     with Import, Convention => Stdcall, External_Name => "WriteFile";

   --  How much is already in the pipe. Reading without asking would block the
   --  whole render loop, because a console pipe has no non-blocking mode.
   function Peek_Named_Pipe
     (H              : HANDLE;
      Buffer         : System.Address;
      Size           : DWORD;
      Read           : access DWORD;
      Total_Available : access DWORD;
      Left_This_Message : access DWORD) return BOOL
     with Import, Convention => Stdcall, External_Name => "PeekNamedPipe";

   function Get_Exit_Code_Process
     (Process : HANDLE;
      Code    : access DWORD) return BOOL
     with Import, Convention => Stdcall, External_Name => "GetExitCodeProcess";

   function Wait_For_Single_Object (H : HANDLE; Milliseconds : DWORD) return DWORD
     with Import, Convention => Stdcall, External_Name => "WaitForSingleObject";

   function Terminate_Process (Process : HANDLE; Code : Interfaces.C.unsigned)
     return BOOL
     with Import, Convention => Stdcall, External_Name => "TerminateProcess";

   function Local_Alloc (Flags : Interfaces.C.unsigned; Bytes : Interfaces.C.size_t)
     return System.Address
     with Import, Convention => Stdcall, External_Name => "LocalAlloc";

   function Local_Free (Memory : System.Address) return System.Address
     with Import, Convention => Stdcall, External_Name => "LocalFree";

   function Capabilities return Backend_Capabilities is
   begin
      return (others => <>);
   end Capabilities;

   function Backend_Status_Label
     (Capabilities : Backend_Capabilities) return String is
   begin
      if Capabilities.Windows_ConPTY then
         return "PTY backend: Windows ConPTY";
      else
         return "PTY backend: none";
      end if;
   end Backend_Status_Label;

   function ConPTY_Status_Label
     (Capabilities : Backend_Capabilities) return String is
   begin
      if Capabilities.Windows_ConPTY then
         return "ConPTY: supported";
      else
         return "ConPTY: unsupported";
      end if;
   end ConPTY_Status_Label;

   procedure Spawn_Default_Shell
     (S      : out Session;
      Rows   : Positive;
      Cols   : Positive;
      Status : out Spawn_Status)
   is
      Input_Read   : aliased HANDLE := System.Null_Address;
      Input_Write  : aliased HANDLE := System.Null_Address;
      Output_Read  : aliased HANDLE := System.Null_Address;
      Output_Write : aliased HANDLE := System.Null_Address;
      Console      : aliased HANDLE := System.Null_Address;
      Info         : aliased PROCESS_INFORMATION;
      Startup      : aliased STARTUPINFOEX;
      List_Size    : aliased Interfaces.C.size_t := 0;
      Command      : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String ("cmd.exe");
      Ignored      : BOOL;
      Freed        : System.Address;
      pragma Unreferenced (Ignored, Freed);

      procedure Abandon is
      begin
         if Console /= System.Null_Address then
            Close_Pseudo_Console (Console);
         end if;

         for H of Handle_List'[Input_Read, Input_Write, Output_Read, Output_Write] loop
            if H /= System.Null_Address and then H /= Invalid_Handle then
               Ignored := Close_Handle (H);
            end if;
         end loop;

         if Startup.Attributes /= System.Null_Address then
            Delete_Attribute_List (Startup.Attributes);
            Freed := Local_Free (Startup.Attributes);
         end if;

         Interfaces.C.Strings.Free (Command);
      end Abandon;
   begin
      S.Console := System.Null_Address;
      S.Input_Write := System.Null_Address;
      S.Output_Read := System.Null_Address;
      S.Process := System.Null_Address;
      S.Thread := System.Null_Address;
      S.Attributes := System.Null_Address;
      S.Closed := True;
      S.Last_Status := 0;
      S.Last_State := Unknown;

      if Rows > Positive (Interfaces.Integer_16'Last)
        or else Cols > Positive (Interfaces.Integer_16'Last)
      then
         Interfaces.C.Strings.Free (Command);
         Status := Invalid_Size;
         return;
      end if;

      --  Two pipes: what we write reaches the child's input, what the child
      --  writes comes back on the other. The console owns the ends it is given.
      if Create_Pipe (Input_Read'Access, Input_Write'Access, System.Null_Address, 0) = 0
        or else Create_Pipe (Output_Read'Access, Output_Write'Access, System.Null_Address, 0) = 0
      then
         Abandon;
         Status := Open_PTY_Failed;
         return;
      end if;

      if Create_Pseudo_Console
           ((X => Interfaces.Integer_16 (Cols), Y => Interfaces.Integer_16 (Rows)),
            Input_Read, Output_Write, 0, Console'Access) /= 0
      then
         Abandon;
         Status := Open_PTY_Failed;
         return;
      end if;

      --  The console holds its own copies of those two ends now.
      Ignored := Close_Handle (Input_Read);
      Input_Read := System.Null_Address;
      Ignored := Close_Handle (Output_Write);
      Output_Write := System.Null_Address;

      --  A child is attached to a pseudo-console through a process attribute,
      --  not through inherited descriptors, so the attribute list has to be
      --  sized, allocated and filled before CreateProcess sees it.
      Ignored := Init_Attribute_List (System.Null_Address, 1, 0, List_Size'Access);
      Startup.Attributes := Local_Alloc (16#0040#, List_Size);

      if Startup.Attributes = System.Null_Address
        or else Init_Attribute_List (Startup.Attributes, 1, 0, List_Size'Access) = 0
        or else Update_Attribute
                  (Startup.Attributes,
                   0,
                   Proc_Thread_Attribute_Pseudoconsole_Handle_List,
                   Console'Address,
                   Console'Size / 8,
                   System.Null_Address,
                   System.Null_Address) = 0
      then
         Abandon;
         Status := Open_PTY_Failed;
         return;
      end if;

      Startup.Size := STARTUPINFOEX'Size / 8;

      if Create_Process
           (System.Null_Address,
            Command,
            System.Null_Address,
            System.Null_Address,
            0,
            Extended_Startupinfo_Present,
            System.Null_Address,
            System.Null_Address,
            Startup'Address,
            Info'Access) = 0
      then
         Abandon;
         Status := Fork_Failed;
         return;
      end if;

      Interfaces.C.Strings.Free (Command);

      S.Console := Console;
      S.Input_Write := Input_Write;
      S.Output_Read := Output_Read;
      S.Process := Info.Process;
      S.Thread := Info.Thread;
      S.Attributes := Startup.Attributes;
      S.Closed := False;
      S.Last_State := Still_Running;
      Status := Ok;
   end Spawn_Default_Shell;

   procedure Read
     (S      : in out Session;
      Buffer : out Terminal.Common.Bytes.Byte_Array;
      Last   : out Natural;
      Status : out Read_Status)
   is
      Available : aliased DWORD := 0;
      Got       : aliased DWORD := 0;
      Peeked    : aliased DWORD := 0;
      Remaining : aliased DWORD := 0;
   begin
      Last := Buffer'First - 1;

      if S.Closed or else S.Output_Read = System.Null_Address then
         Status := Session_Closed;
         return;
      end if;

      if Buffer'Length = 0 then
         Status := Ok;
         return;
      end if;

      --  Ask before reading: a console pipe cannot be put in non-blocking mode,
      --  and a blocking read here would stop the frame loop until the shell
      --  said something.
      if Peek_Named_Pipe
           (S.Output_Read, System.Null_Address, 0,
            Peeked'Access, Available'Access, Remaining'Access) = 0
      then
         --  The child closed its end; the pipe is gone rather than empty.
         Status := End_Of_File;
         return;
      end if;

      if Available = 0 then
         Status := Would_Block;
         return;
      end if;

      declare
         Wanted : constant DWORD :=
           DWORD'Min (Available, DWORD (Buffer'Length));
      begin
         if Read_File (S.Output_Read, Buffer (Buffer'First)'Address,
                       Wanted, Got'Access, System.Null_Address) = 0
         then
            Status := Failed;
            return;
         end if;

         if Got = 0 then
            Status := End_Of_File;
            return;
         end if;

         Last := Buffer'First + Natural (Got) - 1;
         Status := Ok;
      end;
   end Read;

   procedure Write
     (S      : in out Session;
      Data   : Terminal.Common.Bytes.Byte_Array;
      Last   : out Natural;
      Status : out Write_Status)
   is
      Written : aliased DWORD := 0;
   begin
      Last := Data'First - 1;

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

      Last := Data'First + Natural (Written) - 1;
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
           (S.Console,
            (X => Interfaces.Integer_16 (Cols), Y => Interfaces.Integer_16 (Rows))) /= 0
      then
         Status := Ioctl_Failed;
         return;
      end if;

      Status := Ok;
   end Resize;

   function Is_Alive (S : Session) return Boolean is
      Code : aliased DWORD := 0;
   begin
      if S.Closed or else S.Process = System.Null_Address then
         return False;
      end if;

      if Get_Exit_Code_Process (S.Process, Code'Access) = 0 then
         return False;
      end if;

      return Code = Still_Active;
   end Is_Alive;

   function Child_State (S : Session) return Exit_State is
      Code : aliased DWORD := 0;
   begin
      if S.Process = System.Null_Address then
         return S.Last_State;
      end if;

      if Get_Exit_Code_Process (S.Process, Code'Access) = 0 then
         return Unknown;
      end if;

      --  Windows reports one exit code and never says a signal ended it, so
      --  Signaled is not reachable from here.
      if Code = Still_Active then
         return Still_Running;
      else
         return Exited;
      end if;
   end Child_State;

   procedure Close (S : in out Session) is
      Ignored : BOOL;
      Freed   : System.Address;
      Waited  : DWORD;
      Code    : aliased DWORD := 0;
      pragma Unreferenced (Ignored, Freed, Waited);
   begin
      if S.Closed then
         return;
      end if;

      --  The console first: closing it tells the child its terminal is gone,
      --  and closing the pipes underneath it first would leave it writing into
      --  handles that no longer exist.
      if S.Console /= System.Null_Address then
         Close_Pseudo_Console (S.Console);
         S.Console := System.Null_Address;
      end if;

      --  Then wait for the child, and record how it went while the handle is
      --  still open -- Child_State answers from what is recorded here once the
      --  handle is gone. The POSIX side does the same after its SIGHUP.
      if S.Process /= System.Null_Address then
         Waited := Wait_For_Single_Object (S.Process, 500);

         if Get_Exit_Code_Process (S.Process, Code'Access) /= 0
           and then Code = Still_Active
         then
            --  Losing its console did not end it. Closing a session means the
            --  child goes with it, so insist, then read the code again.
            Ignored := Terminate_Process (S.Process, 1);
            Waited := Wait_For_Single_Object (S.Process, 500);
         end if;

         if Get_Exit_Code_Process (S.Process, Code'Access) = 0
           or else Code = Still_Active
         then
            S.Last_State := Unknown;
         else
            S.Last_Status :=
              Integer (To_Signed (Interfaces.Unsigned_32 (Code)));
            S.Last_State := Exited;
         end if;
      end if;

      for H of Handle_List'[S.Input_Write, S.Output_Read, S.Thread, S.Process] loop
         if H /= System.Null_Address then
            Ignored := Close_Handle (H);
         end if;
      end loop;

      if S.Attributes /= System.Null_Address then
         Delete_Attribute_List (S.Attributes);
         Freed := Local_Free (S.Attributes);
         S.Attributes := System.Null_Address;
      end if;

      S.Input_Write := System.Null_Address;
      S.Output_Read := System.Null_Address;
      S.Process := System.Null_Address;
      S.Thread := System.Null_Address;
      S.Closed := True;
   end Close;
end Terminal.PTY.Backend;

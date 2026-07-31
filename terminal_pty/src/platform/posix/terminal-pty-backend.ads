with Terminal.Common.Bytes;

package Terminal.PTY.Backend is
   Max_Status_Label_Length : constant := 96;

   type Session is limited private;

   Term_Name : constant String := "xterm-256color";
   Color_Term : constant String := "truecolor";

   type Backend_Capabilities is record
      POSIX_PTY        : Boolean := True;
      Windows_ConPTY   : Boolean := False;
      Resize           : Boolean := True;
      Terminal_Env     : Boolean := True;
      Nonblocking_Read : Boolean := True;
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
      Exec_Failed,
      Invalid_Size);

   procedure Spawn_Default_Shell
     (S      : out Session;
      Rows   : Positive;
      Cols   : Positive;
      Status : out Spawn_Status);

   type Read_Status is
     (Ok,
      Would_Block,
      End_Of_File,
      Interrupted,
      Failed,
      Session_Closed);

   procedure Read
     (S      : in out Session;
      Buffer : out Terminal.Common.Bytes.Byte_Array;
      Last   : out Natural;
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
      Last   : out Natural;
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

   --  What the last spawn did, step by step. The Windows backend fills this in
   --  because it can only be watched from a build runner; here the steps either
   --  work or the status says which one did not, so it reports the outcome and
   --  errno rather than a trail.
   type Spawn_Trace is record
      Pipes_Made      : Boolean := False;
      Console_Made    : Boolean := False;
      Attributes_Made : Boolean := False;
      Process_Made    : Boolean := False;
      Last_Error      : Natural := 0;
      Startup_Size    : Natural := 0;
      Attribute_Size  : Natural := 0;
   end record;

   function Last_Spawn_Trace return Spawn_Trace;

   --  The same shape as the Windows backend's, so a caller can report it
   --  whichever host it is on.
   type Read_Trace is record
      Peeks       : Natural := 0;
      Peek_Failed : Natural := 0;
      Peek_Error  : Natural := 0;
      Bytes_Seen  : Natural := 0;
   end record;

   function Last_Read_Trace return Read_Trace;

   function Is_Alive (S : Session) return Boolean;

   type Exit_State is
     (Still_Running,
      Exited,
      Signaled,
      Unknown);

   function Child_State (S : Session) return Exit_State;

   --  What the child exited with, once it has. Zero until then. On Windows this
   --  is the exit code reinterpreted as signed, which is how the platform prints
   --  it; on POSIX it is the raw wait status.
   function Child_Status (S : Session) return Integer;

   procedure Close (S : in out Session);

private
   type Session is limited record
      Master_FD   : Integer := -1;
      Child_PID   : Integer := -1;
      Closed      : Boolean := True;
      Last_Status : Integer := 0;
      Last_State  : Exit_State := Unknown;
   end record;
end Terminal.PTY.Backend;

with Terminal.Common.Bytes;

with System;

--  The Windows pseudo-console backend.
--
--  Same operations as the POSIX one, so the application names Terminal.PTY.Backend
--  and gets whichever the host has. The vocabulary is POSIX-shaped in places --
--  Fork_Failed, Signaled -- because it is the shared contract; where Windows has
--  no equivalent the value simply never occurs, which is stated at each one.
package Terminal.PTY.Backend is
   Max_Status_Label_Length : constant := 96;

   type Session is limited private;

   --  ConPTY translates these itself, but a shell still reads them, and a
   --  program that asks what terminal it is talking to should get the same
   --  answer on every host.
   Term_Name : constant String := "xterm-256color";
   Color_Term : constant String := "truecolor";

   type Backend_Capabilities is record
      POSIX_PTY        : Boolean := False;
      Windows_ConPTY   : Boolean := True;
      Resize           : Boolean := True;
      Terminal_Env     : Boolean := True;

      --  Reads go through an overlapped pipe with a zero-length wait, so a read
      --  with nothing to give returns Would_Block rather than parking the loop.
      Nonblocking_Read : Boolean := True;
   end record;

   function Capabilities return Backend_Capabilities;
   function Backend_Status_Label
     (Capabilities : Backend_Capabilities) return String;
   function ConPTY_Status_Label
     (Capabilities : Backend_Capabilities) return String;

   --  The POSIX names are kept so the caller's case statements do not change.
   --  On this host: Open_PTY_Failed is CreatePseudoConsole or its pipes failing,
   --  Fork_Failed is CreateProcess failing, and Exec_Failed cannot occur --
   --  Windows resolves the image inside CreateProcess, so there is no separate
   --  exec step to fail. GrantPT/UnlockPT/PTSName have no counterpart at all.
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

   --  Ioctl_Failed is ResizePseudoConsole failing; the name is the contract's.
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

   function Is_Alive (S : Session) return Boolean;

   --  Signaled never occurs here: Windows reports one exit code and does not
   --  distinguish a signal from a status.
   type Exit_State is
     (Still_Running,
      Exited,
      Signaled,
      Unknown);

   function Child_State (S : Session) return Exit_State;

   procedure Close (S : in out Session);

private
   --  Handles rather than descriptors, and the console object itself, which has
   --  to outlive the child and be closed before the pipes.
   type Session is limited record
      Console      : System.Address := System.Null_Address;
      Input_Write  : System.Address := System.Null_Address;
      Output_Read  : System.Address := System.Null_Address;
      Process      : System.Address := System.Null_Address;
      Thread       : System.Address := System.Null_Address;
      Attributes   : System.Address := System.Null_Address;
      Closed       : Boolean := True;
      Last_Status  : Integer := 0;
      Last_State   : Exit_State := Unknown;
   end record;
end Terminal.PTY.Backend;

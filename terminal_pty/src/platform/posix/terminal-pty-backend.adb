with Interfaces.C;
with Interfaces.C.Strings;
with System;

package body Terminal.PTY.Backend is
   use Interfaces.C;
   use Interfaces.C.Strings;

   subtype ssize_t is long;

   STDIN_FD  : constant int := 0;
   STDOUT_FD : constant int := 1;
   STDERR_FD : constant int := 2;


   function posix_openpt (Flags : int) return int
     with Import, Convention => C, External_Name => "posix_openpt";
   function grantpt (FD : int) return int
     with Import, Convention => C, External_Name => "grantpt";
   function unlockpt (FD : int) return int
     with Import, Convention => C, External_Name => "unlockpt";
   function ptsname (FD : int) return Interfaces.C.Strings.chars_ptr
     with Import, Convention => C, External_Name => "ptsname";
   function fork return int
     with Import, Convention => C, External_Name => "fork";
   function setsid return int
     with Import, Convention => C, External_Name => "setsid";
   function dup2 (OldFD : int; NewFD : int) return int
     with Import, Convention => C, External_Name => "dup2";
   function c_close (FD : int) return int
     with Import, Convention => C, External_Name => "close";
   function c_read (FD : int; Buf : System.Address; Count : size_t) return ssize_t
     with Import, Convention => C, External_Name => "read";
   function c_write (FD : int; Buf : System.Address; Count : size_t) return ssize_t
     with Import, Convention => C, External_Name => "write";
   function C_Set_Winsize
     (FD : int; Rows : unsigned_short; Cols : unsigned_short) return int
     with Import, Convention => C,
          External_Name => "terminal_pty_set_winsize";
   function C_Set_Controlling_Tty (FD : int) return int
     with Import, Convention => C,
          External_Name => "terminal_pty_set_controlling_tty";
   function C_Open_Flags return int
     with Import, Convention => C,
          External_Name => "terminal_pty_open_flags";
   function C_Open_Slave
     (Path : Interfaces.C.Strings.chars_ptr) return int
     with Import, Convention => C,
          External_Name => "terminal_pty_open_slave";
   function C_Set_Nonblocking (FD : int) return int
     with Import, Convention => C,
          External_Name => "terminal_pty_set_nonblocking";
   function C_Error_Is_Interrupted return int
     with Import, Convention => C,
          External_Name => "terminal_pty_error_is_interrupted";
   function C_Error_Is_Would_Block return int
     with Import, Convention => C,
          External_Name => "terminal_pty_error_is_would_block";
   function C_Error_Is_IO return int
     with Import, Convention => C,
          External_Name => "terminal_pty_error_is_io";
   function C_Path_Is_Executable
     (Path : Interfaces.C.Strings.chars_ptr) return int
     with Import, Convention => C,
          External_Name => "terminal_pty_path_is_executable";
   function C_Wait_No_Hang
     (PID : int; Status : System.Address) return int
     with Import, Convention => C,
          External_Name => "terminal_pty_wait_nohang";
   function C_Hangup_Process_Group (PID : int) return int
     with Import, Convention => C,
          External_Name => "terminal_pty_hangup_process_group";
   function C_Kill_Process_Group (PID : int) return int
     with Import, Convention => C,
          External_Name => "terminal_pty_kill_process_group";
   function C_Wait
     (PID : int; Status : System.Address) return int
     with Import, Convention => C,
          External_Name => "terminal_pty_wait";
   function getenv (Name : Interfaces.C.Strings.chars_ptr) return Interfaces.C.Strings.chars_ptr
     with Import, Convention => C, External_Name => "getenv";
   function setenv
     (Name      : Interfaces.C.Strings.chars_ptr;
      Value     : Interfaces.C.Strings.chars_ptr;
      Overwrite : int) return int
     with Import, Convention => C, External_Name => "setenv";
   type Argv_Array is array (Positive range <>) of Interfaces.C.Strings.chars_ptr
     with Convention => C;

   function execv
     (Path : Interfaces.C.Strings.chars_ptr;
      Argv : System.Address) return int
     with Import, Convention => C, External_Name => "execv";
   procedure c_exit (Status : int)
     with Import, Convention => C, External_Name => "_exit";
   procedure Close_FD (FD : int) is
      Ignored : int;
      pragma Unreferenced (Ignored);
   begin
      Ignored := c_close (FD);
   end Close_FD;

   Trace : Spawn_Trace;

   Reads : Read_Trace;

   function Last_Spawn_Trace return Spawn_Trace is (Trace);
   function Last_Read_Trace return Read_Trace is (Reads);

   function Capabilities return Backend_Capabilities is
   begin
      return
        (POSIX_PTY        => True,
         Windows_ConPTY   => False,
         Resize           => True,
         Terminal_Env     => True,
         Nonblocking_Read => True);
   end Capabilities;

   function Backend_Status_Label
     (Capabilities : Backend_Capabilities) return String is
   begin
      if Capabilities.POSIX_PTY
        and then Capabilities.Resize
        and then Capabilities.Terminal_Env
        and then Capabilities.Nonblocking_Read
      then
         return "POSIX PTY backend with resize, env, and nonblocking read";
      else
         return "reduced POSIX PTY backend";
      end if;
   end Backend_Status_Label;

   function ConPTY_Status_Label
     (Capabilities : Backend_Capabilities) return String is
   begin
      if Capabilities.Windows_ConPTY then
         return "Windows ConPTY supported";
      else
         return "Windows ConPTY unsupported by POSIX PTY backend";
      end if;
   end ConPTY_Status_Label;

   function Decode_Exit_State (Status : int) return Exit_State is
      Low_7_Bits : constant int := Status mod 128;
   begin
      if Low_7_Bits = 0 then
         return Exited;
      elsif Low_7_Bits = 127 then
         return Still_Running;
      else
         return Signaled;
      end if;
   end Decode_Exit_State;

   function Shell_Path return String is
      Name  : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String ("SHELL");
      Value : constant Interfaces.C.Strings.chars_ptr := getenv (Name);
   begin
      Interfaces.C.Strings.Free (Name);
      if Value /= Interfaces.C.Strings.Null_Ptr then
         declare
            Candidate : constant String := Interfaces.C.Strings.Value (Value);
            C_Path : Interfaces.C.Strings.chars_ptr :=
              Interfaces.C.Strings.New_String (Candidate);
            Is_Executable : constant Boolean :=
              C_Path_Is_Executable (C_Path) /= 0;
         begin
            Interfaces.C.Strings.Free (C_Path);
            if Candidate'Length > 0 and then Is_Executable then
               return Candidate;
            end if;
         end;
      end if;

      return "/bin/sh";
   end Shell_Path;

   procedure Set_Size (FD : int; Rows : Positive; Cols : Positive; OK : out Boolean) is
   begin
      OK := C_Set_Winsize (FD, unsigned_short (Rows), unsigned_short (Cols)) = 0;
   end Set_Size;

   procedure Set_Nonblocking (FD : int) is
      Ignored : int;
      pragma Unreferenced (Ignored);
   begin
      Ignored := C_Set_Nonblocking (FD);
   end Set_Nonblocking;

   procedure Spawn_Default_Shell
     (S      : out Session;
      Rows   : Positive;
      Cols   : Positive;
      Status : out Spawn_Status;
      Features : String := Term_Features)
   is
      Master : int;
      Slave_Name : Interfaces.C.Strings.chars_ptr;
      PID : int;
      Size_OK : Boolean;
   begin
      S.Master_FD := -1;
      S.Child_PID := -1;
      S.Closed := True;
      S.Last_Status := 0;
      S.Last_State := Unknown;

      Master := posix_openpt (C_Open_Flags);
      if Master < 0 then
         Status := Open_PTY_Failed;
         return;
      end if;
      if grantpt (Master) /= 0 then
         Close_FD (Master);
         Status := GrantPT_Failed;
         return;
      end if;
      if unlockpt (Master) /= 0 then
         Close_FD (Master);
         Status := UnlockPT_Failed;
         return;
      end if;
      Slave_Name := ptsname (Master);
      if Slave_Name = Interfaces.C.Strings.Null_Ptr then
         Close_FD (Master);
         Status := PTSName_Failed;
         return;
      end if;

      Set_Size (Master, Rows, Cols, Size_OK);

      PID := fork;
      if PID < 0 then
         Close_FD (Master);
         Status := Fork_Failed;
         return;
      elsif PID = 0 then
         declare
            Slave : int;
            Shell : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String (Shell_Path);
            Term_Name : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String ("TERM");
            Term_Value : Interfaces.C.Strings.chars_ptr :=
              Interfaces.C.Strings.New_String (Terminal.PTY.Backend.Term_Name);
            Color_Name : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String ("COLORTERM");
            Color_Value : Interfaces.C.Strings.chars_ptr :=
              Interfaces.C.Strings.New_String (Terminal.PTY.Backend.Color_Term);
            Program_Name : Interfaces.C.Strings.chars_ptr :=
              Interfaces.C.Strings.New_String ("TERM_PROGRAM");
            Program_Value : Interfaces.C.Strings.chars_ptr :=
              Interfaces.C.Strings.New_String
                (Terminal.PTY.Backend.Term_Program);
            Program_Version_Name : Interfaces.C.Strings.chars_ptr :=
              Interfaces.C.Strings.New_String ("TERM_PROGRAM_VERSION");
            Program_Version_Value : Interfaces.C.Strings.chars_ptr :=
              Interfaces.C.Strings.New_String
                (Terminal.PTY.Backend.Term_Program_Version);
            Features_Name : Interfaces.C.Strings.chars_ptr :=
              Interfaces.C.Strings.New_String ("TERM_FEATURES");
            Features_Value : Interfaces.C.Strings.chars_ptr :=
              Interfaces.C.Strings.New_String (Features);
            Args : aliased Argv_Array :=
              (1 => Shell,
               2 => Interfaces.C.Strings.Null_Ptr);
            Ignored : int;
            pragma Unreferenced (Ignored);
         begin
            if setsid < 0 then
               c_exit (127);
            end if;
            Slave := C_Open_Slave (Slave_Name);
            if Slave < 0 then
               c_exit (127);
            end if;
            Ignored := C_Set_Controlling_Tty (Slave);
            Set_Size (Slave, Rows, Cols, Size_OK);
            Ignored := dup2 (Slave, STDIN_FD);
            Ignored := dup2 (Slave, STDOUT_FD);
            Ignored := dup2 (Slave, STDERR_FD);
            Close_FD (Master);
            if Slave > STDERR_FD then
               Close_FD (Slave);
            end if;
            Ignored := setenv (Term_Name, Term_Value, 1);
            Ignored := setenv (Color_Name, Color_Value, 1);
            Ignored := setenv (Program_Name, Program_Value, 1);
            Ignored := setenv
              (Program_Version_Name, Program_Version_Value, 1);
            Ignored := setenv (Features_Name, Features_Value, 1);
            Ignored := execv (Shell, Args'Address);
            c_exit (127);
         end;
      else
         Set_Nonblocking (Master);
         S.Master_FD := Integer (Master);
         S.Child_PID := Integer (PID);
         S.Closed := False;
         S.Last_State := Still_Running;
         Status := Ok;
      end if;
   end Spawn_Default_Shell;

   procedure Read
     (S      : in out Session;
      Buffer : out Terminal.Common.Bytes.Byte_Array;
      Last   : out Natural;
      Status : out Read_Status)
   is
      N : ssize_t;
   begin
      Last := 0;
      if S.Closed or else S.Master_FD < 0 then
         Status := Session_Closed;
         return;
      end if;

      N := c_read (int (S.Master_FD), Buffer'Address, size_t (Buffer'Length));
      if N > 0 then
         Last := Natural (N);
         Status := Ok;
      elsif N = 0 then
         Status := End_Of_File;
      elsif C_Error_Is_Interrupted /= 0 then
         Status := Interrupted;
      elsif C_Error_Is_Would_Block /= 0 then
         Status := Would_Block;
      elsif C_Error_Is_IO /= 0 then
         --  Linux PTY masters report EIO after the final slave closes.  It is
         --  the normal terminal end-of-file condition, not a retryable error.
         Status := End_Of_File;
      else
         Status := Failed;
      end if;
   end Read;

   procedure Write
     (S      : in out Session;
      Data   : Terminal.Common.Bytes.Byte_Array;
      Last   : out Natural;
      Status : out Write_Status)
   is
      N : ssize_t;
   begin
      Last := 0;
      if S.Closed or else S.Master_FD < 0 then
         Status := Session_Closed;
         return;
      end if;

      N := c_write (int (S.Master_FD), Data'Address, size_t (Data'Length));
      if N = ssize_t (Data'Length) then
         Last := Natural (N);
         Status := Ok;
      elsif N > 0 then
         Last := Natural (N);
         Status := Partial;
      elsif C_Error_Is_Interrupted /= 0 then
         Status := Interrupted;
      elsif C_Error_Is_Would_Block /= 0 then
         Status := Partial;
      else
         Status := Failed;
      end if;
   end Write;

   procedure Resize
     (S      : in out Session;
      Rows   : Positive;
      Cols   : Positive;
      Status : out Resize_Status)
   is
      Size_Success : Boolean;
   begin
      if S.Closed or else S.Master_FD < 0 then
         Status := Session_Closed;
         return;
      end if;
      Set_Size (int (S.Master_FD), Rows, Cols, Size_Success);
      Status := (if Size_Success then Ok else Ioctl_Failed);
   end Resize;

   procedure Remember_Exit (S : in out Session; Status : int) is
   begin
      S.Last_Status := Integer (Status);
      S.Last_State := Decode_Exit_State (Status);
   end Remember_Exit;

   function Is_Alive (S : in out Session) return Boolean is
      Status : aliased int := 0;
      R : int;
   begin
      if S.Child_PID <= 0 then
         return False;
      elsif S.Last_State in Exited | Signaled then
         return False;
      end if;
      R := C_Wait_No_Hang (int (S.Child_PID), Status'Address);
      if R = 0 then
         return True;
      elsif R > 0 then
         Remember_Exit (S, Status);
      end if;
      return False;
   end Is_Alive;

   function Child_State (S : in out Session) return Exit_State is
      Status : aliased int := 0;
      R : int;
   begin
      if S.Child_PID <= 0 then
         return Unknown;
      elsif S.Last_State in Exited | Signaled or else S.Closed then
         return S.Last_State;
      end if;

      R := C_Wait_No_Hang (int (S.Child_PID), Status'Address);
      if R = 0 then
         return Still_Running;
      elsif R > 0 then
         Remember_Exit (S, Status);
         return S.Last_State;
      else
         return Unknown;
      end if;
   end Child_State;

   function Child_Status (S : Session) return Integer is (S.Last_Status);

   procedure Close (S : in out Session) is
      Status : aliased int := 0;
      R : int;
   begin
      if S.Closed then
         return;
      end if;
      if S.Master_FD >= 0 then
         Close_FD (int (S.Master_FD));
         S.Master_FD := -1;
      end if;
      if S.Child_PID > 0 then
         if S.Last_State in Exited | Signaled then
            R := int (S.Child_PID);
         else
            R := C_Wait_No_Hang (int (S.Child_PID), Status'Address);
         end if;

         if R = 0 then
            R := C_Hangup_Process_Group (int (S.Child_PID));
            for Attempt in 1 .. 20 loop
               R := C_Wait_No_Hang (int (S.Child_PID), Status'Address);
               exit when R /= 0;
               delay 0.01;
            end loop;
         end if;

         if R = 0 then
            R := C_Kill_Process_Group (int (S.Child_PID));
            R := C_Wait (int (S.Child_PID), Status'Address);
         end if;

         if R > 0 then
            if S.Last_State not in Exited | Signaled then
               Remember_Exit (S, Status);
            end if;
         elsif S.Last_State not in Exited | Signaled then
            S.Last_State := Unknown;
         end if;
      end if;
      S.Closed := True;
   end Close;
end Terminal.PTY.Backend;

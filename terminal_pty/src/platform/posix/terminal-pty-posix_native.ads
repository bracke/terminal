with Interfaces.C;
with Interfaces.C.Strings;
with System;

private package Terminal.PTY.POSIX_Native is
   use Interfaces.C;

   subtype ssize_t is long;

   function C_Open_Master (Master_FD : access int; Flags : int) return int
     with Import, Convention => C,
          External_Name => "terminal_pty_open_master";
   function grantpt (FD : int) return int
     with Import, Convention => C, External_Name => "grantpt";
   function unlockpt (FD : int) return int
     with Import, Convention => C, External_Name => "unlockpt";
   function C_Slave_Path_Owned
     (FD     : int;
      Target : access Interfaces.C.Strings.chars_ptr) return int
     with Import, Convention => C,
          External_Name => "terminal_pty_slave_path_owned";
   procedure C_Free_String_Owned
     (Target : access Interfaces.C.Strings.chars_ptr)
     with Import, Convention => C,
          External_Name => "terminal_pty_free_string_owned";
   function c_read
     (FD : int; Buf : System.Address; Count : size_t) return ssize_t
     with Import, Convention => C, External_Name => "read";
   function c_write
     (FD : int; Buf : System.Address; Count : size_t) return ssize_t
     with Import, Convention => C, External_Name => "write";
   function tcgetpgrp (FD : int) return int
     with Import, Convention => C, External_Name => "tcgetpgrp";
   function C_Set_Winsize
     (FD : int; Rows : unsigned_short; Cols : unsigned_short) return int
     with Import, Convention => C,
          External_Name => "terminal_pty_set_winsize";
   --  The first size of a new PTY: on the master, or through the slave where
   --  the master refuses it (macOS, before the slave was ever opened).
   function C_Set_Initial_Winsize
     (Master_FD  : int;
      Slave_Path : Interfaces.C.Strings.chars_ptr;
      Rows       : unsigned_short;
      Cols       : unsigned_short) return int
     with Import, Convention => C,
          External_Name => "terminal_pty_set_initial_winsize";
   function C_Open_Flags return int
     with Import, Convention => C,
          External_Name => "terminal_pty_open_flags";
   function C_Set_Nonblocking (FD : int) return int
     with Import, Convention => C,
          External_Name => "terminal_pty_set_nonblocking";
   function C_Capture_Environment_Owned
     (Environment : access System.Address) return int
     with Import, Convention => C,
          External_Name => "terminal_pty_capture_environment_owned";
   function C_Build_Environment_Owned
     (Environment         : access System.Address;
      Base_Environment    : System.Address;
      Term_Assignment     : Interfaces.C.Strings.chars_ptr;
      Color_Assignment    : Interfaces.C.Strings.chars_ptr;
      Program_Assignment  : Interfaces.C.Strings.chars_ptr;
      Version_Assignment  : Interfaces.C.Strings.chars_ptr;
      Features_Assignment : Interfaces.C.Strings.chars_ptr)
      return int
     with Import, Convention => C,
          External_Name => "terminal_pty_build_environment_owned";
   function C_Environment_Value
     (Environment : System.Address;
      Name        : Interfaces.C.Strings.chars_ptr)
      return Interfaces.C.Strings.chars_ptr
     with Import, Convention => C,
          External_Name => "terminal_pty_environment_value";
   procedure C_Free_Environment (Environment : System.Address)
     with Import, Convention => C,
          External_Name => "terminal_pty_free_environment";
   function C_Spawn_Child
     (Child_PID      : access int;
      Master_FD      : int;
      Spawn_Read_FD  : int;
      Spawn_Write_FD : int;
      Slave_Path     : Interfaces.C.Strings.chars_ptr;
      Path           : Interfaces.C.Strings.chars_ptr;
      Argv           : System.Address;
      Environment    : System.Address) return int
     with Import, Convention => C,
          External_Name => "terminal_pty_spawn_child";
   function C_Create_Spawn_Pipe
     (Read_FD  : access int;
      Write_FD : access int) return int
     with Import, Convention => C,
          External_Name => "terminal_pty_create_spawn_pipe";
   function C_Wait_For_Child_Exec (FD : int) return int
     with Import, Convention => C,
          External_Name => "terminal_pty_wait_for_child_exec";
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
   function C_Wait_No_Hang_Owned
     (PID : access int; Status : System.Address) return int
     with Import, Convention => C,
          External_Name => "terminal_pty_wait_nohang_owned";
   function C_Close_Owned (FD : access int) return int
     with Import, Convention => C,
          External_Name => "terminal_pty_close_owned";
   function C_Hangup_Process_Group (PID : int) return int
     with Import, Convention => C,
          External_Name => "terminal_pty_hangup_process_group";
   function C_Normalize_Wait_Status (Status : int) return int
     with Import, Convention => C,
          External_Name => "terminal_pty_normalize_wait_status";

   function C_Terminate_Child_Owned
     (PID                  : access int;
      Status               : System.Address;
      Timeout_Milliseconds : unsigned) return int
     with Import, Convention => C,
          External_Name => "terminal_pty_posix_terminate_child_owned";
   function C_Handoff_Child_Owned (PID : access int) return int
     with Import, Convention => C,
          External_Name => "terminal_pty_posix_handoff_child_owned";
   procedure C_Abandon_Child_Owned (PID : access int)
     with Import, Convention => C,
          External_Name => "terminal_pty_posix_abandon_child_owned";
   procedure C_Note_Cleanup_Failure
     with Import, Convention => C,
          External_Name => "terminal_pty_posix_note_cleanup_failure";
   procedure C_Note_Cleanup_Abandoned
     with Import, Convention => C,
          External_Name => "terminal_pty_posix_note_cleanup_abandoned";
   function C_Cleanup_Failure_Count return long
     with Import, Convention => C,
          External_Name => "terminal_pty_posix_cleanup_failure_count";
   function C_Cleanup_Pending_Count return long
     with Import, Convention => C,
          External_Name => "terminal_pty_posix_cleanup_pending_count";
   function C_Cleanup_Quarantined_Count return long
     with Import, Convention => C,
          External_Name => "terminal_pty_posix_cleanup_quarantined_count";
   function C_Cleanup_Abandoned_Count return long
     with Import, Convention => C,
          External_Name => "terminal_pty_posix_cleanup_abandoned_count";
   function C_Cleanup_Is_Accepting return int
     with Import, Convention => C,
          External_Name => "terminal_pty_posix_cleanup_is_accepting";
   function C_Cleanup_Drain (Timeout_Milliseconds : unsigned) return int
     with Import, Convention => C,
          External_Name => "terminal_pty_posix_cleanup_drain";
   procedure C_Cleanup_Stop_Accepting
     with Import, Convention => C,
          External_Name => "terminal_pty_posix_cleanup_stop_accepting";
   function C_Cleanup_Drain_Closed
     (Timeout_Milliseconds : unsigned) return int
     with Import, Convention => C,
          External_Name => "terminal_pty_posix_cleanup_drain_closed";
   function C_Cleanup_Shutdown (Timeout_Milliseconds : unsigned) return int
     with Import, Convention => C,
          External_Name => "terminal_pty_posix_cleanup_shutdown";

   type Argv_Array is
     array (Positive range <>) of Interfaces.C.Strings.chars_ptr
     with Convention => C;
end Terminal.PTY.POSIX_Native;

with Ada.Finalization;
with Interfaces.C;
with Interfaces.C.Strings;
with System;

with Terminal.Common.C_Strings;
with Terminal.Common.Process_Spawning;
with Terminal.PTY.POSIX_Native;

package body Terminal.PTY.Backend is
   use Interfaces.C;
   use Interfaces.C.Strings;
   use type System.Address;
   use Terminal.PTY.POSIX_Native;

   type C_String_Guard is
     new Ada.Finalization.Limited_Controlled with record
      Value : aliased Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.Null_Ptr;
   end record;
   overriding procedure Finalize (Guard : in out C_String_Guard);

   overriding procedure Finalize (Guard : in out C_String_Guard) is
   begin
      C_Free_String_Owned (Guard.Value'Access);
   end Finalize;

   type FD_Guard is
     new Ada.Finalization.Limited_Controlled with record
      FD : aliased int := -1;
   end record;
   overriding procedure Finalize (Guard : in out FD_Guard);

   procedure Release (Guard : in out FD_Guard) is
      Result : int;
   begin
      --  The C boundary deliberately consumes the marker before close because
      --  an interrupted POSIX close has ambiguous ownership on supported BSD
      --  hosts; retrying could close a newly reused descriptor.
      Result := C_Close_Owned (Guard.FD'Access);
      if Result /= 0 then
         C_Note_Cleanup_Abandoned;
      end if;
   end Release;

   overriding procedure Finalize (Guard : in out FD_Guard) is
   begin
      Release (Guard);
   end Finalize;

   type Environment_Guard is
     new Ada.Finalization.Limited_Controlled with record
      Address : aliased System.Address := System.Null_Address;
   end record;
   overriding procedure Finalize (Guard : in out Environment_Guard);

   overriding procedure Finalize (Guard : in out Environment_Guard) is
      Owned : constant System.Address := Guard.Address;
   begin
      Guard.Address := System.Null_Address;
      if Owned /= System.Null_Address then
         C_Free_Environment (Owned);
      end if;
   end Finalize;

   type Child_Guard is
     new Ada.Finalization.Limited_Controlled with record
      PID : aliased int := -1;
   end record;
   overriding procedure Finalize (Guard : in out Child_Guard);

   protected Child_Publication_Gate is
      procedure Publish
        (S      : in out Session;
         Child  : in out Child_Guard;
         Master : in out FD_Guard;
         Status : out Spawn_Status);
      procedure Withdraw
        (S      : in out Session;
         Child  : in out Child_Guard;
         Master : in out FD_Guard);
      procedure Restore_Child
        (S     : in out Session;
         Child : in out Child_Guard);
   end Child_Publication_Gate;

   protected body Child_Publication_Gate is
      procedure Publish
        (S      : in out Session;
         Child  : in out Child_Guard;
         Master : in out FD_Guard;
         Status : out Spawn_Status) is
      begin
         if Child.PID <= 0 or else Master.FD < 0 then
            raise Program_Error with "cannot publish an incomplete PTY session";
         end if;
         S.Master_FD := Integer (Master.FD);
         S.Child_PID := Integer (Child.PID);
         S.Closed := False;
         S.Last_State := Still_Running;
         Master.FD := -1;
         Child.PID := -1;
         Status := Ok;
      end Publish;

      procedure Withdraw
        (S      : in out Session;
         Child  : in out Child_Guard;
         Master : in out FD_Guard) is
      begin
         Master.FD := int (S.Master_FD);
         Child.PID := int (S.Child_PID);
         S.Master_FD := -1;
         S.Child_PID := -1;
         S.Closed := True;
      end Withdraw;

      procedure Restore_Child
        (S     : in out Session;
         Child : in out Child_Guard) is
      begin
         if Child.PID <= 0 then
            raise Program_Error with "cannot restore an absent PTY child";
         end if;
         S.Child_PID := Integer (Child.PID);
         S.Master_FD := -1;
         S.Closed := False;
         Child.PID := -1;
      end Restore_Child;
   end Child_Publication_Gate;

   Finalizer_Wait_Milliseconds : constant unsigned := 200;

   procedure Terminate_Or_Defer
     (Child  : in out Child_Guard;
      Status : aliased in out int;
      Result : out int) is
   begin
      Result := C_Terminate_Child_Owned
        (Child.PID'Access, Status'Address, Finalizer_Wait_Milliseconds);
      if Result = 0 then
         --  A failed handoff deliberately leaves Child.PID intact so an owning
         --  session can publish it for a later retry.
         Result :=
           (if C_Handoff_Child_Owned (Child.PID'Access) /= 0 then 0 else -1);
      end if;
   end Terminate_Or_Defer;

   overriding procedure Finalize (Guard : in out Child_Guard) is
      Status : aliased int := 0;
      Result : int;
   begin
      if Guard.PID > 0 then
         Terminate_Or_Defer (Guard, Status, Result);
         if Guard.PID > 0 then
            --  A standalone guard has no enclosing session in which to retain
            --  a rejected PID. This is the final ownership sink only.
            C_Abandon_Child_Owned (Guard.PID'Access);
         end if;
      end if;
   end Finalize;

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

   function Shell_Path (Environment : System.Address) return String is
      Name  : Terminal.Common.C_Strings.Owner;
      Value : Interfaces.C.Strings.chars_ptr;
   begin
      Terminal.Common.C_Strings.Set (Name, "SHELL");
      Value := C_Environment_Value
        (Environment,
         Terminal.Common.C_Strings.Unsafe_Pointer (Name));
      if Value /= Interfaces.C.Strings.Null_Ptr then
         declare
            Candidate : constant String := Interfaces.C.Strings.Value (Value);
            C_Path : Terminal.Common.C_Strings.Owner;
            Is_Executable : Boolean;
         begin
            Terminal.Common.C_Strings.Set (C_Path, Candidate);
            Is_Executable :=
              C_Path_Is_Executable
                (Terminal.Common.C_Strings.Unsafe_Pointer (C_Path)) /= 0;
            if Candidate'Length > 0 and then Is_Executable then
               return Candidate;
            end if;
         end;
      end if;

      return "/bin/sh";
   end Shell_Path;

   function Size_Valid (Rows : Positive; Cols : Positive) return Boolean is
     (Rows <= Natural (unsigned_short'Last)
      and then Cols <= Natural (unsigned_short'Last));

   procedure Set_Size (FD : int; Rows : Positive; Cols : Positive; OK : out Boolean) is
   begin
      OK := Size_Valid (Rows, Cols)
        and then C_Set_Winsize
          (FD, unsigned_short (Rows), unsigned_short (Cols)) = 0;
   end Set_Size;

   procedure Spawn_Default_Shell
     (S      : out Session;
      Rows   : Positive;
      Cols   : Positive;
      Status : out Spawn_Status;
      Features : String := Term_Features)
   is
      Master : FD_Guard;
      Slave_Path : C_String_Guard;
      Child : Child_Guard;
      Size_OK : Boolean;
      Spawn_Read_FD : FD_Guard;
      Spawn_Write_FD : FD_Guard;
      Child_Result : int;
      Wait_Status : aliased int := 0;
      Cleanup_Result : int;
      Base_Environment : Environment_Guard;

      Child_Setup_Error : constant int := 1;
      Child_Exec_Error  : constant int := 2;
   begin
      S.Master_FD := -1;
      S.Child_PID := -1;
      S.Closed := True;
      S.Last_Status := 0;
      S.Last_State := Unknown;
      S.Spawn_Debug := (others => <>);
      S.Read_Debug := (others => <>);

      if C_Cleanup_Is_Accepting = 0 then
         Status := Cleanup_Shutdown;
         return;
      elsif not Size_Valid (Rows, Cols) then
         Status := Invalid_Size;
         return;
      end if;

      --  Snapshot construction is fallible and therefore belongs to the spawn
      --  operation, where failure can be reported through Spawn_Status. Keeping
      --  the snapshot local also makes concurrent spawns independent.
      if C_Capture_Environment_Owned
        (Base_Environment.Address'Access) /= 0
      then
         Status := Child_Setup_Failed;
         return;
      end if;

      if C_Open_Master (Master.FD'Access, C_Open_Flags) /= 0 then
         Status := Open_PTY_Failed;
         return;
      end if;
      if grantpt (Master.FD) /= 0 then
         Status := GrantPT_Failed;
         return;
      end if;
      if unlockpt (Master.FD) /= 0 then
         Status := UnlockPT_Failed;
         return;
      end if;
      if C_Slave_Path_Owned (Master.FD, Slave_Path.Value'Access) /= 0 then
         Status := PTSName_Failed;
         return;
      end if;

      Set_Size (Master.FD, Rows, Cols, Size_OK);
      if not Size_OK then
         Status := Invalid_Size;
         return;
      end if;
      if C_Set_Nonblocking (Master.FD) /= 0 then
         Status := Nonblocking_Failed;
         return;
      end if;
      --  A later tab or pane is spawned while PTY reader tasks already exist.
      --  Construct every allocation and the child environment from the
      --  immutable startup snapshot in the parent. A leaf C helper owns the
      --  complete child branch: standard
      --  descriptor operations are async-signal-safe, while the one required
      --  PTY-control ioctl relies explicitly on the allocation-free Linux/macOS
      --  kernel implementations supported by this backend.
      declare
         Shell              : Terminal.Common.C_Strings.Owner;
         Term_Assignment    : Terminal.Common.C_Strings.Owner;
         Color_Assignment   : Terminal.Common.C_Strings.Owner;
         Program_Assignment : Terminal.Common.C_Strings.Owner;
         Version_Assignment : Terminal.Common.C_Strings.Owner;
         Features_Assignment : Terminal.Common.C_Strings.Owner;
         Args : aliased Argv_Array (1 .. 2) :=
           (others => Interfaces.C.Strings.Null_Ptr);
         Environment : Environment_Guard;
         Spawn_Guard : Terminal.Common.Process_Spawning.Guard;
      begin
         Terminal.Common.C_Strings.Set
           (Shell, Shell_Path (Base_Environment.Address));
         Terminal.Common.C_Strings.Set
           (Term_Assignment, "TERM=" & Terminal.PTY.Backend.Term_Name);
         Terminal.Common.C_Strings.Set
           (Color_Assignment,
            "COLORTERM=" & Terminal.PTY.Backend.Color_Term);
         Terminal.Common.C_Strings.Set
           (Program_Assignment,
            "TERM_PROGRAM=" & Terminal.PTY.Backend.Term_Program);
         Terminal.Common.C_Strings.Set
           (Version_Assignment,
            "TERM_PROGRAM_VERSION=" & Terminal.PTY.Backend.Term_Program_Version);
         Terminal.Common.C_Strings.Set
           (Features_Assignment, "TERM_FEATURES=" & Features);
         if C_Build_Environment_Owned
           (Environment.Address'Access,
            Base_Environment.Address,
            Terminal.Common.C_Strings.Unsafe_Pointer (Term_Assignment),
            Terminal.Common.C_Strings.Unsafe_Pointer (Color_Assignment),
            Terminal.Common.C_Strings.Unsafe_Pointer (Program_Assignment),
            Terminal.Common.C_Strings.Unsafe_Pointer (Version_Assignment),
            Terminal.Common.C_Strings.Unsafe_Pointer (Features_Assignment)) /= 0
         then
            Status := Child_Setup_Failed;
            return;
         end if;
         Args :=
           (1 => Terminal.Common.C_Strings.Unsafe_Pointer (Shell),
            2 => Interfaces.C.Strings.Null_Ptr);

         --  macOS has no pipe2, so its pipe-plus-fcntl fallback must not race
         --  another process creation. Linux uses the same guard so all process
         --  creation observes one simple ordering rule.
         Terminal.Common.Process_Spawning.Acquire (Spawn_Guard);
         if C_Create_Spawn_Pipe
           (Spawn_Read_FD.FD'Access, Spawn_Write_FD.FD'Access) /= 0
         then
            Status := Child_Setup_Failed;
            return;
         end if;

         if C_Spawn_Child
           (Child.PID'Access,
            Master.FD,
            Spawn_Read_FD.FD,
            Spawn_Write_FD.FD,
            Slave_Path.Value,
            Terminal.Common.C_Strings.Unsafe_Pointer (Shell),
            Args'Address,
            Environment.Address) < 0
         then
            Release (Spawn_Read_FD);
            Release (Spawn_Write_FD);
            Status := Fork_Failed;
            return;
         end if;

         Release (Spawn_Write_FD);
         Terminal.Common.Process_Spawning.Release (Spawn_Guard);
         Child_Result := C_Wait_For_Child_Exec (Spawn_Read_FD.FD);
         Release (Spawn_Read_FD);
         if Child_Result /= 0 then
            Terminate_Or_Defer (Child, Wait_Status, Cleanup_Result);
            if Child.PID > 0 then
               Child_Publication_Gate.Restore_Child (S, Child);
            end if;
            Status :=
              (if Child_Result = Child_Exec_Error
               then Exec_Failed
               else Child_Setup_Failed);
            return;
         end if;
         Child_Publication_Gate.Publish (S, Child, Master, Status);
      exception
         when others =>
            Release (Spawn_Read_FD);
            Release (Spawn_Write_FD);
            if S.Child_PID > 0 and then not S.Closed then
               Close (S);
            end if;
            raise;
      end;
   end Spawn_Default_Shell;

   procedure Read
     (S      : in out Session;
      Buffer : out Terminal.Common.Bytes.Byte_Array;
      Count  : out Natural;
      Status : out Read_Status)
   is
      N : ssize_t;
   begin
      Count := 0;
      if S.Closed or else S.Master_FD < 0 then
         Status := Session_Closed;
         return;
      end if;

      N := c_read (int (S.Master_FD), Buffer'Address, size_t (Buffer'Length));
      if N > 0 then
         Count := Natural (N);
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
      Count  : out Natural;
      Status : out Write_Status)
   is
      N : ssize_t;
   begin
      Count := 0;
      if S.Closed or else S.Master_FD < 0 then
         Status := Session_Closed;
         return;
      end if;

      N := c_write (int (S.Master_FD), Data'Address, size_t (Data'Length));
      if N = ssize_t (Data'Length) then
         Count := Natural (N);
         Status := Ok;
      elsif N > 0 then
         Count := Natural (N);
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

      if not Size_Valid (Rows, Cols) then
         Status := Invalid_Size;
         return;
      end if;

      Set_Size (int (S.Master_FD), Rows, Cols, Size_Success);
      Status := (if Size_Success then Ok else Ioctl_Failed);
   end Resize;

   procedure Remember_Exit (S : in out Session; Status : int) is
   begin
      S.Last_Status := Integer (C_Normalize_Wait_Status (Status));
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
      if S.Last_State in Exited | Signaled then
         return S.Last_State;
      elsif S.Child_PID <= 0 or else S.Closed then
         return Unknown;
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
      Master : FD_Guard;
      Child  : Child_Guard;
   begin
      if S.Closed then
         return;
      end if;

      --  Move every native owner out of the retryable session before crossing
      --  a cancellation boundary.  The controlled guards finish cleanup if
      --  this explicit close is interrupted.
      Child_Publication_Gate.Withdraw (S, Child, Master);
      Release (Master);

      if Child.PID > 0 then
         if S.Last_State in Exited | Signaled then
            R := Child.PID;
            Child.PID := -1;
         else
            R := C_Wait_No_Hang_Owned
              (Child.PID'Access, Status'Address);
         end if;

         if R = 0 then
            R := C_Hangup_Process_Group (Child.PID);
            for Attempt in 1 .. 20 loop
               R := C_Wait_No_Hang_Owned
                 (Child.PID'Access, Status'Address);
               exit when R /= 0;
               delay 0.01;
            end loop;
         end if;

         if R = 0 then
            Terminate_Or_Defer (Child, Status, R);
         elsif R < 0 then
            C_Note_Cleanup_Abandoned;
         end if;

         if Child.PID > 0 then
            Child_Publication_Gate.Restore_Child (S, Child);
            raise Deferred_Cleanup_Unavailable with
              "POSIX child cleanup service rejected ownership";
         end if;

         if R > 0 then
            if S.Last_State not in Exited | Signaled then
               Remember_Exit (S, Status);
            end if;
         elsif S.Last_State not in Exited | Signaled then
            S.Last_State := Unknown;
         end if;
      end if;
   end Close;

   procedure Defer_Close (S : in out Session) is
      Master : FD_Guard;
      Child  : Child_Guard;
   begin
      if S.Closed then
         return;
      end if;
      Child_Publication_Gate.Withdraw (S, Child, Master);
      Release (Master);
      if Child.PID > 0
        and then C_Handoff_Child_Owned (Child.PID'Access) = 0
      then
         --  Keep the PID retryable. The master is already consumed, so the
         --  restored session permits no I/O but still owns child reaping.
         Child_Publication_Gate.Restore_Child (S, Child);
         raise Deferred_Cleanup_Unavailable with
           "POSIX child cleanup service rejected ownership";
      end if;
   end Defer_Close;

   overriding procedure Finalize (S : in out Session) is
      Master : FD_Guard;
      Child  : Child_Guard;
   begin
      Close (S);
   exception
      when others =>
         --  Close may restore a PID into S when the asynchronous service
         --  rejects it. Finalization has no later retry point, so withdraw that
         --  owner once more and consume it through the terminal sink.
         if not S.Closed then
            Child_Publication_Gate.Withdraw (S, Child, Master);
            Release (Master);
            if Child.PID > 0
              and then C_Handoff_Child_Owned (Child.PID'Access) = 0
            then
               C_Abandon_Child_Owned (Child.PID'Access);
            end if;
         end if;
         C_Note_Cleanup_Failure;
   end Finalize;

   function Counter_Value (Value : long) return Natural is
     (if Value <= 0 then 0
      elsif Value >= long (Natural'Last) then Natural'Last
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
      Complete := C_Cleanup_Drain (unsigned (Timeout_Milliseconds)) /= 0;
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
        C_Cleanup_Drain_Closed (unsigned (Timeout_Milliseconds)) /= 0;
   end Drain_Closed_Deferred_Cleanup;

   procedure Shutdown_Deferred_Cleanup
     (Timeout_Milliseconds : Natural;
      Complete             : out Boolean) is
   begin
      Complete := C_Cleanup_Shutdown (unsigned (Timeout_Milliseconds)) /= 0;
   end Shutdown_Deferred_Cleanup;
end Terminal.PTY.Backend;

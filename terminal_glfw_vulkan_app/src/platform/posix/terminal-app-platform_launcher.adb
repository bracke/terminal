with Ada.Command_Line;
with Ada.Finalization;
with Interfaces.C;
with Interfaces.C.Strings;
with System;

with GNAT.OS_Lib;
with Terminal.Common.C_Strings;
with Terminal.Common.Process_Spawning;
with Terminal.App.Child_Tracker;
with Terminal.App.Cleanup_Diagnostics;

package body Terminal.App.Platform_Launcher is
   use type Interfaces.C.int;
   use type GNAT.OS_Lib.String_Access;

   package Child_Tracker renames Terminal.App.Child_Tracker;
   --  Children whose wait status is temporarily indeterminate remain owned and
   --  polled, but do not consume the normal launch-admission quota.  The larger
   --  hard ceiling preserves bounded memory if the host wait API is persistently
   --  broken while allowing isolated failures to recover without disabling URI
   --  launching.
   Pending_Children : Child_Tracker.Registry;

   type Spawned_Child_Guard
     (Reservation : not null access Child_Tracker.Reservation) is
     new Ada.Finalization.Limited_Controlled with record
      Process : aliased Interfaces.C.int := 0;
   end record;
   overriding procedure Finalize (Guard : in out Spawned_Child_Guard);

   procedure Dispose_Child (Process : Interfaces.C.int)
     with Import, Convention => C,
          External_Name => "terminal_app_launcher_dispose_child";

   overriding procedure Finalize (Guard : in out Spawned_Child_Guard) is
   begin
      if Guard.Process > 0 and then Child_Tracker.Granted (Guard.Reservation.all)
      then
         begin
            Pending_Children.Commit
              (Child_Tracker.Process_ID (Guard.Process), Guard.Reservation.all);
         exception
            when E : others =>
               declare
                  Orphan : constant Interfaces.C.int := Guard.Process;
               begin
                  Guard.Process := 0;
                  Dispose_Child (Orphan);
               end;
               Terminal.App.Cleanup_Diagnostics.Note_Failure
                 (Terminal.App.Cleanup_Diagnostics.Platform_Launcher,
                  E,
                  "dispose untracked URI-launch child");
         end;
      end if;
      Guard.Process := 0;
   end Finalize;

   --  The shim retries EINTR while errno is still available and classifies
   --  ECHILD as already reaped. Return values are: 0 running, 1 reaped or no
   --  longer a child, 2 unexpected wait failure.
   function Poll_Child
     (Process    : Interfaces.C.int;
      Error_Code : access Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C,
          External_Name => "terminal_app_launcher_poll_child";

   type Argument_Array is
     array (Interfaces.C.size_t range <>) of aliased Interfaces.C.Strings.chars_ptr
     with Convention => C;

   Environment : System.Address
     with Import, Convention => C, External_Name => "environ";

   function Spawn_Path
     (Process      : access Interfaces.C.int;
      Path         : Interfaces.C.Strings.chars_ptr;
      File_Actions : System.Address;
      Attributes   : System.Address;
      Arguments    : System.Address;
      Environment  : System.Address) return Interfaces.C.int
     with Import, Convention => C,
          External_Name => "terminal_app_launcher_spawn";

   procedure Launch_Program
     (Program : String;
      URI     : String;
      Status  : out Launch_Status)
   is
      Program_Name : Terminal.Common.C_Strings.Owner;
      Target       : Terminal.Common.C_Strings.Owner;
      Arguments    : aliased Argument_Array (0 .. 2);
      Reservation  : aliased Child_Tracker.Reservation;
      Child        : Spawned_Child_Guard (Reservation'Access);
      Result       : Interfaces.C.int;
      Spawn_Guard  : Terminal.Common.Process_Spawning.Guard;
   begin
      Pending_Children.Reserve (Reservation);
      if not Child_Tracker.Granted (Reservation) then
         Status := Launch_Failed;
         return;
      end if;
      Terminal.Common.C_Strings.Set (Program_Name, Program);
      Terminal.Common.C_Strings.Set (Target, URI);
      Arguments :=
        (Terminal.Common.C_Strings.Unsafe_Pointer (Program_Name),
         Terminal.Common.C_Strings.Unsafe_Pointer (Target),
         Interfaces.C.Strings.Null_Ptr);
      Terminal.Common.Process_Spawning.Acquire (Spawn_Guard);
      Result :=
        Spawn_Path
          (Child.Process'Access,
           Terminal.Common.C_Strings.Unsafe_Pointer (Program_Name),
           System.Null_Address,
           System.Null_Address,
           Arguments'Address,
           Environment);
      Terminal.Common.Process_Spawning.Release (Spawn_Guard);
      if Result = 0 and then Child.Process > 0 then
         Pending_Children.Commit
           (Child_Tracker.Process_ID (Child.Process), Reservation);
         Child.Process := 0;
         Status := Opened;
      else
         Pending_Children.Cancel (Reservation);
         Status := Launch_Failed;
      end if;
   exception
      when Storage_Error =>
         Status := Launch_Failed;
      when E : others =>
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Platform_Launcher,
            E,
            "launch URI handler");
         raise;
   end Launch_Program;

   procedure Poll is
      Items      : Child_Tracker.Process_ID_Array;
      Item_Count : Natural;
      Result     : Interfaces.C.int;
      Error_Code : aliased Interfaces.C.int;
      First_Report : Boolean;
   begin
      Pending_Children.Snapshot (Items, Item_Count);
      for I in 1 .. Item_Count loop
         Error_Code := 0;
         Result := Poll_Child (Interfaces.C.int (Items (I)), Error_Code'Access);
         if Result = 1 then
            Pending_Children.Remove (Items (I));
         elsif Result = 0 then
            Pending_Children.Note_Poll_Success (Items (I));
         elsif Result = 2 then
            --  Keep ownership of a possibly live child. A later poll may
            --  recover from the host error; dropping the PID here could leave
            --  an eventual zombie that the application can no longer reap.
            Pending_Children.Note_Poll_Error
              (Items (I), First_Report);
            if First_Report then
               Terminal.App.Cleanup_Diagnostics.Note_Failure
                 (Terminal.App.Cleanup_Diagnostics.Platform_Launcher,
                  "waitpid failed with errno" &
                    Interfaces.C.int'Image (Error_Code));
            end if;
         end if;
      end loop;
   end Poll;

   function Pending_Launch_Count return Natural is
     (Pending_Children.Count);

   function Child_Tracking_Available return Boolean is (True);

   procedure Dispatch_URI
     (Preferred_Program : String;
      Fallback_Program  : String;
      URI               : String;
      Status            : out Launch_Status;
      Start             : not null access procedure
        (Program : String;
         URI     : String;
         Status  : out Launch_Status)) is separate;

   procedure Open_URI
     (URI    : String;
      Status : out Launch_Status)
   is
      Preferred : GNAT.OS_Lib.String_Access :=
        GNAT.OS_Lib.Locate_Exec_On_Path ("xdg-open");
      Fallback  : GNAT.OS_Lib.String_Access := null;
   begin
      if Preferred = null then
         Fallback := GNAT.OS_Lib.Locate_Exec_On_Path ("open");
      end if;
      Dispatch_URI
        ((if Preferred = null then "" else Preferred.all),
         (if Fallback = null then "" else Fallback.all),
         URI,
         Status,
         Launch_Program'Access);
      GNAT.OS_Lib.Free (Preferred);
      GNAT.OS_Lib.Free (Fallback);
   exception
      when Storage_Error =>
         GNAT.OS_Lib.Free (Preferred);
         GNAT.OS_Lib.Free (Fallback);
         Status := Launch_Failed;
      when E : others =>
         GNAT.OS_Lib.Free (Preferred);
         GNAT.OS_Lib.Free (Fallback);
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Platform_Launcher,
            E,
            "locate or dispatch URI handler");
         raise;
   end Open_URI;

   procedure Show_Notification
     (Title  : String;
      Message : String;
      Status : out Launch_Status)
   is
      Program : GNAT.OS_Lib.String_Access :=
        GNAT.OS_Lib.Locate_Exec_On_Path ("notify-send");
      Content : constant String :=
        (if Message'Length = 0 then Title
         elsif Title'Length = 0 then Message
         else Title & ": " & Message);
   begin
      if Program = null then
         Status := Launcher_Unavailable;
      elsif Content'Length = 0 then
         Status := Launch_Failed;
      else
         Launch_Program (Program.all, Content, Status);
      end if;
      GNAT.OS_Lib.Free (Program);
   exception
      when Storage_Error =>
         GNAT.OS_Lib.Free (Program);
         Status := Launch_Failed;
   end Show_Notification;

   procedure Open_Window
     (Workspace_Path : String;
      Status         : out Launch_Status) is
   begin
      if Workspace_Path = "" then
         Status := Launch_Failed;
      else
         Launch_Program
           (Ada.Command_Line.Command_Name,
            "--workspace=" & Workspace_Path,
            Status);
      end if;
   end Open_Window;
end Terminal.App.Platform_Launcher;

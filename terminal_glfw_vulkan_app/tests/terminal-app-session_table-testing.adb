with Ada.Unchecked_Deallocation;

package body Terminal.App.Session_Table.Testing is
   use type Runtime_Access;

   procedure Free_Test_Runtime is new Ada.Unchecked_Deallocation
     (Terminal.App.Session_Runtime.Runtime, Runtime_Access);
   procedure Retain_Test_Table_Runtime is new
     Terminal.App.Session_Runtime.Deferred_Cleanup.Retain (Runtime_Access);

   Deallocation_Count : Natural := 0;

   procedure Verify_Deferred_Feed_Status_Merge is
      use type Terminal.Core.Feed_Status;
      Status : Terminal.Core.Feed_Status := Terminal.Core.Ok;
   begin
      Merge_Feed_Status (Terminal.Core.Parser_Recovered, Status);
      if Status /= Terminal.Core.Parser_Recovered then
         raise Program_Error with
           "deferred feed status was not merged without PTY output";
      end if;
      Merge_Feed_Status (Terminal.Core.Parser_Overflow, Status);
      if Status /= Terminal.Core.Parser_Overflow then
         raise Program_Error with "stronger deferred feed status was lost";
      end if;
   end Verify_Deferred_Feed_Status_Merge;

   procedure Reject_Second_Deallocation (Item : in out Runtime_Access) is
   begin
      Deallocation_Count := Deallocation_Count + 1;
      if Deallocation_Count = 1 then
         Free_Test_Runtime (Item);
      else
         raise Storage_Error with "injected runtime deallocation failure";
      end if;
   end Reject_Second_Deallocation;

   procedure Reject_Deallocation (Item : in out Runtime_Access) is
      pragma Unreferenced (Item);
   begin
      raise Storage_Error with "injected finalizer deallocation failure";
   end Reject_Deallocation;

   procedure Verify_Close_All_Deallocation_Rollback is
      use type Terminal.App.Sessions.Session_Count;
      use type Table_Status;

      Table    : Runtime_Table;
      Status   : Table_Status;
      Rejected : Boolean := False;
   begin
      Initialize (Table, 2, 2, 0, Status);
      if Status /= Ok then
         raise Program_Error with "rollback fixture did not initialize";
      end if;
      New_Tab (Table, 2, 2, 0, Status);
      if Status /= Ok or else Count (Table) /= 2 then
         raise Program_Error with
           "multi-runtime rollback fixture did not initialize";
      end if;

      Deallocation_Count := 0;
      begin
         Close_All_Internal
           (Table,
            Raise_Errors => True,
            Deallocate   => Reject_Second_Deallocation'Access);
      exception
         when Storage_Error =>
            Rejected := True;
      end;

      if not Rejected then
         raise Program_Error with "injected deallocation failure did not propagate";
      elsif not Table.Borrows.Has_Items or else not Table.Borrows.Is_Closing then
         raise Program_Error with
           "detached runtimes were not restored under cleanup ownership";
      elsif Deallocation_Count /= 2 then
         raise Program_Error with
           "rollback failure did not follow a successful deallocation";
      elsif Count (Table) /= 2 then
         raise Program_Error with "session model changed during rollback";
      end if;

      Close_All (Table);
      if Table.Borrows.Has_Items
        or else Table.Borrows.Is_Closing
        or else Count (Table) /= 0
      then
         raise Program_Error with "cleanup retry after rollback failed";
      end if;
   end Verify_Close_All_Deallocation_Rollback;

   procedure Verify_Finalizer_Deallocation_Quarantine is
      use type Table_Status;
      Table    : Runtime_Table;
      Status   : Table_Status;
      Baseline : constant Natural := Quarantined_Runtime_Count;
      Complete : Boolean;
   begin
      Initialize (Table, 2, 2, 0, Status);
      if Status /= Ok then
         raise Program_Error with "quarantine fixture did not initialize";
      end if;
      Close_All_Internal
        (Table,
         Raise_Errors => False,
         Deallocate   => Reject_Deallocation'Access);
      if Quarantined_Runtime_Count /= Baseline + 1 then
         raise Program_Error with
           "failed finalizer deallocation was not quarantined";
      elsif Table.Borrows.Has_Items or else Table.Borrows.Is_Closing then
         raise Program_Error with
           "quarantined finalizer runtime remained registered";
      end if;
      Terminal.App.Session_Runtime.Deferred_Cleanup.Drain
        (Timeout_Milliseconds => 1_000,
         Complete             => Complete);
      if not Complete or else Quarantined_Runtime_Count /= Baseline then
         raise Program_Error with
           "deferred finalizer runtime was not released on retry";
      end if;

      --  The queue is intrusive rather than slot-based: retaining more than
      --  the former 64-owner limit must preserve every ownership transfer.
      declare
         Item : Runtime_Access;
      begin
         for Index in 1 .. 80 loop
            pragma Unreferenced (Index);
            Item := new Terminal.App.Session_Runtime.Runtime;
            Retain_Test_Table_Runtime (Item);
            if Item /= null then
               raise Program_Error with
                 "deferred runtime ownership was not transferred";
            end if;
         end loop;
      end;
      if Quarantined_Runtime_Count /= Baseline + 80 then
         raise Program_Error with
           "deferred runtime queue lost ownership beyond 64 entries";
      end if;
      Terminal.App.Session_Runtime.Deferred_Cleanup.Drain
        (Timeout_Milliseconds => 1_000,
         Complete             => Complete);
      if not Complete or else Quarantined_Runtime_Count /= Baseline then
         raise Program_Error with
           "expanded deferred runtime queue was not drained";
      end if;
   end Verify_Finalizer_Deallocation_Quarantine;
end Terminal.App.Session_Table.Testing;

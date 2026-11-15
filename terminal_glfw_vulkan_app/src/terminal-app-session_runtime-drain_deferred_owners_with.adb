separate (Terminal.App.Session_Runtime)
procedure Drain_Deferred_Owners_With
  (Timeout_Milliseconds : Natural;
   Complete             : out Boolean)
is
   use type Ada.Real_Time.Time;
   Maximum_Delay : constant Integer :=
     (if Timeout_Milliseconds > Natural (Integer'Last)
      then Integer'Last
      else Integer (Timeout_Milliseconds));
   Deadline : constant Ada.Real_Time.Time :=
     Ada.Real_Time.Clock + Ada.Real_Time.Milliseconds (Maximum_Delay);
   Drain_Guard    : Deferred_Drain_Guard;
   Resource_Lease : Deferred_Resource_Lease;
   Runtime_Lease  : Deferred_Runtime_Lease;
   Count          : Natural;
   Acquired       : Boolean := False;
   Next_Retry     : Ada.Real_Time.Time;
   Retry_After    : Ada.Real_Time.Time;
   Timed_Out      : Boolean;
   Retry_Pause    : constant Ada.Real_Time.Time_Span :=
     Ada.Real_Time.Milliseconds (10);

   procedure Note_Retry (Candidate : Ada.Real_Time.Time) is
   begin
      if Candidate < Next_Retry then
         Next_Retry := Candidate;
      end if;
   end Note_Retry;
begin
   if Deferred_Owners.Complete then
      Complete := True;
      return;
   end if;
   while not Acquired and then Ada.Real_Time.Clock < Deadline loop
      Deferred_Owners.Try_Begin_Drain (Acquired);
      if not Acquired then
         delay 0.001;
      end if;
   end loop;
   if not Acquired then
      Complete := False;
      return;
   end if;
   Drain_Guard.Active := True;

   while Ada.Real_Time.Clock < Deadline loop
      Next_Retry := Ada.Real_Time.Time_Last;
      Count := Deferred_Owners.Runtime_Count;
      for Index in 1 .. Count loop
         pragma Unreferenced (Index);
         exit when Ada.Real_Time.Clock >= Deadline;
         Deferred_Owners.Take_Runtime (Runtime_Lease);
         exit when Runtime_Lease.Item = null;
         Timed_Out := False;
         if not Deferred_Retry_Due
           (Runtime_Lease.Item.Deferred_Retry)
         then
            Note_Retry (Runtime_Lease.Item.Deferred_Retry.Retry_After);
            Deferred_Owners.Retain_Runtime (Runtime_Lease.Item);
         else
            begin
               select
                  delay until Deadline;
                  Timed_Out := True;
               then abort
                  Release_Runtime (Runtime_Lease.Item);
               end select;
            exception
               when E : others =>
                  if Runtime_Lease.Item /= null then
                     if not Runtime_Lease.Item.Deferred_Retry.Failure_Reported
                     then
                        Terminal.App.Cleanup_Diagnostics.Note_Failure
                          (Terminal.App.Cleanup_Diagnostics.Session_Runtime,
                           E,
                           "retry deferred runtime release");
                        Runtime_Lease.Item.Deferred_Retry.Failure_Reported :=
                          True;
                     end if;
                     Schedule_Deferred_Retry
                       (Runtime_Lease.Item.Deferred_Retry);
                     Note_Retry
                       (Runtime_Lease.Item.Deferred_Retry.Retry_After);
                     Deferred_Owners.Retain_Runtime (Runtime_Lease.Item);
                  else
                     Terminal.App.Cleanup_Diagnostics.Note_Failure
                       (Terminal.App.Cleanup_Diagnostics.Session_Runtime,
                        E,
                        "runtime release failed after consuming owner");
                  end if;
            end;
            if Timed_Out and then Runtime_Lease.Item /= null then
               Schedule_Deferred_Retry
                 (Runtime_Lease.Item.Deferred_Retry);
               Note_Retry
                 (Runtime_Lease.Item.Deferred_Retry.Retry_After);
               Deferred_Owners.Retain_Runtime (Runtime_Lease.Item);
            end if;
         end if;
         Finish_Lease (Runtime_Lease);
         exit when Timed_Out;
      end loop;

      exit when Ada.Real_Time.Clock >= Deadline;

      Count := Deferred_Owners.Resource_Count;
      for Index in 1 .. Count loop
         pragma Unreferenced (Index);
         exit when Ada.Real_Time.Clock >= Deadline;
         Deferred_Owners.Take_Resources (Resource_Lease);
         exit when Resource_Lease.Item = null;
         Timed_Out := False;
         if not Deferred_Retry_Due (Resource_Lease.Item.Retry) then
            Note_Retry (Resource_Lease.Item.Retry.Retry_After);
            Deferred_Owners.Retain_Resources (Resource_Lease.Item);
         else
            select
               delay until Deadline;
               Timed_Out := True;
            then abort
               Retry_Resources (Resource_Lease.Item, Retry_After);
               Note_Retry (Retry_After);
            end select;
            if Timed_Out and then Resource_Lease.Item /= null then
               Schedule_Deferred_Retry (Resource_Lease.Item.Retry);
               Note_Retry (Resource_Lease.Item.Retry.Retry_After);
               Deferred_Owners.Retain_Resources (Resource_Lease.Item);
            end if;
         end if;
         Finish_Lease (Resource_Lease);
         exit when Timed_Out;
      end loop;
      exit when Deferred_Owners.Complete;
      exit when Ada.Real_Time.Clock >= Deadline;
      declare
         Now  : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
         Wake : Ada.Real_Time.Time := Next_Retry;
      begin
         if Wake = Ada.Real_Time.Time_Last then
            Wake := Now + Retry_Pause;
         end if;
         exit when Wake >= Deadline;
         if Wake > Now then
            delay until Wake;
         end if;
      end;
   end loop;
   Complete := Deferred_Owners.Complete;
   Finish_Drain (Drain_Guard);
end Drain_Deferred_Owners_With;

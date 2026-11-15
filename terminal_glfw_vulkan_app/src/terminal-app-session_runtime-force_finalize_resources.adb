separate (Terminal.App.Session_Runtime)
procedure Force_Finalize_Resources (R : in out Runtime) is
   Accepted : Boolean;

   procedure Defer_Reader_Group is
   begin
      R.Cleanup_Ticket.Reader := R.Reader;
      R.Cleanup_Ticket.S := R.S;
      R.Cleanup_Ticket.Q := R.Q;
      R.Reader := null;
      R.S := null;
      R.Q := null;
   end Defer_Reader_Group;
begin
   --  Runtime finalization is the terminal ownership boundary.  Normal Close
   --  keeps failed resources available for an explicit retry, but a finalizer
   --  has no later owner to perform that retry.
   if R.Reader /= null then
      abort R.Reader.all;
      if R.Reader.all'Terminated then
         begin
            Free_Reader (R.Reader);
         exception
            when E : others =>
               Terminal.App.Cleanup_Diagnostics.Note_Failure
                 (Terminal.App.Cleanup_Diagnostics.Session_Runtime,
                  E,
                  "force release PTY reader task");
               Defer_Reader_Group;
         end;
      else
         Defer_Reader_Group;
      end if;
   end if;

   if R.S /= null and then R.Reader = null then
      begin
         Free_Session (R.S);
      exception
         when E : others =>
            Terminal.App.Cleanup_Diagnostics.Note_Failure
              (Terminal.App.Cleanup_Diagnostics.Session_Runtime,
               E,
               "force release PTY session");
            R.Cleanup_Ticket.S := R.S;
            R.S := null;
      end;
   end if;

   if R.Q /= null and then R.Reader = null then
      begin
         Free_Queue (R.Q);
      exception
         when E : others =>
            Terminal.App.Cleanup_Diagnostics.Note_Failure
              (Terminal.App.Cleanup_Diagnostics.Session_Runtime,
               E,
               "force release session input queue");
            R.Cleanup_Ticket.Q := R.Q;
            R.Q := null;
      end;
   end if;

   if R.T /= null then
      begin
         Free_Core (R.T);
      exception
         when E : others =>
            Terminal.App.Cleanup_Diagnostics.Note_Failure
              (Terminal.App.Cleanup_Diagnostics.Session_Runtime,
               E,
               "force release terminal core");
            R.Cleanup_Ticket.T := R.T;
            R.T := null;
      end;
   end if;

   if R.Cleanup_Ticket /= null
     and then not Empty (R.Cleanup_Ticket.all)
   then
      if R.Deferred_Admitted or else R.Cleanup_Producer_Registered then
         --  Admission closure rejects new producers, not subordinate work
         --  published by an owner that was registered before the barrier.
         Deferred_Owners.Retain_Resources (R.Cleanup_Ticket);
         Accepted := True;
      else
         Retain_Deferred_Resources (R.Cleanup_Ticket, Accepted);
      end if;
      if not Accepted then
         --  A finalizer has no caller to receive rejected ownership. Preserve
         --  it internally so a later drain can release it, while diagnosing
         --  the lifecycle-ordering violation that produced it after shutdown.
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Session_Runtime,
            "resource cleanup was produced after shutdown");
         Deferred_Owners.Retain_Resources (R.Cleanup_Ticket);
      end if;
   end if;

   R.Current_State :=
     (if Has_Resources (R) then Cleanup_Pending else Closed);
end Force_Finalize_Resources;

with Terminal.App.Session_Runtime.Deferred_Cleanup.Testing;
with Terminal.App.Session_Table;

procedure Session_Cleanup_Shutdown_Smoke is
   use type Terminal.App.Session_Table.Table_Status;
   Table  : Terminal.App.Session_Table.Runtime_Table;
   Status : Terminal.App.Session_Table.Table_Status;
begin
   --  Shutdown permanently closes this process-global cleanup service.  Keep
   --  the lifecycle boundary in its own executable so test order cannot make
   --  unrelated session tests unable to admit deferred owners.
   Terminal.App.Session_Runtime.Deferred_Cleanup.Testing
     .Verify_Shutdown_Rejection;
   Terminal.App.Session_Table.Initialize
     (Table, Rows => 1, Cols => 1, Scrollback_Limit => 0, Status => Status);
   if Status /= Terminal.App.Session_Table.Start_Failed then
      raise Program_Error with
        "post-shutdown session creation did not return Start_Failed";
   end if;
end Session_Cleanup_Shutdown_Smoke;

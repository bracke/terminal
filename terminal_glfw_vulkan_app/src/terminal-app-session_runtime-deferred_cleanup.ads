package Terminal.App.Session_Runtime.Deferred_Cleanup is
   --  Process-lifecycle ownership service for the application executable.
   --  Session_Table transfers failed Runtime deallocations here, and Runtime
   --  finalizers may add subordinate resource tickets.  Shutdown is terminal:
   --  once it begins, it rejects new owners and prevents newly created Runtime
   --  objects from starting sessions.
   Cleanup_Shutdown : exception;
   Invalid_Owner_State : exception;

   --  Retain transfers Item without allocating. Drain retries owners fairly,
   --  with per-owner backoff, until the supplied time budget expires.
   generic
      type Runtime_Owner is access all Terminal.App.Session_Runtime.Runtime;
   procedure Retain (Item : in out Runtime_Owner);
   procedure Drain
     (Timeout_Milliseconds : Natural;
      Complete             : out Boolean);
   procedure Shutdown
     (Timeout_Milliseconds : Natural;
      Complete             : out Boolean);
   function Runtime_Count return Natural;
end Terminal.App.Session_Runtime.Deferred_Cleanup;

package Terminal.App.Vulkan_Recovery is
   --  Device reconstruction is deliberately driven by the main loop rather
   --  than by Vulkan callbacks.  A failed reconstruction remains pending and
   --  is retried with a bounded exponential delay, so a transient driver or
   --  compositor failure does not terminate the terminal or spin the CPU.
   type Recovery_Reason is (No_Recovery, Device_Lost, Swapchain_Invalid);

   type Controller is private;

   type Diagnostic_Snapshot is record
      Pending              : Boolean := False;
      Reason               : Recovery_Reason := No_Recovery;
      Incidents            : Natural := 0;
      Attempts             : Natural := 0;
      Failed_Attempts      : Natural := 0;
      Successful_Recoveries : Natural := 0;
      Attempts_This_Incident : Natural := 0;
      Next_Attempt_Tick    : Natural := 0;
   end record;

   procedure Initialize (State : out Controller);

   procedure Begin_Recovery
     (State  : in out Controller;
      Reason : Recovery_Reason;
      Tick   : Natural);

   function Attempt_Due
     (State : Controller;
      Tick  : Natural) return Boolean;

   procedure Record_Attempt
     (State     : in out Controller;
      Tick      : Natural;
      Succeeded : Boolean);

   function Is_Pending (State : Controller) return Boolean;
   function Diagnostics (State : Controller) return Diagnostic_Snapshot;

private
   Maximum_Retry_Delay : constant Positive := 128;

   type Controller is record
      Data : Diagnostic_Snapshot;
   end record;
end Terminal.App.Vulkan_Recovery;

package Terminal.App.PTY_Cleanup_Lifecycle is
   type Shutdown_Result is private;
   function Complete (Result : Shutdown_Result) return Boolean;
   function Application_Complete (Result : Shutdown_Result) return Boolean;
   function Native_Complete (Result : Shutdown_Result) return Boolean;
   function Native_Admission_Closed
     (Result : Shutdown_Result) return Boolean;

   --  Result is an accumulator: Native_Admission_Closed remains set across
   --  repeated bounded shutdown attempts.
   procedure Shutdown
     (Timeout_Milliseconds : Natural;
      Result               : in out Shutdown_Result);

private
   type Shutdown_Result is record
      Application_Complete    : Boolean := False;
      Native_Complete         : Boolean := False;
      Native_Admission_Closed : Boolean := False;
   end record;
   type Admission_Backend is access procedure;
   type Shutdown_Backend is access procedure
     (Timeout_Milliseconds : Natural;
      Complete             : out Boolean);
   procedure Shutdown_With
     (Timeout_Milliseconds : Natural;
      App_Backend          : not null Shutdown_Backend;
      Backend_Stop         : not null Admission_Backend;
      Backend_Drain        : not null Shutdown_Backend;
      Backend_Shutdown     : not null Shutdown_Backend;
      Result               : in out Shutdown_Result);
end Terminal.App.PTY_Cleanup_Lifecycle;

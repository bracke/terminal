with Terminal.App.Cleanup_Diagnostics;

package body Terminal.App.PTY_Cleanup_Lifecycle.Testing is
   Backend_Called : Boolean := False;
   Shutdown_Called : Boolean := False;
   Admission_Stop_Called : Boolean := False;

   procedure Recording_Stop is
   begin
      Admission_Stop_Called := True;
   end Recording_Stop;

   procedure Failing_App_Backend
     (Timeout_Milliseconds : Natural;
      Complete             : out Boolean) is
      pragma Unreferenced (Timeout_Milliseconds, Complete);
   begin
      raise Program_Error with "injected application cleanup failure";
   end Failing_App_Backend;

   procedure Recording_Backend
     (Timeout_Milliseconds : Natural;
      Complete             : out Boolean) is
      pragma Unreferenced (Timeout_Milliseconds);
   begin
      Backend_Called := True;
      Complete := True;
   end Recording_Backend;

   procedure Recording_Shutdown
     (Timeout_Milliseconds : Natural;
      Complete             : out Boolean) is
      pragma Unreferenced (Timeout_Milliseconds);
   begin
      Shutdown_Called := True;
      Complete := True;
   end Recording_Shutdown;

   procedure Incomplete_App_Backend
     (Timeout_Milliseconds : Natural;
      Complete             : out Boolean) is
      pragma Unreferenced (Timeout_Milliseconds);
   begin
      Complete := False;
   end Incomplete_App_Backend;

   procedure Verify_Backend_After_App_Failure is
      Result : Shutdown_Result;
   begin
      Backend_Called := False;
      Shutdown_Called := False;
      Admission_Stop_Called := False;
      Shutdown_With
        (Timeout_Milliseconds => 1_000,
         App_Backend          => Failing_App_Backend'Access,
         Backend_Stop         => Recording_Stop'Access,
         Backend_Drain        => Recording_Backend'Access,
         Backend_Shutdown     => Recording_Shutdown'Access,
         Result               => Result);
      if not Backend_Called
        or else Shutdown_Called
        or else Admission_Stop_Called
        or else Application_Complete (Result)
        or else not Native_Complete (Result)
        or else Native_Admission_Closed (Result)
      then
         raise Program_Error with
           "application cleanup failure closed native cleanup admission";
      end if;
      Backend_Called := False;
      Shutdown_Called := False;
      Admission_Stop_Called := False;
      Shutdown_With
        (Timeout_Milliseconds => 1_000,
         App_Backend          => Incomplete_App_Backend'Access,
         Backend_Stop         => Recording_Stop'Access,
         Backend_Drain        => Recording_Backend'Access,
         Backend_Shutdown     => Recording_Shutdown'Access,
         Result               => Result);
      if not Backend_Called
        or else Shutdown_Called
        or else Admission_Stop_Called
        or else Application_Complete (Result)
        or else not Native_Complete (Result)
        or else Native_Admission_Closed (Result)
      then
         raise Program_Error with
           "incomplete application cleanup closed native cleanup admission";
      end if;
   end Verify_Backend_After_App_Failure;

   procedure Incomplete_Backend
     (Timeout_Milliseconds : Natural;
      Complete             : out Boolean) is
      pragma Unreferenced (Timeout_Milliseconds);
   begin
      Complete := False;
   end Incomplete_Backend;

   procedure Complete_App_Backend
     (Timeout_Milliseconds : Natural;
      Complete             : out Boolean) is
      pragma Unreferenced (Timeout_Milliseconds);
   begin
      Complete := True;
   end Complete_App_Backend;

   procedure Raising_Shutdown
     (Timeout_Milliseconds : Natural;
      Complete             : out Boolean) is
      pragma Unreferenced (Timeout_Milliseconds, Complete);
   begin
      raise Program_Error with "injected native drain failure";
   end Raising_Shutdown;

   procedure Exercise_Incomplete_Shutdown is
      Result : Shutdown_Result;
      Runtime_Failures : constant Natural :=
        Terminal.App.Cleanup_Diagnostics.Capture.Counts
          (Terminal.App.Cleanup_Diagnostics.Session_Runtime);
      PTY_Failures : constant Natural :=
        Terminal.App.Cleanup_Diagnostics.Capture.Counts
          (Terminal.App.Cleanup_Diagnostics.PTY_Backend);
   begin
      Shutdown_With
        (Timeout_Milliseconds => 0,
         App_Backend          => Complete_App_Backend'Access,
         Backend_Stop         => Recording_Stop'Access,
         Backend_Drain        => Recording_Backend'Access,
         Backend_Shutdown     => Incomplete_Backend'Access,
         Result               => Result);
      if not Application_Complete (Result)
        or else Native_Complete (Result)
        or else not Native_Admission_Closed (Result)
      then
         raise Program_Error with "incomplete native shutdown result was lost";
      end if;
      Backend_Called := False;
      Shutdown_Called := False;
      Admission_Stop_Called := False;
      Shutdown_With
        (Timeout_Milliseconds => 1_000,
         App_Backend          => Incomplete_App_Backend'Access,
         Backend_Stop         => Recording_Stop'Access,
         Backend_Drain        => Recording_Backend'Access,
         Backend_Shutdown     => Recording_Shutdown'Access,
         Result               => Result);
      if Application_Complete (Result)
        or else not Native_Complete (Result)
        or else not Native_Admission_Closed (Result)
        or else not Backend_Called
        or else Shutdown_Called
        or else Admission_Stop_Called
      then
         raise Program_Error with
           "native admission state was lost across shutdown retries";
      end if;
      if Terminal.App.Cleanup_Diagnostics.Capture.Counts
           (Terminal.App.Cleanup_Diagnostics.Session_Runtime)
           /= Runtime_Failures
        or else Terminal.App.Cleanup_Diagnostics.Capture.Counts
          (Terminal.App.Cleanup_Diagnostics.PTY_Backend) /= PTY_Failures
      then
         raise Program_Error with
           "retryable incomplete cleanup was recorded as a failure";
      end if;

      declare
         Exceptional_Result : Shutdown_Result;
      begin
         Admission_Stop_Called := False;
         Shutdown_With
           (Timeout_Milliseconds => 1_000,
            App_Backend          => Complete_App_Backend'Access,
            Backend_Stop         => Recording_Stop'Access,
            Backend_Drain        => Recording_Backend'Access,
            Backend_Shutdown     => Raising_Shutdown'Access,
            Result               => Exceptional_Result);
         if not Admission_Stop_Called
           or else not Application_Complete (Exceptional_Result)
           or else Native_Complete (Exceptional_Result)
           or else not Native_Admission_Closed (Exceptional_Result)
         then
            raise Program_Error with
              "native admission closure was lost after a drain exception";
         end if;
      end;
   end Exercise_Incomplete_Shutdown;
end Terminal.App.PTY_Cleanup_Lifecycle.Testing;

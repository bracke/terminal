with Ada.Real_Time;
with Terminal.App.Cleanup_Diagnostics;
with Terminal.App.Session_Runtime.Deferred_Cleanup;
with Terminal.PTY.Backend;

package body Terminal.App.PTY_Cleanup_Lifecycle is
   function Complete (Result : Shutdown_Result) return Boolean is
     (Result.Application_Complete
      and then Result.Native_Complete
      and then Result.Native_Admission_Closed);

   function Application_Complete
     (Result : Shutdown_Result) return Boolean is
     (Result.Application_Complete);

   function Native_Complete (Result : Shutdown_Result) return Boolean is
     (Result.Native_Complete);

   function Native_Admission_Closed
     (Result : Shutdown_Result) return Boolean is
     (Result.Native_Admission_Closed);

   procedure App_Shutdown
     (Timeout_Milliseconds : Natural;
      Complete             : out Boolean) is
   begin
      Terminal.App.Session_Runtime.Deferred_Cleanup.Shutdown
        (Timeout_Milliseconds => Timeout_Milliseconds,
         Complete             => Complete);
   end App_Shutdown;

   procedure Native_Shutdown
     (Timeout_Milliseconds : Natural;
      Complete             : out Boolean) is
   begin
      Terminal.PTY.Backend.Drain_Closed_Deferred_Cleanup
        (Timeout_Milliseconds => Timeout_Milliseconds,
         Complete             => Complete);
   end Native_Shutdown;

   procedure Native_Stop_Admission is
   begin
      Terminal.PTY.Backend.Stop_Deferred_Cleanup_Admission;
   end Native_Stop_Admission;

   procedure Native_Drain
     (Timeout_Milliseconds : Natural;
      Complete             : out Boolean) is
   begin
      Terminal.PTY.Backend.Drain_Deferred_Cleanup
        (Timeout_Milliseconds => Timeout_Milliseconds,
         Complete             => Complete);
   end Native_Drain;

   procedure Shutdown_With
     (Timeout_Milliseconds : Natural;
      App_Backend          : not null Shutdown_Backend;
      Backend_Stop         : not null Admission_Backend;
      Backend_Drain        : not null Shutdown_Backend;
      Backend_Shutdown     : not null Shutdown_Backend;
      Result               : in out Shutdown_Result)
   is
      App_Complete     : Boolean := False;
      Backend_Complete : Boolean;
      use type Ada.Real_Time.Time;
      Maximum_Delay : constant Integer :=
        (if Timeout_Milliseconds > Natural (Integer'Last)
         then Integer'Last
         else Integer (Timeout_Milliseconds));
      Deadline : constant Ada.Real_Time.Time :=
        Ada.Real_Time.Clock
        + Ada.Real_Time.Milliseconds (Maximum_Delay);

      function Remaining_Milliseconds return Natural is
         Now       : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
         Remaining : Duration;
      begin
         if Now >= Deadline then
            return 0;
         end if;
         Remaining := Ada.Real_Time.To_Duration
           (Deadline - Now) * 1_000.0;
         if Remaining >= Duration (Natural'Last) then
            return Natural'Last;
         end if;
         return Natural (Remaining);
      end Remaining_Milliseconds;
   begin
      --  Admission closure is irreversible and therefore cumulative across
      --  bounded retries. Per-attempt completion fields are refreshed.
      Result.Application_Complete := False;
      Result.Native_Complete := False;

      begin
         App_Backend.all (Remaining_Milliseconds, App_Complete);
         Result.Application_Complete := App_Complete;
      exception
         when E : others =>
            App_Complete := False;
            Result.Application_Complete := False;
            Terminal.App.Cleanup_Diagnostics.Note_Failure
              (Terminal.App.Cleanup_Diagnostics.Session_Runtime,
               E,
               "shut down deferred session ownership");
      end;

      begin
         if App_Complete then
            Backend_Stop.all;
            Result.Native_Admission_Closed := True;
            Backend_Shutdown.all
              (Remaining_Milliseconds, Backend_Complete);
         else
            --  Application owners may still publish native cleanup work.
            --  Drain current work without closing native admission.
            Backend_Drain.all (Remaining_Milliseconds, Backend_Complete);
         end if;
         Result.Native_Complete := Backend_Complete;
      exception
         when E : others =>
            Terminal.App.Cleanup_Diagnostics.Note_Failure
              (Terminal.App.Cleanup_Diagnostics.PTY_Backend,
               E,
               (if App_Complete
                then "shut down deferred PTY cleanup"
                else "drain deferred PTY cleanup"));
      end;
   end Shutdown_With;

   procedure Shutdown
     (Timeout_Milliseconds : Natural;
      Result               : in out Shutdown_Result) is
   begin
      Shutdown_With
        (Timeout_Milliseconds,
         App_Shutdown'Access,
         Native_Stop_Admission'Access,
         Native_Drain'Access,
         Native_Shutdown'Access,
         Result);
   end Shutdown;
end Terminal.App.PTY_Cleanup_Lifecycle;

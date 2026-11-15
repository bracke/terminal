with Ada.Unchecked_Deallocation;
with Ada.Real_Time;
with System;
with Terminal.App.Cleanup_Diagnostics;

package body Terminal.App.Session_Runtime.Deferred_Cleanup.Testing is
   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;
   use type System.Address;
   use type Terminal.App.Session_Runtime.Runtime_Access;
   use type Terminal.App.Session_Runtime.Deferred_Resource_Set_Access;

   type Test_Runtime_Access is access all Runtime;
   use type Test_Runtime_Access;

   procedure Retain_Test_Runtime is new Retain (Test_Runtime_Access);
   procedure Free_Injected_Runtime is new Ada.Unchecked_Deallocation
     (Runtime,
      Terminal.App.Session_Runtime.Runtime_Access);
   procedure Free_Test_Runtime is new Ada.Unchecked_Deallocation
     (Runtime,
      Test_Runtime_Access);
   procedure Free_Test_Resource_Set is new Ada.Unchecked_Deallocation
     (Deferred_Resource_Set,
      Deferred_Resource_Set_Access);

   Blocked_Address  : System.Address := System.Null_Address;
   Blocked_Attempts : Natural := 0;
   Released         : Natural := 0;
   Block_Release    : Boolean := False;
   Timed_Release    : Boolean := False;
   Release_After    : Ada.Real_Time.Time := Ada.Real_Time.Time_First;

   protected Abort_Fixture is
      procedure Reset;
      procedure Note_Release_Entered;
      entry Wait_For_Release;
      procedure Set_Waiter_Result (Complete : Boolean);
      function Waiter_Completed return Boolean;
   private
      Release_Entered : Boolean := False;
      Waiter_Result   : Boolean := False;
   end Abort_Fixture;

   protected body Abort_Fixture is
      procedure Reset is
      begin
         Release_Entered := False;
         Waiter_Result := False;
      end Reset;

      procedure Note_Release_Entered is
      begin
         Release_Entered := True;
      end Note_Release_Entered;

      entry Wait_For_Release when Release_Entered is
      begin
         null;
      end Wait_For_Release;

      procedure Set_Waiter_Result (Complete : Boolean) is
      begin
         Waiter_Result := Complete;
      end Set_Waiter_Result;

      function Waiter_Completed return Boolean is (Waiter_Result);
   end Abort_Fixture;

   procedure Release_With_Persistent_First
     (Item : in out Terminal.App.Session_Runtime.Runtime_Access) is
   begin
      if Item /= null and then Item.all'Address = Blocked_Address then
         if Block_Release
           and then Timed_Release
           and then Ada.Real_Time.Clock >= Release_After
         then
            Block_Release := False;
         end if;
         if Block_Release then
            Blocked_Attempts := Blocked_Attempts + 1;
            raise Storage_Error with "injected persistent release failure";
         end if;
      end if;
      Free_Injected_Runtime (Item);
      Released := Released + 1;
   end Release_With_Persistent_First;

   procedure Slow_Release
     (Item : in out Terminal.App.Session_Runtime.Runtime_Access) is
   begin
      Abort_Fixture.Note_Release_Entered;
      delay 10.0;
      Free_Injected_Runtime (Item);
   end Slow_Release;

   procedure Slow_Resource_Retry
     (Item        : in out Deferred_Resource_Set_Access;
      Retry_After : out Ada.Real_Time.Time) is
   begin
      Retry_After := Ada.Real_Time.Time_Last;
      delay 10.0;
      Retry_Deferred_Resources (Item, Retry_After);
   end Slow_Resource_Retry;

   procedure Drain_With_Persistent_First is new Drain_Deferred_Owners_With
     (Release_Runtime => Release_With_Persistent_First,
      Retry_Resources => Retry_Deferred_Resources);
   procedure Drain_With_Slow_Release is new Drain_Deferred_Owners_With
     (Release_Runtime => Slow_Release,
      Retry_Resources => Retry_Deferred_Resources);
   procedure Drain_With_Slow_Resource is new Drain_Deferred_Owners_With
     (Release_Runtime => Release_With_Persistent_First,
      Retry_Resources => Slow_Resource_Retry);

   procedure Verify_Retry_Schedule is
      type Delay_Array is array (Positive range <>) of Natural;
      Expected : constant Delay_Array :=
        (10, 20, 40, 80, 160, 320, 640, 1_000, 1_000);
      State : Deferred_Retry_State :=
        (Failure_Reported => True, others => <>);
      Before : Ada.Real_Time.Time;
   begin
      for Interval of Expected loop
         Before := Ada.Real_Time.Clock;
         Schedule_Deferred_Retry (State);
         if State.Delay_Milliseconds /= Interval
           or else State.Retry_After
             < Before + Ada.Real_Time.Milliseconds (Interval)
           or else not State.Failure_Reported
         then
            raise Program_Error with
              "deferred retry schedule did not grow to its time cap";
         end if;
      end loop;
   end Verify_Retry_Schedule;

   procedure Verify_Bounded_Release is
      Item     : Test_Runtime_Access := new Runtime;
      Resource : Deferred_Resource_Set_Access;
      Accepted : Boolean;
      Complete : Boolean;
      Started  : Ada.Real_Time.Time;
   begin
      Retain_Test_Runtime (Item);
      Started := Ada.Real_Time.Clock;
      Drain_With_Slow_Release
        (Timeout_Milliseconds => 50,
         Complete             => Complete);
      if Complete
        or else Ada.Real_Time.Clock - Started >= Ada.Real_Time.Seconds (1)
        or else Deferred_Runtime_Owner_Count /= 1
      then
         raise Program_Error with
           "deferred release callback escaped its drain deadline";
      end if;
      if not Deferred_Runtime_Retry_Delayed
      then
         raise Program_Error with
           "timed-out deferred release was requeued without backoff";
      end if;
      Drain (Timeout_Milliseconds => 1_000, Complete => Complete);
      if not Complete or else Deferred_Runtime_Owner_Count /= 0 then
         raise Program_Error with
           "timed-out deferred release did not preserve ownership";
      end if;

      Resource := new Deferred_Resource_Set;
      Resource.T := new Terminal.Core.Terminal;
      Retain_Deferred_Resources (Resource, Accepted);
      if not Accepted or else Resource /= null then
         raise Program_Error with
           "bounded resource fixture did not transfer ownership";
      end if;
      Started := Ada.Real_Time.Clock;
      Drain_With_Slow_Resource
        (Timeout_Milliseconds => 50,
         Complete             => Complete);
      if Complete
        or else Ada.Real_Time.Clock - Started >= Ada.Real_Time.Seconds (1)
        or else Deferred_Resource_Owner_Count /= 1
      then
         raise Program_Error with
           "deferred resource retry escaped its drain deadline";
      end if;
      Drain (Timeout_Milliseconds => 1_000, Complete => Complete);
      if not Complete or else Deferred_Resource_Owner_Count /= 0 then
         raise Program_Error with
           "timed-out resource retry did not preserve ownership";
      end if;
   end Verify_Bounded_Release;

   procedure Verify_Fair_Retry is
      Item     : Test_Runtime_Access;
      Complete : Boolean;
      Resource : Deferred_Resource_Set_Access := new Deferred_Resource_Set;
      Accepted : Boolean;
      Failures_Before : constant Natural :=
        Terminal.App.Cleanup_Diagnostics.Capture.Counts
          (Terminal.App.Cleanup_Diagnostics.Session_Runtime);
      Failures_After : Natural;
   begin
      Blocked_Attempts := 0;
      Released := 0;
      Block_Release := True;
      Timed_Release := False;

      Item := new Runtime;
      Blocked_Address := Item.all'Address;
      Retain_Test_Runtime (Item);
      for Index in 1 .. 2 loop
         pragma Unreferenced (Index);
         Item := new Runtime;
         Retain_Test_Runtime (Item);
      end loop;

      Drain_With_Persistent_First
        (Timeout_Milliseconds => 100,
         Complete             => Complete);
      if Complete
        or else Released /= 2
        or else Blocked_Attempts = 0
        or else Deferred_Runtime_Owner_Count /= 1
      then
         raise Program_Error with
           "persistent first owner prevented fair bounded retry";
      end if;

      Block_Release := True;
      Timed_Release := True;
      Release_After := Ada.Real_Time.Clock + Ada.Real_Time.Milliseconds (120);
      Drain_With_Persistent_First
        (Timeout_Milliseconds => 500,
         Complete             => Complete);
      if not Complete or else Deferred_Runtime_Owner_Count /= 0 then
         raise Program_Error with
           "drain stopped before its supplied timeout";
      end if;

      Block_Release := False;
      Timed_Release := False;
      Failures_After :=
        Terminal.App.Cleanup_Diagnostics.Capture.Counts
          (Terminal.App.Cleanup_Diagnostics.Session_Runtime);
      if Failures_Before < Natural'Last
        and then Failures_After /= Failures_Before + 1
      then
         raise Program_Error with
           "one persistent owner produced duplicate cleanup diagnostics";
      end if;

      Resource.T := new Terminal.Core.Terminal;
      Resource.Retry.Retry_After :=
        Ada.Real_Time.Clock + Ada.Real_Time.Milliseconds (30);
      Retain_Deferred_Resources (Resource, Accepted);
      if not Accepted or else Resource /= null then
         raise Program_Error with
           "resource backoff fixture did not transfer ownership";
      end if;
      Drain (Timeout_Milliseconds => 15, Complete => Complete);
      if Complete or else Deferred_Resource_Owner_Count /= 1 then
         raise Program_Error with "resource retry backoff was ignored";
      end if;
      Drain (Timeout_Milliseconds => 200, Complete => Complete);
      if not Complete or else Deferred_Resource_Owner_Count /= 0 then
         raise Program_Error with "resource backoff fixture did not drain";
      end if;
   end Verify_Fair_Retry;

   procedure Verify_Abort_And_Concurrent_Drain is
      Item : Test_Runtime_Access := new Runtime;
   begin
      Retain_Test_Runtime (Item);
      Abort_Fixture.Reset;
      declare
         task Slow_Drainer;
         task body Slow_Drainer is
            Complete : Boolean;
         begin
            Drain_With_Slow_Release
              (Timeout_Milliseconds => 10_000,
               Complete             => Complete);
         end Slow_Drainer;
      begin
         Abort_Fixture.Wait_For_Release;
         declare
            task Waiting_Drainer;
            task body Waiting_Drainer is
               Complete : Boolean;
            begin
               Drain (Timeout_Milliseconds => 2_000, Complete => Complete);
               Abort_Fixture.Set_Waiter_Result (Complete);
            end Waiting_Drainer;
         begin
            delay 0.01;
            abort Slow_Drainer;
         end;
      end;
      if not Abort_Fixture.Waiter_Completed
        or else Deferred_Runtime_Owner_Count /= 0
      then
         raise Program_Error with
           "aborted drain did not requeue for the waiting drain";
      end if;
   end Verify_Abort_And_Concurrent_Drain;

   procedure Verify_Invalid_State_Rejection is
      Item     : Test_Runtime_Access := new Runtime;
      Resourceful : Test_Runtime_Access := new Runtime;
      Rejected : Boolean := False;
   begin
      Item.Current_State := Active;
      begin
         Retain_Test_Runtime (Item);
      exception
         when Invalid_Owner_State =>
            Rejected := True;
      end;
      if not Rejected or else Item = null then
         raise Program_Error with
           "active runtime retention did not preserve caller ownership";
      end if;
      Item.Current_State := Closed;
      Free_Test_Runtime (Item);

      Resourceful.Current_State := Closed;
      Resourceful.T := new Terminal.Core.Terminal;
      Rejected := False;
      begin
         Retain_Test_Runtime (Resourceful);
      exception
         when Invalid_Owner_State =>
            Rejected := True;
      end;
      if not Rejected or else Resourceful = null then
         raise Program_Error with
           "resource-owning runtime entered nonblocking deferred release";
      end if;
      Free_Test_Runtime (Resourceful);
   end Verify_Invalid_State_Rejection;

   procedure Verify_Shutdown_Rejection is
      Admitted : Test_Runtime_Access := new Runtime;
      Item     : Test_Runtime_Access := new Runtime;
      Resources : Deferred_Resource_Set_Access := new Deferred_Resource_Set;
      Complete : Boolean;
      Rejected : Boolean := False;
      Accepted : Boolean;
      Failures_Before : Natural;
   begin
      --  A resource discovered while finalizing an already-admitted runtime
      --  is part of that ownership chain and must still drain after Shutdown
      --  closes admission to new producers.
      Admitted.Cleanup_Ticket := new Deferred_Resource_Set;
      Admitted.Cleanup_Ticket.T := new Terminal.Core.Terminal;
      Item.Cleanup_Ticket := new Deferred_Resource_Set;
      Item.Cleanup_Ticket.T := new Terminal.Core.Terminal;
      Retain_Test_Runtime (Admitted);
      Shutdown (Timeout_Milliseconds => 100, Complete => Complete);
      if Complete
        or else Deferred_Runtime_Owner_Count /= 0
        or else Deferred_Resource_Owner_Count /= 0
      then
         raise Program_Error with
           "shutdown ignored a live cleanup producer";
      end if;
      begin
         Retain_Test_Runtime (Item);
      exception
         when Cleanup_Shutdown =>
            Rejected := True;
      end;
      if not Rejected or else Item = null then
         raise Program_Error with
           "post-shutdown retention consumed its caller-owned runtime";
      end if;
      Retain_Deferred_Resources (Resources, Accepted);
      if Accepted
        or else Resources = null
        or else Deferred_Resource_Owner_Count /= 0
      then
         raise Program_Error with
           "post-shutdown resource admission consumed its caller-owned ticket";
      end if;
      Free_Test_Resource_Set (Resources);

      --  Finalizing the last registered producer may publish subordinate
      --  resources, but shutdown cannot report completion until a subsequent
      --  drain consumes them and observes that the producer count reached zero.
      Failures_Before :=
        Terminal.App.Cleanup_Diagnostics.Capture.Counts
          (Terminal.App.Cleanup_Diagnostics.Session_Runtime);
      Free_Test_Runtime (Item);
      if Item /= null or else Deferred_Resource_Owner_Count /= 1 then
         raise Program_Error with
           "post-shutdown finalizer abandoned its resource ownership";
      end if;
      if Terminal.App.Cleanup_Diagnostics.Capture.Counts
           (Terminal.App.Cleanup_Diagnostics.Session_Runtime)
        /= Failures_Before
      then
         raise Program_Error with
           "registered producer publication was diagnosed as a new admission";
      end if;
      Shutdown (Timeout_Milliseconds => 1_000, Complete => Complete);
      if not Complete or else Deferred_Resource_Owner_Count /= 0 then
         raise Program_Error with
           "post-shutdown finalizer resources could not be drained";
      end if;

      Item := new Runtime;
      if Item = null or else Item.Cleanup_Producer_Registered then
         raise Program_Error with
           "post-shutdown runtime unexpectedly registered as a producer";
      end if;
      Free_Test_Runtime (Item);
   end Verify_Shutdown_Rejection;
end Terminal.App.Session_Runtime.Deferred_Cleanup.Testing;

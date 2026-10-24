package body Terminal.App.Vulkan_Recovery is
   procedure Increment (Value : in out Natural) is
   begin
      if Value < Natural'Last then
         Value := Value + 1;
      end if;
   end Increment;

   procedure Initialize (State : out Controller) is
   begin
      State.Data := (others => <>);
   end Initialize;

   procedure Begin_Recovery
     (State  : in out Controller;
      Reason : Recovery_Reason;
      Tick   : Natural) is
   begin
      if Reason = No_Recovery then
         return;
      end if;

      if not State.Data.Pending then
         Increment (State.Data.Incidents);
         State.Data.Attempts_This_Incident := 0;
      end if;
      State.Data.Pending := True;
      State.Data.Reason := Reason;
      State.Data.Next_Attempt_Tick := Tick;
   end Begin_Recovery;

   function Attempt_Due
     (State : Controller;
      Tick  : Natural) return Boolean is
     (State.Data.Pending and then Tick >= State.Data.Next_Attempt_Tick);

   procedure Record_Attempt
     (State     : in out Controller;
      Tick      : Natural;
      Succeeded : Boolean) is
      Retry_Delay : Positive := 1;
   begin
      if not State.Data.Pending then
         return;
      end if;

      Increment (State.Data.Attempts);
      Increment (State.Data.Attempts_This_Incident);

      if Succeeded then
         Increment (State.Data.Successful_Recoveries);
         State.Data.Pending := False;
         State.Data.Reason := No_Recovery;
         State.Data.Next_Attempt_Tick := Tick;
         return;
      end if;

      Increment (State.Data.Failed_Attempts);
      --  1, 2, 4, ... 128 loop ticks (about 16 ms to 2 s in the GUI).
      for I in 2 .. State.Data.Attempts_This_Incident loop
         exit when Retry_Delay >= Maximum_Retry_Delay;
         Retry_Delay :=
           Natural'Min (Maximum_Retry_Delay, Retry_Delay * 2);
      end loop;
      if Tick > Natural'Last - Retry_Delay then
         State.Data.Next_Attempt_Tick := Natural'Last;
      else
         State.Data.Next_Attempt_Tick := Tick + Retry_Delay;
      end if;
   end Record_Attempt;

   function Is_Pending (State : Controller) return Boolean is
     (State.Data.Pending);

   function Diagnostics (State : Controller) return Diagnostic_Snapshot is
     (State.Data);
end Terminal.App.Vulkan_Recovery;

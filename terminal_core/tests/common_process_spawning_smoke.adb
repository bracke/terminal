with AUnit.Assertions;
with Terminal.Common.Process_Spawning;

procedure Common_Process_Spawning_Smoke is
   use AUnit.Assertions;
   package Spawning renames Terminal.Common.Process_Spawning;

   protected Synchronization is
      procedure Mark_Locked;
      entry Wait_Until_Locked;
      entry Wait_Forever;
      procedure Mark_Probe_Completed;
      entry Wait_For_Probe;
   private
      Locked          : Boolean := False;
      Probe_Completed : Boolean := False;
   end Synchronization;

   protected body Synchronization is
      procedure Mark_Locked is
      begin
         Locked := True;
      end Mark_Locked;

      entry Wait_Until_Locked when Locked is
      begin
         null;
      end Wait_Until_Locked;

      entry Wait_Forever when False is
      begin
         null;
      end Wait_Forever;

      procedure Mark_Probe_Completed is
      begin
         Probe_Completed := True;
      end Mark_Probe_Completed;

      entry Wait_For_Probe when Probe_Completed is
      begin
         null;
      end Wait_For_Probe;
   end Synchronization;

   task Lock_Holder;

   task body Lock_Holder is
      Lock : Spawning.Guard;
   begin
      Spawning.Acquire (Lock);
      Synchronization.Mark_Locked;
      Synchronization.Wait_Forever;
   end Lock_Holder;
begin
   Synchronization.Wait_Until_Locked;
   abort Lock_Holder;

   declare
      task Probe;
      task body Probe is
         Lock : Spawning.Guard;
      begin
         Spawning.Acquire (Lock);
         Synchronization.Mark_Probe_Completed;
      end Probe;
   begin
      select
         Synchronization.Wait_For_Probe;
      or
         delay 5.0;
         abort Probe;
         Assert (False, "an aborted owner must release the spawn gate");
      end select;
   end;
end Common_Process_Spawning_Smoke;

with Ada.Real_Time;
with AUnit.Assertions;

with Terminal.App.Output_Triggers;
with Terminal.App.Queues;
with Terminal.Common.Bytes;

procedure Output_Triggers_Smoke is
   use AUnit.Assertions;
   use type Ada.Real_Time.Time;
   package Triggers renames Terminal.App.Output_Triggers;

   Rules : Triggers.Registry;
   State : Triggers.Detector;
   Fired : Triggers.Fired_Set;
   Accepted : Boolean;
   Base : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;

   function Chunk (Text : String) return Terminal.App.Queues.Byte_Chunk is
      Result : Terminal.App.Queues.Byte_Chunk;
   begin
      Result.Length := Text'Length;
      for I in Text'Range loop
         Result.Data (I - Text'First + 1) :=
           Terminal.Common.Bytes.Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end Chunk;
begin
   Triggers.Apply (Rules, "failure", "ERROR", Accepted);
   Assert (Accepted and then Triggers.Count (Rules) = 1,
           "named output trigger is accepted");
   Triggers.Apply (Rules, "bad name", "x", Accepted);
   Assert (not Accepted, "invalid trigger name is rejected");

   Triggers.Process (State, Rules, 1, 11, Chunk ("prefix ERR"), Base, Fired);
   Assert (not Fired (1), "partial trigger does not fire");
   Triggers.Process (State, Rules, 1, 11, Chunk ("OR suffix"), Base, Fired);
   Assert (Fired (1), "trigger matches across output chunks");
   Triggers.Process (State, Rules, 1, 11, Chunk ("ERROR"), Base, Fired);
   Assert (not Fired (1), "trigger cooldown suppresses a duplicate");
   Triggers.Process
     (State, Rules, 2, 12, Chunk ("ERROR"), Base, Fired);
   Assert (Fired (1), "trigger cooldown is isolated per session");
   Triggers.Process
     (State, Rules, 1, 11, Chunk ("ERROR"),
      Base + Ada.Real_Time.Milliseconds (6_000), Fired);
   Assert (Fired (1), "trigger fires after cooldown");

   Triggers.Reset (State, 1);
   Triggers.Process (State, Rules, 1, 11, Chunk ("OR"), Base, Fired);
   Assert (not Fired (1), "reset drops partial output history");
   Triggers.Process (State, Rules, 1, 21, Chunk ("ERR"), Base, Fired);
   Triggers.Process (State, Rules, 1, 22, Chunk ("OR"), Base, Fired);
   Assert (not Fired (1), "new stream drops reused-session history");
   Triggers.Apply (Rules, "failure", "", Accepted);
   Assert (Accepted and then Triggers.Count (Rules) = 0,
           "empty pattern removes a trigger");
end Output_Triggers_Smoke;

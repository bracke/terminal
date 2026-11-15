with Ada.Finalization;

--  Serialize process creation with descriptor setup that cannot be atomic on
--  every supported POSIX host. A controlled guard makes exceptional returns
--  release the process-wide lock as well.
package Terminal.Common.Process_Spawning is
   type Guard is new Ada.Finalization.Limited_Controlled with private;

   procedure Acquire (Item : in out Guard);
   procedure Release (Item : in out Guard);

private
   type Guard is new Ada.Finalization.Limited_Controlled with record
      Held : Boolean := False;
   end record;

   overriding procedure Finalize (Item : in out Guard);
end Terminal.Common.Process_Spawning;

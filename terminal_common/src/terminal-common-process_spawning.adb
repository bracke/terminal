package body Terminal.Common.Process_Spawning is
   protected Spawn_Gate is
      entry Lock (Item : in out Guard);
      procedure Unlock (Item : in out Guard);
   private
      Locked : Boolean := False;
   end Spawn_Gate;

   protected body Spawn_Gate is
      entry Lock (Item : in out Guard) when not Locked is
      begin
         Locked := True;
         Item.Held := True;
      end Lock;

      procedure Unlock (Item : in out Guard) is
      begin
         if not Item.Held then
            return;
         end if;
         Locked := False;
         Item.Held := False;
      end Unlock;
   end Spawn_Gate;

   procedure Acquire (Item : in out Guard) is
   begin
      if not Item.Held then
         Spawn_Gate.Lock (Item);
      end if;
   end Acquire;

   procedure Release (Item : in out Guard) is
   begin
      if Item.Held then
         Spawn_Gate.Unlock (Item);
      end if;
   end Release;

   overriding procedure Finalize (Item : in out Guard) is
   begin
      Release (Item);
   end Finalize;
end Terminal.Common.Process_Spawning;

with Ada.Finalization;

package body Terminal.App.Session_Runtime.Deferred_Cleanup is
   use type Terminal.App.Session_Runtime.Runtime_Status;
   use type Terminal.App.Session_Runtime.Runtime_Access;

   procedure Retain (Item : in out Runtime_Owner) is
      type Transfer_Guard is
        new Ada.Finalization.Limited_Controlled with record
         Item   : Terminal.App.Session_Runtime.Runtime_Access := null;
         Active : Boolean := False;
      end record;
      overriding procedure Finalize (Guard : in out Transfer_Guard);

      overriding procedure Finalize (Guard : in out Transfer_Guard) is
         Accepted : Boolean;
      begin
         if Guard.Active and then Guard.Item /= null then
            Retain_Deferred_Runtime (Guard.Item, Accepted);
            if not Accepted then
               Item := Runtime_Owner (Guard.Item);
               Guard.Item := null;
            end if;
         end if;
         Guard.Active := False;
      exception
         when others =>
            if Guard.Item /= null then
               Item := Runtime_Owner (Guard.Item);
               Guard.Item := null;
            end if;
            Guard.Active := False;
      end Finalize;

      Accepted : Boolean;
      Guard    : Transfer_Guard;
   begin
      if Item /= null
        and then
          (State (Item.all) not in Inactive | Closed
           or else Has_Direct_Resources (Item.all))
      then
         raise Invalid_Owner_State with
           "only inactive or closed runtimes without live resources may be retained";
      end if;
      Guard.Item := Terminal.App.Session_Runtime.Runtime_Access (Item);
      Guard.Active := True;
      Item := null;
      Retain_Deferred_Runtime (Guard.Item, Accepted);
      if not Accepted then
         Item := Runtime_Owner (Guard.Item);
         Guard.Item := null;
         Guard.Active := False;
         raise Cleanup_Shutdown with "deferred cleanup is shut down";
      end if;
      Guard.Active := False;
   end Retain;

   procedure Drain
     (Timeout_Milliseconds : Natural;
      Complete             : out Boolean) is
   begin
      Drain_Deferred_Owners (Timeout_Milliseconds, Complete);
   end Drain;

   procedure Shutdown
     (Timeout_Milliseconds : Natural;
      Complete             : out Boolean) is
   begin
      Stop_Deferred_Owner_Admission;
      Drain_Deferred_Owners (Timeout_Milliseconds, Complete);
   end Shutdown;

   function Runtime_Count return Natural is
     (Deferred_Runtime_Owner_Count);
end Terminal.App.Session_Runtime.Deferred_Cleanup;

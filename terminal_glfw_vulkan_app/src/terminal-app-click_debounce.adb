package body Terminal.App.Click_Debounce is
   use type Ada.Real_Time.Time;

   function Accept_Event
     (Item     : in out State;
      Now      : Ada.Real_Time.Time;
      Interval : Duration) return Boolean
   is
   begin
      if Interval < 0.0 then
         raise Constraint_Error with "click debounce interval cannot be negative";
      elsif not Item.Has_Accepted
        or else Now < Item.Last_Accepted
        or else Ada.Real_Time.To_Duration (Now - Item.Last_Accepted) >= Interval
      then
         Item.Last_Accepted := Now;
         Item.Has_Accepted := True;
         return True;
      else
         return False;
      end if;
   end Accept_Event;
end Terminal.App.Click_Debounce;

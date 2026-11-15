with Ada.Real_Time;

private package Terminal.App.Click_Debounce is
   type State is limited private;

   --  Accept the first event unconditionally, then reject events occurring
   --  inside Interval after the last accepted event.
   function Accept_Event
     (Item     : in out State;
      Now      : Ada.Real_Time.Time;
      Interval : Duration) return Boolean;

private
   type State is limited record
      Last_Accepted : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Has_Accepted  : Boolean := False;
   end record;
end Terminal.App.Click_Debounce;

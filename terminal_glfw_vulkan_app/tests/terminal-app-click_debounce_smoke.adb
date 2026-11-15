with Ada.Real_Time;
with AUnit.Assertions;

with Terminal.App.Click_Debounce;

procedure Terminal.App.Click_Debounce_Smoke is
   use AUnit.Assertions;
   use type Ada.Real_Time.Time;

   Item : Terminal.App.Click_Debounce.State;
   Start : constant Ada.Real_Time.Time := Ada.Real_Time.Time_First;
begin
   Assert
     (Terminal.App.Click_Debounce.Accept_Event (Item, Start, 0.040),
      "first click is always accepted");
   Assert
     (not Terminal.App.Click_Debounce.Accept_Event
        (Item, Start + Ada.Real_Time.Milliseconds (10), 0.040),
      "click inside debounce interval is rejected");
   Assert
     (Terminal.App.Click_Debounce.Accept_Event
        (Item, Start + Ada.Real_Time.Milliseconds (40), 0.040),
      "click at debounce boundary is accepted");
end Terminal.App.Click_Debounce_Smoke;

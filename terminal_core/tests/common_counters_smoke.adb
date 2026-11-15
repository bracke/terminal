with AUnit.Assertions;
with Interfaces;
with Terminal.Common.Counters;

procedure Common_Counters_Smoke is
   use AUnit.Assertions;
   use type Interfaces.Unsigned_64;
   Value : Natural := Natural'Last - 1;
   Wide_Value : Interfaces.Unsigned_64 := Interfaces.Unsigned_64'Last - 1;
begin
   Terminal.Common.Counters.Increment_Saturating (Value);
   Assert (Value = Natural'Last, "increment reaches Natural'Last");
   Terminal.Common.Counters.Increment_Saturating (Value);
   Assert (Value = Natural'Last, "increment saturates at Natural'Last");

   Value := Natural'Last - 4;
   Terminal.Common.Counters.Add_Saturating (Value, 3);
   Assert (Value = Natural'Last - 1, "bounded addition preserves exact sums");
   Terminal.Common.Counters.Add_Saturating (Value, 2);
   Assert (Value = Natural'Last, "addition saturates on overflow");

   Terminal.Common.Counters.Increment_Saturating (Wide_Value);
   Terminal.Common.Counters.Increment_Saturating (Wide_Value);
   Assert
     (Wide_Value = Interfaces.Unsigned_64'Last,
      "wide increment saturates at Unsigned_64'Last");
   Wide_Value := Interfaces.Unsigned_64'Last - 4;
   Terminal.Common.Counters.Add_Saturating (Wide_Value, 3);
   Assert
     (Wide_Value = Interfaces.Unsigned_64'Last - 1,
      "wide bounded addition preserves exact sums");
   Terminal.Common.Counters.Add_Saturating (Wide_Value, 2);
   Assert
     (Wide_Value = Interfaces.Unsigned_64'Last,
      "wide addition saturates on overflow");
end Common_Counters_Smoke;

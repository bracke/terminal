package body Terminal.Common.Counters is
   use type Interfaces.Unsigned_64;

   procedure Increment_Saturating (Value : in out Natural) is
   begin
      if Value < Natural'Last then
         Value := Value + 1;
      end if;
   end Increment_Saturating;

   procedure Add_Saturating (Value : in out Natural; Amount : Natural) is
   begin
      if Amount > Natural'Last - Value then
         Value := Natural'Last;
      else
         Value := Value + Amount;
      end if;
   end Add_Saturating;

   procedure Increment_Saturating (Value : in out Interfaces.Unsigned_64) is
   begin
      if Value < Interfaces.Unsigned_64'Last then
         Value := Value + 1;
      end if;
   end Increment_Saturating;

   procedure Add_Saturating
     (Value  : in out Interfaces.Unsigned_64;
      Amount : Interfaces.Unsigned_64) is
   begin
      if Amount > Interfaces.Unsigned_64'Last - Value then
         Value := Interfaces.Unsigned_64'Last;
      else
         Value := Value + Amount;
      end if;
   end Add_Saturating;
end Terminal.Common.Counters;

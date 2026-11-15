package body Terminal.Common.Modular_Ordering is
   Half_Range : constant Sequence := Sequence (Sequence'Modulus / 2);
   Even_Modulus : constant Boolean := Sequence'Modulus mod 2 = 0;

   function After (Left, Right : Sequence) return Boolean is
     (Left /= Right
      and then
        (if Even_Modulus
         then Left - Right < Half_Range
         else Left - Right <= Half_Range));

   function At_Or_Before (Left, Right : Sequence) return Boolean is
     (Left = Right or else After (Right, Left));
end Terminal.Common.Modular_Ordering;

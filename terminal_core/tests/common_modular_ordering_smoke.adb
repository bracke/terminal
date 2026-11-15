with Ada.Text_IO;
with Terminal.Common.Modular_Ordering;

procedure Common_Modular_Ordering_Smoke is
   type Sequence is mod 2 ** 8;
   package Ordering is new Terminal.Common.Modular_Ordering (Sequence);

   type Odd_Sequence is mod 5;
   package Odd_Ordering is new Terminal.Common.Modular_Ordering (Odd_Sequence);

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;
begin
   Assert (Ordering.After (0, 255), "zero follows wrapped maximum");
   Assert (Ordering.After (1, 255), "one follows wrapped maximum");
   Assert (not Ordering.After (255, 0), "wrapped maximum precedes zero");
   Assert (not Ordering.After (7, 7), "equal values are not ordered after");
   Assert (Ordering.At_Or_Before (255, 0), "wrapped predecessor is before");
   Assert (Ordering.At_Or_Before (0, 0), "equal values are included");
   Assert (not Ordering.At_Or_Before (1, 0), "successor is not before");
   Assert
     (not Ordering.After (128, 0) and then not Ordering.After (0, 128),
      "half-cycle separation is unordered");
   Assert (Odd_Ordering.After (2, 0),
           "odd modulus includes its lower half-cycle boundary");
   Assert (not Odd_Ordering.After (0, 2),
           "odd modulus orders the boundary in only one direction");
   Assert (Odd_Ordering.After (0, 4),
           "odd modulus orders across rollover");
   Ada.Text_IO.Put_Line ("common modular ordering smoke: ok");
end Common_Modular_Ordering_Smoke;

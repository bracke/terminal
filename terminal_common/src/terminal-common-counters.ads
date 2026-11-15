with Interfaces;

package Terminal.Common.Counters is
   procedure Increment_Saturating (Value : in out Natural);
   procedure Add_Saturating (Value : in out Natural; Amount : Natural);
   procedure Increment_Saturating (Value : in out Interfaces.Unsigned_64);
   procedure Add_Saturating
     (Value  : in out Interfaces.Unsigned_64;
      Amount : Interfaces.Unsigned_64);
end Terminal.Common.Counters;

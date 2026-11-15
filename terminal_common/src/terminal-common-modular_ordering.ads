generic
   type Sequence is mod <>;
package Terminal.Common.Modular_Ordering is
   --  Serial-number ordering for values separated by at most half the
   --  modulus. For an even modulus, exactly half a cycle is intentionally
   --  unordered because neither direction is newer.
   function After (Left, Right : Sequence) return Boolean;
   function At_Or_Before (Left, Right : Sequence) return Boolean;
end Terminal.Common.Modular_Ordering;

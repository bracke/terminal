procedure Terminal.App.Bounded_Append
  (Items    : Element_Array_Access;
   Count    : in out Natural;
   Value    : Element_Type;
   Appended : out Boolean) is
begin
   Appended := Items /= null and then Count < Items'Length;
   if Appended then
      Items (Items'First + Count) := Value;
      Count := Count + 1;
   end if;
end Terminal.App.Bounded_Append;

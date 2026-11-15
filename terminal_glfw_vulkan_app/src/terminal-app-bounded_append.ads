generic
   type Element_Type is private;
   type Element_Array is array (Positive range <>) of Element_Type;
   type Element_Array_Access is access all Element_Array;
procedure Terminal.App.Bounded_Append
  (Items    : Element_Array_Access;
   Count    : in out Natural;
   Value    : Element_Type;
   Appended : out Boolean);

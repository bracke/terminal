package Terminal.Common.Sixel is
   pragma Pure;

   type Analysis is record
      Width           : Natural := 0;
      Height          : Natural := 0;
      Logical_Height  : Natural := 0;
      Vertical_Aspect : Positive := 1;
      Transparent     : Boolean := False;
   end record;

   function Analyze (Text : String) return Analysis;
end Terminal.Common.Sixel;

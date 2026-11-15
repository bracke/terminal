private package Terminal.Core.Graphics_Scrolling is
   procedure Reset
     (T                : in out Terminal;
      Alternate_Screen : Boolean);
   procedure Note
     (T         : in out Terminal;
      Direction : Graphics_Scroll_Direction;
      Top       : Positive;
      Bottom    : Positive;
      Count     : Positive);
end Terminal.Core.Graphics_Scrolling;

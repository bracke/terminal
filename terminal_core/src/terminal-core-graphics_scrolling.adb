package body Terminal.Core.Graphics_Scrolling is
   use type Graphics_Scroll_Event_Array_Access;
   use type Graphics_Scroll_Sequence;

   procedure Reset
     (T                : in out Terminal;
      Alternate_Screen : Boolean) is
   begin
      if Alternate_Screen then
         T.Graphics.Alternate_Scroll_Sequence := 0;
         T.Graphics.Alternate_Scroll_Head := 0;
         T.Graphics.Alternate_Scroll_Count := 0;
         if T.Graphics.Alternate_Scroll_Events /= null then
            T.Graphics.Alternate_Scroll_Events.all := (others => <>);
         end if;
      else
         T.Graphics.Primary_Scroll_Sequence := 0;
         T.Graphics.Primary_Scroll_Head := 0;
         T.Graphics.Primary_Scroll_Count := 0;
         if T.Graphics.Primary_Scroll_Events /= null then
            T.Graphics.Primary_Scroll_Events.all := (others => <>);
         end if;
      end if;
   end Reset;

   procedure Note
     (T         : in out Terminal;
      Direction : Graphics_Scroll_Direction;
      Top       : Positive;
      Bottom    : Positive;
      Count     : Positive)
   is
      Sequence : Graphics_Scroll_Sequence;
      Slot : Natural;
   begin
      if T.Graphics.Primary_Scroll_Events = null
        or else T.Graphics.Alternate_Scroll_Events = null
      then
         return;
      end if;
      if T.Active = Alternate then
         T.Graphics.Alternate_Scroll_Sequence :=
           T.Graphics.Alternate_Scroll_Sequence + 1;
         if T.Graphics.Alternate_Scroll_Sequence = 0 then
            T.Graphics.Alternate_Scroll_Sequence := 1;
         end if;
         Sequence := T.Graphics.Alternate_Scroll_Sequence;
         if T.Graphics.Alternate_Scroll_Count < Max_Graphics_Scroll_Events then
            Slot :=
              (T.Graphics.Alternate_Scroll_Head
               + T.Graphics.Alternate_Scroll_Count)
              mod Max_Graphics_Scroll_Events;
            T.Graphics.Alternate_Scroll_Count :=
              T.Graphics.Alternate_Scroll_Count + 1;
         else
            Slot := T.Graphics.Alternate_Scroll_Head;
            T.Graphics.Alternate_Scroll_Head :=
              (T.Graphics.Alternate_Scroll_Head + 1)
              mod Max_Graphics_Scroll_Events;
         end if;
         T.Graphics.Alternate_Scroll_Events (Slot + 1) :=
           (Sequence, Direction, Top, Bottom, Count);
      else
         T.Graphics.Primary_Scroll_Sequence :=
           T.Graphics.Primary_Scroll_Sequence + 1;
         if T.Graphics.Primary_Scroll_Sequence = 0 then
            T.Graphics.Primary_Scroll_Sequence := 1;
         end if;
         Sequence := T.Graphics.Primary_Scroll_Sequence;
         if T.Graphics.Primary_Scroll_Count < Max_Graphics_Scroll_Events then
            Slot :=
              (T.Graphics.Primary_Scroll_Head
               + T.Graphics.Primary_Scroll_Count)
              mod Max_Graphics_Scroll_Events;
            T.Graphics.Primary_Scroll_Count :=
              T.Graphics.Primary_Scroll_Count + 1;
         else
            Slot := T.Graphics.Primary_Scroll_Head;
            T.Graphics.Primary_Scroll_Head :=
              (T.Graphics.Primary_Scroll_Head + 1)
              mod Max_Graphics_Scroll_Events;
         end if;
         T.Graphics.Primary_Scroll_Events (Slot + 1) :=
           (Sequence, Direction, Top, Bottom, Count);
      end if;
   end Note;
end Terminal.Core.Graphics_Scrolling;

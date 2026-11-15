separate (Terminal.Core)
procedure Scroll_Down_Region
  (T      : in out Terminal;
   Top    : Positive;
   Bottom : Positive;
   Count  : Positive := 1)
is
   Cells  : constant Stored_Cell_Array_Access := Active_Cells (T);
   Height : constant Positive :=
     (if Top > Bottom then 1 else Bottom - Top + 1);
   Amount : constant Positive :=
     (if Top > Bottom then 1 else Positive'Min (Count, Height));
begin
   if Cells = null or else Top >= Bottom then
      return;
   end if;
   if Amount < Height then
      for R in reverse Top + Amount .. Bottom loop
         for C in 1 .. T.Cols loop
            Cells (Index (T, R, C)) := Cells (Index (T, R - Amount, C));
         end loop;
         Mark_Dirty (T, R);
      end loop;
   end if;
   for R in Top .. Top + Amount - 1 loop
      Clear_Row (T, R, 1, T.Cols);
   end loop;
   Note_Graphics_Scroll (T, Graphics_Scroll_Down, Top, Bottom, Amount);
end Scroll_Down_Region;

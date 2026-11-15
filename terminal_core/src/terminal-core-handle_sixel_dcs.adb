with Terminal.Common.Sixel;

separate (Terminal.Core)
procedure Handle_Sixel_DCS
  (T      : in out Terminal;
   Extent : Common.Sixel.Analysis)
is
   At_Row : constant Positive :=
     (if T.Current_Modes.Sixel_Display_Mode then 1 else T.Cursor_Row);
   At_Col : constant Positive :=
     (if T.Current_Modes.Sixel_Display_Mode then 1 else T.Cursor_Col);
begin
   Note_Graphics_Protocol
     (T,
      Graphics_Sixel,
      T.Graphics.Transfer_Length,
      T.Graphics.Transfer (1 .. T.Graphics.Transfer_Length),
      At_Row => At_Row,
      At_Col => At_Col);

   if T.Current_Modes.Sixel_Display_Mode then
      return;
   elsif T.Current_Modes.Sixel_Scrolls_Right
     and then T.Cell_Pixel_Width > 0
     and then Extent.Width > 0
     and then Extent.Width <= T.Graphics.Limits.Pixel_Dimension
   then
      declare
         Cells_Wide : constant Natural :=
           1 + (Extent.Width - 1) / T.Cell_Pixel_Width;
      begin
         T.Cursor_Col :=
           (if Cells_Wide >= T.Cols - T.Cursor_Col
            then T.Cols
            else T.Cursor_Col + Positive (Cells_Wide));
         Mark_Cursor_Move (T, T.Cursor_Row);
      end;
   elsif T.Cell_Pixel_Height > 0
     and then Extent.Height > 0
     and then Extent.Height <= T.Graphics.Limits.Pixel_Dimension
   then
      declare
         Cell_Rows : constant Natural :=
           1 + (Extent.Height - 1) / T.Cell_Pixel_Height;
      begin
         for Row in 1 .. Cell_Rows loop
            New_Line (T);
         end loop;
      end;
   end if;
end Handle_Sixel_DCS;

separate (Terminal.App.Renderer)
procedure Release_Frame (R : in out Renderer) is
begin
   Reset_Frame (R);
   R.Graphics_Event_Tracking_Failed := False;
   Free_Rectangles (R.Rectangles);
   Free_Glyphs (R.Glyphs);
   FIS.Release (R.Frame_Images);
   Free_Text_Runs (R.Text_Runs);
   Free_Colour_Glyphs (R.Colour_Glyphs);
   Free_Shaped_Run_Map (R.Shaped_Run_Map);
   VS.Release (R.Batch);
end Release_Frame;

separate (Terminal.App.Renderer)
procedure Reset_Frame (R : in out Renderer) is
begin
   --  Submission batches contain borrowed views into both frame-owned and
   --  image-store-owned buffers.  Make the batch unusable before releasing
   --  either class of storage, while retaining its reusable capacity.
   VS.Invalidate (R.Batch);
   FIS.Reset (R.Frame_Images);
   R.Rectangle_Count := 0;
   R.Glyph_Count := 0;
   R.Colour_Glyph_Count := 0;
   R.Text_Run_Count := 0;
   R.Shaped_Glyph_Count := 0;
   R.Shaping_Fallback_Count := 0;
   R.Text_Fallback_Run_Count := 0;
   R.Color_Glyph_Count := 0;
   R.Color_Emoji_Fallback_Count := 0;
   R.Paragraph_Bidi_Fallback_Count := 0;
   R.Vertex_Count := 0;
   R.Last_Cell_Count := 0;
   R.Last_Dirty_Rows := 0;
   R.Last_Frame_Width := 0;
   R.Last_Frame_Height := 0;
end Reset_Frame;

separate (Terminal.App.Renderer)
overriding procedure Finalize (R : in out Renderer) is
   Palette : Sixel_Palette_Entry_Access := R.Sixel_Palettes;
   Next : Sixel_Palette_Entry_Access;
   Cleanup_Failed : Boolean := False;

   procedure Release_Frame_Safely is
   begin
      Release_Frame (R);
   exception
      when others =>
         Cleanup_Failed := True;
   end Release_Frame_Safely;

   procedure Release_Images_Safely is
   begin
      Release_Image_Objects (R);
   exception
      when others =>
         Cleanup_Failed := True;
   end Release_Images_Safely;

   procedure Release_Events_Safely is
   begin
      Commit_Graphics_Events (R);
   exception
      when others =>
         Cleanup_Failed := True;
   end Release_Events_Safely;

   procedure Release_Text_Safely is
   begin
      Textrender.Reset (R.Text);
   exception
      when others =>
         Cleanup_Failed := True;
   end Release_Text_Safely;
begin
   if not R.Needs_Finalization then
      R.Closed := True;
      return;
   end if;
   --  Close the public state immediately, but keep the finalization guard
   --  armed until every independent cleanup step has completed.  An
   --  explicit Finalize followed by automatic finalization can therefore
   --  retry a partially failed cleanup without permitting new allocations.
   R.Closed := True;
   R.Initialized := False;
   Release_Frame_Safely;
   Release_Images_Safely;
   Release_Events_Safely;
   while Palette /= null loop
      Next := Palette.Next;
      Free_Sixel_Palette_Entry (Palette);
      Palette := Next;
   end loop;
   R.Sixel_Palettes := null;
   Release_Text_Safely;
   if Cleanup_Failed then
      Terminal.App.Cleanup_Diagnostics.Note_Failure
        (Terminal.App.Cleanup_Diagnostics.Renderer_State);
   end if;
   if not Cleanup_Failed then
      R.Needs_Finalization := False;
   end if;
   R.Has_Context := False;
   R.Text_Loaded := False;
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
   R.Missing_Glyph_Count := 0;
   R.Target_Frame_Width := 0;
   R.Target_Frame_Height := 0;
   R.Hovered_Link := (others => <>);
   R.Atlas_Dirty := False;
   R.Colour_Sheet_Dirty := False;
   R.Last_Render_Status := Not_Initialized;
exception
   when others =>
      --  Finalization must never mask the exception that caused scope
      --  unwinding.  Keep Needs_Finalization armed for a possible explicit
      --  retry, but permanently close the public object.
      R.Closed := True;
      R.Initialized := False;
      Terminal.App.Cleanup_Diagnostics.Note_Failure
        (Terminal.App.Cleanup_Diagnostics.Renderer_State);
end Finalize;

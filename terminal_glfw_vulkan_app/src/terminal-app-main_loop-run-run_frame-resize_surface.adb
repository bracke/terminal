separate (Terminal.App.Main_Loop.Run.Run_Frame)
procedure Resize_Surface is
   New_Rows : Positive;
   New_Cols : Positive;
   Core_Resize : Terminal.Core.Resize_Status;
   PTY_Resize  : Terminal.PTY.Backend.Resize_Status;
begin
   GLFW_Vulkan.Windows.Framebuffer_Size (W, FB_Width, FB_Height);
   Terminal.App.Renderer.Set_Framebuffer_Size (R, FB_Width, FB_Height);
   Configure_Active_Core;
   if FB_Width = 0 or else FB_Height = 0 then
      return;
   end if;

   Terminal.App.Resize.Pixels_To_Cells
     (FB_Width,
      FB_Height,
      Terminal.App.Renderer.Cell_Width (R),
      Terminal.App.Renderer.Cell_Height (R),
      Terminal.App.Renderer.Content_Margin,
      New_Rows,
      New_Cols);
   if New_Rows = Last_Rows and then New_Cols = Last_Cols then
      return;
   end if;

   Terminal.App.Session_Runtime.Resize
     (Active_Runtime.all, New_Rows, New_Cols, Core_Resize, PTY_Resize);
   if Core_Resize = Terminal.Core.Ok
     and then PTY_Resize = Terminal.PTY.Backend.Ok
   then
      Last_Rows := New_Rows;
      Last_Cols := New_Cols;
      Scroll_Offset := Terminal.App.Scrollback_View.Clamp_Offset
        (Active_Core.all, Scroll_Offset);
      Terminal.App.Selection.Clear (Selection);
      Apply_Hovered_Link ((others => <>));
      Dirty := True;
      Need_Redraw := True;
      Local_Redraw := True;
   end if;
end Resize_Surface;

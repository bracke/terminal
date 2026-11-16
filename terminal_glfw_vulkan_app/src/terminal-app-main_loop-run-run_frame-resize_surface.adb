separate (Terminal.App.Main_Loop.Run.Run_Frame)
procedure Resize_Surface is
   New_Rows : Positive;
   New_Cols : Positive;
   Resized : Boolean;
   procedure Clamp_Scroll (Core : in out Terminal.Core.Terminal) is
   begin
      Scroll_Offset :=
        Terminal.App.Scrollback_View.Clamp_Offset (Core, Scroll_Offset);
   end Clamp_Scroll;
begin
   GLFW_Vulkan.Windows.Framebuffer_Size (W, FB_Width, FB_Height);
   Terminal.App.Renderer.Set_Framebuffer_Size (R, FB_Width, FB_Height);
   if FB_Width = 0 or else FB_Height = 0 then
      return;
   end if;

   Terminal.App.Resize.Pixels_To_Cells
     (FB_Width,
      FB_Height,
      Terminal.App.Renderer.Cell_Width (R),
      Terminal.App.Renderer.Cell_Height (R),
      Terminal.App.Renderer.Content_Padding (R),
      New_Rows,
      New_Cols);
   if New_Rows = Last_Rows and then New_Cols = Last_Cols then
      return;
   end if;

   Resize_Visible_Runtimes (New_Rows, New_Cols, Resized);
   if Resized then
      Last_Rows := New_Rows;
      Last_Cols := New_Cols;
      Terminal.App.Session_Runtime.With_Core
        (Active_Core, Clamp_Scroll'Access);
      Terminal.App.Selection.Clear (Selection);
      Apply_Hovered_Link ((others => <>));
      Dirty := True;
      Need_Redraw := True;
      Local_Redraw := True;
   end if;
end Resize_Surface;

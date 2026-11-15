package body Terminal.App.Renderer.Frame_Geometry is
   function Origin_X (R : Renderer) return Natural is
     (R.Frame_State.Draw_Offset_X + Content_Margin);

   function Origin_Y (R : Renderer) return Natural is
     (R.Frame_State.Draw_Offset_Y + Content_Margin);
end Terminal.App.Renderer.Frame_Geometry;

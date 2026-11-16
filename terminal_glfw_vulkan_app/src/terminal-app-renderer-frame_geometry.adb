package body Terminal.App.Renderer.Frame_Geometry is
   function Origin_X (R : Renderer) return Natural is
     (R.Frame_State.Draw_Offset_X + R.View_State.Content_Padding);

   function Origin_Y (R : Renderer) return Natural is
     (R.Frame_State.Draw_Offset_Y + R.View_State.Content_Padding);
end Terminal.App.Renderer.Frame_Geometry;

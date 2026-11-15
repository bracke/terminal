private package Terminal.App.Renderer.Graphics_State_Lifecycle is
   procedure Release (Value : in out Sixel_Palette_Entry_Access);
   procedure Release (Object : in out Renderer_Graphics_State);
   procedure Finalize_Renderer (R : in out Renderer);
end Terminal.App.Renderer.Graphics_State_Lifecycle;

package body Terminal.App.Renderer is
   procedure Initialize
     (R       : out Renderer;
      Context : Terminal.App.Vulkan_Context.Context;
      Status  : out Init_Status)
   is
   begin
      if not Terminal.App.Vulkan_Context.Is_Initialized (Context) then
         R.Initialized := False;
         R.Has_Context := False;
         Status := Failed;
         return;
      end if;

      R.Initialized := True;
      R.Has_Context := True;
      R.CW := 8;
      R.CH := 16;
      Status := Ok;
   end Initialize;

   procedure Render
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot;
      Status   : out Render_Status)
   is
      pragma Unreferenced (R, Snapshot);
   begin
      Status := Ok;
   end Render;

   procedure Finalize (R : in out Renderer) is
   begin
      R.Initialized := False;
      R.Has_Context := False;
   end Finalize;

   function Cell_Width (R : Renderer) return Positive is
      pragma Unreferenced (R);
   begin
      return 8;
   end Cell_Width;

   function Cell_Height (R : Renderer) return Positive is
      pragma Unreferenced (R);
   begin
      return 16;
   end Cell_Height;
end Terminal.App.Renderer;

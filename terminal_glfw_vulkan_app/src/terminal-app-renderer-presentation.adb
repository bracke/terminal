package body Terminal.App.Renderer.Presentation is
   procedure Present
     (R         : Renderer;
      Context   : Terminal.App.Vulkan_Context.Context;
      Presenter : in out Terminal.App.Vulkan_Presenter.Presenter;
      Status    : out Terminal.App.Vulkan_Presenter.Present_Status) is
   begin
      Terminal.App.Vulkan_Presenter.Present
        (P       => Presenter,
         Context => Context,
         Batch   => R.Frame_State.Batch,
         Status  => Status);
   end Present;

   procedure Present_Retained
     (R         : Renderer;
      Context   : Terminal.App.Vulkan_Context.Context;
      Presenter : in out Terminal.App.Vulkan_Presenter.Presenter;
      Status    : out Terminal.App.Vulkan_Presenter.Present_Status) is
      pragma Unreferenced (R);
   begin
      Terminal.App.Vulkan_Presenter.Present_Retained
        (P       => Presenter,
         Context => Context,
         Status  => Status);
   end Present_Retained;
end Terminal.App.Renderer.Presentation;

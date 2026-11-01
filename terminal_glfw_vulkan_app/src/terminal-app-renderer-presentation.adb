package body Terminal.App.Renderer.Presentation is
   procedure Present
     (R         : Renderer;
      Context   : Terminal.App.Vulkan_Context.Context;
      Presenter : in out Terminal.App.Vulkan_Presenter.Presenter;
      Status    : out Terminal.App.Vulkan_Presenter.Present_Status) is
   begin
      Terminal.App.Renderer.Present (R, Context, Presenter, Status);
   end Present;

   procedure Present_Retained
     (R         : Renderer;
      Context   : Terminal.App.Vulkan_Context.Context;
      Presenter : in out Terminal.App.Vulkan_Presenter.Presenter;
      Status    : out Terminal.App.Vulkan_Presenter.Present_Status) is
   begin
      Terminal.App.Renderer.Present_Retained
        (R, Context, Presenter, Status);
   end Present_Retained;
end Terminal.App.Renderer.Presentation;

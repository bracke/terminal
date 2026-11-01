with Terminal.App.Vulkan_Context;
with Terminal.App.Vulkan_Presenter;

package Terminal.App.Renderer.Presentation is
   procedure Present
     (R         : Renderer;
      Context   : Terminal.App.Vulkan_Context.Context;
      Presenter : in out Terminal.App.Vulkan_Presenter.Presenter;
      Status    : out Terminal.App.Vulkan_Presenter.Present_Status);
   procedure Present_Retained
     (R         : Renderer;
      Context   : Terminal.App.Vulkan_Context.Context;
      Presenter : in out Terminal.App.Vulkan_Presenter.Presenter;
      Status    : out Terminal.App.Vulkan_Presenter.Present_Status);
end Terminal.App.Renderer.Presentation;

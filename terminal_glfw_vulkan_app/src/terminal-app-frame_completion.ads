with Terminal.App.Renderer;
with Terminal.App.Vulkan_Presenter;

package Terminal.App.Frame_Completion is
   type Decision is record
      Accept_Graphics : Boolean := False;
      Redraw          : Boolean := False;
      Close_Window    : Boolean := False;
   end record;

   function Decide
     (Render_Status    : Terminal.App.Renderer.Render_Status;
      Present_Status   : Terminal.App.Vulkan_Presenter.Present_Status;
      Recovery_Pending : Boolean) return Decision;
end Terminal.App.Frame_Completion;

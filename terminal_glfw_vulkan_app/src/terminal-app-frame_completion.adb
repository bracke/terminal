package body Terminal.App.Frame_Completion is
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.App.Vulkan_Presenter.Present_Action;

   function Decide
     (Render_Status    : Terminal.App.Renderer.Render_Status;
      Present_Status   : Terminal.App.Vulkan_Presenter.Present_Status;
      Recovery_Pending : Boolean) return Decision
   is
      Action : constant Terminal.App.Vulkan_Presenter.Present_Action :=
        Terminal.App.Vulkan_Presenter.Action_For (Present_Status);
   begin
      if Render_Status = Terminal.App.Renderer.Ok
        and then Action =
          Terminal.App.Vulkan_Presenter.Presentation_Complete
      then
         return (Accept_Graphics => True, others => False);
      end if;

      case Action is
         when Terminal.App.Vulkan_Presenter.Presentation_Not_Attempted =>
            return
              (if Render_Status = Terminal.App.Renderer.Allocation_Failed
               then (Redraw => True, others => False)
               else (Close_Window => True, others => False));
         when Terminal.App.Vulkan_Presenter.Retry_Frame =>
            return (Redraw => True, others => False);
         when Terminal.App.Vulkan_Presenter.Recreate_Swapchain
            | Terminal.App.Vulkan_Presenter.Recreate_Device =>
            return
              (Redraw       => Recovery_Pending,
               Close_Window => not Recovery_Pending,
               others       => False);
         when Terminal.App.Vulkan_Presenter.Await_Recovery =>
            return
              (Redraw       => Recovery_Pending,
               Close_Window => not Recovery_Pending,
               others       => False);
         when Terminal.App.Vulkan_Presenter.Fatal_Error =>
            return (Close_Window => True, others => False);
         when Terminal.App.Vulkan_Presenter.Presentation_Complete
            =>
            --  A successful presentation paired with a failed renderer, or
            --  any other inconsistent status combination, is an internal
            --  invariant violation and cannot become valid on retry.
            return (Close_Window => True, others => False);
      end case;
   end Decide;
end Terminal.App.Frame_Completion;

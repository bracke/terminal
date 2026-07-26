with Ada.Environment_Variables;
with Ada.Text_IO;
with AUnit.Assertions;

with GLFW_Vulkan;
with GLFW_Vulkan.Events;
with GLFW_Vulkan.Windows;
with Terminal.App.Renderer;
with Terminal.App.Vulkan_Context;
with Terminal.App.Vulkan_Presenter;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure GUI_Present_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type GLFW_Vulkan.Init_Status;
   use type GLFW_Vulkan.Windows.Create_Status;
   use type GLFW_Vulkan.Windows.Cursor_Status;
   use type Terminal.App.Renderer.Init_Status;
   use type Terminal.App.Renderer.Render_Status;
   use type Terminal.App.Vulkan_Context.Init_Status;
   use type Terminal.App.Vulkan_Presenter.Init_Status;
   use type Terminal.App.Vulkan_Presenter.Present_Status;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;

   Ctx : GLFW_Vulkan.Context;
   W   : GLFW_Vulkan.Windows.Window;
   Init : GLFW_Vulkan.Init_Status;
   Window_Status : GLFW_Vulkan.Windows.Create_Status;
   Vk_Ctx : Terminal.App.Vulkan_Context.Context;
   Vk_Status : Terminal.App.Vulkan_Context.Init_Status;
   Presenter : Terminal.App.Vulkan_Presenter.Presenter;
   Presenter_Status : Terminal.App.Vulkan_Presenter.Init_Status;
   R : Terminal.App.Renderer.Renderer;
   Renderer_Status : Terminal.App.Renderer.Init_Status;
   T : Terminal.Core.Terminal;
   Core_Status : Terminal.Core.Initialize_Status;
   Feed_Status : Terminal.Core.Feed_Status;
   Render_Status : Terminal.App.Renderer.Render_Status;
   Present_Status : Terminal.App.Vulkan_Presenter.Present_Status;
   FB_Width  : Natural := 0;
   FB_Height : Natural := 0;
   Cursor_Status : GLFW_Vulkan.Windows.Cursor_Status;

   function Display_Available return Boolean is
     (Ada.Environment_Variables.Exists ("DISPLAY")
      or else Ada.Environment_Variables.Exists ("WAYLAND_DISPLAY"));

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   procedure Skip (Reason : String) is
   begin
      Ada.Text_IO.Put_Line ("gui_present_smoke: skipped: " & Reason);
   end Skip;
begin
   GLFW_Vulkan.Windows.Set_Standard_Cursor
     (W, GLFW_Vulkan.Windows.Hand_Cursor, Cursor_Status);
   Assert
     (Cursor_Status = GLFW_Vulkan.Windows.Window_Invalid,
      "invalid window cursor set should be explicit");

   if not Display_Available then
      Skip ("no DISPLAY or WAYLAND_DISPLAY");
      return;
   end if;

   GLFW_Vulkan.Initialize (Ctx, Init);
   if Init /= GLFW_Vulkan.Ok then
      Skip ("GLFW init failed: " & GLFW_Vulkan.Init_Status'Image (Init));
      return;
   end if;

   GLFW_Vulkan.Windows.Create
     (Ctx, W, 320, 200, "Terminal GUI Smoke", Window_Status);
   if Window_Status /= GLFW_Vulkan.Windows.Ok then
      GLFW_Vulkan.Finalize (Ctx);
      Skip
        ("window creation failed: "
         & GLFW_Vulkan.Windows.Create_Status'Image (Window_Status));
      return;
   end if;

   GLFW_Vulkan.Events.Poll;
   Assert (GLFW_Vulkan.Windows.Is_Valid (W), "window should be valid");
   GLFW_Vulkan.Windows.Set_Standard_Cursor
     (W, GLFW_Vulkan.Windows.Hand_Cursor, Cursor_Status);
   Assert
     (Cursor_Status = GLFW_Vulkan.Windows.Ok,
      "hand cursor should be set on valid window");
   GLFW_Vulkan.Windows.Set_Standard_Cursor
     (W, GLFW_Vulkan.Windows.Default_Cursor, Cursor_Status);
   Assert
     (Cursor_Status = GLFW_Vulkan.Windows.Ok,
      "default cursor should be restored on valid window");

   Terminal.App.Vulkan_Context.Initialize (Vk_Ctx, W, Vk_Status);
   if Vk_Status /= Terminal.App.Vulkan_Context.Ok then
      GLFW_Vulkan.Windows.Destroy (W);
      GLFW_Vulkan.Finalize (Ctx);
      Skip
        ("Vulkan context init failed: "
         & Terminal.App.Vulkan_Context.Init_Status'Image (Vk_Status));
      return;
   end if;

   GLFW_Vulkan.Windows.Framebuffer_Size (W, FB_Width, FB_Height);
   if FB_Width = 0 or else FB_Height = 0 then
      Terminal.App.Vulkan_Context.Finalize (Vk_Ctx);
      GLFW_Vulkan.Windows.Destroy (W);
      GLFW_Vulkan.Finalize (Ctx);
      Skip ("zero-sized framebuffer");
      return;
   end if;

   Terminal.App.Vulkan_Presenter.Initialize
     (P              => Presenter,
      Context        => Vk_Ctx,
      Status         => Presenter_Status,
      Desired_Width  => FB_Width,
      Desired_Height => FB_Height);
   if Presenter_Status /= Terminal.App.Vulkan_Presenter.Ok then
      Terminal.App.Vulkan_Context.Finalize (Vk_Ctx);
      GLFW_Vulkan.Windows.Destroy (W);
      GLFW_Vulkan.Finalize (Ctx);
      Skip
        ("presenter init failed: "
         & Terminal.App.Vulkan_Presenter.Init_Status'Image (Presenter_Status));
      return;
   end if;

   Terminal.App.Renderer.Initialize (R, Vk_Ctx, Renderer_Status);
   Assert
     (Renderer_Status = Terminal.App.Renderer.Ok,
      "renderer should initialize with live Vulkan context");

   Terminal.App.Renderer.Set_Framebuffer_Size (R, FB_Width, FB_Height);
   Terminal.Core.Initialize (T, 4, 16, 10, Core_Status);
   Assert (Core_Status = Terminal.Core.Ok, "core should initialize");
   Terminal.Core.Feed (T, To_Bytes ("GUI smoke"), Feed_Status);
   Assert (Feed_Status = Terminal.Core.Ok, "core feed should succeed");

   declare
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      Terminal.App.Renderer.Render (R, Snap, Render_Status);
      Terminal.Core.Release (Snap);
   end;
   Assert (Render_Status = Terminal.App.Renderer.Ok, "render should succeed");
   Assert
     (Terminal.App.Renderer.Diagnostics (R).Last_Vertex_Count > 0,
      "render should produce Vulkan vertices");

   Terminal.App.Renderer.Present (R, Vk_Ctx, Presenter, Present_Status);
   Assert
     (Present_Status = Terminal.App.Vulkan_Presenter.Ok
      or else Present_Status = Terminal.App.Vulkan_Presenter.Validated_Not_Presented,
      "present should succeed or validate without presentation");

   Terminal.App.Renderer.Finalize (R);
   Terminal.App.Vulkan_Presenter.Finalize (Presenter);
   Terminal.App.Vulkan_Context.Finalize (Vk_Ctx);
   GLFW_Vulkan.Windows.Destroy (W);
   GLFW_Vulkan.Finalize (Ctx);
end GUI_Present_Smoke;

separate (Terminal.App.Main_Loop.Run)
function Start return Boolean is
begin
   Terminal.App.Vulkan_Recovery.Initialize (Vulkan_Recovery);
   GLFW_Vulkan.Initialize (Ctx, Init_Status);
   if Init_Status /= GLFW_Vulkan.Ok then
      Terminal.App.Diagnostics.Log_Startup_Failure
        ("glfw", GLFW_Vulkan.Init_Status'Image (Init_Status));
      return False;
   end if;
   GLFW_Ready := True;

   Terminal.App.Config.Load (App_Config);
   if Workspace_Override /= "" then
      declare
         Accepted : Boolean;
      begin
         Terminal.App.Config.Set_Workspace_Path
           (App_Config, Workspace_Override, Accepted);
         if not Accepted then
            Terminal.App.Diagnostics.Log_Startup_Failure
              ("workspace", "invalid workspace override");
            Shutdown;
            return False;
         end if;
      end;
   end if;
   Unbounded.Set_Unbounded_String
     (Active_Font_Path,
      (if Terminal.App.Config.Font_Path_String (App_Config)'Length = 0
       then Terminal.App.Fonts.Default_Font_Path
       else Terminal.App.Config.Font_Path_String (App_Config)));
   Active_Font_Size := App_Config.Font_Pixel_Size;
   Runtime_Graphics :=
     Terminal.App.Graphics_Profile.Create
       (App_Config.Kitty_File_Transfer,
        App_Config.Kitty_Temporary_Transfer,
        App_Config.Kitty_Shared_Memory,
        App_Config.ITerm2_File_Downloads);
   GLFW_Vulkan.Windows.Create
     (Ctx, W, App_Config.Window_Width, App_Config.Window_Height,
      "Ada Terminal", Window_Status);
   if Window_Status /= GLFW_Vulkan.Windows.Ok then
      Terminal.App.Diagnostics.Log_Startup_Failure
        ("window", GLFW_Vulkan.Windows.Create_Status'Image (Window_Status));
      Shutdown;
      return False;
   end if;
   Window_Ready := True;
   Terminal.App.Accessibility.Initialize (Accessibility, W);
   Terminal.App.Accessibility.Set_Focused (Accessibility, True);

   Terminal.App.Vulkan_Context.Initialize (Vk_Ctx, W, Vk_Status);
   if Vk_Status /= Terminal.App.Vulkan_Context.Ok then
      Terminal.App.Diagnostics.Log_Startup_Failure
        ("vulkan-context",
         Terminal.App.Vulkan_Context.Init_Status'Image (Vk_Status));
      Shutdown;
      return False;
   end if;

   GLFW_Vulkan.Windows.Framebuffer_Size (W, FB_Width, FB_Height);
   Terminal.App.Vulkan_Presenter.Initialize
     (P              => Presenter,
      Context        => Vk_Ctx,
      Status         => Presenter_Status,
      Desired_Width  => FB_Width,
      Desired_Height => FB_Height);
   if Presenter_Status /= Terminal.App.Vulkan_Presenter.Ok then
      Terminal.App.Diagnostics.Log_Startup_Failure
        ("vulkan-presenter",
         Terminal.App.Vulkan_Presenter.Init_Status'Image (Presenter_Status));
      Shutdown;
      return False;
   end if;

   Terminal.App.Renderer.Initialize
     (R,
      Vk_Ctx,
      Renderer_Status,
      Font_Path => Unbounded.To_String (Active_Font_Path),
      Font_Pixel_Size => Active_Font_Size);
   if Renderer_Status /= Terminal.App.Renderer.Ok then
      Terminal.App.Diagnostics.Log_Startup_Failure
        ("renderer", Terminal.App.Renderer.Init_Status'Image (Renderer_Status));
      Shutdown;
      return False;
   end if;
   Terminal.App.Renderer.Set_Theme
     (R, Terminal.App.Config.Active_Theme (App_Config), Theme_Status);
   if Theme_Status /= Terminal.App.Renderer.Theme_Ok then
      Terminal.App.Diagnostics.Log_Startup_Failure
        ("theme",
         Terminal.App.Renderer.Theme_Update_Status'Image (Theme_Status));
   end if;
   Terminal.App.Renderer.Graphics.Set_Access_Policy
     (R, Terminal.App.Graphics_Profile.Access_Policy (Runtime_Graphics));
   declare
      Policy : Terminal.App.ITerm2_Files.Download_Policy;
   begin
      Terminal.App.ITerm2_Files.Configure
        (Policy,
         Terminal.App.Graphics_Profile.Downloads_Enabled (Runtime_Graphics),
         Terminal.App.ITerm2_Files.Default_Download_Directory);
      Terminal.App.Renderer.Graphics.Set_ITerm2_Download_Policy (R, Policy);
   end;
   declare
      Limit_Status :
        Terminal.App.Renderer.Graphics.Resource_Limit_Update_Status;
   begin
      Terminal.App.Renderer.Graphics.Set_Resource_Limits
        (R,
         (Image_Objects => App_Config.Graphics_Image_Objects,
          Image_Bytes => App_Config.Graphics_Image_Bytes,
          Placements => App_Config.Graphics_Placements,
          Animation_Frames => App_Config.Graphics_Animation_Frames,
          Per_Image_Bytes => App_Config.Graphics_Per_Image_Bytes,
          Theme_Transaction_Bytes => App_Config.Graphics_Image_Bytes * 4,
          Pixel_Dimension => App_Config.Graphics_Pixel_Dimension,
          GPU_Atlas_Bytes => App_Config.Graphics_GPU_Atlas_Bytes,
          GPU_Atlas_Dimension => App_Config.Graphics_GPU_Atlas_Dimension),
         Limit_Status);
      if Limit_Status /= Terminal.App.Renderer.Graphics.Limits_Applied then
         Terminal.App.Diagnostics.Log_Startup_Failure
           ("graphics limits", "existing resources exceed configured limits");
      end if;
   end;

   Terminal.App.Resize.Startup_Cells
     (Pixel_Width  => FB_Width,
      Pixel_Height => FB_Height,
      Cell_Width   => Terminal.App.Renderer.Cell_Width (R),
      Cell_Height  => Terminal.App.Renderer.Cell_Height (R),
      Margin       => Terminal.App.Renderer.Content_Margin,
      Default_Rows => App_Config.Startup_Rows,
      Default_Cols => App_Config.Startup_Cols,
      Rows         => Initial_Rows,
      Cols         => Initial_Cols);
   Last_Rows := Initial_Rows;
   Last_Cols := Initial_Cols;
   Terminal.App.Session_Table.Initialize
     (Sessions,
      Initial_Rows,
      Initial_Cols,
      App_Config.Scrollback_Limit,
      Session_Table_Status,
      Graphics_Profile =>
        Terminal.App.Graphics_Profile.Core_Capabilities (Runtime_Graphics));
   if Session_Table_Status /= Terminal.App.Session_Table.Ok then
      Terminal.App.Diagnostics.Log_Startup_Failure
        ("session-table",
         Terminal.App.Session_Table.Table_Status'Image
           (Session_Table_Status));
      Shutdown;
      return False;
   end if;
   Sessions_Ready := True;
   Restore_Workspace;
   Configure_Visible_Cores;
   return True;
end Start;

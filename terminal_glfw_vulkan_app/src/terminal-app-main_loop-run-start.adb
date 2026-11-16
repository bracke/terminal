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
   Protected_Input := App_Config.Protected_Input;
   System_Preference :=
     (if App_Config.Follow_System_Theme
      then Terminal.App.System_Theme.Current
      else Terminal.App.System_Theme.Unknown);
   Last_System_Theme_Check := Ada.Real_Time.Clock;
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
   declare
      IME_Status : Terminal.App.Platform_IME.Install_Status;
   begin
      Terminal.App.Platform_IME.Initialize
        (GLFW_Vulkan.Windows.Native_Handle (W), IME_Status);
      if IME_Status = Terminal.App.Platform_IME.Install_Failed then
         Terminal.App.Diagnostics.Log_Startup_Failure
           ("ime", "native input-method initialization failed");
      end if;
   end;
   declare
      Drop_Status : Terminal.App.File_Drop.Install_Status;
   begin
      Terminal.App.File_Drop.Initialize
        (GLFW_Vulkan.Windows.Native_Handle (W), Drop_Status);
      if Drop_Status /= Terminal.App.File_Drop.Installed then
         Terminal.App.Diagnostics.Log_Startup_Failure
           ("file-drop", "native file-drop callback unavailable");
      end if;
   end;
   declare
      Status : GLFW_Vulkan.Windows.Property_Status;
      Blur_Status : Terminal.App.Platform_Appearance.Blur_Status;
   begin
      GLFW_Vulkan.Windows.Set_Opacity
        (W, Float (App_Config.Window_Opacity_Percent) / 100.0, Status);
      GLFW_Vulkan.Windows.Set_Floating
        (W, App_Config.Always_On_Top or else Quick, Status);
      GLFW_Vulkan.Windows.Set_Decorated
        (W, App_Config.Window_Decorations and then not App_Config.Focus_Mode
         and then not Quick, Status);
      Terminal.App.Platform_Appearance.Set_Background_Blur
        (GLFW_Vulkan.Windows.Native_Handle (W),
         App_Config.Background_Blur,
         Blur_Status);
      if App_Config.Background_Blur
        and then Blur_Status = Terminal.App.Platform_Appearance.Blur_Failed
      then
         Terminal.App.Diagnostics.Log_Startup_Failure
           ("background-blur", "native compositor request failed");
      end if;
   end;
   declare
      Hotkey_Status : Terminal.App.Global_Hotkey.Register_Status;
   begin
      Terminal.App.Global_Hotkey.Register
        (Terminal.App.Config.Global_Hotkey_String (App_Config), Hotkey_Status);
      if Hotkey_Status not in Terminal.App.Global_Hotkey.Registered
        | Terminal.App.Global_Hotkey.Disabled
      then
         Terminal.App.Diagnostics.Log_Startup_Failure
           ("global-hotkey",
            Terminal.App.Global_Hotkey.Register_Status'Image (Hotkey_Status));
      end if;
   end;
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
      Font_Pixel_Size => Active_Font_Size,
      Bold_Font_Path => Terminal.App.Config.Font_Bold_Path_String (App_Config),
      Italic_Font_Path =>
        Terminal.App.Config.Font_Italic_Path_String (App_Config),
      Bold_Italic_Font_Path =>
        Terminal.App.Config.Font_Bold_Italic_Path_String (App_Config),
      Font_Features => Terminal.App.Config.Font_Features_String (App_Config),
      Font_Variations =>
        Terminal.App.Config.Font_Variations_String (App_Config));
   if Renderer_Status /= Terminal.App.Renderer.Ok then
      Terminal.App.Diagnostics.Log_Startup_Failure
        ("renderer", Terminal.App.Renderer.Init_Status'Image (Renderer_Status));
      Shutdown;
      return False;
   end if;
   Terminal.App.Renderer.Set_Content_Padding (R, App_Config.Content_Padding);
   Terminal.App.Renderer.Set_Tab_Style
     (R, App_Config.Tab_Bar, App_Config.Tabs);
   Terminal.App.Renderer.Set_Theme
     (R, Resolved_Theme (App_Config, System_Preference), Theme_Status);
   if Theme_Status /= Terminal.App.Renderer.Theme_Ok then
      Terminal.App.Diagnostics.Log_Startup_Failure
        ("theme",
         Terminal.App.Renderer.Theme_Update_Status'Image (Theme_Status));
   end if;
   declare
      Background_Status : Terminal.App.Renderer.Background_Update_Status;
   begin
      Terminal.App.Renderer.Set_Background_Image
        (R,
         Terminal.App.Config.Background_Image_Path_String (App_Config),
         App_Config.Background_Image_Opacity_Percent,
         Background_Status);
      if Terminal.App.Config.Background_Image_Path_String (App_Config) /= ""
        and then Background_Status /= Terminal.App.Renderer.Background_Ok
      then
         Terminal.App.Diagnostics.Log_Startup_Failure
           ("background-image",
            Terminal.App.Renderer.Background_Update_Status'Image
              (Background_Status));
      end if;
   end;
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
      Margin       => App_Config.Content_Padding,
      Default_Rows => App_Config.Startup_Rows,
      Default_Cols => App_Config.Startup_Cols,
      Rows         => Initial_Rows,
      Cols         => Initial_Cols);
   Last_Rows := Initial_Rows;
   Last_Cols := Initial_Cols;
   if Ada.Environment_Variables.Exists (Control_Environment) then
      Ada.Environment_Variables.Clear (Control_Environment);
   end if;
   declare
      Status : Terminal.App.Control_Server.Start_Status;
   begin
      Terminal.App.Control_Server.Start
        (Control, Terminal.App.Control_Server.Default_Path, Status);
      if Status = Terminal.App.Control_Server.Started then
         Ada.Environment_Variables.Set
           (Control_Environment, Terminal.App.Control_Server.Path (Control));
      else
         Terminal.App.Diagnostics.Log_Startup_Failure
           ("control socket", Status'Image);
      end if;
   end;
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

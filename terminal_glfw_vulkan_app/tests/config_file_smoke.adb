with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with AUnit.Assertions;

with GLFW_Vulkan.Input;
with Terminal.App.Config;
with Terminal.App.Key_Bindings;
with Terminal.App.Output_Triggers;
with Terminal.App.Session_Profiles;
with Terminal.App.Theme;
with Test_Support;

procedure Config_File_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Config.Config_Load_Status;
   use type Terminal.App.Config.Config_Export_Status;
   use type Terminal.App.Config.Line_Status;
   use type Terminal.App.Key_Bindings.Action;
   use type Terminal.App.Theme.Tab_Bar_Mode;

   C : Terminal.App.Config.Config;
   Fixture : Test_Support.Temporary_File;
   File : Ada.Text_IO.File_Type;
begin
   Assert
     (Terminal.App.Key_Bindings.Action_For
        (Terminal.App.Key_Bindings.Defaults,
         (Key       => GLFW_Vulkan.Input.V,
          Raw_Key   => 0,
          Scancode  => 0,
          Action    => GLFW_Vulkan.Input.Press,
          Modifiers =>
            (Shift => False, Control => False,
             Alt => False, Super => True))) =
        Terminal.App.Key_Bindings.Paste,
      "default bindings preserve platform paste alias");
   Test_Support.Reserve (Fixture, "ada-terminal-config-smoke.conf");
   declare
      Path : constant String := Test_Support.Path (Fixture);
   begin
      Terminal.App.Config.Load_File
        (C, Path & ".missing", Missing_Is_Error => True);
      Assert
        (C.Load_Status = Terminal.App.Config.Config_Not_Found,
         "missing explicit config is reported");

      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line (File, "window-width = 1111");
      Ada.Text_IO.Put_Line (File, "unknown-setting = value");
      Ada.Text_IO.Put_Line (File, "window-height = 777");
      Ada.Text_IO.Put_Line (File, "window-opacity = 85");
      Ada.Text_IO.Put_Line (File, "always-on-top = true");
      Ada.Text_IO.Put_Line (File, "window-decorations = false");
      Ada.Text_IO.Put_Line (File, "font-path = /tmp/terminal-test.ttf");
      Ada.Text_IO.Put_Line (File, "font-size = 21");
      Ada.Text_IO.Put_Line (File, "bind-search = alt+f3");
      Ada.Text_IO.Put_Line (File, "bind-copy = none");
      Ada.Text_IO.Put_Line (File, "desktop-notifications = false");
      Ada.Text_IO.Put_Line (File, "bell-notifications = true");
      Ada.Text_IO.Put_Line
        (File, "command-completion-notifications = true");
      Ada.Text_IO.Put_Line (File, "shell-integration = false");
      Ada.Text_IO.Put_Line (File, "workspace-file = /tmp/workspace.state");
      Ada.Text_IO.Put_Line (File, "restore-workspace = false");
      Ada.Text_IO.Put_Line (File, "startup-command = make check");
      Ada.Text_IO.Put_Line (File, "profile.work.command = make test");
      Ada.Text_IO.Put_Line (File, "profile.work.cwd = /tmp/work");
      Ada.Text_IO.Put_Line (File, "default-profile = work");
      Ada.Text_IO.Close (File);
      Terminal.App.Config.Load_File (C, Path);
      Assert
        (C.Load_Status = Terminal.App.Config.Config_Invalid
         and then C.Invalid_Line = 2
         and then C.Invalid_Line_Status = Terminal.App.Config.Unknown_Key,
         "config loader reports the first invalid line");
      Assert
        (C.Window_Width = 1_111 and then C.Window_Height = 777
         and then C.Window_Opacity_Percent = 85
         and then C.Always_On_Top
         and then not C.Window_Decorations,
         "config loader applies window appearance after a rejected line");
      Assert
        (Terminal.App.Config.Font_Path_String (C) =
           "/tmp/terminal-test.ttf"
         and then C.Font_Pixel_Size = 21,
         "config loader applies font path and size");
      Assert
        (Terminal.App.Key_Bindings.Action_For
           (C.Bindings,
            (Key       => GLFW_Vulkan.Input.F3,
             Raw_Key   => 0,
             Scancode  => 0,
             Action    => GLFW_Vulkan.Input.Press,
             Modifiers =>
               (Shift => False, Control => False,
                Alt => True, Super => False))) =
           Terminal.App.Key_Bindings.Search
         and then not C.Bindings (Terminal.App.Key_Bindings.Copy).Enabled,
         "config loader applies and disables key bindings");
      Assert
        (Terminal.App.Key_Bindings.Action_For
           (C.Bindings,
            (Key       => GLFW_Vulkan.Input.Insert,
             Raw_Key   => 0,
             Scancode  => 0,
             Action    => GLFW_Vulkan.Input.Press,
             Modifiers =>
               (Shift => False, Control => True,
                Alt => False, Super => False))) =
           Terminal.App.Key_Bindings.No_Action,
         "disabling copy also disables its default aliases");
      Assert
        (not C.Desktop_Notifications
         and then C.Bell_Notifications
         and then C.Command_Completion_Notifications
         and then not C.Shell_Integration
         and then not C.Restore_Workspace
         and then Terminal.App.Config.Startup_Command_String (C) = "make check"
         and then Terminal.App.Session_Profiles.Count (C.Session_Profiles) = 1
         and then Terminal.App.Session_Profiles.Default_Index
           (C.Session_Profiles) = 1
         and then Terminal.App.Config.Workspace_Path_String (C) =
           "/tmp/workspace.state",
         "config loader applies notification and workspace policy");
      Assert
        (Ada.Strings.Fixed.Index
           (Terminal.App.Config.Status_Label (C), "config line 2") > 0,
         "config status label reports the rejected line");
      C.Invalid_Line := Natural'Last;
      Assert
        (Terminal.App.Config.Status_Label (C)'Length <=
           Terminal.App.Config.Max_Status_Label_Length,
         "config load diagnostics remain bounded");

      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line (File, "theme=" & String'(1 .. 5_000 => 'x'));
      Ada.Text_IO.Close (File);
      Terminal.App.Config.Load_File (C, Path);
      Assert
        (C.Load_Status = Terminal.App.Config.Config_Invalid
         and then C.Invalid_Line = 1
         and then C.Invalid_Line_Status = Terminal.App.Config.Invalid_Value,
         "config loader rejects an overlong line without allocating it");

      declare
         Source : Terminal.App.Config.Config := (others => <>);
         Imported : Terminal.App.Config.Config := (others => <>);
         Accepted : Boolean;
         Export_Status : Terminal.App.Config.Config_Export_Status;
         Import_Status : Terminal.App.Config.Config_Load_Status;
         Export_Path : constant String := Path & ".export";
         procedure Apply (Line : String) is
         begin
            Terminal.App.Config.Apply_Line (Source, Line, Accepted);
            Assert (Accepted, "round-trip source config line accepted: " & Line);
         end Apply;
      begin
         Apply ("theme = dracula");
         Apply ("follow-system-theme = true");
         Apply ("foreground = #123456FF");
         Apply ("window-width = 1234");
         Apply ("window-opacity = 75");
         Apply ("focus-mode = true");
         Apply ("global-hotkey = ctrl+alt+t");
         Apply ("font-bold-path = /tmp/bold.ttf");
         Apply ("font-italic-path = /tmp/italic.ttf");
         Apply ("font-bold-italic-path = /tmp/bold-italic.ttf");
         Apply ("font-features = liga=0,kern=1");
         Apply ("font-variations = wght=625,wdth=90");
         Apply ("background-blur = true");
         Apply ("background-image = /tmp/background.png");
         Apply ("background-image-opacity = 42");
         Apply ("content-padding = 23");
         Apply ("tab-bar = always");
         Apply ("tab-bar-background = #112233FF");
         Apply ("active-tab-background = #445566FF");
         Apply ("inactive-tab-background = #778899FF");
         Apply ("bind-search = alt+f3");
         Apply ("bind-copy = none");
         Apply ("protected-input = true");
         Apply ("output-trigger.failure = ERROR: build failed");
         Apply ("profile.work.command = make test");
         Apply ("profile.work.cwd = /tmp/work");
         Apply ("profile.work.environment = A=1,B=2");
         Apply ("default-profile = work");
         Terminal.App.Config.Export_File (Source, Export_Path, Export_Status);
         Assert
           (Export_Status = Terminal.App.Config.Config_Exported,
            "complete config export status");
         Terminal.App.Config.Import_File (Imported, Export_Path, Import_Status);
         Assert
           (Import_Status = Terminal.App.Config.Config_Loaded,
            "complete config import status");
         Assert
           (Imported.Window_Width = 1_234
            and then Imported.Window_Opacity_Percent = 75
            and then Imported.Focus_Mode
            and then Terminal.App.Config.Global_Hotkey_String (Imported) =
              "ctrl+alt+t"
            and then Terminal.App.Config.Font_Bold_Path_String (Imported) =
              "/tmp/bold.ttf"
            and then Terminal.App.Config.Font_Italic_Path_String (Imported) =
              "/tmp/italic.ttf"
            and then Terminal.App.Config.Font_Bold_Italic_Path_String
              (Imported) = "/tmp/bold-italic.ttf"
            and then Terminal.App.Config.Font_Features_String (Imported) =
              "liga=0,kern=1"
            and then Terminal.App.Config.Font_Variations_String (Imported) =
              "wght=625,wdth=90"
            and then Imported.Background_Blur
            and then Terminal.App.Config.Background_Image_Path_String
              (Imported) = "/tmp/background.png"
            and then Imported.Background_Image_Opacity_Percent = 42
            and then Imported.Content_Padding = 23
            and then Imported.Tab_Bar = Terminal.App.Theme.Tab_Always
            and then Imported.Follow_System_Theme
            and then abs
              (Imported.Tabs.Bar_Background.R
               - Float (16#11#) / 255.0) < 0.001
            and then abs
              (Imported.Tabs.Active_Background.G
               - Float (16#55#) / 255.0) < 0.001
            and then abs
              (Imported.Tabs.Inactive_Background.B
               - Float (16#99#) / 255.0) < 0.001
            and then Imported.Use_Custom_Theme
            and then Terminal.App.Key_Bindings.Image
              (Imported.Bindings (Terminal.App.Key_Bindings.Search)) = "alt+f3"
            and then not Imported.Bindings (Terminal.App.Key_Bindings.Copy).Enabled,
            "appearance and bindings survive config round trip");
         Assert
           (Imported.Protected_Input
            and then Terminal.App.Output_Triggers.Count
              (Imported.Output_Trigger_Rules) = 1
            and then Terminal.App.Output_Triggers.Name
              (Imported.Output_Trigger_Rules, 1) = "failure"
            and then Terminal.App.Output_Triggers.Pattern
              (Imported.Output_Trigger_Rules, 1) = "ERROR: build failed",
            "protected input and output triggers survive config round trip");
         Assert
           (Terminal.App.Session_Profiles.Count (Imported.Session_Profiles) = 1
            and then Terminal.App.Session_Profiles.Default_Index
              (Imported.Session_Profiles) = 1
            and then Terminal.App.Session_Profiles.Environment
              (Terminal.App.Session_Profiles.Item
                 (Imported.Session_Profiles, 1)) = "A=1,B=2",
            "profiles survive config round trip");

         Imported.Window_Width := 999;
         Terminal.App.Config.Import_File (Imported, Path, Import_Status);
         Assert
           (Import_Status = Terminal.App.Config.Config_Invalid
            and then Imported.Window_Width = 999,
            "invalid config import is transactional");
         Ada.Directories.Delete_File (Export_Path);
      end;
      Ada.Directories.Delete_File (Path);
   end;
exception
   when others =>
      if Ada.Text_IO.Is_Open (File) then
         Ada.Text_IO.Close (File);
      end if;
      raise;
end Config_File_Smoke;

with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with AUnit.Assertions;

with GLFW_Vulkan.Input;
with Terminal.App.Config;
with Terminal.App.Key_Bindings;
with Terminal.App.Session_Profiles;
with Test_Support;

procedure Config_File_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Config.Config_Load_Status;
   use type Terminal.App.Config.Line_Status;
   use type Terminal.App.Key_Bindings.Action;

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
      Ada.Text_IO.Put_Line (File, "font-path = /tmp/terminal-test.ttf");
      Ada.Text_IO.Put_Line (File, "font-size = 21");
      Ada.Text_IO.Put_Line (File, "bind-search = alt+f3");
      Ada.Text_IO.Put_Line (File, "bind-copy = none");
      Ada.Text_IO.Put_Line (File, "desktop-notifications = false");
      Ada.Text_IO.Put_Line (File, "bell-notifications = true");
      Ada.Text_IO.Put_Line
        (File, "command-completion-notifications = true");
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
        (C.Window_Width = 1_111 and then C.Window_Height = 777,
         "config loader continues after a rejected line");
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
      Ada.Directories.Delete_File (Path);
   end;
exception
   when others =>
      if Ada.Text_IO.Is_Open (File) then
         Ada.Text_IO.Close (File);
      end if;
      raise;
end Config_File_Smoke;

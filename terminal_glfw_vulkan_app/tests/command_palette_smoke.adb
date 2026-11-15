with AUnit.Assertions;
with Terminal.App.Command_Palette;
with Terminal.App.Session_Profiles;

procedure Command_Palette_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Command_Palette.Choice_Kind;
   Profiles : Terminal.App.Session_Profiles.Registry;
   Palette : Terminal.App.Command_Palette.State;
   Accepted : Boolean;
begin
   Terminal.App.Session_Profiles.Apply_Field
     (Profiles, "work.command", "make check", Accepted);
   Assert (Accepted, "profile command accepted");
   Terminal.App.Session_Profiles.Apply_Field
     (Profiles, "work.cwd", "/work/tree", Accepted);
   Assert (Accepted, "profile cwd accepted");
   Terminal.App.Session_Profiles.Apply_Field
     (Profiles, "work.environment", "MODE=test,JOBS=2", Accepted);
   Assert (Accepted, "profile environment accepted");
   Terminal.App.Session_Profiles.Apply_Field
     (Profiles, "work.theme", "light", Accepted);
   Assert (Accepted, "profile theme accepted");
   Terminal.App.Session_Profiles.Apply_Field
     (Profiles, "server.ssh", "dev@example.test", Accepted);
   Assert (Accepted, "ssh profile accepted");
   Terminal.App.Session_Profiles.Apply_Field
     (Profiles, "zsh.shell", "/bin/zsh", Accepted);
   Assert (Accepted, "shell profile accepted");
   Terminal.App.Session_Profiles.Set_Default (Profiles, "work", Accepted);
   Assert
     (Accepted
      and then Terminal.App.Session_Profiles.Count (Profiles) = 3
      and then Terminal.App.Session_Profiles.Default_Index (Profiles) = 1,
      "profile registry and default");
   Assert
     (Terminal.App.Session_Profiles.Launch_Command
        (Terminal.App.Session_Profiles.Item (Profiles, 1)) =
          "export MODE='test' JOBS='2'; make check",
      "profile builds quoted environment command");
   Assert
     (Terminal.App.Session_Profiles.Launch_Command
        (Terminal.App.Session_Profiles.Item (Profiles, 2)) =
          "exec ssh -- 'dev@example.test'",
      "profile builds ssh command");
   Assert
     (Terminal.App.Session_Profiles.Launch_Command
        (Terminal.App.Session_Profiles.Item (Profiles, 3)) =
          "exec '/bin/zsh'",
      "profile builds shell command");

   Terminal.App.Command_Palette.Enter (Palette, Profiles);
   Assert
     (Terminal.App.Command_Palette.Active (Palette)
      and then Terminal.App.Command_Palette.Match_Count (Palette) > 2,
      "palette exposes actions and profiles");
   declare
      Query : constant String := "server";
   begin
      for Ch of Query loop
         Terminal.App.Command_Palette.Append (Palette, Ch);
      end loop;
   end;
   Assert
     (Terminal.App.Command_Palette.Match_Count (Palette) = 1
      and then Terminal.App.Command_Palette.Selected (Palette).Kind =
        Terminal.App.Command_Palette.Profile_Choice
      and then Terminal.App.Command_Palette.Status_Label (Palette)'Length <=
        Terminal.App.Command_Palette.Max_Status_Length,
      "palette filters and selects an ssh profile");
   Terminal.App.Command_Palette.Backspace (Palette);
   Terminal.App.Command_Palette.Move (Palette, 1);
   Terminal.App.Command_Palette.Leave (Palette);
   Assert (not Terminal.App.Command_Palette.Active (Palette), "palette leaves");
end Command_Palette_Smoke;

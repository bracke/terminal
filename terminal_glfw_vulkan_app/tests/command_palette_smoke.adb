with AUnit.Assertions;
with Ada.Strings.Fixed;
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
     (Profiles, "server.ssh-identity", "/home/dev/.ssh/work key", Accepted);
   Assert (Accepted, "ssh identity accepted");
   Terminal.App.Session_Profiles.Apply_Field
     (Profiles, "server.ssh-port", "2222", Accepted);
   Assert (Accepted, "ssh port accepted");
   Terminal.App.Session_Profiles.Apply_Field
     (Profiles, "server.ssh-jump", "jump@example.test", Accepted);
   Assert (Accepted, "ssh jump host accepted");
   Terminal.App.Session_Profiles.Apply_Field
     (Profiles, "server.ssh-setup", "true", Accepted);
   Assert (Accepted, "ssh remote setup accepted");
   Terminal.App.Session_Profiles.Apply_Field
     (Profiles, "zsh.shell", "/bin/zsh", Accepted);
   Assert (Accepted, "shell profile accepted");
   Terminal.App.Session_Profiles.Apply_Field
     (Profiles, "serial.serial", "/dev/ttyUSB0", Accepted);
   Assert (Accepted, "serial profile accepted");
   Terminal.App.Session_Profiles.Apply_Field
     (Profiles, "serial.baud", "921600", Accepted);
   Assert (Accepted, "serial baud accepted");
   Terminal.App.Session_Profiles.Apply_Field
     (Profiles, "agent.socket", "/tmp/agent.sock", Accepted);
   Assert (Accepted, "local socket profile accepted");
   Terminal.App.Session_Profiles.Apply_Field
     (Profiles, "build.container", "worker", Accepted);
   Assert (Accepted, "container profile accepted");
   Terminal.App.Session_Profiles.Apply_Field
     (Profiles, "linux.wsl", "Ubuntu-24.04", Accepted);
   Assert (Accepted, "WSL profile accepted");
   Terminal.App.Session_Profiles.Apply_Field
     (Profiles, "secure.tls", "example.test:443", Accepted);
   Assert (Accepted, "TLS profile accepted");
   Terminal.App.Session_Profiles.Apply_Field
     (Profiles, "persist.command", "htop", Accepted);
   Assert (Accepted, "persistent command accepted");
   Terminal.App.Session_Profiles.Apply_Field
     (Profiles, "persist.persistent", "true", Accepted);
   Assert (Accepted, "persistent session accepted");
   Terminal.App.Session_Profiles.Set_Default (Profiles, "work", Accepted);
   Assert
     (Accepted
      and then Terminal.App.Session_Profiles.Count (Profiles) = 9
      and then Terminal.App.Session_Profiles.Default_Index (Profiles) = 1,
      "profile registry and default");
   Assert
     (Terminal.App.Session_Profiles.Launch_Command
        (Terminal.App.Session_Profiles.Item (Profiles, 1)) =
          "export MODE='test' JOBS='2'; make check",
      "profile builds quoted environment command");
   declare
      SSH_Command : constant String :=
        Terminal.App.Session_Profiles.Launch_Command
          (Terminal.App.Session_Profiles.Item (Profiles, 2));
   begin
      Assert
        (Ada.Strings.Fixed.Index (SSH_Command, "-i '/home/dev/.ssh/work key'") > 0
         and then Ada.Strings.Fixed.Index (SSH_Command, "-p 2222") > 0
         and then Ada.Strings.Fixed.Index
           (SSH_Command, "-J 'jump@example.test'") > 0
         and then Ada.Strings.Fixed.Index
           (SSH_Command, "BRACKE_TERMINAL_REMOTE=1") > 0,
         "profile builds authenticated SSH command and remote bootstrap");
   end;
   Assert
     (Terminal.App.Session_Profiles.Launch_Command
        (Terminal.App.Session_Profiles.Item (Profiles, 3)) =
          "exec '/bin/zsh'",
      "profile builds shell command");
   Assert
     (Terminal.App.Session_Profiles.Launch_Command
        (Terminal.App.Session_Profiles.Item (Profiles, 4)) =
          "exec picocom --baud 921600 -- '/dev/ttyUSB0'",
      "profile builds serial command");
   Assert
     (Terminal.App.Session_Profiles.Launch_Command
        (Terminal.App.Session_Profiles.Item (Profiles, 5)) =
          "exec socat STDIO UNIX-CONNECT:'/tmp/agent.sock'",
      "profile builds local socket command");
   Assert
     (Terminal.App.Session_Profiles.Launch_Command
        (Terminal.App.Session_Profiles.Item (Profiles, 6)) =
          "exec docker exec -it -- 'worker' /bin/sh",
      "profile builds container command");
   Assert
     (Terminal.App.Session_Profiles.Launch_Command
        (Terminal.App.Session_Profiles.Item (Profiles, 7)) =
          "exec wsl.exe -d 'Ubuntu-24.04'",
      "profile builds WSL command");
   Assert
     (Terminal.App.Session_Profiles.Launch_Command
        (Terminal.App.Session_Profiles.Item (Profiles, 8)) =
          "exec openssl s_client -quiet -connect 'example.test:443'",
      "profile builds TLS command");
   Assert
     (Terminal.App.Session_Profiles.Launch_Command
        (Terminal.App.Session_Profiles.Item (Profiles, 9)) =
          "exec tmux new-session -A -s 'persist' 'htop'",
      "profile builds reconnectable persistent tmux session");

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

with Ada.Directories;
with Ada.Text_IO;
with AUnit.Assertions;
with Terminal.App.Session_Profile_Discovery;
with Terminal.App.Session_Profiles;
with Test_Support;

procedure Profile_Discovery_Smoke is
   use AUnit.Assertions;
   Fixture : Test_Support.Temporary_File;
   Profiles : Terminal.App.Session_Profiles.Registry;
   Added : Natural;
begin
   Test_Support.Reserve (Fixture, "bracke-terminal-ssh-config");
   declare
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Test_Support.Path (Fixture));
      Ada.Text_IO.Put_Line (File, "Host work.example jump_box");
      Ada.Text_IO.Put_Line (File, "  HostName 192.0.2.1");
      Ada.Text_IO.Put_Line (File, "Host * !blocked wildcard?.example");
      Ada.Text_IO.Close (File);
   end;
   Terminal.App.Session_Profile_Discovery.Discover_SSH
     (Profiles, Test_Support.Path (Fixture), Added);
   Assert (Added = 2, "two concrete SSH aliases are discovered");
   Assert
     (Terminal.App.Session_Profiles.Count (Profiles) = 2,
      "wildcard and negated SSH patterns are ignored");
   Assert
     (Terminal.App.Session_Profiles.Name
        (Terminal.App.Session_Profiles.Item (Profiles, 1)) = "ssh-work-example"
      and then Terminal.App.Session_Profiles.SSH_Host
        (Terminal.App.Session_Profiles.Item (Profiles, 1)) = "work.example",
      "discovered SSH profile is sanitized and preserves its alias");
   Ada.Directories.Delete_File (Test_Support.Path (Fixture));
end Profile_Discovery_Smoke;

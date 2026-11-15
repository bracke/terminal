with Ada.Directories;
with AUnit.Assertions;

with Terminal.App.Workspace;
with Test_Support;

procedure Workspace_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Workspace.IO_Status;
   use type Terminal.App.Workspace.Layout_Kind;
   use type Terminal.App.Workspace.Pane_Orientation;

   Fixture : Test_Support.Temporary_File;
   Before, After : Terminal.App.Workspace.State;
   Status : Terminal.App.Workspace.IO_Status;
begin
   Test_Support.Reserve (Fixture, "ada-terminal-workspace-smoke.conf");
   Before.Layout := Terminal.App.Workspace.Panes;
   Before.Count := 3;
   Before.Active := 2;
   Before.Orientation := Terminal.App.Workspace.Vertical;
   Terminal.App.Workspace.Set_Path
     (Before.Entries (1).Working_Directory, "/work/one");
   Terminal.App.Workspace.Set_Path
     (Before.Entries (2).Working_Directory, "/work/two=equals");
   Terminal.App.Workspace.Set_Label (Before.Entries (2).Label, "editor");
   Terminal.App.Workspace.Set_Command
     (Before.Entries (2).Startup_Command, "make check");

   Terminal.App.Workspace.Save (Test_Support.Path (Fixture), Before, Status);
   Assert (Status = Terminal.App.Workspace.Saved, "workspace save status");
   Terminal.App.Workspace.Load (Test_Support.Path (Fixture), After, Status);
   Assert
     (Status = Terminal.App.Workspace.Loaded
      and then After.Layout = Terminal.App.Workspace.Panes
      and then After.Count = 3
      and then After.Active = 2
      and then After.Orientation = Terminal.App.Workspace.Vertical,
      "workspace layout round trip");
   Assert
     (Terminal.App.Workspace.Path_Text
        (After.Entries (2).Working_Directory) = "/work/two=equals"
      and then Terminal.App.Workspace.Label_Text (After.Entries (2).Label) =
        "editor"
      and then Terminal.App.Workspace.Command_Text
        (After.Entries (2).Startup_Command) = "make check",
      "workspace session metadata round trip");
   Ada.Directories.Delete_File (Test_Support.Path (Fixture));
end Workspace_Smoke;

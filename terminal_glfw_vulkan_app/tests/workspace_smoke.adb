with Ada.Directories;
with Ada.Text_IO;
with AUnit.Assertions;

with Terminal.App.Workspace;
with Terminal.App.Splits;
with Test_Support;

procedure Workspace_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Workspace.IO_Status;
   use type Terminal.App.Workspace.Layout_Kind;
   use type Terminal.App.Workspace.Pane_Orientation;
   use type Terminal.App.Splits.Pane_Layout;
   use type Terminal.App.Splits.Split_Status;

   Fixture : Test_Support.Temporary_File;
   Before, After : Terminal.App.Workspace.State;
   Status : Terminal.App.Workspace.IO_Status;
   Split_State, Restored_Splits : Terminal.App.Splits.Split_State;
   Split_Status : Terminal.App.Splits.Split_Status;
begin
   Test_Support.Reserve (Fixture, "ada-terminal-workspace-smoke.conf");
   Before.Layout := Terminal.App.Workspace.Panes;
   Before.Count := 3;
   Before.Active := 2;
   Before.Orientation := Terminal.App.Workspace.Vertical;
   Terminal.App.Splits.Initialize (Split_State);
   Terminal.App.Splits.Apply
     (Split_State, Terminal.App.Splits.Split_Vertical, Split_Status);
   Terminal.App.Splits.Apply
     (Split_State, Terminal.App.Splits.Split_Horizontal, Split_Status);
   Terminal.App.Splits.Activate (Split_State, 2, Split_Status);
   Assert (Split_Status = Terminal.App.Splits.Ok, "nested workspace setup");
   Before.Pane_Tree := Terminal.App.Splits.Tree (Split_State);
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
   Terminal.App.Splits.Restore
     (Restored_Splits, After.Pane_Tree, Split_Status);
   Assert
     (Split_Status = Terminal.App.Splits.Ok
      and then Terminal.App.Splits.Layout (Restored_Splits, 20, 30) =
        Terminal.App.Splits.Layout (Split_State, 20, 30),
      "workspace preserves a mixed-orientation pane tree");
   Assert
     (Terminal.App.Workspace.Path_Text
        (After.Entries (2).Working_Directory) = "/work/two=equals"
      and then Terminal.App.Workspace.Label_Text (After.Entries (2).Label) =
        "editor"
      and then Terminal.App.Workspace.Command_Text
        (After.Entries (2).Startup_Command) = "make check",
      "workspace session metadata round trip");

   declare
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create
        (File, Ada.Text_IO.Out_File, Test_Support.Path (Fixture));
      Ada.Text_IO.Put_Line (File, "version=1");
      Ada.Text_IO.Put_Line (File, "count=1");
      Ada.Text_IO.Put_Line (File, "active=1");
      Ada.Text_IO.Put_Line
        (File,
         "session-1-label="
         & String'(1 .. Terminal.App.Workspace.Max_Label_Length + 1 => 'x'));
      Ada.Text_IO.Close (File);
   end;
   Terminal.App.Workspace.Load
     (Test_Support.Path (Fixture), After, Status);
   Assert
     (Status = Terminal.App.Workspace.Invalid_Data,
      "workspace loader rejects oversized fields instead of truncating");

   declare
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create
        (File, Ada.Text_IO.Out_File, Test_Support.Path (Fixture));
      Ada.Text_IO.Put_Line (File, "version=1");
      Ada.Text_IO.Put_Line (File, String'(1 .. 2_000 => 'x'));
      Ada.Text_IO.Close (File);
   end;
   Terminal.App.Workspace.Load
     (Test_Support.Path (Fixture), After, Status);
   Assert
     (Status = Terminal.App.Workspace.Invalid_Data,
      "workspace loader rejects an overlong line without allocating it");
   Ada.Directories.Delete_File (Test_Support.Path (Fixture));
end Workspace_Smoke;

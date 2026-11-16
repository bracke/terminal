with Ada.Environment_Variables;
with AUnit.Assertions;
with Terminal.App.Workspace_Names;

procedure Workspace_Names_Smoke is
   use AUnit.Assertions;
   package Names renames Terminal.App.Workspace_Names;
   use type Names.Namespace_Kind;
   Valid : Boolean;
begin
   Assert (Names.Valid_Name ("dev.main-2"), "portable workspace name");
   Assert (not Names.Valid_Name (""), "empty workspace name rejection");
   Assert (not Names.Valid_Name ("../escape"), "workspace traversal rejection");
   Assert (not Names.Valid_Name (".hidden"), "hidden workspace rejection");
   Assert (not Names.Valid_Name ("-option"), "option-like workspace rejection");
   Assert
     (not Names.Valid_Name (String'(1 .. Names.Max_Name_Length + 1 => 'x')),
      "oversized workspace name rejection");

   Ada.Environment_Variables.Set ("XDG_STATE_HOME", "/tmp/state-root");
   Ada.Environment_Variables.Set ("XDG_CONFIG_HOME", "/tmp/config-root");
   declare
      Session : constant String :=
        Names.Path (Names.Named_Session, "project", Valid);
   begin
      Assert
        (Valid and then Session =
           "/tmp/state-root/ada-terminal/sessions/project.workspace",
         "named session state path");
   end;
   declare
      Layout : constant String :=
        Names.Path (Names.Named_Layout, "three-pane", Valid);
   begin
      Assert
        (Valid and then Layout =
           "/tmp/config-root/ada-terminal/layouts/three-pane.workspace",
         "named layout config path");
   end;
   declare
      Invalid : constant String :=
        Names.Path (Names.Named_Session, "../escape", Valid);
   begin
      Assert (not Valid and then Invalid = "", "invalid named path rejection");
   end;
end Workspace_Names_Smoke;

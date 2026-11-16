with AUnit.Assertions;
with Terminal.App.Remote_Workflows;
with Terminal.App.Session_Profiles;

procedure Remote_Workflows_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Remote_Workflows.Workflow_Status;
   Profiles : Terminal.App.Session_Profiles.Registry;
   Accepted : Boolean;
   Status : Terminal.App.Remote_Workflows.Workflow_Status;
begin
   Terminal.App.Session_Profiles.Apply_Field
     (Profiles, "local.command", "true", Accepted);
   Assert (Accepted, "local profile accepted");
   Terminal.App.Remote_Workflows.Execute
     (Terminal.App.Session_Profiles.Item (Profiles, 1),
      Terminal.App.Remote_Workflows.Upload,
      "/tmp/source", "/tmp/target", Status);
   Assert (Status = Terminal.App.Remote_Workflows.Invalid_Profile,
           "transfer requires an SSH profile");

   Terminal.App.Session_Profiles.Apply_Field
     (Profiles, "remote.ssh", "dev@example.test", Accepted);
   Assert (Accepted, "remote profile accepted");
   Terminal.App.Remote_Workflows.Execute
     (Terminal.App.Session_Profiles.Item (Profiles, 2),
      Terminal.App.Remote_Workflows.Download,
      "/tmp/target", "bad" & ASCII.LF & "path", Status);
   Assert (Status = Terminal.App.Remote_Workflows.Invalid_Path,
           "control characters are rejected before launching scp");
   Assert
     (Terminal.App.Remote_Workflows.Status_Label (Status)'Length > 0,
      "workflow status has a diagnostic label");
end Remote_Workflows_Smoke;

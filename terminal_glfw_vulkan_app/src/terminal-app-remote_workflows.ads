with Terminal.App.Session_Profiles;

package Terminal.App.Remote_Workflows is
   type Action is (Upload, Download, Remote_Edit, Remote_Open);
   type Workflow_Status is
     (Ok, Invalid_Profile, Invalid_Path, Tool_Not_Found, Launch_Failed,
      Child_Failed);

   procedure Execute
     (Profile     : Terminal.App.Session_Profiles.Profile;
      Operation   : Action;
      Local_Path  : String;
      Remote_Path : String;
      Status      : out Workflow_Status);

   function Status_Label (Status : Workflow_Status) return String;
end Terminal.App.Remote_Workflows;

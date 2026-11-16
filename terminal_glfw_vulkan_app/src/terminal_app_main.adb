with Ada.Command_Line;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Text_IO;
with Terminal.App.Control_Client;
with Terminal.App.Control_Protocol;
with Terminal.App.Control_Server;
with Terminal.App.Config;
with Terminal.App.Crash_Reports;
with Terminal.App.Main_Loop;
with Terminal.App.Remote_Workflows;
with Terminal.App.Session_Profiles;
with Terminal.App.Workspace_Names;

procedure Terminal_App_Main is
   use type Terminal.App.Control_Client.Client_Status;
   use type Terminal.App.Crash_Reports.Report_Status;
   use type Terminal.App.Config.Config_Load_Status;
   use type Terminal.App.Config.Config_Export_Status;
   use type Terminal.App.Workspace_Names.Namespace_Kind;
   use type Terminal.App.Remote_Workflows.Workflow_Status;
   Control_Environment : constant String := "BRACKE_TERMINAL_CONTROL";

   function Starts_With (Value, Prefix : String) return Boolean is
     (Value'Length >= Prefix'Length
      and then Value (Value'First .. Value'First + Prefix'Length - 1) = Prefix);

   procedure Run_Control (Path : String; First_Command : Positive) is
      Request : String (1 .. Terminal.App.Control_Protocol.Max_Request_Length);
      Last : Natural := 0;
      Response : String (1 .. Terminal.App.Control_Server.Max_Response_Length);
      Response_Length : Natural;
      Status : Terminal.App.Control_Client.Client_Status;
   begin
      for I in First_Command .. Ada.Command_Line.Argument_Count loop
         declare
            Part : constant String := Ada.Command_Line.Argument (I);
         begin
            if Last > 0 then
               Last := Last + 1;
               Request (Last) := ' ';
            end if;
            if Part'Length > Request'Last - Last then
               Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "request too long");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               return;
            end if;
            Request (Last + 1 .. Last + Part'Length) := Part;
            Last := Last + Part'Length;
         end;
      end loop;
      Terminal.App.Control_Client.Execute
        (Path,
         (if Last = 0 then "ping" else Request (1 .. Last)),
         Response,
         Response_Length,
         Status);
      if Status /= Terminal.App.Control_Client.Ok then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            Terminal.App.Control_Client.Status_Label (Status));
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      elsif Response_Length > 0 then
         Ada.Text_IO.Put_Line (Response (1 .. Response_Length));
         if Response_Length >= 6 and then Response (1 .. 6) = "error " then
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         end if;
      end if;
   end Run_Control;

   procedure Run_Named
     (Kind : Terminal.App.Workspace_Names.Namespace_Kind;
      Name : String)
   is
      Valid : Boolean;
      Path : constant String :=
        Terminal.App.Workspace_Names.Path (Kind, Name, Valid);
   begin
      if Valid then
         Terminal.App.Main_Loop.Run (Workspace_Override => Path);
      else
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "invalid named "
            & (if Kind = Terminal.App.Workspace_Names.Named_Session
               then "session" else "layout")
            & ": use 1-64 letters, digits, '.', '_' or '-'");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end if;
   end Run_Named;

   procedure Export_Config (Path : String) is
      Value : Terminal.App.Config.Config;
      Status : Terminal.App.Config.Config_Export_Status;
   begin
      Terminal.App.Config.Load (Value);
      Terminal.App.Config.Export_File (Value, Path, Status);
      if Status /= Terminal.App.Config.Config_Exported then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "config export failed");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end if;
   end Export_Config;

   procedure Import_Config (Path : String) is
      Value : Terminal.App.Config.Config := (others => <>);
      Load_Status : Terminal.App.Config.Config_Load_Status;
      Export_Status : Terminal.App.Config.Config_Export_Status;
      Target : constant String := Terminal.App.Config.Default_Path;
   begin
      Terminal.App.Config.Import_File (Value, Path, Load_Status);
      if Load_Status /= Terminal.App.Config.Config_Loaded or else Target = "" then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "config import failed");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;
      Terminal.App.Config.Export_File (Value, Target, Export_Status);
      if Export_Status /= Terminal.App.Config.Config_Exported then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "config import save failed");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end if;
   end Import_Config;

   procedure Run_Remote
     (Operation : Terminal.App.Remote_Workflows.Action;
      Profile_Name : String;
      Local_Path : String;
      Remote_Path : String)
   is
      Value : Terminal.App.Config.Config;
      Index : Natural;
      Status : Terminal.App.Remote_Workflows.Workflow_Status;
   begin
      Terminal.App.Config.Load (Value);
      Index := Terminal.App.Session_Profiles.Find
        (Value.Session_Profiles, Profile_Name);
      if Index = 0 then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error, "unknown SSH profile: " & Profile_Name);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;
      Terminal.App.Remote_Workflows.Execute
        (Terminal.App.Session_Profiles.Item (Value.Session_Profiles, Index),
         Operation, Local_Path, Remote_Path, Status);
      if Status /= Terminal.App.Remote_Workflows.Ok then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            Terminal.App.Remote_Workflows.Status_Label (Status));
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end if;
   end Run_Remote;
begin
   if Ada.Command_Line.Argument_Count >= 1
     and then Starts_With (Ada.Command_Line.Argument (1), "--control=")
   then
      declare
         Supplied : constant String := Ada.Command_Line.Argument (1)
           (Ada.Command_Line.Argument (1)'First + 10
            .. Ada.Command_Line.Argument (1)'Last);
         Path : constant String :=
           (if Supplied = "auto"
              and then Ada.Environment_Variables.Exists (Control_Environment)
            then Ada.Environment_Variables.Value (Control_Environment)
            else Supplied);
      begin
         Run_Control (Path, 2);
      end;
   elsif Ada.Command_Line.Argument_Count >= 1
     and then Ada.Command_Line.Argument (1) = "--control"
   then
      if Ada.Environment_Variables.Exists (Control_Environment) then
         Run_Control
           (Ada.Environment_Variables.Value (Control_Environment), 2);
      else
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            Control_Environment & " is not set; use --control=PATH");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end if;
   elsif Ada.Command_Line.Argument_Count = 1
     and then Starts_With (Ada.Command_Line.Argument (1), "--workspace=")
   then
      Terminal.App.Main_Loop.Run
        (Ada.Command_Line.Argument (1)
           (13 .. Ada.Command_Line.Argument (1)'Last));
   elsif Ada.Command_Line.Argument_Count = 1
     and then Starts_With (Ada.Command_Line.Argument (1), "--session=")
   then
      Run_Named
        (Terminal.App.Workspace_Names.Named_Session,
         Ada.Command_Line.Argument (1)
           (11 .. Ada.Command_Line.Argument (1)'Last));
   elsif Ada.Command_Line.Argument_Count = 1
     and then Starts_With (Ada.Command_Line.Argument (1), "--layout=")
   then
      Run_Named
        (Terminal.App.Workspace_Names.Named_Layout,
         Ada.Command_Line.Argument (1)
           (10 .. Ada.Command_Line.Argument (1)'Last));
   elsif Ada.Command_Line.Argument_Count = 1
     and then Starts_With (Ada.Command_Line.Argument (1), "--export-config=")
   then
      Export_Config
        (Ada.Command_Line.Argument (1)
           (17 .. Ada.Command_Line.Argument (1)'Last));
   elsif Ada.Command_Line.Argument_Count = 1
     and then Starts_With (Ada.Command_Line.Argument (1), "--import-config=")
   then
      Import_Config
        (Ada.Command_Line.Argument (1)
           (17 .. Ada.Command_Line.Argument (1)'Last));
   elsif Ada.Command_Line.Argument_Count = 1
     and then Ada.Command_Line.Argument (1) = "--quick"
   then
      Terminal.App.Main_Loop.Run (Quick => True);
   elsif Ada.Command_Line.Argument_Count = 3
     and then Starts_With (Ada.Command_Line.Argument (1), "--upload=")
   then
      Run_Remote
        (Terminal.App.Remote_Workflows.Upload,
         Ada.Command_Line.Argument (1) (10 .. Ada.Command_Line.Argument (1)'Last),
         Ada.Command_Line.Argument (2), Ada.Command_Line.Argument (3));
   elsif Ada.Command_Line.Argument_Count = 3
     and then Starts_With (Ada.Command_Line.Argument (1), "--download=")
   then
      Run_Remote
        (Terminal.App.Remote_Workflows.Download,
         Ada.Command_Line.Argument (1) (12 .. Ada.Command_Line.Argument (1)'Last),
         Ada.Command_Line.Argument (3), Ada.Command_Line.Argument (2));
   elsif Ada.Command_Line.Argument_Count = 2
     and then Starts_With (Ada.Command_Line.Argument (1), "--remote-edit=")
   then
      Run_Remote
        (Terminal.App.Remote_Workflows.Remote_Edit,
         Ada.Command_Line.Argument (1) (15 .. Ada.Command_Line.Argument (1)'Last),
         "", Ada.Command_Line.Argument (2));
   elsif Ada.Command_Line.Argument_Count = 2
     and then Starts_With (Ada.Command_Line.Argument (1), "--remote-open=")
   then
      Run_Remote
        (Terminal.App.Remote_Workflows.Remote_Open,
         Ada.Command_Line.Argument (1) (15 .. Ada.Command_Line.Argument (1)'Last),
         "", Ada.Command_Line.Argument (2));
   else
      Terminal.App.Main_Loop.Run;
   end if;
exception
   when Error : others =>
      declare
         Path : constant String := Terminal.App.Crash_Reports.Default_Path;
         Status : Terminal.App.Crash_Reports.Report_Status;
      begin
         Terminal.App.Crash_Reports.Write (Path, Error, Status);
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            Ada.Exceptions.Exception_Information (Error));
         if Status = Terminal.App.Crash_Reports.Written then
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error, "Crash report written to " & Path);
         end if;
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end;
end Terminal_App_Main;


with GNAT.OS_Lib;

package body Terminal.App.Remote_Workflows is
   package Profiles renames Terminal.App.Session_Profiles;
   package OS renames GNAT.OS_Lib;
   use type OS.String_Access;

   function Safe_Path (Value : String; Allow_Empty : Boolean := False)
     return Boolean
   is
   begin
      if Value'Length > Profiles.Max_Value_Length
        or else (Value = "" and then not Allow_Empty)
      then
         return False;
      end if;
      for Ch of Value loop
         if Ch in ASCII.NUL .. ASCII.US or else Ch = ASCII.DEL then
            return False;
         end if;
      end loop;
      return True;
   end Safe_Path;

   function Shell_Quote (Value : String) return String is
      Result : String (1 .. Value'Length * 5 + 2);
      Last : Natural := 1;
   begin
      Result (1) := ''';
      for Ch of Value loop
         if Ch = ''' then
            Result (Last + 1 .. Last + 5) := "'""'""'";
            Last := Last + 5;
         else
            Last := Last + 1;
            Result (Last) := Ch;
         end if;
      end loop;
      Last := Last + 1;
      Result (Last) := ''';
      return Result (1 .. Last);
   end Shell_Quote;

   procedure Execute
     (Profile     : Profiles.Profile;
      Operation   : Action;
      Local_Path  : String;
      Remote_Path : String;
      Status      : out Workflow_Status)
   is
      Host : constant String := Profiles.SSH_Host (Profile);
      Is_Copy : constant Boolean := Operation in Upload | Download;
      Program : OS.String_Access :=
        OS.Locate_Exec_On_Path (if Is_Copy then "scp" else "ssh");
      Option_Count : Natural := 0;
      Exit_Code : Integer := -1;
   begin
      if Host = "" then
         Status := Invalid_Profile;
         return;
      elsif not Safe_Path (Remote_Path)
        or else (Is_Copy and then not Safe_Path (Local_Path))
      then
         Status := Invalid_Path;
         return;
      elsif Program = null then
         Status := Tool_Not_Found;
         return;
      end if;

      if Profiles.SSH_Identity (Profile) /= "" then
         Option_Count := Option_Count + 2;
      end if;
      if Profiles.SSH_Port (Profile) /= "" then
         Option_Count := Option_Count + 2;
      end if;
      if Profiles.SSH_Jump_Host (Profile) /= "" then
         Option_Count := Option_Count + 2;
      end if;

      declare
         Base_Count : constant Positive := (if Is_Copy then 3 else 4);
         Args : OS.Argument_List (1 .. Base_Count + Option_Count);
         Last : Natural := 0;
         procedure Add (Value : String) is
         begin
            Last := Last + 1;
            Args (Last) := new String'(Value);
         end Add;
         procedure Free_Args is
         begin
            for Item of Args loop
               OS.Free (Item);
            end loop;
         end Free_Args;
      begin
         if Profiles.SSH_Identity (Profile) /= "" then
            Add ("-i");
            Add (Profiles.SSH_Identity (Profile));
         end if;
         if Profiles.SSH_Port (Profile) /= "" then
            Add (if Is_Copy then "-P" else "-p");
            Add (Profiles.SSH_Port (Profile));
         end if;
         if Profiles.SSH_Jump_Host (Profile) /= "" then
            Add ("-J");
            Add (Profiles.SSH_Jump_Host (Profile));
         end if;
         if Is_Copy then
            Add ("--");
            if Operation = Upload then
               Add (Local_Path);
               Add (Host & ":" & Remote_Path);
            else
               Add (Host & ":" & Remote_Path);
               Add (Local_Path);
            end if;
         else
            Add ("-t");
            Add ("--");
            Add (Host);
            Add
              ((if Operation = Remote_Edit
                then "exec ${VISUAL:-${EDITOR:-vi}} -- "
                else "(command -v xdg-open >/dev/null && exec xdg-open -- "
                  & Shell_Quote (Remote_Path)
                  & ") || (command -v open >/dev/null && exec open -- ")
               & Shell_Quote (Remote_Path)
               & (if Operation = Remote_Edit then "" else ")") );
         end if;
         begin
            Exit_Code := OS.Spawn (Program.all, Args);
            Status := (if Exit_Code = 0 then Ok else Child_Failed);
         exception
            when others => Status := Launch_Failed;
         end;
         Free_Args;
      exception
         when others =>
            Free_Args;
            OS.Free (Program);
            raise;
      end;
      OS.Free (Program);
   exception
      when others =>
         OS.Free (Program);
         Status := Launch_Failed;
   end Execute;

   function Status_Label (Status : Workflow_Status) return String is
     (case Status is
        when Ok => "ok",
        when Invalid_Profile => "profile is not an SSH profile",
        when Invalid_Path => "invalid local or remote path",
        when Tool_Not_Found => "required ssh/scp tool not found",
        when Launch_Failed => "could not launch remote workflow",
        when Child_Failed => "remote workflow failed");
end Terminal.App.Remote_Workflows;

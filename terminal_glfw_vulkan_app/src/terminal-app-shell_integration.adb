with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;

package body Terminal.App.Shell_Integration is
   function Exists (Path : String) return Boolean is
     (Path /= "" and then Ada.Directories.Exists (Path));

   function Entry_At (Root : String) return Boolean is
     (Exists (Root & "/b/bracke-terminal")
      or else Exists (Root & "/62/bracke-terminal"));

   function Native_Terminfo_Available return Boolean is
      Explicit : constant String :=
        Ada.Environment_Variables.Value ("TERMINFO", "");
      Home : constant String := Ada.Environment_Variables.Value ("HOME", "");
   begin
      return (Explicit /= "" and then Entry_At (Explicit))
        or else (Home /= "" and then Entry_At (Home & "/.terminfo"))
        or else Entry_At ("/usr/share/terminfo")
        or else Entry_At ("/lib/terminfo")
        or else Entry_At ("/etc/terminfo");
   end Native_Terminfo_Available;

   function Base_Name (Path : String) return String is
      Slash : Natural := 0;
   begin
      for I in Path'Range loop
         if Path (I) = '/' or else Path (I) = '\' then
            Slash := I;
         end if;
      end loop;
      return Ada.Characters.Handling.To_Lower
        (Path ((if Slash = 0 then Path'First else Slash + 1) .. Path'Last));
   end Base_Name;

   function Quote_POSIX (Value : String) return String is
      Count : Natural := 2;
   begin
      for Ch of Value loop
         Count := Count + (if Ch = ''' then 4 else 1);
      end loop;
      return Result : String (1 .. Count) do
         declare
            Last : Natural := 1;
         begin
            Result (1) := ''';
            for Ch of Value loop
               if Ch = ''' then
                  Result (Last + 1 .. Last + 4) := "'\''";
                  Last := Last + 4;
               else
                  Last := Last + 1;
                  Result (Last) := Ch;
               end if;
            end loop;
            Result (Count) := ''';
         end;
      end return;
   end Quote_POSIX;

   function Integration_Path (Extension : String) return String is
      Data_Home : constant String :=
        Ada.Environment_Variables.Value ("XDG_DATA_HOME", "");
      Home : constant String := Ada.Environment_Variables.Value ("HOME", "");
      Installed : constant String :=
        (if Data_Home /= ""
         then Data_Home
         elsif Home /= "" then Home & "/.local/share"
         else "")
        & "/bracke-terminal/shell-integration/bracke-terminal." & Extension;
      --  A development run starts in the repository root or, like the app
      --  crate's own tests, in terminal_glfw_vulkan_app/ just below it.
      Development : constant String :=
        "resources/shell-integration/bracke-terminal." & Extension;
      App_Crate_Development : constant String := "../" & Development;
   begin
      if Exists (Installed) then
         return Installed;
      elsif Exists (Development) then
         return Development;
      elsif Exists (App_Crate_Development) then
         return App_Crate_Development;
      else
         return "";
      end if;
   end Integration_Path;

   function Bootstrap
     (Enabled      : Boolean;
      Control_Path : String) return String
   is
      Shell : constant String := Base_Name
        (Ada.Environment_Variables.Value ("SHELL", "sh"));
      Extension : constant String :=
        (if Ada.Strings.Fixed.Index (Shell, "bash") > 0 then "bash"
         elsif Ada.Strings.Fixed.Index (Shell, "zsh") > 0 then "zsh"
         elsif Ada.Strings.Fixed.Index (Shell, "fish") > 0 then "fish"
         elsif Ada.Strings.Fixed.Index (Shell, "nu") > 0 then "nu"
         else "");
      Script : constant String :=
        (if Enabled and then Extension /= ""
         then Integration_Path (Extension) else "");
      Native_TERM : constant Boolean := Native_Terminfo_Available;
   begin
      if Extension = "fish" then
         return
           (if Control_Path = "" then ""
            else "set -gx BRACKE_TERMINAL_CONTROL "
              & Quote_POSIX (Control_Path) & "; ")
           & (if Native_TERM then "set -gx TERM bracke-terminal; " else "")
           & (if Script = "" then "" else "source " & Quote_POSIX (Script));
      elsif Extension = "nu" then
         return
           (if Control_Path = "" then ""
            else "$env.BRACKE_TERMINAL_CONTROL = "
              & Quote_POSIX (Control_Path) & "; ")
           & (if Native_TERM then "$env.TERM = 'bracke-terminal'; " else "")
           & (if Script = "" then "" else "source " & Quote_POSIX (Script));
      else
         return
           (if Control_Path = "" then ""
            else "export BRACKE_TERMINAL_CONTROL="
              & Quote_POSIX (Control_Path) & "; ")
           & (if Native_TERM then "export TERM=bracke-terminal; " else "")
           & (if Script = "" then "" else ". " & Quote_POSIX (Script));
      end if;
   end Bootstrap;
end Terminal.App.Shell_Integration;

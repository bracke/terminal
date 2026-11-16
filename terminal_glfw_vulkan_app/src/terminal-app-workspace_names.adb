with Ada.Environment_Variables;

package body Terminal.App.Workspace_Names is
   function Valid_Name (Name : String) return Boolean is
   begin
      if Name'Length = 0 or else Name'Length > Max_Name_Length
        or else Name = "." or else Name = ".."
      then
         return False;
      end if;
      for Ch of Name loop
         if Ch not in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '-' | '_' | '.' then
            return False;
         end if;
      end loop;
      return Name (Name'First) not in '-' | '.';
   end Valid_Name;

   function Path
     (Kind  : Namespace_Kind;
      Name  : String;
      Valid : out Boolean) return String
   is
      XDG_Base : constant String :=
        Ada.Environment_Variables.Value
          ((if Kind = Named_Session then "XDG_STATE_HOME" else "XDG_CONFIG_HOME"),
           "");
      Home : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Base : constant String :=
        (if XDG_Base /= "" then XDG_Base
         elsif Home = "" then ""
         elsif Kind = Named_Session then Home & "/.local/state"
         else Home & "/.config");
      Directory : constant String :=
        (if Kind = Named_Session then "sessions" else "layouts");
   begin
      Valid := Valid_Name (Name) and then Base /= "";
      if not Valid then
         return "";
      end if;
      return Base & "/ada-terminal/" & Directory & "/" & Name & ".workspace";
   end Path;
end Terminal.App.Workspace_Names;

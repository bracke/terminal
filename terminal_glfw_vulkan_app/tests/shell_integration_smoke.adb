with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with AUnit.Assertions;
with Terminal.App.Shell_Integration;

procedure Shell_Integration_Smoke is
   use AUnit.Assertions;
   Had_Shell : constant Boolean := Ada.Environment_Variables.Exists ("SHELL");
   Saved_Shell : constant String :=
     Ada.Environment_Variables.Value ("SHELL", "");

   procedure Restore is
   begin
      if Had_Shell then
         Ada.Environment_Variables.Set ("SHELL", Saved_Shell);
      elsif Ada.Environment_Variables.Exists ("SHELL") then
         Ada.Environment_Variables.Clear ("SHELL");
      end if;
   end Restore;
begin
   Ada.Environment_Variables.Set ("SHELL", "/bin/bash");
   declare
      Command : constant String := Terminal.App.Shell_Integration.Bootstrap
        (True, "/tmp/bracke socket.sock");
   begin
      Assert
        (Ada.Strings.Fixed.Index
           (Command, "BRACKE_TERMINAL_CONTROL='/tmp/bracke socket.sock'") > 0,
         "bootstrap exports the selected control socket safely");
      Assert
        (Ada.Strings.Fixed.Index (Command, "bracke-terminal.bash") > 0,
         "bash integration is discovered and sourced");
      Assert
        ((Ada.Strings.Fixed.Index (Command, "TERM=bracke-terminal") > 0) =
           Terminal.App.Shell_Integration.Native_Terminfo_Available,
         "native TERM is selected only when its compiled entry is installed");
   end;

   Ada.Environment_Variables.Set ("SHELL", "/usr/bin/fish");
   declare
      Command : constant String := Terminal.App.Shell_Integration.Bootstrap
        (True, "/tmp/control.sock");
   begin
      Assert
        (Ada.Strings.Fixed.Index (Command, "set -gx") > 0
         and then Ada.Strings.Fixed.Index (Command, "source ") > 0,
         "fish receives native environment and source syntax");
   end;

   Ada.Environment_Variables.Set ("SHELL", "/bin/bash");
   Assert
     (Ada.Strings.Fixed.Index
        (Terminal.App.Shell_Integration.Bootstrap
           (False, "/tmp/control.sock"),
         "bracke-terminal.bash") = 0,
      "integration can be disabled without losing control-socket export");
   Restore;
exception
   when others =>
      Restore;
      raise;
end Shell_Integration_Smoke;

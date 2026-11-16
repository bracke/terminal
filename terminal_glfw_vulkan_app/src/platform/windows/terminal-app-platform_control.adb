with Ada.Directories;

package body Terminal.App.Platform_Control is
   function Restrict_To_Owner (Path : String) return Boolean is
      pragma Unreferenced (Path);
   begin
      --  AF_UNIX endpoints on Windows are constrained to the current user by
      --  their containing user-profile directory. There is no POSIX chmod.
      return True;
   end Restrict_To_Owner;

   procedure Remove_Socket (Path : String) is
   begin
      Ada.Directories.Delete_File (Path);
   exception
      when Ada.Directories.Name_Error | Ada.Directories.Use_Error => null;
   end Remove_Socket;
end Terminal.App.Platform_Control;

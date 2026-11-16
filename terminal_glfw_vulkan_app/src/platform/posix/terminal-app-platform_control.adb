with Interfaces.C;
with Interfaces.C.Strings;
with Terminal.Common.C_Strings;

package body Terminal.App.Platform_Control is
   use type Interfaces.C.int;
   function Chmod
     (Path : Interfaces.C.Strings.chars_ptr;
      Mode : Interfaces.C.unsigned) return Interfaces.C.int
     with Import, Convention => C, External_Name => "chmod";
   function Unlink (Path : Interfaces.C.Strings.chars_ptr) return Interfaces.C.int
     with Import, Convention => C, External_Name => "unlink";

   function Restrict_To_Owner (Path : String) return Boolean is
      C_Path : Terminal.Common.C_Strings.Owner;
   begin
      Terminal.Common.C_Strings.Set (C_Path, Path);
      return Chmod
        (Terminal.Common.C_Strings.Unsafe_Pointer (C_Path), 8#600#) = 0;
   end Restrict_To_Owner;

   procedure Remove_Socket (Path : String) is
      C_Path : Terminal.Common.C_Strings.Owner;
      Ignored : Interfaces.C.int;
      pragma Unreferenced (Ignored);
   begin
      Terminal.Common.C_Strings.Set (C_Path, Path);
      Ignored := Unlink (Terminal.Common.C_Strings.Unsafe_Pointer (C_Path));
   end Remove_Socket;
end Terminal.App.Platform_Control;

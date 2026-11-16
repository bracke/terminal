with Interfaces.C;
with Interfaces.C.Strings;
with Terminal.Common.C_Strings;

package body Terminal.App.Platform_Files is
   use type Interfaces.C.int;
   function Rename
     (Source, Target : Interfaces.C.Strings.chars_ptr) return Interfaces.C.int
     with Import, Convention => C, External_Name => "rename";

   function Replace_File (Source, Target : String) return Boolean is
      C_Source : Terminal.Common.C_Strings.Owner;
      C_Target : Terminal.Common.C_Strings.Owner;
   begin
      Terminal.Common.C_Strings.Set (C_Source, Source);
      Terminal.Common.C_Strings.Set (C_Target, Target);
      return Rename
        (Terminal.Common.C_Strings.Unsafe_Pointer (C_Source),
         Terminal.Common.C_Strings.Unsafe_Pointer (C_Target)) = 0;
   end Replace_File;
end Terminal.App.Platform_Files;

with Interfaces.C;
with Interfaces.C.Strings;
with Terminal.Common.C_Strings;

package body Terminal.App.Platform_Files is
   use type Interfaces.C.int;
   Movefile_Replace_Existing : constant Interfaces.C.unsigned_long := 1;
   Movefile_Write_Through : constant Interfaces.C.unsigned_long := 8;
   function Move_File_Ex
     (Source, Target : Interfaces.C.Strings.chars_ptr;
      Flags : Interfaces.C.unsigned_long) return Interfaces.C.int
     with Import, Convention => Stdcall, External_Name => "MoveFileExA";

   function Replace_File (Source, Target : String) return Boolean is
      C_Source : Terminal.Common.C_Strings.Owner;
      C_Target : Terminal.Common.C_Strings.Owner;
   begin
      Terminal.Common.C_Strings.Set (C_Source, Source);
      Terminal.Common.C_Strings.Set (C_Target, Target);
      return Move_File_Ex
        (Terminal.Common.C_Strings.Unsafe_Pointer (C_Source),
         Terminal.Common.C_Strings.Unsafe_Pointer (C_Target),
         Movefile_Replace_Existing or Movefile_Write_Through) /= 0;
   end Replace_File;
end Terminal.App.Platform_Files;

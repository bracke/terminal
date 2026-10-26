with GNAT.OS_Lib;
with Interfaces.C;
with System;

package Terminal.App.Platform_Media is
   package OS renames GNAT.OS_Lib;
   package C renames Interfaces.C;

   function Local_File_Transfers_Available return Boolean;
   function Shared_Memory_Transfers_Available return Boolean;
   function File_Downloads_Available return Boolean;

   function Open_Read_No_Follow (Path : String) return OS.File_Descriptor;
   function Descriptor_Path (FD : OS.File_Descriptor) return String;
   function Shared_Memory_Open (Name : String) return OS.File_Descriptor;
   function Shared_Memory_Unlink (Name : String) return Boolean;

   function Open_Directory_No_Follow (Path : String) return C.int;
   function Open_Read_At_No_Follow
     (Directory : C.int;
      Name      : String) return OS.File_Descriptor;
   function Create_File_At
     (Directory : C.int;
      Name      : String;
      Mode      : C.unsigned) return C.int;
   function Write_File
     (FD     : C.int;
      Buffer : System.Address;
      Count  : C.size_t) return C.long;
   function Close_File (FD : C.int) return C.int;
   function Delete_File_At
     (Directory : C.int;
      Name      : String) return Boolean;

end Terminal.App.Platform_Media;

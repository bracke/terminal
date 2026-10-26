package body Terminal.App.Platform_Media is
   use type C.int;
   use type C.long;

   function Local_File_Transfers_Available return Boolean is (False);
   function Shared_Memory_Transfers_Available return Boolean is (False);
   function File_Downloads_Available return Boolean is (False);

   function Open_Read_No_Follow (Path : String) return OS.File_Descriptor is
      pragma Unreferenced (Path);
   begin
      return OS.Invalid_FD;
   end Open_Read_No_Follow;

   function Descriptor_Path (FD : OS.File_Descriptor) return String is
      pragma Unreferenced (FD);
   begin
      return "";
   end Descriptor_Path;

   function Shared_Memory_Open (Name : String) return OS.File_Descriptor is
      pragma Unreferenced (Name);
   begin
      return OS.Invalid_FD;
   end Shared_Memory_Open;

   function Shared_Memory_Unlink (Name : String) return Boolean is
      pragma Unreferenced (Name);
   begin
      return False;
   end Shared_Memory_Unlink;

   function Open_Directory_No_Follow (Path : String) return C.int is
      pragma Unreferenced (Path);
   begin
      return -1;
   end Open_Directory_No_Follow;

   function Open_Read_At_No_Follow
     (Directory : C.int;
      Name      : String) return OS.File_Descriptor
   is
      pragma Unreferenced (Directory, Name);
   begin
      return OS.Invalid_FD;
   end Open_Read_At_No_Follow;

   function Create_File_At
     (Directory : C.int;
      Name      : String;
      Mode      : C.unsigned) return C.int
   is
      pragma Unreferenced (Directory, Name, Mode);
   begin
      return -1;
   end Create_File_At;

   function Write_File
     (FD     : C.int;
      Buffer : System.Address;
      Count  : C.size_t) return C.long
   is
      pragma Unreferenced (FD, Buffer, Count);
   begin
      return -1;
   end Write_File;

   function Close_File (FD : C.int) return C.int is
      pragma Unreferenced (FD);
   begin
      return -1;
   end Close_File;

   function Delete_File_At
     (Directory : C.int;
      Name      : String) return Boolean
   is
      pragma Unreferenced (Directory, Name);
   begin
      return False;
   end Delete_File_At;

end Terminal.App.Platform_Media;

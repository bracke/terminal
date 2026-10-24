with Interfaces.C.Strings;

package body Terminal.App.Platform_Media is
   package CS renames Interfaces.C.Strings;

   use type C.int;

   function C_Shm_Open
     (Name  : CS.chars_ptr;
      Flags : C.int;
      Mode  : C.unsigned) return C.int
   with Import, Convention => C, External_Name => "shm_open";

   function C_Shm_Unlink (Name : CS.chars_ptr) return C.int
   with Import, Convention => C, External_Name => "shm_unlink";

   function C_Open
     (Path  : CS.chars_ptr;
      Flags : C.int) return C.int
   with Import, Convention => C, External_Name => "open";

   function C_Openat
     (Directory : C.int;
      Path      : CS.chars_ptr;
      Flags     : C.int;
      Mode      : C.unsigned) return C.int
   with Import, Convention => C, External_Name => "openat";

   function C_Write
     (FD     : C.int;
      Buffer : System.Address;
      Count  : C.size_t) return C.long
   with Import, Convention => C, External_Name => "write";

   function C_Close (FD : C.int) return C.int
   with Import, Convention => C, External_Name => "close";

   function C_Unlinkat
     (Directory : C.int;
      Path      : CS.chars_ptr;
      Flags     : C.int) return C.int
   with Import, Convention => C, External_Name => "unlinkat";

   function Dlopen (Name : CS.chars_ptr; Flags : C.int) return System.Address
   with Import, Convention => C, External_Name => "dlopen";

   function Dlsym
     (Handle : System.Address;
      Name   : CS.chars_ptr) return System.Address
   with Import, Convention => C, External_Name => "dlsym";

   O_RDONLY   : constant C.int := 0;
   O_WRONLY   : constant C.int := 1;
   O_CREAT    : constant C.int := 64;
   O_EXCL     : constant C.int := 128;
   O_DIRECTORY : constant C.int := 65_536;
   O_NOFOLLOW : constant C.int := 131_072;
   O_CLOEXEC  : constant C.int := 524_288;
   RTLD_LAZY  : constant C.int := 1;

   function Local_File_Transfers_Available return Boolean is (True);
   function Shared_Memory_Transfers_Available return Boolean is (True);
   function File_Downloads_Available return Boolean is (True);

   function Open_Read_No_Follow (Path : String) return OS.File_Descriptor is
      Name : CS.chars_ptr := CS.New_String (Path);
      Raw  : C.int;
   begin
      Raw := C_Open (Name, O_RDONLY + O_NOFOLLOW + O_CLOEXEC);
      CS.Free (Name);
      return (if Raw < 0 then OS.Invalid_FD else OS.File_Descriptor (Raw));
   exception
      when others =>
         CS.Free (Name);
         return OS.Invalid_FD;
   end Open_Read_No_Follow;

   function Descriptor_Path (FD : OS.File_Descriptor) return String is
      Image : constant String := OS.File_Descriptor'Image (FD);
   begin
      return "/proc/self/fd/" & Image (Image'First + 1 .. Image'Last);
   end Descriptor_Path;

   function Shared_Memory_Open (Name : String) return OS.File_Descriptor is
      C_Name : CS.chars_ptr := CS.New_String (Name);
      Raw    : C.int;
   begin
      Raw := C_Shm_Open (C_Name, O_RDONLY, 0);
      CS.Free (C_Name);
      return (if Raw < 0 then OS.Invalid_FD else OS.File_Descriptor (Raw));
   exception
      when others =>
         CS.Free (C_Name);
         return OS.Invalid_FD;
   end Shared_Memory_Open;

   function Shared_Memory_Unlink (Name : String) return Boolean is
      C_Name : CS.chars_ptr := CS.New_String (Name);
      Result : C.int;
   begin
      Result := C_Shm_Unlink (C_Name);
      CS.Free (C_Name);
      return Result = 0;
   exception
      when others =>
         CS.Free (C_Name);
         return False;
   end Shared_Memory_Unlink;

   function Open_Directory_No_Follow (Path : String) return C.int is
      Name : CS.chars_ptr := CS.New_String (Path);
      Result : C.int;
   begin
      Result := C_Open (Name, O_DIRECTORY + O_NOFOLLOW + O_CLOEXEC);
      CS.Free (Name);
      return Result;
   exception
      when others =>
         CS.Free (Name);
         return -1;
   end Open_Directory_No_Follow;

   function Create_File_At
     (Directory : C.int;
      Name      : String;
      Mode      : C.unsigned) return C.int
   is
      C_Name : CS.chars_ptr := CS.New_String (Name);
      Result : C.int;
   begin
      Result := C_Openat
        (Directory,
         C_Name,
         O_WRONLY + O_CREAT + O_EXCL + O_NOFOLLOW + O_CLOEXEC,
         Mode);
      CS.Free (C_Name);
      return Result;
   exception
      when others =>
         CS.Free (C_Name);
         return -1;
   end Create_File_At;

   function Write_File
     (FD     : C.int;
      Buffer : System.Address;
      Count  : C.size_t) return C.long is
     (C_Write (FD, Buffer, Count));

   function Close_File (FD : C.int) return C.int is (C_Close (FD));

   function Delete_File_At
     (Directory : C.int;
      Name      : String) return Boolean
   is
      C_Name : CS.chars_ptr := CS.New_String (Name);
      Result : C.int;
   begin
      Result := C_Unlinkat (Directory, C_Name, 0);
      CS.Free (C_Name);
      return Result = 0;
   exception
      when others =>
         CS.Free (C_Name);
         return False;
   end Delete_File_At;

   function Open_Dynamic_Library (Name : String) return System.Address is
      C_Name : CS.chars_ptr := CS.New_String (Name);
      Result : System.Address;
   begin
      Result := Dlopen (C_Name, RTLD_LAZY);
      CS.Free (C_Name);
      return Result;
   exception
      when others =>
         CS.Free (C_Name);
         return System.Null_Address;
   end Open_Dynamic_Library;

   function Dynamic_Symbol
     (Handle : System.Address;
      Name   : String) return System.Address
   is
      C_Name : CS.chars_ptr := CS.New_String (Name);
      Result : System.Address;
   begin
      Result := Dlsym (Handle, C_Name);
      CS.Free (C_Name);
      return Result;
   exception
      when others =>
         CS.Free (C_Name);
         return System.Null_Address;
   end Dynamic_Symbol;
end Terminal.App.Platform_Media;

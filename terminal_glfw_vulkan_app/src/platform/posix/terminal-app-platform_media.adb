with Interfaces.C.Strings;

package body Terminal.App.Platform_Media is
   package CS renames Interfaces.C.Strings;

   use type C.int;

   function C_Local_Available return C.int
   with Import, Convention => C,
        External_Name => "terminal_media_local_file_transfers_available";

   function C_Shm_Open (Name : CS.chars_ptr) return C.int
   with Import, Convention => C,
        External_Name => "terminal_media_shared_memory_open";

   function C_Shm_Unlink (Name : CS.chars_ptr) return C.int
   with Import, Convention => C,
        External_Name => "terminal_media_shared_memory_unlink";

   function C_Open_Read (Path : CS.chars_ptr) return C.int
   with Import, Convention => C,
        External_Name => "terminal_media_open_read_no_follow";

   function C_Descriptor_Path
     (FD       : C.int;
      Buffer   : System.Address;
      Capacity : C.size_t) return C.int
   with Import, Convention => C,
        External_Name => "terminal_media_descriptor_path";

   function C_Open_Directory (Path : CS.chars_ptr) return C.int
   with Import, Convention => C,
        External_Name => "terminal_media_open_directory_no_follow";

   function C_Open_Read_At
     (Directory : C.int;
      Path      : CS.chars_ptr) return C.int
   with Import, Convention => C,
        External_Name => "terminal_media_open_read_at_no_follow";

   function C_Create_File_At
     (Directory : C.int;
      Path      : CS.chars_ptr;
      Mode      : C.unsigned) return C.int
   with Import, Convention => C,
        External_Name => "terminal_media_create_file_at";

   function C_Write
     (FD     : C.int;
      Buffer : System.Address;
      Count  : C.size_t) return C.long
   with Import, Convention => C, External_Name => "terminal_media_write";

   function C_Close (FD : C.int) return C.int
   with Import, Convention => C, External_Name => "terminal_media_close";

   function C_Delete_File_At
     (Directory : C.int;
      Path      : CS.chars_ptr) return C.int
   with Import, Convention => C,
        External_Name => "terminal_media_delete_file_at";

   function Local_File_Transfers_Available return Boolean is
     (C_Local_Available /= 0);
   function Shared_Memory_Transfers_Available return Boolean is (True);
   function File_Downloads_Available return Boolean is (True);

   function Open_Read_No_Follow (Path : String) return OS.File_Descriptor is
      Name : CS.chars_ptr := CS.New_String (Path);
      Raw  : C.int;
   begin
      Raw := C_Open_Read (Name);
      CS.Free (Name);
      return (if Raw < 0 then OS.Invalid_FD else OS.File_Descriptor (Raw));
   exception
      when others =>
         CS.Free (Name);
         raise;
   end Open_Read_No_Follow;

   function Descriptor_Path (FD : OS.File_Descriptor) return String is
      Buffer : aliased String (1 .. 4_096) := (others => ASCII.NUL);
      Length : C.int;
   begin
      Length := C_Descriptor_Path
        (C.int (FD), Buffer (Buffer'First)'Address, C.size_t (Buffer'Length));
      if Length <= 0 or else Length > C.int (Buffer'Length) then
         return "";
      end if;
      return Buffer (1 .. Natural (Length));
   end Descriptor_Path;

   function Shared_Memory_Open (Name : String) return OS.File_Descriptor is
      C_Name : CS.chars_ptr := CS.New_String (Name);
      Raw    : C.int;
   begin
      Raw := C_Shm_Open (C_Name);
      CS.Free (C_Name);
      return (if Raw < 0 then OS.Invalid_FD else OS.File_Descriptor (Raw));
   exception
      when others =>
         CS.Free (C_Name);
         raise;
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
         raise;
   end Shared_Memory_Unlink;

   function Open_Directory_No_Follow (Path : String) return C.int is
      Name : CS.chars_ptr := CS.New_String (Path);
      Result : C.int;
   begin
      Result := C_Open_Directory (Name);
      CS.Free (Name);
      return Result;
   exception
      when others =>
         CS.Free (Name);
         raise;
   end Open_Directory_No_Follow;

   function Open_Read_At_No_Follow
     (Directory : C.int;
      Name      : String) return OS.File_Descriptor
   is
      C_Name : CS.chars_ptr := CS.New_String (Name);
      Raw : C.int;
   begin
      Raw := C_Open_Read_At (Directory, C_Name);
      CS.Free (C_Name);
      return (if Raw < 0 then OS.Invalid_FD else OS.File_Descriptor (Raw));
   exception
      when others =>
         CS.Free (C_Name);
         raise;
   end Open_Read_At_No_Follow;

   function Create_File_At
     (Directory : C.int;
      Name      : String;
      Mode      : C.unsigned) return C.int
   is
      C_Name : CS.chars_ptr := CS.New_String (Name);
      Result : C.int;
   begin
      Result := C_Create_File_At
        (Directory,
         C_Name,
         Mode);
      CS.Free (C_Name);
      return Result;
   exception
      when others =>
         CS.Free (C_Name);
         raise;
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
      Result := C_Delete_File_At (Directory, C_Name);
      CS.Free (C_Name);
      return Result = 0;
   exception
      when others =>
         CS.Free (C_Name);
         raise;
   end Delete_File_At;

end Terminal.App.Platform_Media;

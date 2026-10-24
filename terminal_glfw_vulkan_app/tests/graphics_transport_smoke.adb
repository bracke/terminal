with Ada.Directories;
with AUnit.Assertions;
with GNAT.OS_Lib;
with Interfaces.C;
with Interfaces.C.Strings;
with Terminal.App.Graphics_Transport;
with Terminal.Common.Bytes;

procedure Graphics_Transport_Smoke is
   use AUnit.Assertions;
   use type GNAT.OS_Lib.File_Descriptor;
   use type Terminal.App.Graphics_Transport.Byte_Array_Access;
   use type Terminal.App.Graphics_Transport.Load_Status;
   use type Terminal.Common.Bytes.Byte;

   package Transport renames Terminal.App.Graphics_Transport;
   package OS renames GNAT.OS_Lib;
   package C renames Interfaces.C;
   package CS renames Interfaces.C.Strings;

   use type C.int;

   function C_Symlink
     (Target : CS.chars_ptr;
      Link   : CS.chars_ptr) return C.int
   with Import, Convention => C, External_Name => "symlink";

   File_Path : constant String := "/tmp/terminal-graphics-transport.bin";
   File_Name : constant String :=
     "L3RtcC90ZXJtaW5hbC1ncmFwaGljcy10cmFuc3BvcnQuYmlu";
   Temp_Path : constant String :=
     "/tmp/tty-graphics-protocol-terminal-test.bin";
   Temp_Name : constant String :=
     "L3RtcC90dHktZ3JhcGhpY3MtcHJvdG9jb2wtdGVybWluYWwtdGVzdC5iaW4=";
   Temp_Link_Path : constant String :=
     "/tmp/tty-graphics-protocol-terminal-link.bin";
   Temp_Link_Name : constant String :=
     "L3RtcC90dHktZ3JhcGhpY3MtcHJvdG9jb2wtdGVybWluYWwtbGluay5iaW4=";
   Shm_Path : constant String := "/dev/shm/terminal-graphics-shm-test";
   Shm_Name : constant String := "L3Rlcm1pbmFsLWdyYXBoaWNzLXNobS10ZXN0";
   Content : aliased Terminal.Common.Bytes.Byte_Array :=
     (1 => 16#10#, 2 => 16#20#, 3 => 16#30#, 4 => 16#40#);

   procedure Write_File (Path : String) is
      FD : constant OS.File_Descriptor := OS.Create_File (Path, OS.Binary);
      Written : Integer;
   begin
      Assert (FD /= OS.Invalid_FD, "create transport fixture");
      Written := OS.Write (FD, Content (1)'Address, Content'Length);
      OS.Close (FD);
      Assert (Written = Content'Length, "write transport fixture");
   end Write_File;

   procedure Delete_If_Present (Path : String) is
      Deleted : Boolean;
   begin
      if Ada.Directories.Exists (Path) then
         OS.Delete_File (Path, Deleted);
      end if;
   end Delete_If_Present;

   function Create_Symlink (Target, Link : String) return Boolean is
      Target_C : CS.chars_ptr := CS.New_String (Target);
      Link_C   : CS.chars_ptr := CS.New_String (Link);
      Result   : C.int;
   begin
      Result := C_Symlink (Target_C, Link_C);
      CS.Free (Target_C);
      CS.Free (Link_C);
      return Result = 0;
   exception
      when others =>
         CS.Free (Target_C);
         CS.Free (Link_C);
         return False;
   end Create_Symlink;

   procedure Check_Load
     (Medium : Character;
      Name : String;
      Offset : Natural;
      Size : Natural;
      Size_Specified : Boolean;
      Expected_Length : Natural;
      Label_Text : String)
   is
      Bytes : Transport.Byte_Array_Access := null;
      Length : Natural;
      Status : Transport.Load_Status;
   begin
      Transport.Load
        (Medium,
         Name,
         Offset,
         Size,
         Size_Specified,
         Transport.Trusted_Access_Policy,
         Transport.Max_Transfer_Bytes,
         Bytes,
         Length,
         Status);
      Assert (Status = Transport.Load_Ok, Label_Text & " status");
      Assert
        (Bytes /= null and then Length = Expected_Length,
         Label_Text & " length");
      if Expected_Length = 2 then
         Assert
           (Bytes (1) = 16#20# and then Bytes (2) = 16#30#,
            Label_Text & " content");
      else
         Assert
           (Bytes (1) = 16#10# and then Bytes (4) = 16#40#,
            Label_Text & " content");
      end if;
      Transport.Release (Bytes);
   end Check_Load;
begin
   Delete_If_Present (File_Path);
   Delete_If_Present (Temp_Path);
   Delete_If_Present (Temp_Link_Path);
   Delete_If_Present (Shm_Path);

   Write_File (File_Path);
   declare
      Bytes : Transport.Byte_Array_Access := null;
      Length : Natural;
      Status : Transport.Load_Status;
   begin
      Transport.Load
        ('f', File_Name, 0, 0, False, Bytes, Length, Status);
      Assert
        (Status = Transport.Load_Access_Failed and then Bytes = null,
         "ordinary files require an explicit access policy");
   end;
   Check_Load ('f', File_Name, 1, 2, True, 2, "regular file slice");
   Check_Load ('f', File_Name, 0, 0, False, 4, "regular file remainder");

   declare
      Bytes : Transport.Byte_Array_Access := null;
      Length : Natural;
      Status : Transport.Load_Status;
   begin
      Transport.Load
        ('f',
         File_Name,
         0,
         0,
         False,
         Transport.Trusted_Access_Policy,
         Maximum_Bytes => 3,
         Bytes => Bytes,
         Length => Length,
         Status => Status);
      Assert
        (Status = Transport.Load_Too_Large and then Bytes = null,
         "configured transport byte limit is enforced before allocation");
   end;

   declare
      Bytes : Transport.Byte_Array_Access := null;
      Length : Natural;
      Status : Transport.Load_Status;
   begin
      Transport.Load
        ('f',
         "L2Rldi9udWxs",
         0,
         0,
         False,
         Transport.Trusted_Access_Policy,
         Transport.Max_Transfer_Bytes,
         Bytes,
         Length,
         Status);
      Assert
        (Status = Transport.Load_Access_Failed and then Bytes = null,
         "special sensitive files must be rejected uniformly");
      Transport.Load ('f', "!", 0, 0, False, Bytes, Length, Status);
      Assert
        (Status = Transport.Load_Invalid_Location and then Bytes = null,
         "malformed location must be rejected");
   end;

   Write_File (Temp_Path);
   Assert
     (Create_Symlink (Temp_Path, Temp_Link_Path),
      "create temporary transport symlink fixture");
   declare
      Bytes : Transport.Byte_Array_Access := null;
      Length : Natural;
      Status : Transport.Load_Status;
   begin
      Transport.Load
        ('t',
         Temp_Link_Name,
         0,
         0,
         False,
         Transport.Trusted_Access_Policy,
         Transport.Max_Transfer_Bytes,
         Bytes,
         Length,
         Status);
      Assert
        (Status = Transport.Load_Access_Failed and then Bytes = null,
         "temporary transfer must not follow a symbolic link");
   end;
   Delete_If_Present (Temp_Link_Path);
   Check_Load ('t', Temp_Name, 0, 0, False, 4, "temporary file");
   Assert
     (not Ada.Directories.Exists (Temp_Path),
      "safe temporary transfer must unlink its file");

   Write_File (Shm_Path);
   Check_Load ('s', Shm_Name, 0, 0, False, 4, "POSIX shared memory");
   Assert
     (not Ada.Directories.Exists (Shm_Path),
      "POSIX shared-memory transfer must unlink its object");

   Delete_If_Present (File_Path);
end Graphics_Transport_Smoke;

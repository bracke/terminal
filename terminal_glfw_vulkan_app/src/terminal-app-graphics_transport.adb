with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Unchecked_Deallocation;
with GNAT.OS_Lib;
with Interfaces.C;
with Interfaces.C.Strings;

package body Terminal.App.Graphics_Transport is
   package OS renames GNAT.OS_Lib;
   package C renames Interfaces.C;
   package C_Strings renames Interfaces.C.Strings;

   use type OS.File_Descriptor;
   use type OS.Large_File_Size;
   use type C.int;

   procedure Free_Bytes is new Ada.Unchecked_Deallocation
     (Terminal.Common.Bytes.Byte_Array, Byte_Array_Access);

   function C_Shm_Open
     (Name  : C_Strings.chars_ptr;
      Flags : C.int;
      Mode  : C.unsigned) return C.int
   with Import, Convention => C, External_Name => "shm_open";

   function C_Shm_Unlink (Name : C_Strings.chars_ptr) return C.int
   with Import, Convention => C, External_Name => "shm_unlink";

   function C_Open
     (Path  : C_Strings.chars_ptr;
      Flags : C.int) return C.int
   with Import, Convention => C, External_Name => "open";

   O_RDONLY : constant C.int := 0;
   O_NOFOLLOW : constant C.int := 131_072;
   O_CLOEXEC  : constant C.int := 524_288;

   function Open_No_Follow (Path : String) return OS.File_Descriptor is
      Name : C_Strings.chars_ptr := C_Strings.New_String (Path);
      Raw  : C.int;
   begin
      Raw := C_Open (Name, O_RDONLY + O_NOFOLLOW + O_CLOEXEC);
      C_Strings.Free (Name);
      if Raw < 0 then
         return OS.Invalid_FD;
      end if;
      return OS.File_Descriptor (Raw);
   exception
      when others =>
         C_Strings.Free (Name);
         return OS.Invalid_FD;
   end Open_No_Follow;

   procedure Release (Bytes : in out Byte_Array_Access) is
   begin
      if Bytes /= null then
         Free_Bytes (Bytes);
      end if;
   end Release;

   function Base64_Value (Ch : Character) return Integer is
   begin
      case Ch is
         when 'A' .. 'Z' =>
            return Character'Pos (Ch) - Character'Pos ('A');
         when 'a' .. 'z' =>
            return 26 + Character'Pos (Ch) - Character'Pos ('a');
         when '0' .. '9' =>
            return 52 + Character'Pos (Ch) - Character'Pos ('0');
         when '+' => return 62;
         when '/' => return 63;
         when others => return -1;
      end case;
   end Base64_Value;

   function Decode_Location (Text : String) return String is
      Result : String (1 .. Max_Location_Length);
      Length : Natural := 0;
      Values : array (Positive range 1 .. 4) of Natural := (others => 0);
      Count : Natural := 0;
      Padding : Natural := 0;
      Finished : Boolean := False;

      procedure Append (Value : Natural) is
      begin
         if Length = Result'Length or else Value = 0 then
            raise Constraint_Error;
         end if;
         Length := Length + 1;
         Result (Length) := Character'Val (Value mod 256);
      end Append;

      procedure Flush is
      begin
         if Count < 2 or else Padding > 2 then
            raise Constraint_Error;
         end if;
         Append (Values (1) * 4 + Values (2) / 16);
         if Count >= 3 and then Padding < 2 then
            Append ((Values (2) mod 16) * 16 + Values (3) / 4);
         end if;
         if Count = 4 and then Padding = 0 then
            Append ((Values (3) mod 4) * 64 + Values (4));
         end if;
      end Flush;
   begin
      if Text'Length = 0 then
         return "";
      end if;

      for Ch of Text loop
         declare
            Value : constant Integer := Base64_Value (Ch);
         begin
            if Finished then
               raise Constraint_Error;
            elsif Ch = '=' then
               Count := Count + 1;
               Padding := Padding + 1;
               if Count > 4 then
                  raise Constraint_Error;
               end if;
               Values (Count) := 0;
               if Count = 4 then
                  Flush;
                  Finished := True;
               end if;
            elsif Value < 0 or else Padding > 0 then
               raise Constraint_Error;
            else
               Count := Count + 1;
               if Count > 4 then
                  raise Constraint_Error;
               end if;
               Values (Count) := Natural (Value);
               if Count = 4 then
                  Flush;
                  Values := (others => 0);
                  Count := 0;
               end if;
            end if;
         end;
      end loop;

      if not Finished and then Count > 0 then
         Flush;
      end if;
      if Length = 0 then
         return "";
      end if;
      return Result (1 .. Length);
   exception
      when Constraint_Error =>
         return "";
   end Decode_Location;

   function Has_Path_Prefix (Path, Prefix : String) return Boolean is
      Last : Natural;
   begin
      if Prefix'Length = 0 or else Path'Length < Prefix'Length then
         return False;
      end if;
      Last := Path'First + Prefix'Length - 1;
      if Path (Path'First .. Last) /= Prefix then
         return False;
      end if;
      return Path'Length = Prefix'Length
        or else Prefix (Prefix'Last) = '/'
        or else Path (Last + 1) = '/';
   end Has_Path_Prefix;

   function Sensitive_Path (Path : String) return Boolean is
   begin
      return Has_Path_Prefix (Path, "/proc")
        or else Has_Path_Prefix (Path, "/sys")
        or else Has_Path_Prefix (Path, "/dev")
        or else Has_Path_Prefix (Path, "/run");
   end Sensitive_Path;

   function Descriptor_Path (FD : OS.File_Descriptor) return String is
      Image : constant String := OS.File_Descriptor'Image (FD);
   begin
      return "/proc/self/fd/" & Image (Image'First + 1 .. Image'Last);
   end Descriptor_Path;

   function Safe_Temporary_Path (Path : String) return Boolean is
      Marker : constant String := "tty-graphics-protocol";
      function Under (Directory : String) return Boolean is
         Normalized : constant String :=
           OS.Normalize_Pathname
             (Directory, Resolve_Links => True, Case_Sensitive => True);
      begin
         return Normalized'Length > 0 and then Has_Path_Prefix (Path, Normalized);
      end Under;
   begin
      if Ada.Strings.Fixed.Index (Path, Marker) = 0 then
         return False;
      end if;
      if Under ("/tmp") or else Under ("/var/tmp") or else Under ("/dev/shm")
      then
         return True;
      end if;
      if Ada.Environment_Variables.Exists ("TMPDIR") then
         return Under (Ada.Environment_Variables.Value ("TMPDIR"));
      end if;
      return False;
   exception
      when others =>
         return False;
   end Safe_Temporary_Path;

   procedure Read_Descriptor
     (FD             : OS.File_Descriptor;
      Offset         : Natural;
      Size           : Natural;
      Size_Specified : Boolean;
      Maximum_Bytes  : Positive;
      Bytes          : out Byte_Array_Access;
      Length         : out Natural;
      Status         : out Load_Status)
   is
      File_Length : constant OS.Large_File_Size := OS.File_Length64 (FD);
      Available : OS.Large_File_Size;
      Wanted : Natural;
      Got : Natural := 0;
   begin
      Bytes := null;
      Length := 0;
      Status := Load_Access_Failed;
      if File_Length < 0
        or else OS.Large_File_Size (Offset) > File_Length
      then
         return;
      end if;
      Available := File_Length - OS.Large_File_Size (Offset);
      if Size_Specified then
         if Size > Maximum_Bytes then
            Status := Load_Too_Large;
            return;
         elsif OS.Large_File_Size (Size) > Available then
            return;
         end if;
         Wanted := Size;
      else
         if Available > OS.Large_File_Size (Maximum_Bytes) then
            Status := Load_Too_Large;
            return;
         end if;
         Wanted := Natural (Available);
      end if;
      if Wanted = 0 then
         return;
      end if;

      Bytes := new Terminal.Common.Bytes.Byte_Array (1 .. Wanted);
      OS.Lseek (FD, Long_Integer (Offset), OS.Seek_Set);
      while Got < Wanted loop
         declare
            Read_Count : constant Integer :=
              OS.Read
                (FD,
                 Bytes (Got + 1)'Address,
                 Integer (Wanted - Got));
         begin
            if Read_Count <= 0 then
               Release (Bytes);
               return;
            end if;
            Got := Got + Natural (Read_Count);
         end;
      end loop;
      Length := Wanted;
      Status := Load_Ok;
   exception
      when Storage_Error =>
         Release (Bytes);
         Status := Load_Allocation_Failed;
      when others =>
         Release (Bytes);
         Status := Load_Access_Failed;
   end Read_Descriptor;

   procedure Load
     (Medium           : Character;
      Encoded_Location : String;
      Offset           : Natural;
      Size             : Natural;
      Size_Specified   : Boolean;
      Policy           : Access_Policy;
      Maximum_Bytes    : Positive;
      Bytes            : out Byte_Array_Access;
      Length           : out Natural;
      Status           : out Load_Status)
   is
      Location : constant String := Decode_Location (Encoded_Location);
      FD : OS.File_Descriptor := OS.Invalid_FD;
   begin
      Bytes := null;
      Length := 0;
      Status := Load_Invalid_Location;
      if Location'Length = 0 then
         return;
      end if;

      if (Medium = 'f' and then not Policy.Allow_Regular_Files)
        or else (Medium = 't' and then not Policy.Allow_Temporary_Files)
        or else (Medium = 's' and then not Policy.Allow_Shared_Memory)
      then
         Status := Load_Access_Failed;
         return;
      elsif Medium in 'f' | 't' then
         declare
            Canonical : constant String :=
              OS.Normalize_Pathname
                (Location, Resolve_Links => True, Case_Sensitive => True);
            Temporary : constant Boolean := Medium = 't';
            Delete_Ok : Boolean := False;
         begin
            if Canonical'Length = 0
              or else not OS.Is_Absolute_Path (Canonical)
              or else (not Temporary and then Sensitive_Path (Canonical))
              or else (Temporary and then not Safe_Temporary_Path (Canonical))
              or else not OS.Is_Regular_File (Canonical)
            then
               Status := Load_Access_Failed;
               return;
            end if;

            FD := Open_No_Follow (Location);
            if FD = OS.Invalid_FD then
               Status := Load_Access_Failed;
               return;
            end if;
            --  Validate the object actually opened, rather than trusting the
            --  earlier pathname lookup. O_NOFOLLOW protects the final path
            --  component and this descriptor resolution also catches a raced
            --  parent-directory replacement.
            declare
               Opened_Path : constant String :=
                 OS.Normalize_Pathname
                   (Descriptor_Path (FD),
                    Resolve_Links => True,
                    Case_Sensitive => True);
            begin
               if Opened_Path'Length = 0
                 or else not OS.Is_Absolute_Path (Opened_Path)
                 or else not OS.Is_Regular_File (Descriptor_Path (FD))
                 or else
                   (if Temporary
                    then not Safe_Temporary_Path (Opened_Path)
                    else Sensitive_Path (Opened_Path))
               then
                  OS.Close (FD);
                  FD := OS.Invalid_FD;
                  Status := Load_Access_Failed;
                  return;
               end if;
               Read_Descriptor
                 (FD,
                  Offset,
                  Size,
                  Size_Specified,
                  Maximum_Bytes,
                  Bytes,
                  Length,
                  Status);
            end;
            OS.Close (FD);
            FD := OS.Invalid_FD;
            if Temporary and then Status = Load_Ok then
               OS.Delete_File (Canonical, Delete_Ok);
               if not Delete_Ok then
                  Release (Bytes);
                  Length := 0;
                  Status := Load_Access_Failed;
               end if;
            end if;
         end;
      elsif Medium = 's' then
         if Location (Location'First) /= '/'
           or else Location'Length > 255
           or else
             Ada.Strings.Fixed.Index
               (Location (Location'First + 1 .. Location'Last), "/") /= 0
         then
            return;
         end if;
         declare
            Name : C_Strings.chars_ptr := C_Strings.New_String (Location);
            Raw_FD : C.int;
            Ignored : C.int := 0;
         begin
            Raw_FD := C_Shm_Open (Name, O_RDONLY, 0);
            if Raw_FD >= 0 then
               FD := OS.File_Descriptor (Raw_FD);
               Read_Descriptor
                 (FD,
                  Offset,
                  Size,
                  Size_Specified,
                  Maximum_Bytes,
                  Bytes,
                  Length,
                  Status);
               Ignored := C_Shm_Unlink (Name);
               OS.Close (FD);
               FD := OS.Invalid_FD;
            else
               Status := Load_Access_Failed;
            end if;
            C_Strings.Free (Name);
            pragma Unreferenced (Ignored);
         exception
            when others =>
               C_Strings.Free (Name);
               if FD /= OS.Invalid_FD then
                  OS.Close (FD);
               end if;
               Release (Bytes);
               Length := 0;
               Status := Load_Access_Failed;
         end;
      end if;
   exception
      when Storage_Error =>
         if FD /= OS.Invalid_FD then
            OS.Close (FD);
         end if;
         Release (Bytes);
         Status := Load_Allocation_Failed;
      when others =>
         if FD /= OS.Invalid_FD then
            OS.Close (FD);
         end if;
         Release (Bytes);
         Status := Load_Access_Failed;
   end Load;

   procedure Load
     (Medium           : Character;
      Encoded_Location : String;
      Offset           : Natural;
      Size             : Natural;
      Size_Specified   : Boolean;
      Bytes            : out Byte_Array_Access;
      Length           : out Natural;
      Status           : out Load_Status) is
   begin
      Load
        (Medium,
         Encoded_Location,
         Offset,
         Size,
         Size_Specified,
         Default_Access_Policy,
         Max_Transfer_Bytes,
         Bytes,
         Length,
         Status);
   end Load;
end Terminal.App.Graphics_Transport;

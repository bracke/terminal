with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Unchecked_Deallocation;
with GNAT.OS_Lib;
with Interfaces.C;

with Terminal.App.Platform_Media;
with Terminal.Common.Base64;

package body Terminal.App.Graphics_Transport is
   package OS renames GNAT.OS_Lib;
   package Platform renames Terminal.App.Platform_Media;

   use type OS.File_Descriptor;
   use type OS.Large_File_Size;
   use type Interfaces.C.int;

   procedure Free_Bytes is new Ada.Unchecked_Deallocation
     (Terminal.Common.Bytes.Byte_Array, Byte_Array_Access);

   procedure Release (Bytes : in out Byte_Array_Access) is
   begin
      if Bytes /= null then
         Free_Bytes (Bytes);
      end if;
   end Release;

   function Decode_Location (Text : String) return String is
      Result : String (1 .. Max_Location_Length);
      Length : Natural := 0;
      Values : Terminal.Common.Base64.Quantum := (others => 0);
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
         if not Terminal.Common.Base64.Is_Valid_Quantum
           (Values, Count, Padding, Allow_Unpadded => True)
         then
            raise Constraint_Error;
         end if;
         Append (Natural (Terminal.Common.Base64.Decode_Byte (Values, 1)));
         if Count >= 3 and then Padding < 2 then
            Append (Natural (Terminal.Common.Base64.Decode_Byte (Values, 2)));
         end if;
         if Count = 4 and then Padding = 0 then
            Append (Natural (Terminal.Common.Base64.Decode_Byte (Values, 3)));
         end if;
      end Flush;
   begin
      if Text'Length = 0 then
         return "";
      end if;

      for Ch of Text loop
         declare
            Value : constant Integer := Terminal.Common.Base64.Value (Ch);
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
         raise;
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
      Directory_FD : Interfaces.C.int := -1;
   begin
      Bytes := null;
      Length := 0;
      Status := Load_Invalid_Location;
      if Location'Length = 0 then
         return;
      end if;

      if (Medium in 'f' | 't'
          and then not Platform.Local_File_Transfers_Available)
        or else
          (Medium = 's'
           and then not Platform.Shared_Memory_Transfers_Available)
        or else (Medium = 'f' and then not Policy.Allow_Regular_Files)
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
            Requested : constant String :=
              OS.Normalize_Pathname
                (Location, Resolve_Links => False, Case_Sensitive => True);
            Temporary : constant Boolean := Medium = 't';
            Parent : constant String :=
              (if Requested'Length = 0
               then ""
               else Ada.Directories.Containing_Directory (Requested));
            Name : constant String :=
              (if Requested'Length = 0
               then ""
               else Ada.Directories.Simple_Name (Requested));
         begin
            if Canonical'Length = 0
              or else Requested'Length = 0
              or else not OS.Is_Absolute_Path (Canonical)
              or else not OS.Is_Absolute_Path (Requested)
              or else (not Temporary and then Sensitive_Path (Canonical))
              or else (Temporary and then not Safe_Temporary_Path (Canonical))
              or else not OS.Is_Regular_File (Canonical)
            then
               Status := Load_Access_Failed;
               return;
            end if;

            if Temporary then
               Directory_FD := Platform.Open_Directory_No_Follow (Parent);
               if Directory_FD < 0 then
                  Status := Load_Access_Failed;
                  return;
               end if;
               FD := Platform.Open_Read_At_No_Follow (Directory_FD, Name);
            else
               FD := Platform.Open_Read_No_Follow (Location);
            end if;
            if FD = OS.Invalid_FD then
               if Directory_FD >= 0 then
                  declare
                     Ignored : constant Interfaces.C.int :=
                       Platform.Close_File (Directory_FD);
                     pragma Unreferenced (Ignored);
                  begin
                     Directory_FD := -1;
                  end;
               end if;
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
                   (Platform.Descriptor_Path (FD),
                    Resolve_Links => True,
                    Case_Sensitive => True);
            begin
               if Opened_Path'Length = 0
                 or else not OS.Is_Absolute_Path (Opened_Path)
                 or else Opened_Path /= Canonical
                 or else not OS.Is_Regular_File (Platform.Descriptor_Path (FD))
                 or else
                   (if Temporary
                    then not Safe_Temporary_Path (Opened_Path)
                    else Sensitive_Path (Opened_Path))
               then
                  OS.Close (FD);
                  FD := OS.Invalid_FD;
                  if Directory_FD >= 0 then
                     declare
                        Ignored : constant Interfaces.C.int :=
                          Platform.Close_File (Directory_FD);
                        pragma Unreferenced (Ignored);
                     begin
                        Directory_FD := -1;
                     end;
                  end if;
                  Status := Load_Access_Failed;
                  return;
               end if;
               if Temporary
                 and then not Platform.Delete_File_At (Directory_FD, Name)
               then
                  OS.Close (FD);
                  FD := OS.Invalid_FD;
                  declare
                     Ignored : constant Interfaces.C.int :=
                       Platform.Close_File (Directory_FD);
                     pragma Unreferenced (Ignored);
                  begin
                     Directory_FD := -1;
                  end;
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
            if Directory_FD >= 0 then
               declare
                  Ignored : constant Interfaces.C.int :=
                    Platform.Close_File (Directory_FD);
                  pragma Unreferenced (Ignored);
               begin
                  Directory_FD := -1;
               end;
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
            Unlinked : Boolean := False;
         begin
            FD := Platform.Shared_Memory_Open (Location);
            if FD /= OS.Invalid_FD then
               Read_Descriptor
                 (FD,
                  Offset,
                  Size,
                  Size_Specified,
                  Maximum_Bytes,
                  Bytes,
                  Length,
                  Status);
               Unlinked := Platform.Shared_Memory_Unlink (Location);
               OS.Close (FD);
               FD := OS.Invalid_FD;
            else
               Status := Load_Access_Failed;
            end if;
            pragma Unreferenced (Unlinked);
         end;
      end if;
   exception
      when Storage_Error =>
         if FD /= OS.Invalid_FD then
            OS.Close (FD);
         end if;
         if Directory_FD >= 0 then
            declare
               Ignored : constant Interfaces.C.int :=
                 Platform.Close_File (Directory_FD);
               pragma Unreferenced (Ignored);
            begin
               null;
            end;
         end if;
         Release (Bytes);
         Status := Load_Allocation_Failed;
      when others =>
         if FD /= OS.Invalid_FD then
            OS.Close (FD);
         end if;
         if Directory_FD >= 0 then
            declare
               Ignored : constant Interfaces.C.int :=
                 Platform.Close_File (Directory_FD);
               pragma Unreferenced (Ignored);
            begin
               null;
            end;
         end if;
         Release (Bytes);
         raise;
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

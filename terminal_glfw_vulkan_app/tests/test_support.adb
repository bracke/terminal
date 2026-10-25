with Ada.Directories;
with GNAT.OS_Lib;
with Interfaces.C;
with System;

package body Test_Support is
   package C renames Interfaces.C;
   use type C.int;
   use type System.Address;

   Alphabet : constant String :=
     "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

   function C_Mkstemp (Template : System.Address) return C.int
   with Import, Convention => C, External_Name => "mkstemp";
   function C_Mkdtemp (Template : System.Address) return System.Address
   with Import, Convention => C, External_Name => "mkdtemp";
   function C_Unlink (Path : System.Address) return C.int
   with Import, Convention => C, External_Name => "unlink";
   function C_Rmdir (Path : System.Address) return C.int
   with Import, Convention => C, External_Name => "rmdir";

   procedure Set_Path (Target : in out Path_Buffer; Value : String) is
   begin
      if Value'Length > Target.Value'Length then
         raise Constraint_Error with "temporary path exceeds test buffer";
      end if;
      Target.Length := Value'Length;
      Target.Value (1 .. Value'Length) := Value;
   end Set_Path;

   function Value (Source : Path_Buffer) return String is
     (Source.Value (1 .. Source.Length));

   procedure Reserve
     (Item      : in out Temporary_File;
      Prefix    : String;
      Directory : String := "/tmp")
   is
      Template : C.char_array :=
        C.To_C (Directory & "/" & Prefix & "-XXXXXX");
      FD : C.int := -1;
   begin
      Finalize (Item);
      FD := C_Mkstemp (Template (Template'First)'Address);
      if FD < 0 then
         raise Program_Error with "unable to reserve a temporary test file";
      end if;
      GNAT.OS_Lib.Close (GNAT.OS_Lib.File_Descriptor (FD));
      FD := -1;
      Set_Path (Item.Name, C.To_Ada (Template, Trim_Nul => True));
   exception
      when others =>
         if FD >= 0 then
            GNAT.OS_Lib.Close (GNAT.OS_Lib.File_Descriptor (FD));
         end if;
         declare
            Ignored : constant C.int :=
              C_Unlink (Template (Template'First)'Address);
            pragma Unreferenced (Ignored);
         begin
            null;
         end;
         raise;
   end Reserve;

   function Path (Item : Temporary_File) return String is
     (Value (Item.Name));

   overriding procedure Finalize (Item : in out Temporary_File) is
   begin
      if Item.Name.Length > 0 then
         Delete_If_Present (Value (Item.Name));
         Item.Name.Length := 0;
      end if;
   exception
      when others =>
         Item.Name.Length := 0;
   end Finalize;

   procedure Reserve
     (Item      : in out Temporary_Directory;
      Prefix    : String;
      Directory : String := "/tmp")
   is
      Template : C.char_array :=
        C.To_C (Directory & "/" & Prefix & "-XXXXXX");
      Result : System.Address;
   begin
      Finalize (Item);
      Result := C_Mkdtemp (Template (Template'First)'Address);
      if Result = System.Null_Address then
         raise Program_Error with "unable to reserve a temporary test directory";
      end if;
      Set_Path (Item.Name, C.To_Ada (Template, Trim_Nul => True));
   exception
      when others =>
         declare
            Ignored : constant C.int :=
              C_Rmdir (Template (Template'First)'Address);
            pragma Unreferenced (Ignored);
         begin
            null;
         end;
         raise;
   end Reserve;

   function Path (Item : Temporary_Directory) return String is
     (Value (Item.Name));

   overriding procedure Finalize (Item : in out Temporary_Directory) is
   begin
      if Item.Name.Length > 0
        and then Ada.Directories.Exists (Value (Item.Name))
      then
         Ada.Directories.Delete_Tree (Value (Item.Name));
      end if;
      Item.Name.Length := 0;
   exception
      when others =>
         Item.Name.Length := 0;
   end Finalize;

   function Base64 (Text : String) return String is
      Length : constant Natural := 4 * ((Text'Length + 2) / 3);
      Result : String (1 .. Length) := (others => '=');
      Input  : Natural := Text'First;
      Output : Natural := Result'First;
   begin
      while Input <= Text'Last loop
         declare
            Remaining : constant Natural := Text'Last - Input + 1;
            B0 : constant Natural := Character'Pos (Text (Input));
            B1 : constant Natural :=
              (if Remaining >= 2 then Character'Pos (Text (Input + 1)) else 0);
            B2 : constant Natural :=
              (if Remaining >= 3 then Character'Pos (Text (Input + 2)) else 0);
         begin
            Result (Output) := Alphabet (B0 / 4 + 1);
            Result (Output + 1) :=
              Alphabet ((B0 mod 4) * 16 + B1 / 16 + 1);
            if Remaining >= 2 then
               Result (Output + 2) :=
                 Alphabet ((B1 mod 16) * 4 + B2 / 64 + 1);
            end if;
            if Remaining >= 3 then
               Result (Output + 3) := Alphabet (B2 mod 64 + 1);
            end if;
            Input := Input + Natural'Min (3, Remaining);
            Output := Output + 4;
         end;
      end loop;
      return Result;
   end Base64;

   procedure Delete_If_Present (Path : String) is
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
   exception
      when Ada.Directories.Name_Error | Ada.Directories.Use_Error =>
         null;
   end Delete_If_Present;
end Test_Support;

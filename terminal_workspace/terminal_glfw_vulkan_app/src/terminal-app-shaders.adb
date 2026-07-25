with Ada.Directories;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Unchecked_Deallocation;

package body Terminal.App.Shaders is
   use type Ada.Directories.File_Size;
   use type Ada.Streams.Stream_Element_Offset;
   use type Interfaces.Unsigned_32;
   use type Word_Array_Access;

   procedure Free_Words is new Ada.Unchecked_Deallocation
     (Word_Array, Word_Array_Access);

   function Candidate_Path (Name : String; Index : Positive) return String is
   begin
      case Index is
         when 1 =>
            return "assets/shaders/" & Name;
         when 2 =>
            return "terminal_glfw_vulkan_app/assets/shaders/" & Name;
         when 3 =>
            return "terminal_workspace/terminal_glfw_vulkan_app/assets/shaders/" & Name;
         when others =>
            return "";
      end case;
   end Candidate_Path;

   function Existing_Path (Name : String) return String is
   begin
      for I in 1 .. 3 loop
         declare
            Path : constant String := Candidate_Path (Name, I);
         begin
            if Ada.Directories.Exists (Path) then
               return Path;
            end if;
         end;
      end loop;

      return "";
   end Existing_Path;

   procedure Release (Code : in out Shader_Code) is
   begin
      if Code.Data /= null then
         Free_Words (Code.Data);
      end if;
      Code.Count := 0;
   end Release;

   procedure Load
     (Name   : String;
      Code   : in out Shader_Code;
      Status : out Load_Status)
   is
      Path : constant String := Existing_Path (Name);
   begin
      Release (Code);

      if Path = "" then
         Status := Not_Found;
         return;
      end if;

      declare
         Size : constant Ada.Directories.File_Size := Ada.Directories.Size (Path);
      begin
         if Size = 0 or else Size mod 4 /= 0 then
            Status := Invalid_Size;
            return;
         elsif Size / 4 > Ada.Directories.File_Size (Max_Shader_Words) then
            Status := Too_Large;
            return;
         end if;

         declare
            subtype Buffer_Range is Ada.Streams.Stream_Element_Offset
              range 1 .. Ada.Streams.Stream_Element_Offset (Size);
            Buffer : Ada.Streams.Stream_Element_Array (Buffer_Range);
            Last   : Ada.Streams.Stream_Element_Offset;
            File   : Ada.Streams.Stream_IO.File_Type;
            Count  : constant Natural := Natural (Size / 4);
         begin
            Code.Data := new Word_Array (1 .. Count);
            Ada.Streams.Stream_IO.Open
              (File, Ada.Streams.Stream_IO.In_File, Path);
            Ada.Streams.Stream_IO.Read (File, Buffer, Last);
            Ada.Streams.Stream_IO.Close (File);

            if Last /= Buffer'Last then
               Release (Code);
               Status := Read_Failed;
               return;
            end if;

            for I in 1 .. Count loop
               declare
                  Base : constant Ada.Streams.Stream_Element_Offset :=
                    Buffer'First + Ada.Streams.Stream_Element_Offset ((I - 1) * 4);
                  B0 : constant Interfaces.Unsigned_32 :=
                    Interfaces.Unsigned_32 (Buffer (Base));
                  B1 : constant Interfaces.Unsigned_32 :=
                    Interfaces.Unsigned_32 (Buffer (Base + 1));
                  B2 : constant Interfaces.Unsigned_32 :=
                    Interfaces.Unsigned_32 (Buffer (Base + 2));
                  B3 : constant Interfaces.Unsigned_32 :=
                    Interfaces.Unsigned_32 (Buffer (Base + 3));
               begin
                  Code.Data (I) :=
                    B0 or
                    Interfaces.Shift_Left (B1, 8) or
                    Interfaces.Shift_Left (B2, 16) or
                    Interfaces.Shift_Left (B3, 24);
               end;
            end loop;

            Code.Count := Count;
            Status := Ok;
         exception
            when Storage_Error =>
               if Ada.Streams.Stream_IO.Is_Open (File) then
                  Ada.Streams.Stream_IO.Close (File);
               end if;
               Release (Code);
               Status := Allocation_Failed;
            when others =>
               if Ada.Streams.Stream_IO.Is_Open (File) then
                  Ada.Streams.Stream_IO.Close (File);
               end if;
               Release (Code);
               Status := Read_Failed;
         end;
      end;
   end Load;

   function Words (Code : Shader_Code) return Word_Array_Access is
     (Code.Data);

   function Word_Count (Code : Shader_Code) return Natural is
     (Code.Count);

   function Byte_Size (Code : Shader_Code) return Natural is
     (Code.Count * 4);

   function Address (Code : Shader_Code) return System.Address is
     (if Code.Data = null then System.Null_Address else Code.Data (1)'Address);
end Terminal.App.Shaders;

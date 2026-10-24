with Ada.Command_Line;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Text_IO;
with GNAT.OS_Lib;

with Terminal_Tools;

procedure Compile_Shaders is
   use type Ada.Directories.File_Kind;
   use type Ada.Directories.File_Size;

   function Arg (Value : String) return GNAT.OS_Lib.String_Access is
     (new String'(Value));

   procedure Set_Status (Value : Natural) is
   begin
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Exit_Status (Value));
   end Set_Status;

   Root : constant String := Terminal_Tools.Repository_Root;
   Compiler : constant String :=
     Terminal_Tools.Locate_Executable ("glslangValidator");
begin
   if Ada.Command_Line.Argument_Count /= 0 then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, "usage: compile_shaders");
      Set_Status (2);
      return;
   elsif Root'Length = 0 then
      raise Program_Error with "repository root not found";
   elsif Compiler'Length = 0 then
      raise Program_Error with
        "glslangValidator not found (install glslang-tools)";
   end if;

   declare
      Shader_Directory : constant String :=
        Terminal_Tools.Path
          (Root, "terminal_glfw_vulkan_app/assets/shaders");

      procedure Compile (Stage : String) is
         Source : constant String :=
           Terminal_Tools.Path (Shader_Directory, "terminal." & Stage);
         Output : constant String := Source & ".spv";
      begin
         if not Ada.Directories.Exists (Source)
           or else Ada.Directories.Kind (Source) /=
             Ada.Directories.Ordinary_File
         then
            raise Program_Error with "shader source not found: " & Source;
         end if;
         Ada.Text_IO.Put_Line
           ("compile_shaders: " & Source & " -> " & Output);
         if Terminal_Tools.Run
           (Compiler,
            [Arg ("-V"), Arg (Source), Arg ("-o"), Arg (Output)]) /= 0
         then
            raise Program_Error with
              "glslangValidator failed for " & Source;
         end if;
         if not Ada.Directories.Exists (Output)
           or else Ada.Directories.Kind (Output) /=
             Ada.Directories.Ordinary_File
           or else Ada.Directories.Size (Output) = 0
         then
            raise Program_Error with
              "glslangValidator produced no SPIR-V for " & Source;
         end if;
      end Compile;
   begin
      Compile ("vert");
      Compile ("frag");
   end;
   Ada.Text_IO.Put_Line ("compile_shaders: completed");
exception
   when Error : others =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "compile_shaders: FAIL ("
         & Ada.Exceptions.Exception_Message (Error) & ")");
      Set_Status (1);
end Compile_Shaders;

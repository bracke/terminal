with AUnit.Assertions;
with System;

with Terminal.App.Shaders;

procedure Shader_Loader_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Shaders.Load_Status;
   use type Terminal.App.Shaders.Word_Array_Access;
   use type System.Address;

   package Shaders renames Terminal.App.Shaders;

   Code : Shaders.Shader_Code;
   Status : Shaders.Load_Status;
begin
   Shaders.Load ("terminal.vert.spv", Code, Status);
   Assert (Status = Shaders.Ok, "vertex shader should load");
   Assert (Shaders.Word_Count (Code) > 0, "vertex shader should contain words");
   Assert (Shaders.Byte_Size (Code) mod 4 = 0, "SPIR-V size is word-aligned");
   Assert (Shaders.Words (Code) /= null, "word storage should exist");
   Assert (Shaders.Address (Code) /= System.Null_Address, "shader address");
   Shaders.Release (Code);

   Shaders.Load ("missing.spv", Code, Status);
   Assert (Status = Shaders.Not_Found, "missing shader should be explicit");
end Shader_Loader_Smoke;

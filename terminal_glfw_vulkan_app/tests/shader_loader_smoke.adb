with AUnit.Assertions;
with System;

with Terminal.App.Shaders;

procedure Shader_Loader_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Shaders.Load_Status;
   use type System.Address;

   package Shaders renames Terminal.App.Shaders;

   Code : Shaders.Shader_Code;
   Status : Shaders.Load_Status;
begin
   Assert
     (Shaders.Status_Label (Shaders.Ok) = "Shader load: Ok",
      "shader ok status label");
   Assert
     (Shaders.Status_Label (Shaders.Not_Found) = "Shader load: Not Found",
      "shader missing status label");
   Assert
     (Shaders.Status_Label (Shaders.Allocation_Failed)'Length <=
      Shaders.Max_Status_Label_Length,
      "shader status label should be bounded");

   Shaders.Load ("terminal.vert.spv", Code, Status);
   Assert (Status = Shaders.Ok, "vertex shader should load");
   Assert
     (Shaders.Status_Label (Status) = "Shader load: Ok",
      "loaded shader status label");
   Assert (Shaders.Word_Count (Code) > 0, "vertex shader should contain words");
   Assert (Shaders.Byte_Size (Code) mod 4 = 0, "SPIR-V size is word-aligned");
   Assert (Shaders.Address (Code) /= System.Null_Address, "shader address");
   Shaders.Release (Code);
   Assert (Shaders.Word_Count (Code) = 0, "released shader word count");
   Assert
     (Shaders.Address (Code) = System.Null_Address,
      "released shader address");
   Shaders.Release (Code);

   Shaders.Load ("missing.spv", Code, Status);
   Assert (Status = Shaders.Not_Found, "missing shader should be explicit");
   Assert
     (Shaders.Status_Label (Status) = "Shader load: Not Found",
      "missing shader status label");

   Shaders.Load (".", Code, Status);
   Assert
     (Status = Shaders.Read_Failed,
      "filesystem failures are reported through the loader status");
end Shader_Loader_Smoke;

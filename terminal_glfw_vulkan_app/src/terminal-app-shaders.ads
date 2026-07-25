with Interfaces;
with System;

package Terminal.App.Shaders is
   Max_Shader_Words : constant := 16_384;

   type Load_Status is
     (Ok,
      Not_Found,
      Invalid_Size,
      Too_Large,
      Read_Failed,
      Allocation_Failed);

   type Word_Array is array (Positive range <>) of Interfaces.Unsigned_32;
   type Word_Array_Access is access all Word_Array;

   type Shader_Code is limited private;

   procedure Load
     (Name   : String;
      Code   : in out Shader_Code;
      Status : out Load_Status);

   procedure Release (Code : in out Shader_Code);

   function Words (Code : Shader_Code) return Word_Array_Access;
   function Word_Count (Code : Shader_Code) return Natural;
   function Byte_Size (Code : Shader_Code) return Natural;
   function Address (Code : Shader_Code) return System.Address;

private
   type Shader_Code is limited record
      Data  : Word_Array_Access := null;
      Count : Natural := 0;
   end record;
end Terminal.App.Shaders;

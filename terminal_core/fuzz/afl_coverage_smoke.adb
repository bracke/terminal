with Ada.Command_Line;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Ada.Unchecked_Conversion;
with GNAT.OS_Lib;
with Interfaces;
with Interfaces.C;
with System;
with System.Storage_Elements;

procedure AFL_Coverage_Smoke is
   package C renames Interfaces.C;
   use type C.int;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_64;
   use type System.Address;

   AFL_Map_Size : constant := 65_536;
   IPC_Private : constant C.int := 0;
   IPC_Create_And_User_RW : constant C.int := 16#380#;
   IPC_Remove : constant C.int := 0;

   type Coverage_Array is
     array (Natural range 0 .. AFL_Map_Size - 1) of aliased Interfaces.Unsigned_8
       with Convention => C;
   type Coverage_Access is access all Coverage_Array;

   function To_Coverage is new Ada.Unchecked_Conversion
     (System.Address, Coverage_Access);

   function Shmget
     (Key : C.int;
      Size : C.size_t;
      Flags : C.int) return C.int
     with Import, Convention => C, External_Name => "shmget";
   function Shmat
     (Identity : C.int;
      Address : System.Address;
      Flags : C.int) return System.Address
     with Import, Convention => C, External_Name => "shmat";
   function Shmdt (Address : System.Address) return C.int
     with Import, Convention => C, External_Name => "shmdt";
   function Shmctl
     (Identity : C.int;
      Command : C.int;
      Buffer : System.Address) return C.int
     with Import, Convention => C, External_Name => "shmctl";

   Failed_Address : constant System.Address :=
     System.Storage_Elements.To_Address
       (System.Storage_Elements.Integer_Address'Last);
   Identity : C.int := -1;
   Mapping : System.Address := System.Null_Address;
   Coverage : Coverage_Access := null;

   procedure Clean_Up is
      Ignored : C.int;
   begin
      if Mapping /= System.Null_Address and then Mapping /= Failed_Address then
         Ignored := Shmdt (Mapping);
         Mapping := System.Null_Address;
      end if;
      if Identity >= 0 then
         Ignored := Shmctl (Identity, IPC_Remove, System.Null_Address);
         Identity := -1;
      end if;
   end Clean_Up;

   procedure Clear_Coverage is
   begin
      Coverage.all := [others => 0];
   end Clear_Coverage;

   procedure Coverage_Signature
     (Hash : out Interfaces.Unsigned_64;
      Populated : out Natural)
   is
   begin
      Hash := 1_469_598_103_934_665_603;
      Populated := 0;
      for Index in Coverage'Range loop
         if Coverage (Index) /= 0 then
            Populated := Populated + 1;
            Hash := Hash xor Interfaces.Unsigned_64 (Index);
            Hash := Hash * 1_099_511_628_211;
            Hash := Hash xor Interfaces.Unsigned_64 (Coverage (Index));
            Hash := Hash * 1_099_511_628_211;
         end if;
      end loop;
   end Coverage_Signature;

   function Arg (Value : String) return GNAT.OS_Lib.String_Access is
     (new String'(Value));

   function Run_Target (Target, Input : String) return Boolean is
     (GNAT.OS_Lib.Spawn (Target, [1 => Arg (Input)]) = 0);

   First_Hash, Second_Hash : Interfaces.Unsigned_64;
   First_Populated, Second_Populated : Natural;
begin
   if Ada.Command_Line.Argument_Count /= 3 then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "usage: afl_coverage_smoke TARGET INPUT_A INPUT_B");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Identity :=
     Shmget
       (IPC_Private,
        C.size_t (AFL_Map_Size),
        IPC_Create_And_User_RW);
   if Identity < 0 then
      raise Program_Error with "shmget failed";
   end if;
   Mapping := Shmat (Identity, System.Null_Address, 0);
   if Mapping = Failed_Address then
      raise Program_Error with "shmat failed";
   end if;
   Coverage := To_Coverage (Mapping);
   if Coverage = null then
      raise Program_Error with "shared coverage map is null";
   end if;
   Clear_Coverage;
   Ada.Environment_Variables.Set
     ("__AFL_SHM_ID",
      Ada.Strings.Fixed.Trim (C.int'Image (Identity), Ada.Strings.Both));

   if not Run_Target
     (Ada.Command_Line.Argument (1), Ada.Command_Line.Argument (2))
   then
      raise Program_Error with "first instrumented target failed";
   end if;
   Coverage_Signature (First_Hash, First_Populated);
   Clear_Coverage;
   if not Run_Target
     (Ada.Command_Line.Argument (1), Ada.Command_Line.Argument (3))
   then
      raise Program_Error with "second instrumented target failed";
   end if;
   Coverage_Signature (Second_Hash, Second_Populated);

   if First_Populated = 0 or else Second_Populated = 0 then
      raise Program_Error with "instrumented target produced no coverage";
   elsif First_Hash = Second_Hash then
      raise Program_Error with "distinct protocols produced identical coverage";
   end if;
   Ada.Text_IO.Put_Line
     ("AFL coverage smoke:"
      & Natural'Image (First_Populated)
      & "/" & Natural'Image (Second_Populated)
      & " input-sensitive edges");
   Clean_Up;
exception
   when Error : others =>
      Clean_Up;
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "afl_coverage_smoke: "
         & Ada.Exceptions.Exception_Message (Error));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end AFL_Coverage_Smoke;

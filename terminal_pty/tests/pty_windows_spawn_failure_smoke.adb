with Ada.Environment_Variables;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with AUnit.Assertions;
with Interfaces.C;
with System;

with Terminal.Common.Bytes;
with Terminal.PTY.Backend;

procedure PTY_Windows_Spawn_Failure_Smoke is
   use type Terminal.PTY.Backend.Read_Status;
   use type Terminal.PTY.Backend.Spawn_Status;
   use type Interfaces.C.int;
   package Unbounded renames Ada.Strings.Unbounded;

   Had_Comspec : constant Boolean :=
     Ada.Environment_Variables.Exists ("COMSPEC");
   Previous_Comspec : constant Unbounded.Unbounded_String :=
     Unbounded.To_Unbounded_String
       ((if Had_Comspec
         then Ada.Environment_Variables.Value ("COMSPEC")
         else ""));
   S : Terminal.PTY.Backend.Session;
   Spawn : Terminal.PTY.Backend.Spawn_Status;
   Read_Result : Terminal.PTY.Backend.Read_Status;
   Buffer : Terminal.Common.Bytes.Byte_Array (1 .. 1);
   Last : Natural;
   subtype DWORD is Interfaces.C.unsigned_long;
   use type DWORD;
   Before_Handles : aliased DWORD := 0;
   After_Handles  : aliased DWORD := 0;

   function Get_Current_Process return System.Address
     with Import, Convention => Stdcall, External_Name => "GetCurrentProcess";
   function Get_Process_Handle_Count
     (Process : System.Address;
      Count   : access DWORD) return Interfaces.C.int
     with Import, Convention => Stdcall,
          External_Name => "GetProcessHandleCount";

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "FAILED: " & Message);
         AUnit.Assertions.Assert (False, Message);
      end if;
   end Assert;

   procedure Restore_Environment is
   begin
      if Had_Comspec then
         Ada.Environment_Variables.Set
           ("COMSPEC", Unbounded.To_String (Previous_Comspec));
      else
         Ada.Environment_Variables.Clear ("COMSPEC");
      end if;
   end Restore_Environment;
begin
   Ada.Environment_Variables.Set
     ("COMSPEC", "?:\terminal-definitely-missing\shell.exe");
   Terminal.PTY.Backend.Spawn_Default_Shell (S, 24, 80, Spawn);
   Assert
     (Spawn = Terminal.PTY.Backend.Fork_Failed,
      "CreateProcess failure must be reported without leaking spawn resources");
   Terminal.PTY.Backend.Read (S, Buffer, Last, Read_Result);
   Assert
     (Read_Result = Terminal.PTY.Backend.Session_Closed,
      "failed Windows spawn must leave the session closed");
   Terminal.PTY.Backend.Close (S);
   Assert
     (Get_Process_Handle_Count
        (Get_Current_Process, Before_Handles'Access) /= 0,
      "query handle count before repeated spawn failures");
   for Attempt in 1 .. 32 loop
      Terminal.PTY.Backend.Spawn_Default_Shell (S, 24, 80, Spawn);
      Assert
        (Spawn = Terminal.PTY.Backend.Fork_Failed,
         "repeated CreateProcess failure must be reported");
      Terminal.PTY.Backend.Close (S);
   end loop;
   Assert
     (Get_Process_Handle_Count
        (Get_Current_Process, After_Handles'Access) /= 0,
      "query handle count after repeated spawn failures");
   Assert
     (After_Handles = Before_Handles,
      "repeated CreateProcess failures must not leak process handles");
   Restore_Environment;
exception
   when others =>
      Terminal.PTY.Backend.Close (S);
      Restore_Environment;
      raise;
end PTY_Windows_Spawn_Failure_Smoke;

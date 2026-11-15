with Ada.Characters.Latin_1;
with Ada.Command_Line;
with Ada.Environment_Variables;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with GNAT.OS_Lib;

with AUnit.Assertions;

with Terminal.Common.Bytes;
with Terminal.PTY.Backend;

procedure PTY_Spawn_Failure_Smoke is
   use type GNAT.OS_Lib.File_Descriptor;
   use type GNAT.OS_Lib.String_Access;
   use type Terminal.PTY.Backend.Read_Status;
   use type Terminal.PTY.Backend.Spawn_Status;
   package Unbounded renames Ada.Strings.Unbounded;

   Snapshot_Child : constant Boolean :=
     Ada.Command_Line.Argument_Count = 1
     and then Ada.Command_Line.Argument (1) = "--snapshot-child";

   Had_Shell : constant Boolean := Ada.Environment_Variables.Exists ("SHELL");
   Previous_Shell : constant Unbounded.Unbounded_String :=
     Unbounded.To_Unbounded_String
       ((if Had_Shell then Ada.Environment_Variables.Value ("SHELL") else ""));
   Temp_FD : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
   Temp_Name : GNAT.OS_Lib.String_Access := null;
   Script : aliased constant String :=
     "#!/definitely/missing/terminal-pty-interpreter"
     & Ada.Characters.Latin_1.LF;
   S : Terminal.PTY.Backend.Session;
   Spawn : Terminal.PTY.Backend.Spawn_Status;
   Read_Result : Terminal.PTY.Backend.Read_Status;
   Buffer : Terminal.Common.Bytes.Byte_Array (1 .. 1);
   Last : Natural;

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "FAILED: " & Message);
         AUnit.Assertions.Assert (False, Message);
      end if;
   end Assert;

   procedure Cleanup is
   begin
      Terminal.PTY.Backend.Close (S);
      if Had_Shell then
         Ada.Environment_Variables.Set
           ("SHELL", Unbounded.To_String (Previous_Shell));
      else
         Ada.Environment_Variables.Clear ("SHELL");
      end if;
      if Temp_FD /= GNAT.OS_Lib.Invalid_FD then
         GNAT.OS_Lib.Close (Temp_FD);
         Temp_FD := GNAT.OS_Lib.Invalid_FD;
      end if;
      if Temp_Name /= null then
         declare
            Deleted : Boolean;
         begin
            GNAT.OS_Lib.Delete_File (Temp_Name.all, Deleted);
         end;
         GNAT.OS_Lib.Free (Temp_Name);
      end if;
   end Cleanup;
begin
   if not Snapshot_Child then
      GNAT.OS_Lib.Create_Temp_File (Temp_FD, Temp_Name);
      Assert
        (Temp_FD /= GNAT.OS_Lib.Invalid_FD and then Temp_Name /= null,
         "invalid-shell fixture creation failed");
      Assert
        (GNAT.OS_Lib.Write (Temp_FD, Script'Address, Script'Length)
           = Script'Length,
         "invalid-shell fixture write failed");
      GNAT.OS_Lib.Close (Temp_FD);
      Temp_FD := GNAT.OS_Lib.Invalid_FD;
      GNAT.OS_Lib.Set_Executable (Temp_Name.all);

      --  The backend deliberately uses the process's immutable startup
      --  environment. Re-exec this test with SHELL already set so the child
      --  validates the failed-exec path without mutating live environ.
      Ada.Environment_Variables.Set ("SHELL", Temp_Name.all);
      declare
         Args : GNAT.OS_Lib.Argument_List (1 .. 1) :=
           (1 => new String'("--snapshot-child"));
         Child_Status : constant Integer :=
           GNAT.OS_Lib.Spawn (Ada.Command_Line.Command_Name, Args);
      begin
         GNAT.OS_Lib.Free (Args (1));
         Cleanup;
         Assert
           (Child_Status = 0,
            "environment-snapshot child did not validate failed shell exec");
         return;
      end;
   end if;

   Terminal.PTY.Backend.Spawn_Default_Shell (S, 24, 80, Spawn);
   Assert
     (Spawn = Terminal.PTY.Backend.Exec_Failed,
      "failed shell exec must be reported synchronously");
   Terminal.PTY.Backend.Read (S, Buffer, Last, Read_Result);
   Assert
     (Read_Result = Terminal.PTY.Backend.Session_Closed,
      "failed shell exec must leave the session closed");
   Cleanup;
exception
   when others =>
      Cleanup;
      raise;
end PTY_Spawn_Failure_Smoke;

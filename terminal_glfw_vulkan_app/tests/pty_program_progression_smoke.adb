with AUnit.Assertions;

with Terminal.Common;
with Terminal.Common.Bytes;
with Terminal.App.PTY_Write;
with Terminal.App.Queues;
with Terminal.Core;
with Terminal.PTY.Backend;

procedure PTY_Program_Progression_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Common.Code_Point;
   use type Terminal.App.PTY_Write.Write_All_Status;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.PTY.Backend.Read_Status;
   use type Terminal.PTY.Backend.Spawn_Status;

   Rows : constant Positive := 24;
   Cols : constant Positive := 120;

   Git_Marker  : constant String := "ADA_GIT_STATUS_DONE";
   Less_Marker : constant String := "ADA_LESS_DONE";
   Nano_Marker : constant String := "ADA_NANO_DONE";
   Vim_Marker  : constant String := "ADA_VIM_DONE";
   Top_Marker  : constant String := "ADA_TOP_DONE";

   Command : constant String :=
     "set +e; "
     & "rm -rf /tmp/terminal_program_progression_smoke; "
     & "mkdir /tmp/terminal_program_progression_smoke; "
     & "cd /tmp/terminal_program_progression_smoke; "
     & "git init -q; "
     & "printf tracked > tracked.txt; "
     & "git add tracked.txt; "
     & "printf change >> tracked.txt; "
     & "printf untracked > untracked.txt; "
     & "git status --short; "
     & "printf 'ADA_GIT_STATUS_DONE\n'; "
     & "printf 'ADA_LESS_VISIBLE\n' > less.txt; "
     & "if command -v less >/dev/null 2>&1; then less -F -X less.txt; fi; "
     & "printf 'ADA_LESS_DONE\n'; "
     & "if command -v nano >/dev/null 2>&1; then nano --version | head -n 1; fi; "
     & "printf 'ADA_NANO_DONE\n'; "
     & "if command -v vim >/dev/null 2>&1; then vim --version | head -n 1; fi; "
     & "printf 'ADA_VIM_DONE\n'; "
     & "if command -v top >/dev/null 2>&1; then top -b -n 1 | head -n 1; fi; "
     & "printf 'ADA_TOP_DONE\n'; "
     & "rm -rf /tmp/terminal_program_progression_smoke; "
     & "exit"
     & Character'Val (13);

   T            : Terminal.Core.Terminal;
   Init_Status  : Terminal.Core.Initialize_Status;
   Feed_Status  : Terminal.Core.Feed_Status;
   S            : Terminal.PTY.Backend.Session;
   Spawn_Status : Terminal.PTY.Backend.Spawn_Status;
   Write_Status : Terminal.App.PTY_Write.Write_All_Status;
   Buffer       : Byte_Array (1 .. 4096);
   Last         : Natural := 0;
   Read_Status  : Terminal.PTY.Backend.Read_Status;
   Git_Found    : Boolean := False;
   Git_Status_Found : Boolean := False;
   Less_Found   : Boolean := False;
   Nano_Found   : Boolean := False;
   Vim_Found    : Boolean := False;
   Top_Found    : Boolean := False;

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   function To_Chunk (Text : String) return Terminal.App.Queues.Byte_Chunk is
      Result : Terminal.App.Queues.Byte_Chunk;
      Bytes  : constant Byte_Array := To_Bytes (Text);
   begin
      Result := (others => <>);
      Assert
        (Bytes'Length <= Terminal.App.Queues.Max_Chunk_Length,
         "program progression command should fit one chunk");
      Result.Length := Bytes'Length;
      Result.Data (1 .. Bytes'Length) := Bytes;
      return Result;
   end To_Chunk;

   function Cell_Matches
     (Snap : Terminal.Core.Render_Snapshot;
      Row  : Positive;
      Col  : Positive;
      Ch   : Character) return Boolean is
   begin
      return Terminal.Core.Cell_At (Snap, Row, Col).Text.Code_Point =
        Terminal.Common.Code_Point (Character'Pos (Ch));
   end Cell_Matches;

   function Find_Text
     (Snap : Terminal.Core.Render_Snapshot;
      Text : String) return Boolean
   is
      Match : Boolean;
   begin
      if Text'Length = 0
        or else Snap.Rows = 0
        or else Snap.Cols < Text'Length
      then
         return False;
      end if;

      for R in 1 .. Snap.Rows loop
         for C in 1 .. Snap.Cols - Text'Length + 1 loop
            Match := True;
            for I in Text'Range loop
               if not Cell_Matches (Snap, R, C + I - Text'First, Text (I)) then
                  Match := False;
                  exit;
               end if;
            end loop;
            if Match then
               return True;
            end if;
         end loop;
      end loop;

      return False;
   end Find_Text;

   procedure Inspect_Snapshot is
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
   begin
      if not Git_Status_Found then
         Git_Status_Found :=
           Find_Text (Snap, "AM tracked.txt")
           or else Find_Text (Snap, "A  tracked.txt");
      end if;
      if not Git_Found then
         Git_Found := Find_Text (Snap, Git_Marker);
      end if;
      if not Less_Found then
         Less_Found := Find_Text (Snap, Less_Marker);
      end if;
      if not Nano_Found then
         Nano_Found := Find_Text (Snap, Nano_Marker);
      end if;
      if not Vim_Found then
         Vim_Found := Find_Text (Snap, Vim_Marker);
      end if;
      if not Top_Found then
         Top_Found := Find_Text (Snap, Top_Marker);
      end if;
      Terminal.Core.Release (Snap);
   end Inspect_Snapshot;
begin
   Terminal.Core.Initialize (T, Rows, Cols, 200, Init_Status);
   Assert (Init_Status = Terminal.Core.Ok, "core initialize failed");

   Terminal.PTY.Backend.Spawn_Default_Shell (S, Rows, Cols, Spawn_Status);
   Assert (Spawn_Status = Terminal.PTY.Backend.Ok, "pty spawn failed");

   declare
      Data : constant Terminal.App.Queues.Byte_Chunk := To_Chunk (Command);
   begin
      Terminal.App.PTY_Write.Write_All (S, Data, Write_Status);
      Assert (Write_Status = Terminal.App.PTY_Write.Ok, "pty write failed");
   end;

   for Attempt in 1 .. 900 loop
      Terminal.PTY.Backend.Read (S, Buffer, Last, Read_Status);
      case Read_Status is
         when Terminal.PTY.Backend.Ok =>
            if Last > 0 then
               Terminal.Core.Feed (T, Buffer (1 .. Last), Feed_Status);
               Assert
                 (Feed_Status = Terminal.Core.Ok
                  or else Feed_Status = Terminal.Core.Parser_Recovered,
                  "core feed should accept program output");
               Inspect_Snapshot;
            end if;
         when Terminal.PTY.Backend.Would_Block
            | Terminal.PTY.Backend.Interrupted =>
            delay 0.01;
         when Terminal.PTY.Backend.End_Of_File
            | Terminal.PTY.Backend.Failed
            | Terminal.PTY.Backend.Session_Closed =>
            exit;
      end case;

      exit when Git_Found
        and then Git_Status_Found
        and then Less_Found
        and then Nano_Found
        and then Vim_Found
        and then Top_Found;
   end loop;

   Terminal.PTY.Backend.Close (S);

   Assert (Git_Found, "git status progression marker should be visible");
   Assert (Git_Status_Found, "git status should report changed tracked file");
   Assert (Less_Found, "less progression marker should be visible");
   Assert (Nano_Found, "nano progression marker should be visible");
   Assert (Vim_Found, "vim progression marker should be visible");
   Assert (Top_Found, "top progression marker should be visible");
end PTY_Program_Progression_Smoke;

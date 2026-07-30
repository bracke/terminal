with AUnit.Assertions;

with Terminal.Common;
with Terminal.Common.Bytes;
with Terminal.App.PTY_Write;
with Terminal.App.Queues;
with Terminal.Core;
with Terminal.PTY.Backend;

procedure PTY_M1_Commands_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.Common.Code_Point;
   use type Terminal.Core.Color_Kind;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.App.PTY_Write.Write_All_Status;
   use type Terminal.PTY.Backend.Read_Status;
   use type Terminal.PTY.Backend.Spawn_Status;

   Rows : constant Positive := 12;
   Cols : constant Positive := 100;

   Echo_Marker  : constant String := "ADA_ECHO_OK";
   Cat_Marker   : constant String := "ADA_CAT_OK";
   Red_Marker   : constant String := "ADA_RED_OK";
   LS_Marker    : constant String := "ADA_LS_COLOR_DIR";
   Clear_Marker : constant String := "ADA_CLEAR_OK";

   Command : constant String :=
     "printf '\033[2J\033[H'; "
     & "echo ADA_ECHO_OK; sleep 0.05; "
     & "printf 'ADA_CAT_OK\n' | cat; sleep 0.05; "
     & "printf '\033[31mADA_RED_OK\033[0m\n'; sleep 0.05; "
     & "rm -rf /tmp/ADA_LS_COLOR_DIR; mkdir /tmp/ADA_LS_COLOR_DIR; "
     & "cd /tmp; LS_COLORS='di=01;34' ls --color=always -d ADA_LS_COLOR_DIR; "
     & "rm -rf /tmp/ADA_LS_COLOR_DIR; sleep 0.05; "
     & "printf '\033[2J\033[HADA_CLEAR_OK\n'; exit"
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
   Echo_Found   : Boolean := False;
   Cat_Found    : Boolean := False;
   Red_Found    : Boolean := False;
   LS_Found     : Boolean := False;
   Clear_Found  : Boolean := False;

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
     (Snap  : Terminal.Core.Render_Snapshot;
      Text  : String;
      Row   : out Positive;
      Col   : out Positive) return Boolean
   is
      Match : Boolean;
   begin
      if Text'Length = 0
        or else Snap.Rows = 0
        or else Snap.Cols < Text'Length
      then
         Row := 1;
         Col := 1;
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
               Row := R;
               Col := C;
               return True;
            end if;
         end loop;
      end loop;

      Row := 1;
      Col := 1;
      return False;
   end Find_Text;

   function Text_At_Top_Left
     (Snap : Terminal.Core.Render_Snapshot;
      Text : String) return Boolean
   is
   begin
      if Snap.Rows = 0 or else Snap.Cols < Text'Length then
         return False;
      end if;

      for I in Text'Range loop
         if not Cell_Matches (Snap, 1, I - Text'First + 1, Text (I)) then
            return False;
         end if;
      end loop;

      return True;
   end Text_At_Top_Left;

   procedure Inspect_Snapshot is
      Snap : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (T);
      Row  : Positive := 1;
      Col  : Positive := 1;
   begin
      if not Echo_Found then
         Echo_Found := Find_Text (Snap, Echo_Marker, Row, Col);
      end if;

      if not Cat_Found then
         Cat_Found := Find_Text (Snap, Cat_Marker, Row, Col);
      end if;

      if not Red_Found and then Find_Text (Snap, Red_Marker, Row, Col) then
         declare
            Cell : constant Terminal.Core.Cell :=
              Terminal.Core.Cell_At (Snap, Row, Col);
         begin
            Red_Found :=
              Cell.Style.Foreground.Kind = Terminal.Core.Indexed
              and then Cell.Style.Foreground.Index = 1;
         end;
      end if;

      if not LS_Found and then Find_Text (Snap, LS_Marker, Row, Col) then
         declare
            Cell : constant Terminal.Core.Cell :=
              Terminal.Core.Cell_At (Snap, Row, Col);
         begin
            LS_Found :=
              Cell.Style.Bold
              and then Cell.Style.Foreground.Kind = Terminal.Core.Indexed
              and then Cell.Style.Foreground.Index = 4;
         end;
      end if;

      Clear_Found := Text_At_Top_Left (Snap, Clear_Marker);
      Terminal.Core.Release (Snap);
   end Inspect_Snapshot;
begin
   Terminal.Core.Initialize (T, Rows, Cols, 100, Init_Status);
   Assert (Init_Status = Terminal.Core.Ok, "core initialize failed");

   Terminal.PTY.Backend.Spawn_Default_Shell (S, Rows, Cols, Spawn_Status);
   Assert (Spawn_Status = Terminal.PTY.Backend.Ok, "pty spawn failed");

   declare
      Data : constant Terminal.App.Queues.Byte_Chunk := To_Chunk (Command);
   begin
      Terminal.App.PTY_Write.Write_All (S, Data, Write_Status);
      Assert (Write_Status = Terminal.App.PTY_Write.Ok, "pty write failed");
   end;

   for Attempt in 1 .. 500 loop
      Terminal.PTY.Backend.Read (S, Buffer, Last, Read_Status);
      case Read_Status is
         when Terminal.PTY.Backend.Ok =>
            if Last > 0 then
               Terminal.Core.Feed (T, Buffer (1 .. Last), Feed_Status);
               Assert
                 (Feed_Status = Terminal.Core.Ok
                  or else Feed_Status = Terminal.Core.Parser_Recovered,
                  "core feed should accept shell command output");
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

      exit when Echo_Found
        and then Cat_Found
        and then Red_Found
        and then LS_Found
        and then Clear_Found;
   end loop;

   Terminal.PTY.Backend.Close (S);

   Assert (Echo_Found, "echo output should be visible in core snapshot");
   Assert (Cat_Found, "cat output should be visible in core snapshot");
   Assert (Red_Found, "SGR red output should carry indexed foreground style");
   Assert (LS_Found, "ls --color output should carry directory color style");
   Assert (Clear_Found, "clear sequence should leave marker at top-left");
end PTY_M1_Commands_Smoke;

with Ada.Text_IO;

with AUnit.Assertions;

with Terminal.Common.Bytes;
with Terminal.PTY.Backend;

procedure PTY_Env_Smoke is
   use Terminal.Common.Bytes;
   use type Terminal.PTY.Backend.Read_Status;
   use type Terminal.PTY.Backend.Spawn_Status;
   use type Terminal.PTY.Backend.Write_Status;

   --  AUnit's Assert outside a test case raises with no word of what
   --  failed; say it on standard error first, so a CI log names the check.
   procedure Assert (Condition : Boolean; Message : String);

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Ada.Text_IO.Flush;
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "FAILED: " & Message);
         AUnit.Assertions.Assert (False, Message);
      end if;
   end Assert;

   Rows : constant Positive := 12;
   Cols : constant Positive := 80;
   Term_Marker : constant String :=
     "__TERM=" & Terminal.PTY.Backend.Term_Name & "__";
   Color_Marker : constant String :=
     "__COLORTERM=" & Terminal.PTY.Backend.Color_Term & "__";
   Program_Marker : constant String :=
     "__TERM_PROGRAM=" & Terminal.PTY.Backend.Term_Program & "__";
   Version_Marker : constant String :=
     "__TERM_PROGRAM_VERSION="
     & Terminal.PTY.Backend.Term_Program_Version & "__";
   Requested_Features : constant String := "FSx";
   Features_Marker : constant String :=
     "__TERM_FEATURES=" & Requested_Features & "__";
   --  Asked in the shell the host actually runs. The backend spawns sh on POSIX
   --  and cmd.exe on Windows, and neither understands the other's syntax; what
   --  is under test is that the child was given the variables, not how it is
   --  asked for them.
   On_Windows : constant Boolean :=
     Terminal.PTY.Backend.Capabilities.Windows_ConPTY;

   Command : constant String :=
     (if On_Windows
      then
        --  No "exit" here, deliberately. A pseudo-console paints on a tick and
        --  coalesces what it paints; a shell that runs two echoes and leaves
        --  within milliseconds can be gone before the first paint, and then
        --  conhost tears down with the output never written. Leaving the shell
        --  up lets the console paint, which is also what a terminal does with a
        --  real one. Close ends it afterwards.
        "echo __TERM=%TERM%__& echo __COLORTERM=%COLORTERM%__"
             & "& echo __TERM_PROGRAM=%TERM_PROGRAM%__"
             & "& echo __TERM_PROGRAM_VERSION=%TERM_PROGRAM_VERSION%__"
             & "& echo __TERM_FEATURES=%TERM_FEATURES%__"
             & Character'Val (13)
      else "printf '__TERM=%s__\n' ""$TERM""; "
             & "printf '__COLORTERM=%s__\n' ""$COLORTERM""; "
             & "printf '__TERM_PROGRAM=%s__\n' ""$TERM_PROGRAM""; "
             & "printf '__TERM_PROGRAM_VERSION=%s__\n' "
             & """$TERM_PROGRAM_VERSION""; "
             & "printf '__TERM_FEATURES=%s__\n' ""$TERM_FEATURES""; exit"
             & Character'Val (13));

   S            : Terminal.PTY.Backend.Session;
   Spawn_Status : Terminal.PTY.Backend.Spawn_Status;
   Write_Status : Terminal.PTY.Backend.Write_Status;
   Read_Status  : Terminal.PTY.Backend.Read_Status;
   Buffer       : Byte_Array (1 .. 1024);
   Last         : Natural := 0;
   Output       : String (1 .. 4096) := (others => ASCII.NUL);
   Output_Last  : Natural := 0;
   Attempts     : Natural := 0;
   Reads        : Natural := 0;
   Unprompted   : Natural := 0;
   Written_Total : Natural := 0;
   Alive_Before_Write : Boolean := False;
   Alive_After_Write  : Boolean := False;
   Alive_After_Spawn : Boolean := False;

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   procedure Append_Output is
   begin
      for I in 1 .. Last loop
         exit when Output_Last = Output'Last;
         Output_Last := Output_Last + 1;
         Output (Output_Last) := Character'Val (Natural (Buffer (I)));
      end loop;
   end Append_Output;

   function Contains (Pattern : String) return Boolean is
   begin
      if Output_Last < Pattern'Length then
         return False;
      end if;

      for Start in 1 .. Output_Last - Pattern'Length + 1 loop
         if Output (Start .. Start + Pattern'Length - 1) = Pattern then
            return True;
         end if;
      end loop;

      return False;
   end Contains;
   --  A pseudo-terminal takes only what fits in its input queue, and on
   --  macOS that can be nothing until the shell reads, or until what it echoed
   --  is read; so read while waiting, and give up only after a while.
   procedure Write_All (Data : Byte_Array) is
      First : Positive := Data'First;
      Wrote : Natural := 0;
      Stalls : Natural := 0;
   begin
      while First <= Data'Last loop
         Terminal.PTY.Backend.Write
           (S, Data (First .. Data'Last), Wrote, Write_Status);

         case Write_Status is
            when Terminal.PTY.Backend.Ok | Terminal.PTY.Backend.Partial =>
               if Wrote > 0 then
                  Written_Total := Written_Total + Wrote;
                  First := First + Wrote;
                  Stalls := 0;
               else
                  Stalls := Stalls + 1;
                  Assert (Stalls < 500, "write made no progress");
                  Terminal.PTY.Backend.Read (S, Buffer, Last, Read_Status);
                  if Read_Status = Terminal.PTY.Backend.Ok then
                     Append_Output;
                  end if;
                  delay 0.01;
               end if;
            when Terminal.PTY.Backend.Interrupted =>
               null;
            when Terminal.PTY.Backend.Failed
               | Terminal.PTY.Backend.Session_Closed =>
               Assert (False, "pty write failed");
         end case;
      end loop;
   end Write_All;

begin
   Assert
     (Terminal.PTY.Backend.Term_Name = "xterm-256color",
      "PTY TERM constant");
   Assert
     (Terminal.PTY.Backend.Color_Term = "truecolor",
      "PTY COLORTERM constant");
   Assert
     (Terminal.PTY.Backend.Term_Program = "bracke-terminal"
      and then Terminal.PTY.Backend.Term_Program_Version = "0.1.0-dev",
      "PTY terminal program identity");

   Terminal.PTY.Backend.Spawn_Default_Shell
     (S, Rows, Cols, Spawn_Status, Requested_Features);
   Assert (Spawn_Status = Terminal.PTY.Backend.Ok, "pty spawn failed");

   Alive_After_Spawn := Terminal.PTY.Backend.Is_Alive (S);

   --  Listen before saying anything. A shell under a pseudo-console announces
   --  itself -- cmd prints its version banner, sh its prompt -- so whatever
   --  arrives here arrives without being asked for. Nothing at all separates a
   --  console that is not connected from one that simply had nothing to say.
   for Attempt in 1 .. 200 loop
      Terminal.PTY.Backend.Read (S, Buffer, Last, Read_Status);

      case Read_Status is
         when Terminal.PTY.Backend.Ok =>
            Unprompted := Unprompted + Last;
            Append_Output;
         when Terminal.PTY.Backend.Would_Block
            | Terminal.PTY.Backend.Interrupted =>
            delay 0.01;
         when others =>
            exit;
      end case;

      exit when Unprompted > 0;
   end loop;

   --  Was it still there when we spoke to it? This splits what is left in two:
   --  gone already means the shell quits on its own with nothing to do with us,
   --  still there means it quits because of what we sent. Spoken to only now:
   --  a shell setting up its terminal, as on macOS, takes nothing typed before.
   Alive_Before_Write := Terminal.PTY.Backend.Is_Alive (S);

   declare
      Data : constant Byte_Array := To_Bytes (Command);
   begin
      Write_All (Data);
   end;

   Alive_After_Write := Terminal.PTY.Backend.Is_Alive (S);

   for Attempt in 1 .. 1_500 loop
      Attempts := Attempt;
      Terminal.PTY.Backend.Read (S, Buffer, Last, Read_Status);
      case Read_Status is
         when Terminal.PTY.Backend.Ok =>
            Reads := Reads + 1;
            Append_Output;
         when Terminal.PTY.Backend.Would_Block
            | Terminal.PTY.Backend.Interrupted =>
            delay 0.01;
         when Terminal.PTY.Backend.End_Of_File
            | Terminal.PTY.Backend.Failed
            | Terminal.PTY.Backend.Session_Closed =>
            exit;
      end case;

      exit when Contains (Term_Marker)
        and then Contains (Color_Marker)
        and then Contains (Program_Marker)
        and then Contains (Version_Marker)
        and then Contains (Features_Marker);
   end loop;

   --  Say what came back when it is not what was wanted. A bare assertion here
   --  tells whoever reads the log that the marker was absent and nothing about
   --  what the shell said instead -- which, when the only machine that can run
   --  this is a build runner, is the difference between a diagnosis and another
   --  round trip.
   if not
     (Contains (Term_Marker)
      and then Contains (Color_Marker)
      and then Contains (Program_Marker)
      and then Contains (Version_Marker)
      and then Contains (Features_Marker))
   then
      --  Enough to tell a child that died at once from a read that never
      --  worked: the first shows as not alive with nothing to read, the second
      --  as alive with the loop giving up.
      Ada.Text_IO.Put_Line
        ("pty_env_smoke: read" & Natural'Image (Output_Last) & " bytes"
         & " after" & Natural'Image (Attempts) & " attempts"
         & "," & Natural'Image (Reads) & " of them returning data"
         & "; alive after spawn: " & Boolean'Image (Alive_After_Spawn)
         & "; alive at end: "
         & Boolean'Image (Terminal.PTY.Backend.Is_Alive (S))
         & "; last read: "
         & Terminal.PTY.Backend.Read_Status'Image (Read_Status)
         & "; child: "
         & Terminal.PTY.Backend.Exit_State'Image
             (Terminal.PTY.Backend.Child_State (S)));

      for I in 1 .. Output_Last loop
         if Output (I) in ' ' .. '~' then
            Ada.Text_IO.Put (Output (I));
         else
            Ada.Text_IO.Put
              ("<" & Natural'Image (Character'Pos (Output (I))) & ">");
         end if;
      end loop;

      Ada.Text_IO.New_Line;

      declare
         T : constant Terminal.PTY.Backend.Spawn_Trace :=
           Terminal.PTY.Backend.Last_Spawn_Trace;
      begin
         Ada.Text_IO.Put_Line
           ("pty_env_smoke: spawn trace"
            & " pipes=" & Boolean'Image (T.Pipes_Made)
            & " console=" & Boolean'Image (T.Console_Made)
            & " attributes=" & Boolean'Image (T.Attributes_Made)
            & " process=" & Boolean'Image (T.Process_Made)
            & " last_error=" & Natural'Image (T.Last_Error)
            & " startup_size=" & Natural'Image (T.Startup_Size)
            & " attribute_size=" & Natural'Image (T.Attribute_Size));
      end;

      declare
         R : constant Terminal.PTY.Backend.Read_Trace :=
           Terminal.PTY.Backend.Last_Read_Trace;
      begin
         Ada.Text_IO.Put_Line
           ("pty_env_smoke: read trace"
            & " peeks=" & Natural'Image (R.Peeks)
            & " failed=" & Natural'Image (R.Peek_Failed)
            & " peek_error=" & Natural'Image (R.Peek_Error)
            & " bytes_seen=" & Natural'Image (R.Bytes_Seen)
            & "; unprompted bytes before any write:"
            & Natural'Image (Unprompted));
      end;

      Ada.Text_IO.Put_Line
        ("pty_env_smoke: wrote" & Natural'Image (Written_Total)
         & " of" & Natural'Image (Command'Length) & " bytes;"
         & " alive before write: " & Boolean'Image (Alive_Before_Write)
         & "; alive after write: " & Boolean'Image (Alive_After_Write)
         & "; child exited with"
         & Integer'Image (Terminal.PTY.Backend.Child_Status (S)));
   end if;

   Terminal.PTY.Backend.Close (S);

   Assert (Contains (Term_Marker), "child shell should see TERM=xterm-256color");
   Assert
     (Contains (Color_Marker),
      "child shell should see COLORTERM=truecolor");
   Assert
     (Contains (Features_Marker),
      "child shell should see truthful graphics TERM_FEATURES");
end PTY_Env_Smoke;

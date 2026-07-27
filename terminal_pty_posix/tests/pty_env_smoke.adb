with AUnit.Assertions;

with Terminal.Common.Bytes;
with Terminal.PTY.POSIX;

procedure PTY_Env_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.PTY.POSIX.Read_Status;
   use type Terminal.PTY.POSIX.Spawn_Status;
   use type Terminal.PTY.POSIX.Write_Status;

   Rows : constant Positive := 12;
   Cols : constant Positive := 80;
   Term_Marker : constant String :=
     "__TERM=" & Terminal.PTY.POSIX.Term_Name & "__";
   Color_Marker : constant String :=
     "__COLORTERM=" & Terminal.PTY.POSIX.Color_Term & "__";
   Command : constant String :=
     "printf '__TERM=%s__\n' ""$TERM""; "
     & "printf '__COLORTERM=%s__\n' ""$COLORTERM""; exit"
     & Character'Val (13);

   S            : Terminal.PTY.POSIX.Session;
   Spawn_Status : Terminal.PTY.POSIX.Spawn_Status;
   Write_Status : Terminal.PTY.POSIX.Write_Status;
   Read_Status  : Terminal.PTY.POSIX.Read_Status;
   Buffer       : Byte_Array (1 .. 1024);
   Last         : Natural := 0;
   Output       : String (1 .. 4096) := (others => ASCII.NUL);
   Output_Last  : Natural := 0;

   function To_Bytes (Text : String) return Byte_Array is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) := Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

   procedure Write_All (Data : Byte_Array) is
      First : Positive := Data'First;
      Wrote : Natural := 0;
   begin
      while First <= Data'Last loop
         Terminal.PTY.POSIX.Write
           (S, Data (First .. Data'Last), Wrote, Write_Status);

         case Write_Status is
            when Terminal.PTY.POSIX.Ok | Terminal.PTY.POSIX.Partial =>
               Assert (Wrote > 0, "write made no progress");
               First := First + Wrote;
            when Terminal.PTY.POSIX.Interrupted =>
               null;
            when Terminal.PTY.POSIX.Failed
               | Terminal.PTY.POSIX.Session_Closed =>
               Assert (False, "pty write failed");
         end case;
      end loop;
   end Write_All;

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
begin
   Assert
     (Terminal.PTY.POSIX.Term_Name = "xterm-256color",
      "PTY TERM constant");
   Assert
     (Terminal.PTY.POSIX.Color_Term = "truecolor",
      "PTY COLORTERM constant");

   Terminal.PTY.POSIX.Spawn_Default_Shell (S, Rows, Cols, Spawn_Status);
   Assert (Spawn_Status = Terminal.PTY.POSIX.Ok, "pty spawn failed");

   declare
      Data : constant Byte_Array := To_Bytes (Command);
   begin
      Write_All (Data);
   end;

   for Attempt in 1 .. 300 loop
      Terminal.PTY.POSIX.Read (S, Buffer, Last, Read_Status);
      case Read_Status is
         when Terminal.PTY.POSIX.Ok =>
            Append_Output;
         when Terminal.PTY.POSIX.Would_Block
            | Terminal.PTY.POSIX.Interrupted =>
            delay 0.01;
         when Terminal.PTY.POSIX.End_Of_File
            | Terminal.PTY.POSIX.Failed
            | Terminal.PTY.POSIX.Session_Closed =>
            exit;
      end case;

      exit when Contains (Term_Marker) and then Contains (Color_Marker);
   end loop;

   Terminal.PTY.POSIX.Close (S);

   Assert (Contains (Term_Marker), "child shell should see TERM=xterm-256color");
   Assert
     (Contains (Color_Marker),
      "child shell should see COLORTERM=truecolor");
end PTY_Env_Smoke;

with Ada.Text_IO;
with AUnit.Assertions;

with Terminal.Common.Bytes;
with Terminal.PTY.Backend;

procedure PTY_Resize_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.PTY.Backend.Read_Status;
   use type Terminal.PTY.Backend.Resize_Status;
   use type Terminal.PTY.Backend.Spawn_Status;
   use type Terminal.PTY.Backend.Write_Status;

   Initial_Rows : constant Positive := 24;
   Initial_Cols : constant Positive := 80;
   Resized_Rows : constant Positive := 33;
   Resized_Cols : constant Positive := 101;
   --  Each host is asked in its own shell's language, and answers in its own
   --  shape: stty prints the pair of numbers, mode con prints two labelled and
   --  padded lines.
   On_Windows : constant Boolean :=
     Terminal.PTY.Backend.Capabilities.Windows_ConPTY;

   Ready_Command : constant String :=
     (if On_Windows
      then "echo __PTY_READY__" & Character'Val (13)
      else "printf __PTY_READY__" & Character'Val (10));

   --  No "exit" on the Windows side, deliberately, for the same reason as the
   --  environment smoke: a pseudo-console paints on a tick, and a shell that
   --  answers and leaves within milliseconds can be gone before the first paint.
   --  Close ends it afterwards.
   Size_Command  : constant String :=
     (if On_Windows
      then "mode con" & Character'Val (13)
      else "stty size; exit" & Character'Val (13));

   Ready_Marker  : constant String := "__PTY_READY__";
   Expected      : constant String := "33 101";

   S             : Terminal.PTY.Backend.Session;
   Spawn_Status  : Terminal.PTY.Backend.Spawn_Status;
   Resize_Status : Terminal.PTY.Backend.Resize_Status;
   Write_Status  : Terminal.PTY.Backend.Write_Status;
   Read_Status   : Terminal.PTY.Backend.Read_Status;
   Buffer        : Byte_Array (1 .. 1024);
   Last          : Natural := 0;
   Output        : String (1 .. 8192) := (others => ASCII.NUL);
   Output_Last   : Natural := 0;

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
         Terminal.PTY.Backend.Write
           (S, Data (First .. Data'Last), Wrote, Write_Status);

         case Write_Status is
            when Terminal.PTY.Backend.Ok | Terminal.PTY.Backend.Partial =>
               Assert (Wrote > 0, "write made no progress");
               First := First + Wrote;
            when Terminal.PTY.Backend.Interrupted =>
               null;
            when Terminal.PTY.Backend.Failed
               | Terminal.PTY.Backend.Session_Closed =>
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

   --  The number a label stands in front of, however much padding is between
   --  them: "    Columns:        101" is one line of mode con's answer.
   function Value_After (Label : String) return Natural is
      Result : Natural := 0;
      Seen   : Boolean := False;
   begin
      if Output_Last < Label'Length then
         return 0;
      end if;

      for Start in 1 .. Output_Last - Label'Length + 1 loop
         if Output (Start .. Start + Label'Length - 1) = Label then
            for I in Start + Label'Length .. Output_Last loop
               if Output (I) in '0' .. '9' then
                  Result := Result * 10 + (Character'Pos (Output (I))
                                           - Character'Pos ('0'));
                  Seen := True;
               elsif Seen or else Output (I) not in ' ' | Character'Val (9) then
                  return Result;
               end if;
            end loop;

            return Result;
         end if;
      end loop;

      return 0;
   end Value_After;

   procedure Pump (Ended : out Boolean) is
   begin
      Ended := False;
      Terminal.PTY.Backend.Read (S, Buffer, Last, Read_Status);
      case Read_Status is
         when Terminal.PTY.Backend.Ok =>
            Append_Output;
         when Terminal.PTY.Backend.Would_Block
            | Terminal.PTY.Backend.Interrupted =>
            delay 0.01;
         when Terminal.PTY.Backend.End_Of_File
            | Terminal.PTY.Backend.Failed
            | Terminal.PTY.Backend.Session_Closed =>
            Ended := True;
      end case;
   end Pump;

   procedure Drain_For (Attempts : Positive) is
      Ended : Boolean;
   begin
      for Attempt in 1 .. Attempts loop
         Pump (Ended);
         exit when Ended;
      end loop;
   end Drain_For;

   procedure Drain_Until
     (Pattern : String;
      Found   : out Boolean)
   is
      Ended : Boolean;
   begin
      Found := False;
      for Attempt in 1 .. 300 loop
         Pump (Ended);
         exit when Ended;

         if Contains (Pattern) then
            Found := True;
            exit;
         end if;
      end loop;
   end Drain_Until;
begin
   Terminal.PTY.Backend.Spawn_Default_Shell
     (S, Initial_Rows, Initial_Cols, Spawn_Status);
   Assert (Spawn_Status = Terminal.PTY.Backend.Ok, "pty spawn failed");

   declare
      Ready_Data : constant Byte_Array := To_Bytes (Ready_Command);
      Ready      : Boolean;
   begin
      Write_All (Ready_Data);
      Drain_Until (Ready_Marker, Ready);
      Assert (Ready, "shell should execute readiness command");
   end;

   Terminal.PTY.Backend.Resize (S, Resized_Rows, Resized_Cols, Resize_Status);
   Assert (Resize_Status = Terminal.PTY.Backend.Ok, "pty resize failed");

   declare
      Size_Data : constant Byte_Array := To_Bytes (Size_Command);
      Found     : Boolean;
   begin
      Write_All (Size_Data);

      if On_Windows then
         --  Wait for the label, then keep reading: the number it stands in
         --  front of is painted after it, and may well be in a later read.
         Drain_Until ("Columns:", Found);
         Drain_For (50);
         Terminal.PTY.Backend.Close (S);

         declare
            Rows : constant Natural := Value_After ("Lines:");
            Cols : constant Natural := Value_After ("Columns:");
         begin
            --  An assertion message is lost when AUnit's exception goes
            --  uncaught, and what the console answered is the whole diagnosis.
            Ada.Text_IO.Put_Line
              ("pty_resize_smoke: asked for" & Natural'Image (Resized_Rows)
               & " x" & Natural'Image (Resized_Cols)
               & ", console answered" & Natural'Image (Rows)
               & " x" & Natural'Image (Cols)
               & " in" & Natural'Image (Output_Last) & " bytes");

            if Rows /= Resized_Rows or else Cols /= Resized_Cols then
               for I in 1 .. Output_Last loop
                  if Output (I) >= ' ' and then Output (I) <= '~' then
                     Ada.Text_IO.Put (Output (I));
                  else
                     Ada.Text_IO.Put
                       ("<" & Natural'Image (Character'Pos (Output (I))) & ">");
                  end if;
               end loop;
               Ada.Text_IO.New_Line;
            end if;

            Assert (Rows = Resized_Rows and then Cols = Resized_Cols,
                    "child shell should observe resized pty size, saw"
                    & Natural'Image (Rows) & " x" & Natural'Image (Cols));
         end;
      else
         Drain_Until (Expected, Found);
         Terminal.PTY.Backend.Close (S);
         Assert (Found, "child shell should observe resized pty size");
      end if;
   end;
end PTY_Resize_Smoke;

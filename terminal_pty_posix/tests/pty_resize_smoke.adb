with AUnit.Assertions;

with Terminal.Common.Bytes;
with Terminal.PTY.POSIX;

procedure PTY_Resize_Smoke is
   use AUnit.Assertions;
   use Terminal.Common.Bytes;
   use type Terminal.PTY.POSIX.Read_Status;
   use type Terminal.PTY.POSIX.Resize_Status;
   use type Terminal.PTY.POSIX.Spawn_Status;
   use type Terminal.PTY.POSIX.Write_Status;

   Initial_Rows : constant Positive := 24;
   Initial_Cols : constant Positive := 80;
   Resized_Rows : constant Positive := 33;
   Resized_Cols : constant Positive := 101;
   Ready_Command : constant String := "printf __PTY_READY__" & Character'Val (10);
   Size_Command  : constant String := "stty size; exit" & Character'Val (13);
   Ready_Marker  : constant String := "__PTY_READY__";
   Expected     : constant String := "33 101";

   S             : Terminal.PTY.POSIX.Session;
   Spawn_Status  : Terminal.PTY.POSIX.Spawn_Status;
   Resize_Status : Terminal.PTY.POSIX.Resize_Status;
   Write_Status  : Terminal.PTY.POSIX.Write_Status;
   Read_Status   : Terminal.PTY.POSIX.Read_Status;
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

   procedure Drain_Until
     (Pattern : String;
      Found   : out Boolean)
   is
   begin
      Found := False;
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

         if Contains (Pattern) then
            Found := True;
            exit;
         end if;
      end loop;
   end Drain_Until;
begin
   Terminal.PTY.POSIX.Spawn_Default_Shell
     (S, Initial_Rows, Initial_Cols, Spawn_Status);
   Assert (Spawn_Status = Terminal.PTY.POSIX.Ok, "pty spawn failed");

   declare
      Ready_Data : constant Byte_Array := To_Bytes (Ready_Command);
      Ready      : Boolean;
   begin
      Write_All (Ready_Data);
      Drain_Until (Ready_Marker, Ready);
      Assert (Ready, "shell should execute readiness command");
   end;

   Terminal.PTY.POSIX.Resize (S, Resized_Rows, Resized_Cols, Resize_Status);
   Assert (Resize_Status = Terminal.PTY.POSIX.Ok, "pty resize failed");

   declare
      Size_Data : constant Byte_Array := To_Bytes (Size_Command);
      Found     : Boolean;
   begin
      Write_All (Size_Data);
      Drain_Until (Expected, Found);
      Terminal.PTY.POSIX.Close (S);
      Assert (Found, "child shell should observe resized pty size");
   end;
end PTY_Resize_Smoke;

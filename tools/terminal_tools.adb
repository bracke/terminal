with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

package body Terminal_Tools is
   use type Ada.Directories.File_Kind;
   use type Ada.Streams.Stream_Element_Offset;
   use type GNAT.OS_Lib.String_Access;

   package SIO renames Ada.Streams.Stream_IO;
   package US renames Ada.Strings.Unbounded;

   function Path (Directory, Name : String) return String is
     (if Directory'Length = 0
      then Name
      elsif Directory (Directory'Last) = GNAT.OS_Lib.Directory_Separator
      then Directory & Name
      else Directory & GNAT.OS_Lib.Directory_Separator & Name);

   function Find_Root_From (Start : String) return String is
      Current : US.Unbounded_String := US.To_Unbounded_String (Start);
   begin
      loop
         declare
            Here : constant String := US.To_String (Current);
            Marker : constant String := Path (Here, "terminal.gpr");
            Parent : constant String := Ada.Directories.Containing_Directory (Here);
         begin
            if Ada.Directories.Exists (Marker)
              and then Ada.Directories.Kind (Marker) = Ada.Directories.Ordinary_File
            then
               return Here;
            elsif Parent = Here then
               return "";
            end if;
            Current := US.To_Unbounded_String (Parent);
         end;
      end loop;
   exception
      when others =>
         return "";
   end Find_Root_From;

   function Repository_Root return String is
      From_Current : constant String :=
        Find_Root_From (Ada.Directories.Current_Directory);
   begin
      if From_Current'Length > 0 then
         return From_Current;
      end if;
      declare
         Executable : constant String := Current_Executable;
      begin
         if Executable'Length = 0 then
            return "";
         end if;
         return Find_Root_From (Ada.Directories.Containing_Directory (Executable));
      end;
   end Repository_Root;

   function Locate_Executable (Name : String) return String is
      Located : GNAT.OS_Lib.String_Access := GNAT.OS_Lib.Locate_Exec_On_Path (Name);
   begin
      if Located = null then
         return "";
      end if;
      declare
         Result : constant String := Located.all;
      begin
         GNAT.OS_Lib.Free (Located);
         return Result;
      end;
   end Locate_Executable;

   function Current_Executable return String is
      Command : constant String := Ada.Command_Line.Command_Name;
   begin
      if Command'Length = 0 then
         return "";
      elsif Ada.Directories.Exists (Command) then
         return Ada.Directories.Full_Name (Command);
      else
         return Locate_Executable (Command);
      end if;
   exception
      when others =>
         return "";
   end Current_Executable;

   function Shell_Quote (Value : String) return String is
      Result : US.Unbounded_String := US.To_Unbounded_String ("'");
   begin
      for Item of Value loop
         if Item = ''' then
            US.Append (Result, ''');
            US.Append (Result, '\');
            US.Append (Result, ''');
            US.Append (Result, ''');
         else
            US.Append (Result, Item);
         end if;
      end loop;
      US.Append (Result, "'");
      return US.To_String (Result);
   end Shell_Quote;

   function Run
     (Program     : String;
      Args        : GNAT.OS_Lib.Argument_List;
      Output_File : String := "";
      Err_To_Out  : Boolean := True) return Integer
   is
      Success : Boolean;
      Status : Integer;
   begin
      if Program'Length = 0 then
         return -1;
      elsif Output_File'Length = 0 then
         return GNAT.OS_Lib.Spawn (Program, Args);
      end if;
      GNAT.OS_Lib.Spawn
        (Program,
         Args,
         Output_File,
         Success,
         Status,
         Err_To_Out);
      return (if Success then Status else -1);
   end Run;

   function Read_File (Name : String) return String is
      Input : SIO.File_Type;
   begin
      SIO.Open (Input, SIO.In_File, Name);
      declare
         Length : constant Ada.Streams.Stream_Element_Offset :=
           Ada.Streams.Stream_Element_Offset (SIO.Size (Input));
         Data : Ada.Streams.Stream_Element_Array (1 .. Length);
         Last : Ada.Streams.Stream_Element_Offset := 0;
         Result : String (1 .. Natural (Length));
      begin
         if Length > 0 then
            SIO.Read (Input, Data, Last);
         end if;
         SIO.Close (Input);
         for I in 1 .. Natural (Last) loop
            Result (I) := Character'Val (Data (Ada.Streams.Stream_Element_Offset (I)));
         end loop;
         return Result (1 .. Natural (Last));
      end;
   exception
      when others =>
         if SIO.Is_Open (Input) then
            SIO.Close (Input);
         end if;
         return "";
   end Read_File;

   function Read_First_Line (Name : String) return String is
      Data : constant String := Read_File (Name);
      Last : Natural := Data'Last;
   begin
      for I in Data'Range loop
         if Data (I) in ASCII.CR | ASCII.LF then
            Last := I - 1;
            exit;
         end if;
      end loop;
      return (if Last < Data'First then "" else Data (Data'First .. Last));
   end Read_First_Line;

   function File_Contains (Name, Pattern : String) return Boolean is
      Data : constant String := Read_File (Name);
   begin
      if Pattern'Length = 0 then
         return True;
      end if;
      return Ada.Strings.Fixed.Index (Data, Pattern) /= 0;
   end File_Contains;

   function File_Has_Line (Name, Expected : String) return Boolean is
      Data : constant String := Read_File (Name);
      First : Positive := Data'First;
      Last : Natural;
   begin
      while First <= Data'Last loop
         Last := First;
         while Last <= Data'Last and then Data (Last) not in ASCII.CR | ASCII.LF loop
            Last := Last + 1;
         end loop;
         if Data (First .. Last - 1) = Expected then
            return True;
         end if;
         while Last <= Data'Last and then Data (Last) in ASCII.CR | ASCII.LF loop
            Last := Last + 1;
         end loop;
         exit when Last > Data'Last;
         First := Last;
      end loop;
      return False;
   end File_Has_Line;

   procedure Write_Bytes
     (Name : String;
      Data : Ada.Streams.Stream_Element_Array)
   is
      Output : SIO.File_Type;
   begin
      SIO.Create (Output, SIO.Out_File, Name);
      SIO.Write (Output, Data);
      SIO.Close (Output);
   exception
      when others =>
         if SIO.Is_Open (Output) then
            SIO.Close (Output);
         end if;
         raise;
   end Write_Bytes;

   function Create_Work_Directory (Prefix : String) return String is
      Base : constant String :=
        (if Ada.Environment_Variables.Exists ("TMPDIR")
         then Ada.Environment_Variables.Value ("TMPDIR")
         else "/tmp");
      Process : constant String := Ada.Strings.Fixed.Trim
        (Integer'Image
           (GNAT.OS_Lib.Pid_To_Integer (GNAT.OS_Lib.Current_Process_Id)),
         Ada.Strings.Both);
   begin
      for Attempt in 0 .. 999 loop
         declare
            Suffix : constant String :=
              (if Attempt = 0
               then ""
               else "-" & Ada.Strings.Fixed.Trim
                 (Natural'Image (Attempt), Ada.Strings.Both));
            Candidate : constant String :=
              Path (Base, Prefix & "-" & Process & Suffix);
         begin
            if not Ada.Directories.Exists (Candidate) then
               Ada.Directories.Create_Directory (Candidate);
               return Candidate;
            end if;
         exception
            when Ada.Directories.Use_Error | Ada.Directories.Name_Error =>
               null;
         end;
      end loop;
      return "";
   end Create_Work_Directory;

   procedure Remove_Work_Directory (Name : String) is
   begin
      if Name'Length > 0 and then Ada.Directories.Exists (Name) then
         Ada.Directories.Delete_Tree (Name);
      end if;
   exception
      when others =>
         null;
   end Remove_Work_Directory;
end Terminal_Tools;

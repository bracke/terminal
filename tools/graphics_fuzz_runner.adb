with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Real_Time;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with GNAT.OS_Lib;

with Terminal_Tools;

procedure Graphics_Fuzz_Runner is
   use type Ada.Directories.File_Kind;
   use type Ada.Directories.File_Size;
   use type Ada.Real_Time.Time;
   use type GNAT.OS_Lib.Process_Id;

   function Arg (Value : String) return GNAT.OS_Lib.String_Access is
     (new String'(Value));

   procedure Set_Status (Value : Natural) is
   begin
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Exit_Status (Value));
   end Set_Status;

   function Decimal (Value : String) return Boolean is
   begin
      if Value'Length = 0 then
         return False;
      end if;
      for Item of Value loop
         if Item not in '0' .. '9' then
            return False;
         end if;
      end loop;
      return True;
   end Decimal;

   function Full_Path (Root, Value : String) return String is
     (if Value'Length > 0
        and then Value (Value'First) = GNAT.OS_Lib.Directory_Separator
      then Value
      else Terminal_Tools.Path (Root, Value));

   type Finding_Kind is (No_Finding, Crash_Finding, Hang_Finding);

   procedure Count_Findings
     (Directory : String;
      Context   : Finding_Kind;
      Crashes   : in out Natural;
      Hangs     : in out Natural)
   is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;
      Search_Active : Boolean := False;
   begin
      if not Ada.Directories.Exists (Directory)
        or else Ada.Directories.Kind (Directory) /= Ada.Directories.Directory
      then
         return;
      end if;
      Ada.Directories.Start_Search
        (Search,
         Directory,
         "*",
         (Ada.Directories.Ordinary_File => True,
          Ada.Directories.Directory     => True,
          Ada.Directories.Special_File  => False));
      Search_Active := True;
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Item);
            Path : constant String := Ada.Directories.Full_Name (Item);
            Kind : constant Ada.Directories.File_Kind :=
              Ada.Directories.Kind (Item);
         begin
            if Kind = Ada.Directories.Directory
              and then Name /= "." and then Name /= ".."
            then
               Count_Findings
                 (Path,
                  (if Name = "crashes" then Crash_Finding
                   elsif Name = "hangs" then Hang_Finding
                   else Context),
                  Crashes,
                  Hangs);
            elsif Kind = Ada.Directories.Ordinary_File
              and then Ada.Strings.Fixed.Index (Name, "id:") = Name'First
            then
               case Context is
                  when Crash_Finding => Crashes := Crashes + 1;
                  when Hang_Finding  => Hangs := Hangs + 1;
                  when No_Finding    => null;
               end case;
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
      Search_Active := False;
   exception
      when others =>
         if Search_Active then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Count_Findings;

   procedure Run_Bounded
     (Program : String;
      Args    : GNAT.OS_Lib.Argument_List;
      Seconds : Positive)
   is
      Child : constant GNAT.OS_Lib.Process_Id :=
        GNAT.OS_Lib.Non_Blocking_Spawn (Program, Args);
      Finished : GNAT.OS_Lib.Process_Id;
      Success : Boolean := False;
      Timed_Out : Boolean := False;
      Deadline : constant Ada.Real_Time.Time :=
        Ada.Real_Time.Clock
        + Ada.Real_Time.To_Time_Span (Duration (Seconds));
   begin
      if Child = GNAT.OS_Lib.Invalid_Pid then
         raise Program_Error with "could not start AFL++";
      end if;

      loop
         GNAT.OS_Lib.Non_Blocking_Wait_Process (Finished, Success);
         exit when Finished = Child;
         if Ada.Real_Time.Clock >= Deadline then
            Timed_Out := True;
            GNAT.OS_Lib.Kill_Process_Tree (Child, Hard_Kill => False);
            exit;
         end if;
         delay 0.10;
      end loop;

      if Timed_Out then
         declare
            Kill_Deadline : constant Ada.Real_Time.Time :=
              Ada.Real_Time.Clock + Ada.Real_Time.Seconds (15);
         begin
            loop
               GNAT.OS_Lib.Non_Blocking_Wait_Process (Finished, Success);
               exit when Finished = Child;
               if Ada.Real_Time.Clock >= Kill_Deadline then
                  GNAT.OS_Lib.Kill_Process_Tree (Child, Hard_Kill => True);
                  GNAT.OS_Lib.Wait_Process (Finished, Success);
                  exit;
               end if;
               delay 0.10;
            end loop;
         end;
      elsif not Success then
         raise Program_Error with "AFL++ exited before the deadline with an error";
      end if;
   exception
      when others =>
         if Child /= GNAT.OS_Lib.Invalid_Pid then
            GNAT.OS_Lib.Kill_Process_Tree (Child, Hard_Kill => True);
         end if;
         raise;
   end Run_Bounded;

   Root : constant String := Terminal_Tools.Repository_Root;
   Alr : constant String := Terminal_Tools.Locate_Executable ("alr");
   AFL_Fuzz : constant String := Terminal_Tools.Locate_Executable ("afl-fuzz");
   AFL_Showmap : constant String :=
     Terminal_Tools.Locate_Executable ("afl-showmap");
begin
   if Ada.Command_Line.Argument_Count > 3 then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "usage: graphics_fuzz_runner [SECONDS [OUTPUT [core|pipeline]]]");
      Set_Status (2);
      return;
   elsif Root'Length = 0 then
      raise Program_Error with "repository root not found";
   elsif Alr'Length = 0 then
      raise Program_Error with "alr is required";
   end if;

   declare
      Seconds_Text : constant String :=
        (if Ada.Command_Line.Argument_Count >= 1
         then Ada.Command_Line.Argument (1) else "300");
      Output_Text : constant String :=
        (if Ada.Command_Line.Argument_Count >= 2
         then Ada.Command_Line.Argument (2) else "fuzz/findings");
      Profile : constant String :=
        (if Ada.Command_Line.Argument_Count >= 3
         then Ada.Command_Line.Argument (3) else "core");
   begin
      if not Decimal (Seconds_Text) or else Natural'Value (Seconds_Text) = 0 then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "duration must be a positive number of seconds");
         Set_Status (2);
         return;
      elsif Profile /= "core" and then Profile /= "pipeline" then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "profile must be core or pipeline");
         Set_Status (2);
         return;
      elsif AFL_Fuzz'Length = 0 or else AFL_Showmap'Length = 0 then
         raise Program_Error with "AFL++ is required (install afl++)";
      end if;

      declare
         Seconds : constant Positive := Positive'Value (Seconds_Text);
         Base_Directory : constant String :=
           Terminal_Tools.Path
             (Root,
              (if Profile = "core"
               then "terminal_core"
               else "terminal_glfw_vulkan_app"));
         Output : constant String := Full_Path (Base_Directory, Output_Text);
         Project : constant String :=
           (if Profile = "core"
            then "terminal_core/fuzz/core_graphics_fuzz.gpr"
            else "terminal_glfw_vulkan_app/fuzz/graphics_pipeline_fuzz.gpr");
         Target : constant String :=
           (if Profile = "core"
            then "terminal_core/fuzz/bin/core_graphics_fuzz_target"
            else
              "terminal_glfw_vulkan_app/fuzz/bin/graphics_pipeline_fuzz_target");
         Coverage_Smoke : constant String :=
           (if Profile = "core"
            then "terminal_core/fuzz/bin/afl_coverage_smoke"
            else "terminal_glfw_vulkan_app/fuzz/bin/afl_coverage_smoke");
         Coverage_A : constant String :=
           (if Profile = "core"
            then "terminal_core/fuzz/corpus/kitty_query"
            else "terminal_glfw_vulkan_app/fuzz/corpus/kitty_rgba");
         Coverage_B : constant String :=
           (if Profile = "core"
            then "terminal_core/fuzz/corpus/sixel"
            else "terminal_glfw_vulkan_app/fuzz/corpus/kitty_png");
         Corpus : constant String :=
           (if Profile = "core"
            then "terminal_core/fuzz/corpus"
            else "terminal_glfw_vulkan_app/fuzz/corpus");
         Dictionary : constant String :=
           (if Profile = "core"
            then "terminal_core/fuzz/graphics.dict"
            else "terminal_glfw_vulkan_app/fuzz/graphics.dict");
         Work : constant String :=
           Terminal_Tools.Create_Work_Directory ("terminal-afl-coverage");
      begin
         if Work'Length = 0 then
            raise Program_Error with "temporary directory unavailable";
         end if;
         Ada.Directories.Set_Directory (Root);
         if Terminal_Tools.Run
           (Alr,
            [Arg ("--non-interactive"), Arg ("exec"), Arg ("--"),
             Arg ("gprbuild"), Arg ("-p"), Arg ("-P"), Arg (Project)]) /= 0
         then
            raise Program_Error with "fuzz target build failed";
         end if;
         Ada.Directories.Create_Path (Output);
         if Terminal_Tools.Run
           (Full_Path (Root, Coverage_Smoke),
            [Arg (Full_Path (Root, Target)),
             Arg (Full_Path (Root, Coverage_A)),
             Arg (Full_Path (Root, Coverage_B))]) /= 0
         then
            raise Program_Error with "coverage instrumentation smoke failed";
         end if;

         declare
            Coverage_Map : constant String :=
              Terminal_Tools.Path (Work, "coverage.map");
         begin
            Ada.Environment_Variables.Set ("AFL_NO_UI", "1");
            Ada.Environment_Variables.Set ("AFL_SKIP_CPUFREQ", "1");
            Ada.Environment_Variables.Set
              ("AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES", "1");
            Ada.Environment_Variables.Set ("AFL_NO_FORKSRV", "1");
            if Terminal_Tools.Run
              (AFL_Showmap,
               [Arg ("-q"), Arg ("-o"), Arg (Coverage_Map), Arg ("--"),
                Arg (Full_Path (Root, Target)),
                Arg (Full_Path (Root, Coverage_A))]) /= 0
            then
               raise Program_Error with
                 "AFL++ could not execute the instrumented target";
            elsif not Ada.Directories.Exists (Coverage_Map)
              or else Ada.Directories.Size (Coverage_Map) = 0
            then
               raise Program_Error with "fuzz target produced no AFL++ coverage";
            end if;

            Run_Bounded
              (AFL_Fuzz,
               [Arg ("-i"), Arg (Full_Path (Root, Corpus)),
                Arg ("-o"), Arg (Output),
                Arg ("-x"), Arg (Full_Path (Root, Dictionary)),
                Arg ("--"), Arg (Full_Path (Root, Target)), Arg ("@@")],
               Seconds);
         end;

         declare
            Crashes : Natural := 0;
            Hangs : Natural := 0;
         begin
            Count_Findings (Output, No_Finding, Crashes, Hangs);
            if Crashes /= 0 or else Hangs /= 0 then
               raise Program_Error with
                 Ada.Strings.Fixed.Trim (Natural'Image (Crashes), Ada.Strings.Both)
                 & " AFL++ crash(es) and "
                 & Ada.Strings.Fixed.Trim (Natural'Image (Hangs), Ada.Strings.Both)
                 & " hang(s) found";
            end if;
         end;
         Terminal_Tools.Remove_Work_Directory (Work);
      exception
         when others =>
            Terminal_Tools.Remove_Work_Directory (Work);
            raise;
      end;
   end;
exception
   when Error : others =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "graphics_fuzz_runner: FAIL ("
         & Ada.Exceptions.Exception_Message (Error) & ")");
      Set_Status (1);
end Graphics_Fuzz_Runner;

with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Streams;
with Ada.Text_IO;
with GNAT.OS_Lib;

with Terminal_Tools;

procedure External_Graphics_Clients_Probe is
   use type Ada.Streams.Stream_Element;

   function Arg (Value : String) return GNAT.OS_Lib.String_Access is
     (new String'(Value));

   procedure Set_Status (Value : Natural) is
   begin
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Exit_Status (Value));
   end Set_Status;

   Chafa : constant String := Terminal_Tools.Locate_Executable ("chafa");
   Img2sixel : constant String := Terminal_Tools.Locate_Executable ("img2sixel");
   Root : constant String := Terminal_Tools.Repository_Root;
begin
   if Chafa'Length = 0 then
      Ada.Text_IO.Put_Line
        ("external_graphics_clients_probe: SKIP (chafa not installed)");
      Set_Status (77);
      return;
   elsif Img2sixel'Length = 0 then
      Ada.Text_IO.Put_Line
        ("external_graphics_clients_probe: SKIP (img2sixel not installed)");
      Set_Status (77);
      return;
   elsif Root'Length = 0 then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "external_graphics_clients_probe: FAIL (repository root not found)");
      Set_Status (1);
      return;
   end if;

   declare
      Target : constant String := Terminal_Tools.Path
        (Root, "terminal_core/fuzz/bin/core_graphics_fuzz_target");
      Render_Probe : constant String := Terminal_Tools.Path
        (Root,
         "terminal_glfw_vulkan_app/tests/bin/external_graphics_stream_probe");
   begin
      if not Ada.Directories.Exists (Target) then
         Ada.Text_IO.Put_Line
           ("external_graphics_clients_probe: SKIP "
            & "(build fuzz/core_graphics_fuzz.gpr first)");
         Set_Status (77);
         return;
      elsif not Ada.Directories.Exists (Render_Probe) then
         Ada.Text_IO.Put_Line
           ("external_graphics_clients_probe: SKIP "
            & "(build tests/app_tests.gpr first)");
         Set_Status (77);
         return;
      end if;

      declare
         Work : constant String :=
           Terminal_Tools.Create_Work_Directory ("terminal-graphics-clients");
      begin
         if Work'Length = 0 then
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "external_graphics_clients_probe: FAIL "
               & "(temporary directory unavailable)");
            Set_Status (1);
            return;
         end if;

         declare
            PNG : constant String := Terminal_Tools.Path (Work, "probe.png");
            Kitty : constant String :=
              Terminal_Tools.Path (Work, "chafa-kitty.bin");
            Tmux_Kitty : constant String :=
              Terminal_Tools.Path (Work, "chafa-kitty-tmux.bin");
            Sixel : constant String :=
              Terminal_Tools.Path (Work, "libsixel.bin");
            Chafa_Version_File : constant String :=
              Terminal_Tools.Path (Work, "chafa-version.txt");
            Sixel_Version_File : constant String :=
              Terminal_Tools.Path (Work, "sixel-version.txt");
            Probe_PNG : constant Ada.Streams.Stream_Element_Array :=
              [137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68,
               82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 3, 0, 0, 0, 40, 203, 52,
               187, 0, 0, 0, 3, 80, 76, 84, 69, 17, 34, 51, 162, 252,
               211, 171, 0, 0, 0, 1, 116, 82, 78, 83, 68, 49, 87, 93, 239,
               0, 0, 0, 13, 73, 68, 65, 84, 120, 1, 1, 2, 0, 253, 255, 0,
               0, 0, 2, 0, 1, 126, 5, 13, 210, 0, 0, 0, 0, 73, 69, 78,
               68, 174, 66, 96, 130];
            Status : Integer;

            procedure Fail (Message : String) is
            begin
               raise Program_Error with Message;
            end Fail;

            procedure Require_Success
              (Program : String;
               Args : GNAT.OS_Lib.Argument_List;
               Output : String := "")
            is
            begin
               if Terminal_Tools.Run (Program, Args, Output) /= 0 then
                  Fail ("external command failed: " & Program);
               end if;
            end Require_Success;
         begin
            Terminal_Tools.Write_Bytes (PNG, Probe_PNG);
            Require_Success
              (Chafa,
               [Arg ("--format"), Arg ("kitty"),
                Arg ("--passthrough"), Arg ("none"),
                Arg ("--animate"), Arg ("off"),
                Arg ("--size"), Arg ("2x1"),
                Arg ("--view-size"), Arg ("2x1"), Arg (PNG)],
               Kitty);
            Require_Success
              (Chafa,
               [Arg ("--format"), Arg ("kitty"),
                Arg ("--passthrough"), Arg ("tmux"),
                Arg ("--animate"), Arg ("off"),
                Arg ("--size"), Arg ("2x1"),
                Arg ("--view-size"), Arg ("2x1"), Arg (PNG)],
               Tmux_Kitty);
            Require_Success
              (Img2sixel,
               [Arg ("-w"), Arg ("2"), Arg ("-h"), Arg ("1"), Arg (PNG)],
               Sixel);

            if not Terminal_Tools.File_Contains
              (Kitty, ASCII.ESC & "_G")
            then
               Fail ("Chafa emitted no Kitty APC");
            elsif not Terminal_Tools.File_Contains
              (Tmux_Kitty, ASCII.ESC & "Ptmux;")
            then
               Fail ("Chafa emitted no tmux DCS");
            elsif not Terminal_Tools.File_Contains
              (Sixel, ASCII.ESC & "P")
            then
               Fail ("img2sixel emitted no DCS");
            end if;

            Ada.Environment_Variables.Set ("TERMINAL_REQUIRE_GRAPHICS_EVENT", "1");
            Require_Success (Target, [1 => Arg (Kitty)]);
            Require_Success (Target, [1 => Arg (Tmux_Kitty)]);
            Require_Success (Target, [1 => Arg (Sixel)]);
            Ada.Environment_Variables.Clear ("TERMINAL_REQUIRE_GRAPHICS_EVENT");
            Require_Success (Render_Probe, [1 => Arg (Kitty)]);
            Require_Success (Render_Probe, [1 => Arg (Tmux_Kitty)]);
            Require_Success (Render_Probe, [1 => Arg (Sixel)]);

            Status := Terminal_Tools.Run
              (Chafa, [1 => Arg ("--version")], Chafa_Version_File);
            if Status /= 0 then
               Fail ("could not query Chafa version");
            end if;
            Status := Terminal_Tools.Run
              (Img2sixel, [1 => Arg ("--version")], Sixel_Version_File);
            if Status /= 0 then
               Fail ("could not query img2sixel version");
            end if;
            Ada.Text_IO.Put_Line
              ("external_graphics_clients_probe: PASS ("
               & Terminal_Tools.Read_First_Line (Chafa_Version_File)
               & "; " & Terminal_Tools.Read_First_Line (Sixel_Version_File)
               & ")");
            Terminal_Tools.Remove_Work_Directory (Work);
         exception
            when Error : others =>
               Ada.Environment_Variables.Clear
                 ("TERMINAL_REQUIRE_GRAPHICS_EVENT");
               Terminal_Tools.Remove_Work_Directory (Work);
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error,
                  "external_graphics_clients_probe: FAIL ("
                  & Ada.Exceptions.Exception_Message (Error) & ")");
               Set_Status (1);
         end;
      end;
   end;
end External_Graphics_Clients_Probe;

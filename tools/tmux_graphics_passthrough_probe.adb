with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with GNAT.OS_Lib;

with Terminal_Tools;

procedure Tmux_Graphics_Passthrough_Probe is
   function Arg (Value : String) return GNAT.OS_Lib.String_Access is
     (new String'(Value));

   procedure Set_Status (Value : Natural) is
   begin
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Exit_Status (Value));
   end Set_Status;

   procedure Emit_Payload is
   begin
      delay 1.0;
      Ada.Text_IO.Put
        (ASCII.ESC & "Ptmux;"
         & ASCII.ESC & ASCII.ESC
         & "_Gi=31,s=1,v=1,a=q,t=d,f=24;AAAA"
         & ASCII.ESC & ASCII.ESC & "\"
         & ASCII.ESC & "\");
      Ada.Text_IO.Put
        (ASCII.ESC & "Ptmux;"
         & ASCII.ESC & ASCII.ESC
         & "_Gq=2,a=T,i=32,f=32,s=1,v=1,c=1,r=1,C=1;/wAA/w=="
         & ASCII.ESC & ASCII.ESC & "\"
         & ASCII.ESC & "\");
      Ada.Text_IO.Flush;
      delay 1.0;
   end Emit_Payload;
begin
   if Ada.Command_Line.Argument_Count = 1
     and then Ada.Command_Line.Argument (1) = "--payload"
   then
      Emit_Payload;
      return;
   elsif Ada.Command_Line.Argument_Count > 1
     or else
       (Ada.Command_Line.Argument_Count = 1
        and then Ada.Command_Line.Argument (1) /= "--present")
   then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "usage: tmux_graphics_passthrough_probe [--present]");
      Set_Status (2);
      return;
   end if;

   declare
      Tmux : constant String := Terminal_Tools.Locate_Executable ("tmux");
      Script : constant String := Terminal_Tools.Locate_Executable ("script");
      Root : constant String := Terminal_Tools.Repository_Root;
      Self : constant String := Terminal_Tools.Current_Executable;
   begin
      if Tmux'Length = 0 then
         Ada.Text_IO.Put_Line
           ("tmux_graphics_passthrough_probe: SKIP (tmux not installed)");
         Set_Status (77);
         return;
      elsif Script'Length = 0 then
         Ada.Text_IO.Put_Line
           ("tmux_graphics_passthrough_probe: SKIP (script not installed)");
         Set_Status (77);
         return;
      elsif Root'Length = 0 or else Self'Length = 0 then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "tmux_graphics_passthrough_probe: FAIL "
            & "(repository or executable path not found)");
         Set_Status (1);
         return;
      end if;

      declare
         Process : constant String := Ada.Strings.Fixed.Trim
           (Integer'Image
              (GNAT.OS_Lib.Pid_To_Integer (GNAT.OS_Lib.Current_Process_Id)),
            Ada.Strings.Both);
         Socket_Name : constant String :=
           "terminal-graphics-validation-" & Process;
         Work : constant String :=
           Terminal_Tools.Create_Work_Directory ("terminal-tmux-probe");
         Server_Started : Boolean := False;

         procedure Cleanup is
            Ignored : Integer;
         begin
            if Server_Started then
               Ignored := Terminal_Tools.Run
                 (Tmux,
                  [Arg ("-L"), Arg (Socket_Name),
                   Arg ("kill-server")],
                  Terminal_Tools.Path (Work, "cleanup.txt"));
               pragma Unreferenced (Ignored);
            end if;
            Terminal_Tools.Remove_Work_Directory (Work);
         end Cleanup;

         procedure Require_Success
           (Args : GNAT.OS_Lib.Argument_List;
            Message : String;
            Output : String := "")
         is
         begin
            if Terminal_Tools.Run (Tmux, Args, Output) /= 0 then
               raise Program_Error with Message;
            end if;
         end Require_Success;
      begin
         if Work'Length = 0 then
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "tmux_graphics_passthrough_probe: FAIL "
               & "(temporary directory unavailable)");
            Set_Status (1);
            return;
         end if;

         declare
            Capture : constant String := Terminal_Tools.Path (Work, "capture.bin");
            Discard : constant String := Terminal_Tools.Path (Work, "output.txt");
            Allow_File : constant String := Terminal_Tools.Path (Work, "allow.txt");
            Environment_File : constant String :=
              Terminal_Tools.Path (Work, "environment.txt");
            Version_File : constant String := Terminal_Tools.Path (Work, "version.txt");
            Attach_Command : constant String :=
              Terminal_Tools.Shell_Quote (Tmux)
              & " -L " & Terminal_Tools.Shell_Quote (Socket_Name)
              & " attach-session -t validation";
            Expected : constant String :=
              ASCII.ESC & "_Gi=31,s=1,v=1,a=q,t=d,f=24;AAAA"
              & ASCII.ESC & "\";
            Expected_Image : constant String :=
              ASCII.ESC
              & "_Gq=2,a=T,i=32,f=32,s=1,v=1,c=1,r=1,C=1;/wAA/w=="
              & ASCII.ESC & "\";
            Render_Probe : constant String := Terminal_Tools.Path
              (Root,
               "terminal_glfw_vulkan_app/tests/bin/external_graphics_stream_probe");
            GUI_Probe : constant String := Terminal_Tools.Path
              (Root, "terminal_glfw_vulkan_app/tests/bin/gui_present_smoke");
            Status : Integer;
         begin
            Require_Success
              ([Arg ("-L"), Arg (Socket_Name), Arg ("-f"), Arg ("/dev/null"),
                Arg ("new-session"), Arg ("-d"), Arg ("-s"), Arg ("validation"),
                Arg (Terminal_Tools.Shell_Quote (Self) & " --payload")],
               "could not create dedicated tmux server",
               Discard);
            Server_Started := True;
            Require_Success
              ([Arg ("-L"), Arg (Socket_Name), Arg ("set-option"), Arg ("-g"),
                Arg ("allow-passthrough"), Arg ("on")],
               "could not enable allow-passthrough", Discard);
            Require_Success
              ([Arg ("-L"), Arg (Socket_Name), Arg ("set-option"), Arg ("-ga"),
                Arg ("update-environment"), Arg ("TERM")],
               "could not add TERM to update-environment", Discard);
            Require_Success
              ([Arg ("-L"), Arg (Socket_Name), Arg ("set-option"), Arg ("-ga"),
                Arg ("update-environment"), Arg ("TERM_PROGRAM")],
               "could not add TERM_PROGRAM to update-environment", Discard);

            Require_Success
              ([Arg ("-L"), Arg (Socket_Name), Arg ("show-options"), Arg ("-gv"),
                Arg ("allow-passthrough")],
               "could not inspect allow-passthrough", Allow_File);
            if Terminal_Tools.Read_First_Line (Allow_File) /= "on" then
               raise Program_Error with "allow-passthrough is not on";
            end if;
            Require_Success
              ([Arg ("-L"), Arg (Socket_Name), Arg ("show-options"), Arg ("-gv"),
                Arg ("update-environment")],
               "could not inspect update-environment", Environment_File);
            if not Terminal_Tools.File_Has_Line (Environment_File, "TERM") then
               raise Program_Error with "TERM not updated";
            elsif not Terminal_Tools.File_Has_Line
              (Environment_File, "TERM_PROGRAM")
            then
               raise Program_Error with "TERM_PROGRAM not updated";
            end if;

            Ada.Environment_Variables.Set ("TERM", "xterm-256color");
            Status := Terminal_Tools.Run
              (Script,
               [Arg ("-q"), Arg ("-e"), Arg ("-c"), Arg (Attach_Command),
                Arg (Capture)],
               Discard);
            if Status /= 0 then
               raise Program_Error with "tmux attachment capture failed";
            elsif not Terminal_Tools.File_Contains (Capture, Expected) then
               raise Program_Error with "Kitty APC was not passed through";
            elsif not Terminal_Tools.File_Contains (Capture, Expected_Image) then
               raise Program_Error with "Kitty image was not passed through";
            end if;

            if Ada.Directories.Exists (Render_Probe)
              and then Terminal_Tools.Run
                (Render_Probe,
                 [Arg (Capture), Arg ("--allow-unrelated")]) /= 0
            then
               raise Program_Error with "captured stream did not render";
            end if;

            if Ada.Command_Line.Argument_Count = 1 then
               if not Ada.Directories.Exists (GUI_Probe) then
                  Cleanup;
                  Ada.Text_IO.Put_Line
                    ("tmux_graphics_passthrough_probe: SKIP "
                     & "(build tests/app_tests.gpr first)");
                  Set_Status (77);
                  return;
               elsif Terminal_Tools.Run
                 (GUI_Probe, [1 => Arg (Capture)]) /= 0
               then
                  raise Program_Error with
                    "captured stream did not reach Vulkan presentation";
               end if;
            end if;

            Status := Terminal_Tools.Run
              (Tmux, [1 => Arg ("-V")], Version_File);
            if Status /= 0 then
               raise Program_Error with "could not query tmux version";
            end if;
            Ada.Text_IO.Put_Line
              ("tmux_graphics_passthrough_probe: PASS ("
               & Terminal_Tools.Read_First_Line (Version_File) & ")");
            Cleanup;
         exception
            when Error : others =>
               Cleanup;
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error,
                  "tmux_graphics_passthrough_probe: FAIL ("
                  & Ada.Exceptions.Exception_Message (Error) & ")");
               Set_Status (1);
         end;
      end;
   end;
end Tmux_Graphics_Passthrough_Probe;

with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with AUnit.Assertions;

with Terminal.App.Config;
with Test_Support;

procedure Config_File_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Config.Config_Load_Status;
   use type Terminal.App.Config.Line_Status;

   C : Terminal.App.Config.Config;
   Fixture : Test_Support.Temporary_File;
   File : Ada.Text_IO.File_Type;
begin
   Test_Support.Reserve (Fixture, "ada-terminal-config-smoke.conf");
   declare
      Path : constant String := Test_Support.Path (Fixture);
   begin
      Terminal.App.Config.Load_File
        (C, Path & ".missing", Missing_Is_Error => True);
      Assert
        (C.Load_Status = Terminal.App.Config.Config_Not_Found,
         "missing explicit config is reported");

      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line (File, "window-width = 1111");
      Ada.Text_IO.Put_Line (File, "unknown-setting = value");
      Ada.Text_IO.Put_Line (File, "window-height = 777");
      Ada.Text_IO.Close (File);
      Terminal.App.Config.Load_File (C, Path);
      Assert
        (C.Load_Status = Terminal.App.Config.Config_Invalid
         and then C.Invalid_Line = 2
         and then C.Invalid_Line_Status = Terminal.App.Config.Unknown_Key,
         "config loader reports the first invalid line");
      Assert
        (C.Window_Width = 1_111 and then C.Window_Height = 777,
         "config loader continues after a rejected line");
      Assert
        (Ada.Strings.Fixed.Index
           (Terminal.App.Config.Status_Label (C), "config line 2") > 0,
         "config status label reports the rejected line");
      C.Invalid_Line := Natural'Last;
      Assert
        (Terminal.App.Config.Status_Label (C)'Length <=
           Terminal.App.Config.Max_Status_Label_Length,
         "config load diagnostics remain bounded");
      Ada.Directories.Delete_File (Path);
   end;
exception
   when others =>
      if Ada.Text_IO.Is_Open (File) then
         Ada.Text_IO.Close (File);
      end if;
      raise;
end Config_File_Smoke;

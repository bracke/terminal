with Ada.Directories;
with Ada.Exceptions;
with Ada.Text_IO;
with AUnit.Assertions;
with Terminal.App.Crash_Reports;
with Test_Support;

procedure Crash_Reports_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Crash_Reports.Report_Status;
   Fixture : Test_Support.Temporary_File;
   Status : Terminal.App.Crash_Reports.Report_Status;
begin
   Test_Support.Reserve (Fixture, "bracke-terminal-crash-report.txt");
   begin
      raise Constraint_Error with "crash-report-test-marker";
   exception
      when Error : others =>
         Terminal.App.Crash_Reports.Write
           (Test_Support.Path (Fixture), Error, Status);
   end;
   Assert (Status = Terminal.App.Crash_Reports.Written, "crash report status");
   declare
      File : Ada.Text_IO.File_Type;
      Found_Name, Found_Message, Found_Version : Boolean := False;
   begin
      Ada.Text_IO.Open
        (File, Ada.Text_IO.In_File, Test_Support.Path (Fixture));
      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (File);
         begin
            Found_Name := Found_Name or else Line = "exception=CONSTRAINT_ERROR";
            Found_Message := Found_Message
              or else Line = "message=crash-report-test-marker";
            Found_Version := Found_Version or else Line = "version=0.1.0-dev";
         end;
      end loop;
      Ada.Text_IO.Close (File);
      Assert
        (Found_Name and then Found_Message and then Found_Version,
         "crash report contains bounded diagnostic identity");
   end;
   Ada.Directories.Delete_File (Test_Support.Path (Fixture));
exception
   when others =>
      if Ada.Directories.Exists (Test_Support.Path (Fixture)) then
         Ada.Directories.Delete_File (Test_Support.Path (Fixture));
      end if;
      raise;
end Crash_Reports_Smoke;

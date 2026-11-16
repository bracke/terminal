with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.IO_Exceptions;
with Ada.Text_IO;
with Terminal.App.Platform_Files;
with Terminal.Common.Identity;

package body Terminal.App.Crash_Reports is
   function Default_Path return String is
      XDG_State : constant String :=
        Ada.Environment_Variables.Value ("XDG_STATE_HOME", "");
      Home : constant String := Ada.Environment_Variables.Value ("HOME", "");
   begin
      if XDG_State /= "" then
         return XDG_State & "/bracke-terminal/last-crash.txt";
      elsif Home /= "" then
         return Home & "/.local/state/bracke-terminal/last-crash.txt";
      else
         return ".bracke-terminal-last-crash.txt";
      end if;
   end Default_Path;

   procedure Write
     (Path   : String;
      Error  : Ada.Exceptions.Exception_Occurrence;
      Status : out Report_Status)
   is
      File : Ada.Text_IO.File_Type;
      Temp : constant String := Path & ".tmp";
      Parent : constant String :=
        (if Path = "" then "" else Ada.Directories.Containing_Directory (Path));
   begin
      if Path = "" then
         Status := Invalid_Path;
         return;
      end if;
      if Parent /= "" and then not Ada.Directories.Exists (Parent) then
         Ada.Directories.Create_Path (Parent);
      end if;
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Temp);
      Ada.Text_IO.Put_Line
        (File, "program=" & Terminal.Common.Identity.Program_Name);
      Ada.Text_IO.Put_Line
        (File, "version=" & Terminal.Common.Identity.Program_Version);
      Ada.Text_IO.Put_Line
        (File, "time=" & Ada.Calendar.Formatting.Image (Ada.Calendar.Clock));
      Ada.Text_IO.Put_Line
        (File, "exception=" & Ada.Exceptions.Exception_Name (Error));
      Ada.Text_IO.Put_Line
        (File, "message=" & Ada.Exceptions.Exception_Message (Error));
      Ada.Text_IO.Put_Line (File, "information-begin");
      Ada.Text_IO.Put_Line (File, Ada.Exceptions.Exception_Information (Error));
      Ada.Text_IO.Put_Line (File, "information-end");
      Ada.Text_IO.Close (File);
      if Terminal.App.Platform_Files.Replace_File (Temp, Path) then
         Status := Written;
      else
         if Ada.Directories.Exists (Temp) then Ada.Directories.Delete_File (Temp); end if;
         Status := IO_Error;
      end if;
   exception
      when Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error
         | Ada.IO_Exceptions.Device_Error | Ada.IO_Exceptions.Status_Error
         | Ada.IO_Exceptions.Mode_Error | Ada.IO_Exceptions.Layout_Error =>
         if Ada.Text_IO.Is_Open (File) then Ada.Text_IO.Close (File); end if;
         if Ada.Directories.Exists (Temp) then Ada.Directories.Delete_File (Temp); end if;
         Status := IO_Error;
   end Write;
end Terminal.App.Crash_Reports;

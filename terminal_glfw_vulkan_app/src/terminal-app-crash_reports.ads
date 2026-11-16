with Ada.Exceptions;

package Terminal.App.Crash_Reports is
   type Report_Status is (Written, Invalid_Path, IO_Error);

   function Default_Path return String;
   procedure Write
     (Path   : String;
      Error  : Ada.Exceptions.Exception_Occurrence;
      Status : out Report_Status);
end Terminal.App.Crash_Reports;

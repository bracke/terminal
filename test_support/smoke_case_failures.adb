with Ada.Text_IO;

package body Smoke_Case_Failures is
   procedure Reraise
     (Name  : String;
      Error : Ada.Exceptions.Exception_Occurrence) is
   begin
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "FAILED CASE: " & Name & ": "
         & Ada.Exceptions.Exception_Information (Error));
      Ada.Exceptions.Reraise_Occurrence (Error);
   end Reraise;
end Smoke_Case_Failures;

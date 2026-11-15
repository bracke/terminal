with Ada.Exceptions;

package Smoke_Case_Failures is
   procedure Reraise
     (Name  : String;
      Error : Ada.Exceptions.Exception_Occurrence)
   with No_Return;
end Smoke_Case_Failures;

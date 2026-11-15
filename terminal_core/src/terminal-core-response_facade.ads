private package Terminal.Core.Response_Facade is
   procedure Begin_Transaction (T : in out Terminal);
   procedure End_Transaction (T : in out Terminal);
   procedure Abort_Transaction (T : in out Terminal);
   procedure Append_Character
     (T  : in out Terminal;
      Ch : Standard.Character);
   procedure Append_String
     (T    : in out Terminal;
      Text : String);
   procedure Append_Natural
     (T     : in out Terminal;
      Value : Natural);
   procedure Append_Graphics_ID
     (T     : in out Terminal;
      Value : Graphics_ID);
end Terminal.Core.Response_Facade;

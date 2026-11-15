private package Terminal.Core.Response_Writer is
   procedure Begin_Transaction (State : in out Response_Runtime_State);
   procedure End_Transaction
     (State           : in out Response_Runtime_State;
      Parser_Overflow : in out Natural);
   procedure Abort_Transaction (State : in out Response_Runtime_State);
   procedure Append_Character
     (State           : in out Response_Runtime_State;
      Parser_Overflow : in out Natural;
      Ch              : Standard.Character);
   procedure Append_String
     (State           : in out Response_Runtime_State;
      Parser_Overflow : in out Natural;
      Text            : String);
   procedure Append_Natural
     (State           : in out Response_Runtime_State;
      Parser_Overflow : in out Natural;
      Value           : Natural);
   procedure Append_Graphics_ID
     (State           : in out Response_Runtime_State;
      Parser_Overflow : in out Natural;
      Value           : Graphics_ID);
end Terminal.Core.Response_Writer;

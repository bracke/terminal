with Terminal.Core.Response_Writer;

package body Terminal.Core.Response_Facade is
   procedure Begin_Transaction (T : in out Terminal) is
   begin
      Response_Writer.Begin_Transaction (T.Responses);
   end Begin_Transaction;

   procedure End_Transaction (T : in out Terminal) is
   begin
      Response_Writer.End_Transaction
        (T.Responses, T.Diag.Parser_Overflow);
   end End_Transaction;

   procedure Abort_Transaction (T : in out Terminal) is
   begin
      Response_Writer.Abort_Transaction (T.Responses);
   end Abort_Transaction;

   procedure Append_Character
     (T  : in out Terminal;
      Ch : Standard.Character) is
   begin
      Response_Writer.Append_Character
        (T.Responses, T.Diag.Parser_Overflow, Ch);
   end Append_Character;

   procedure Append_String
     (T    : in out Terminal;
      Text : String) is
   begin
      Response_Writer.Append_String
        (T.Responses, T.Diag.Parser_Overflow, Text);
   end Append_String;

   procedure Append_Natural
     (T     : in out Terminal;
      Value : Natural) is
   begin
      Response_Writer.Append_Natural
        (T.Responses, T.Diag.Parser_Overflow, Value);
   end Append_Natural;

   procedure Append_Graphics_ID
     (T     : in out Terminal;
      Value : Graphics_ID) is
   begin
      Response_Writer.Append_Graphics_ID
        (T.Responses, T.Diag.Parser_Overflow, Value);
   end Append_Graphics_ID;
end Terminal.Core.Response_Facade;

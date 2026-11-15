with Terminal.Common.Counters;

package body Terminal.Core.Response_Writer is
   procedure Append_Byte
     (State           : in out Response_Runtime_State;
      Parser_Overflow : in out Natural;
      B               : Common.Bytes.Byte) is
   begin
      if State.Transaction_Overflowed then
         return;
      elsif State.Length < Max_Response_Length then
         State.Length := State.Length + 1;
         State.Bytes (State.Length) := B;
      elsif State.Transaction_Active then
         State.Transaction_Overflowed := True;
      else
         Common.Counters.Increment_Saturating (Parser_Overflow);
      end if;
   end Append_Byte;

   procedure Begin_Transaction (State : in out Response_Runtime_State) is
   begin
      if State.Transaction_Active then
         raise Program_Error with "response transaction is already active";
      end if;
      State.Transaction_Start := State.Length;
      State.Transaction_Active := True;
      State.Transaction_Overflowed := False;
   end Begin_Transaction;

   procedure End_Transaction
     (State           : in out Response_Runtime_State;
      Parser_Overflow : in out Natural) is
   begin
      if not State.Transaction_Active then
         raise Program_Error with "response transaction is not active";
      end if;
      if State.Transaction_Overflowed then
         State.Length := State.Transaction_Start;
         Common.Counters.Increment_Saturating (Parser_Overflow);
      end if;
      State.Transaction_Start := 0;
      State.Transaction_Active := False;
      State.Transaction_Overflowed := False;
   end End_Transaction;

   procedure Abort_Transaction (State : in out Response_Runtime_State) is
   begin
      if State.Transaction_Active then
         State.Length := State.Transaction_Start;
      end if;
      State.Transaction_Start := 0;
      State.Transaction_Active := False;
      State.Transaction_Overflowed := False;
   end Abort_Transaction;

   procedure Append_Character
     (State           : in out Response_Runtime_State;
      Parser_Overflow : in out Natural;
      Ch              : Standard.Character) is
   begin
      Append_Byte
        (State,
         Parser_Overflow,
         Common.Bytes.Byte (Standard.Character'Pos (Ch)));
   end Append_Character;

   procedure Append_String
     (State           : in out Response_Runtime_State;
      Parser_Overflow : in out Natural;
      Text            : String) is
   begin
      for Ch of Text loop
         Append_Character (State, Parser_Overflow, Ch);
      end loop;
   end Append_String;

   procedure Append_Natural
     (State           : in out Response_Runtime_State;
      Parser_Overflow : in out Natural;
      Value           : Natural) is
      Text : constant String := Natural'Image (Value);
   begin
      for Ch of Text loop
         if Ch /= ' ' then
            Append_Character (State, Parser_Overflow, Ch);
         end if;
      end loop;
   end Append_Natural;

   procedure Append_Graphics_ID
     (State           : in out Response_Runtime_State;
      Parser_Overflow : in out Natural;
      Value           : Graphics_ID) is
      Text : constant String := Graphics_ID'Image (Value);
   begin
      for Ch of Text loop
         if Ch /= ' ' then
            Append_Character (State, Parser_Overflow, Ch);
         end if;
      end loop;
   end Append_Graphics_ID;
end Terminal.Core.Response_Writer;

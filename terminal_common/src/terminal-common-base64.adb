package body Terminal.Common.Base64 is
   use type Terminal.Common.Bytes.Byte;

   function Value (Ch : Character) return Integer is
   begin
      case Ch is
         when 'A' .. 'Z' =>
            return Character'Pos (Ch) - Character'Pos ('A');
         when 'a' .. 'z' =>
            return 26 + Character'Pos (Ch) - Character'Pos ('a');
         when '0' .. '9' =>
            return 52 + Character'Pos (Ch) - Character'Pos ('0');
         when '+' =>
            return 62;
         when '/' =>
            return 63;
         when others =>
            return -1;
      end case;
   end Value;

   function Value (Ch : Terminal.Common.Bytes.Byte) return Integer is
   begin
      if Ch > Terminal.Common.Bytes.Byte (Character'Pos (Character'Last)) then
         return -1;
      end if;
      return Value (Character'Val (Ch));
   end Value;

   function Is_Whitespace (Ch : Character) return Boolean is
     (Ch in ' ' | ASCII.CR | ASCII.LF);

   function Is_Whitespace
     (Ch : Terminal.Common.Bytes.Byte) return Boolean
   is
     (Ch = Character'Pos (' ')
      or else Ch = Character'Pos (ASCII.CR)
      or else Ch = Character'Pos (ASCII.LF));

   function Is_Valid_Quantum
     (Values         : Quantum;
      Count          : Natural;
      Padding        : Natural;
      Allow_Unpadded : Boolean) return Boolean
   is
   begin
      if Count not in 2 .. 4 or else Padding > 2 then
         return False;
      elsif Padding > 0 and then Count /= 4 then
         return False;
      elsif Padding = 2 then
         return Values (2) mod 16 = 0;
      elsif Padding = 1 then
         return Values (3) mod 4 = 0;
      elsif Count = 2 then
         return Allow_Unpadded and then Values (2) mod 16 = 0;
      elsif Count = 3 then
         return Allow_Unpadded and then Values (3) mod 4 = 0;
      else
         return Count = 4;
      end if;
   end Is_Valid_Quantum;

   function Decoded_Length
     (Count   : Natural;
      Padding : Natural) return Natural
   is
   begin
      if Padding > Count or else Count < 2 then
         return 0;
      end if;
      return (Count * 6) / 8 - Padding;
   end Decoded_Length;

   function Decode_Byte
     (Values : Quantum;
      Index  : Positive) return Terminal.Common.Bytes.Byte
   is
   begin
      case Index is
         when 1 =>
            return Terminal.Common.Bytes.Byte
              (Values (1) * 4 + Values (2) / 16);
         when 2 =>
            return Terminal.Common.Bytes.Byte
              ((Values (2) mod 16) * 16 + Values (3) / 4);
         when 3 =>
            return Terminal.Common.Bytes.Byte
              ((Values (3) mod 4) * 64 + Values (4));
         when others =>
            raise Constraint_Error with "invalid Base64 byte index";
      end case;
   end Decode_Byte;

   procedure Reset
     (State          : out Decoder_State;
      Allow_Unpadded : Boolean;
      Allow_Whitespace : Boolean) is
   begin
      State :=
        (Allow_Unpadded   => Allow_Unpadded,
         Allow_Whitespace => Allow_Whitespace,
         others           => <>);
   end Reset;

   procedure Emit
     (State  : in out Decoder_State;
      Output : out Decoded_Quantum;
      Length : out Natural;
      Status : out Decoder_Status)
   is
   begin
      Output := (others => 0);
      Length := 0;
      if not Is_Valid_Quantum
        (State.Values, State.Count, State.Padding, State.Allow_Unpadded)
      then
         State.Invalid := True;
         Status := Invalid_Data;
         return;
      end if;
      Length := Decoded_Length (State.Count, State.Padding);
      for I in 1 .. Length loop
         Output (I) := Decode_Byte (State.Values, I);
      end loop;
      State.Finished := State.Padding > 0;
      State.Values := (others => 0);
      State.Count := 0;
      State.Padding := 0;
      Status := Produced;
   end Emit;

   procedure Push
     (State  : in out Decoder_State;
      Ch     : Character;
      Output : out Decoded_Quantum;
      Length : out Natural;
      Status : out Decoder_Status)
   is
      V : constant Integer := Value (Ch);
   begin
      Output := (others => 0);
      Length := 0;
      Status := Accepted;
      if State.Invalid then
         Status := Invalid_Data;
      elsif Is_Whitespace (Ch) then
         if not State.Allow_Whitespace then
            State.Invalid := True;
            Status := Invalid_Data;
         end if;
      elsif State.Finished then
         State.Invalid := True;
         Status := Invalid_Data;
      elsif Ch = '=' then
         if State.Count = 4 or else State.Padding = 2 then
            State.Invalid := True;
            Status := Invalid_Data;
            return;
         end if;
         State.Count := State.Count + 1;
         State.Padding := State.Padding + 1;
         State.Values (State.Count) := 0;
         if State.Count = 4 then
            Emit (State, Output, Length, Status);
         end if;
      elsif V < 0 or else State.Padding > 0 or else State.Count = 4 then
         State.Invalid := True;
         Status := Invalid_Data;
      else
         State.Count := State.Count + 1;
         State.Values (State.Count) := Sextet (V);
         if State.Count = 4 then
            Emit (State, Output, Length, Status);
         end if;
      end if;
   end Push;

   procedure Push
     (State  : in out Decoder_State;
      Ch     : Terminal.Common.Bytes.Byte;
      Output : out Decoded_Quantum;
      Length : out Natural;
      Status : out Decoder_Status) is
   begin
      if Ch > Terminal.Common.Bytes.Byte (Character'Pos (Character'Last)) then
         Output := (others => 0);
         Length := 0;
         State.Invalid := True;
         Status := Invalid_Data;
      else
         Push (State, Character'Val (Ch), Output, Length, Status);
      end if;
   end Push;

   procedure Finish
     (State  : in out Decoder_State;
      Output : out Decoded_Quantum;
      Length : out Natural;
      Status : out Decoder_Status) is
   begin
      Output := (others => 0);
      Length := 0;
      if State.Invalid then
         Status := Invalid_Data;
      elsif State.Count = 0 then
         Status := Accepted;
      elsif State.Finished then
         State.Invalid := True;
         Status := Invalid_Data;
      else
         Emit (State, Output, Length, Status);
         if Status = Produced then
            State.Finished := True;
         end if;
      end if;
   end Finish;

   function Is_Complete (State : Decoder_State) return Boolean is
     (State.Finished and then not State.Invalid);
end Terminal.Common.Base64;

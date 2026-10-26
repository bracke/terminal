with Terminal.Common.Bytes;

package Terminal.Common.Base64 is
   function Is_Whitespace (Ch : Character) return Boolean;
   function Is_Whitespace (Ch : Terminal.Common.Bytes.Byte) return Boolean;

   type Decoder_Status is (Accepted, Produced, Invalid_Data);
   type Decoder_State is private;
   subtype Decoded_Quantum is Terminal.Common.Bytes.Byte_Array (1 .. 3);

   procedure Reset
     (State          : out Decoder_State;
      Allow_Unpadded : Boolean;
      Allow_Whitespace : Boolean);
   procedure Push
     (State  : in out Decoder_State;
      Ch     : Character;
      Output : out Decoded_Quantum;
      Length : out Natural;
      Status : out Decoder_Status);
   procedure Push
     (State  : in out Decoder_State;
      Ch     : Terminal.Common.Bytes.Byte;
      Output : out Decoded_Quantum;
      Length : out Natural;
      Status : out Decoder_Status);
   procedure Finish
     (State  : in out Decoder_State;
      Output : out Decoded_Quantum;
      Length : out Natural;
      Status : out Decoder_Status);
   function Is_Complete (State : Decoder_State) return Boolean;
private
   subtype Sextet is Natural range 0 .. 63;
   type Quantum is array (Positive range 1 .. 4) of Sextet;

   function Value (Ch : Character) return Integer;
   function Value (Ch : Terminal.Common.Bytes.Byte) return Integer;
   function Is_Valid_Quantum
     (Values         : Quantum;
      Count          : Natural;
      Padding        : Natural;
      Allow_Unpadded : Boolean) return Boolean;
   function Decoded_Length
     (Count   : Natural;
      Padding : Natural) return Natural;
   function Decode_Byte
     (Values : Quantum;
      Index  : Positive) return Terminal.Common.Bytes.Byte;

   type Decoder_State is record
      Values           : Quantum := (others => 0);
      Count            : Natural range 0 .. 4 := 0;
      Padding          : Natural range 0 .. 2 := 0;
      Allow_Unpadded   : Boolean := False;
      Allow_Whitespace : Boolean := False;
      Finished         : Boolean := False;
      Invalid          : Boolean := False;
   end record;
end Terminal.Common.Base64;

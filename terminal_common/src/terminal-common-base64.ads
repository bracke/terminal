with Terminal.Common.Bytes;

package Terminal.Common.Base64 is
   subtype Sextet is Natural range 0 .. 63;
   type Quantum is array (Positive range 1 .. 4) of Sextet;

   function Value (Ch : Character) return Integer;
   function Value (Ch : Terminal.Common.Bytes.Byte) return Integer;
   function Is_Whitespace (Ch : Character) return Boolean;
   function Is_Whitespace (Ch : Terminal.Common.Bytes.Byte) return Boolean;

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
end Terminal.Common.Base64;

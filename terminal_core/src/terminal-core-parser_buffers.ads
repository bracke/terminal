private package Terminal.Core.Parser_Buffers is
   function OSC_Slice
     (T : Terminal; First : Positive; Last : Natural) return String;
   function Ignored_String_Slice
     (T : Terminal; First : Positive; Last : Natural) return String;

   procedure Append_OSC_Byte
     (T          : in out Terminal;
      Ch         : Standard.Character;
      Overflowed : in out Boolean);

   procedure Append_Ignored_String_Byte
     (T          : in out Terminal;
      Ch         : Standard.Character;
      Overflowed : in out Boolean);

   procedure Start_Ignored_String
     (T      : in out Terminal;
      Is_DCS : Boolean;
      Is_APC : Boolean := False);
end Terminal.Core.Parser_Buffers;

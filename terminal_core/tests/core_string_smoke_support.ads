with Terminal.Common.Bytes;

package Core_String_Smoke_Support is
   function To_Bytes (Text : String) return Terminal.Common.Bytes.Byte_Array;
   function Repeat_Char (Ch : Character; Count : Natural) return String;
   function Wrap_Tmux (Text : String) return String;
   function DCS_Overflow_Fixture return Terminal.Common.Bytes.Byte_Array;
   function Long_Title_Fixture return Terminal.Common.Bytes.Byte_Array;
end Core_String_Smoke_Support;

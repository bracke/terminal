package Terminal.Common.UTF8 is
   type UTF16_Unit is mod 2 ** 16
     with Size => 16, Convention => C;
   type UTF16_Array is array (Natural range <>) of aliased UTF16_Unit
     with Convention => C;

   --  Decode Value into UTF-16 and append a zero terminator. Length excludes
   --  the terminator. Valid is False for malformed UTF-8 or a short target;
   --  callers must ignore Result in that case.
   procedure Decode_UTF16
     (Value  : String;
      Result : out UTF16_Array;
      Length : out Natural;
      Valid  : out Boolean);
end Terminal.Common.UTF8;

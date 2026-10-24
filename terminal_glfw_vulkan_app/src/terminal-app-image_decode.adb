package body Terminal.App.Image_Decode is
   function Suffix (Value : Status) return String is
   begin
      case Value is
         when Decode_Not_Attempted | Decode_Ok =>
            return "";
         when Decode_Invalid_Byte =>
            return " invalid-byte";
         when Decode_Trailing_Data =>
            return " trailing-data";
         when Decode_Preview_Truncated =>
            return " truncated";
         when Decode_Invalid_Data =>
            return " invalid-data";
         when Decode_Too_Large =>
            return " too-large";
         when Decode_Allocation_Failed =>
            return " allocation-failed";
         when Decode_Unsupported_Format =>
            return " unsupported-format";
      end case;
   end Suffix;
end Terminal.App.Image_Decode;

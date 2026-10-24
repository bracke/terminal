package Terminal.App.Image_Decode is
   type Status is
     (Decode_Not_Attempted,
      Decode_Ok,
      Decode_Invalid_Byte,
      Decode_Trailing_Data,
      Decode_Preview_Truncated,
      Decode_Invalid_Data,
      Decode_Too_Large,
      Decode_Allocation_Failed,
      Decode_Unsupported_Format);

   function Suffix (Value : Status) return String;
end Terminal.App.Image_Decode;

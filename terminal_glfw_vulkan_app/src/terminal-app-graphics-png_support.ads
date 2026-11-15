with Terminal.Common.Bytes;

private package Terminal.App.Graphics.PNG_Support is
   function U32_BE
     (Bytes : Terminal.Common.Bytes.Byte_Array;
      First : Positive) return Natural;
   function Paeth (A, B, C : Natural) return Natural;
   function Bit_Depth_Allowed
     (Color_Type, Bit_Depth : Natural) return Boolean;
   function Bits_Per_Pixel
     (Color_Type, Bit_Depth : Natural) return Natural;
   function Filter_BPP
     (Color_Type, Bit_Depth : Natural) return Natural;
   function Row_Bytes
     (Width, Color_Type, Bit_Depth : Natural) return Natural;
   function Pass_Size
     (Full_Size, Start, Step : Natural) return Natural;
   function Inflated_Length
     (Width, Height, Color_Type, Bit_Depth, Interlace : Natural)
      return Natural;
   function Packed_Sample
     (Row          : Terminal.Common.Bytes.Byte_Array;
      Bit_Depth    : Natural;
      Sample_Index : Natural) return Natural;
   function Sample_16
     (Row : Terminal.Common.Bytes.Byte_Array;
      First : Positive) return Natural;
   function Scale_Sample
     (Value, Bit_Depth : Natural) return Natural;
end Terminal.App.Graphics.PNG_Support;

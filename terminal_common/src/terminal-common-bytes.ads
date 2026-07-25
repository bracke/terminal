package Terminal.Common.Bytes is
   pragma Pure;

   type Byte is mod 2 ** 8;
   for Byte'Size use 8;

   type Byte_Array is array (Positive range <>) of Byte;
   subtype Byte_Count is Natural;
end Terminal.Common.Bytes;


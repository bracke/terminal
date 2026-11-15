with System;
with Terminal.App.Borrowed_Bytes;

private package Terminal.App.Borrowed_Stream is
   generic
      type External_Byte is mod <>;
      type External_Byte_Array is array (Positive range <>) of External_Byte;
      type External_Count is range <>;
      type External_Offset is range <>;
      type External_Result is private;
      with function Success
        (Count        : External_Count;
         End_Of_Input : Boolean) return External_Result;
   package Adapter is
      pragma Compile_Time_Error
        (External_Byte'Modulus < 256,
         "borrowed stream byte type must represent every octet");
      pragma Compile_Time_Error
        (External_Count'First > 0
         or else External_Count'Base'Size < Natural'Size
         or else External_Count'Last <
           External_Count'Base (Natural'Last),
         "borrowed stream count type must contain Natural");
      pragma Compile_Time_Error
        (External_Offset'First > 0
         or else External_Offset'Base'Size < Natural'Size
         or else External_Offset'Last <
           External_Offset'Base (Natural'Last),
         "borrowed stream offset type must contain Natural");

      procedure Open
        (Data    : in out Terminal.App.Borrowed_Bytes.Cursor;
         Storage : System.Address;
         Length  : Natural);

      function Read
        (Data   : in out Terminal.App.Borrowed_Bytes.Cursor;
         Buffer : out External_Byte_Array) return External_Result;

      function Offset
        (Data : Terminal.App.Borrowed_Bytes.Cursor) return External_Offset;

      function Skip
        (Data  : in out Terminal.App.Borrowed_Bytes.Cursor;
         Count : External_Count) return External_Result;
   end Adapter;
end Terminal.App.Borrowed_Stream;

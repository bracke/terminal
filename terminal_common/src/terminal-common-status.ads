with Terminal.Common.Bytes;

package Terminal.Common.Status is
   pragma Pure;

   type Operation_Status is (Ok, Invalid_Argument, Overflow, Failed);

   function Preview_Bytes_Label
     (Bytes  : Terminal.Common.Bytes.Byte_Array;
      Length : Natural;
      Limit  : Natural := 4) return String;
end Terminal.Common.Status;

private package Terminal.Core.Parser_Execution is
   procedure Execute_CSI
     (T : in out Terminal;
      Final : Standard.Character);

   procedure Decode_Printable
     (T : in out Terminal;
      B : Common.Bytes.Byte);

   procedure Dispatch_Parser_Byte
     (T                  : in out Terminal;
      B                  : Common.Bytes.Byte;
      Overflowed         : in out Boolean;
      Recovered          : in out Boolean;
      Passthrough        : in out Core_Byte_Array_Access;
      Passthrough_Length : in out Natural;
      Passthrough_Budget : in out Natural);

   procedure Process_Feed_Byte
     (T                  : in out Terminal;
      B                  : Common.Bytes.Byte;
      Overflowed         : in out Boolean;
      Recovered          : in out Boolean;
      Passthrough        : in out Core_Byte_Array_Access;
      Passthrough_Length : in out Natural;
      Passthrough_Budget : in out Natural);
end Terminal.Core.Parser_Execution;

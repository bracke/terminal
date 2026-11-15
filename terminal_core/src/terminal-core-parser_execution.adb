with Terminal.Common.Counters;
with Terminal.Core.Graphics_Runtime;
with Terminal.Core.Parser;
with Terminal.Core.Parser_Buffers;
with Terminal.Core.Parser_Primitives;
with Terminal.Core.Response_Queries;
with Terminal.Core.Scrollback_Storage;
with Terminal.Core.Screen_Rows;

package body Terminal.Core.Parser_Execution is
   use Common.Counters;
   use Parser_Buffers;
   use Parser_Primitives;
   use Response_Queries;
   use Screen_Rows;

   procedure Execute_CSI
     (T : in out Terminal;
      Final : Standard.Character)
   is separate;

   procedure Decode_Printable
     (T : in out Terminal;
      B : Common.Bytes.Byte)
   is separate;

   procedure Dispatch_Parser_Byte
     (T                  : in out Terminal;
      B                  : Common.Bytes.Byte;
      Overflowed         : in out Boolean;
      Recovered          : in out Boolean;
      Passthrough        : in out Core_Byte_Array_Access;
      Passthrough_Length : in out Natural;
      Passthrough_Budget : in out Natural)
   is separate;

   procedure Process_Feed_Byte
     (T                  : in out Terminal;
      B                  : Common.Bytes.Byte;
      Overflowed         : in out Boolean;
      Recovered          : in out Boolean;
      Passthrough        : in out Core_Byte_Array_Access;
      Passthrough_Length : in out Natural;
      Passthrough_Budget : in out Natural)
   is separate;
end Terminal.Core.Parser_Execution;

with Pictlib;
with Pictlib.Errors;
with Pictlib.Results;
with Pictlib.Streams;
with System;
with Terminal.App.Borrowed_Bytes;
with Terminal.App.Image_Media;

private package Terminal.App.PICT_Adapter is
   type Source is limited new Pictlib.Streams.Source with private;

   procedure Open
     (Object  : in out Source;
      Storage : System.Address;
      Length  : Natural);

   procedure Set_Diagnostic
     (Target  : in out Terminal.App.Image_Media.Decode_Diagnostic;
      Failure : Pictlib.Results.Result);

   procedure Set_Warning
     (Target  : in out Terminal.App.Image_Media.Decode_Diagnostic;
      Warning : Pictlib.Errors.Warning);

private
   type Source is limited new Pictlib.Streams.Source with record
      Data : Terminal.App.Borrowed_Bytes.Cursor;
   end record;

   overriding function Read
     (Object : in out Source;
      Buffer : out Pictlib.Streams.Byte_Array)
      return Pictlib.Streams.Source_Result;
   overriding function Offset
     (Object : Source) return Pictlib.Source_Offset;
   overriding function Skip
     (Object : in out Source;
      Count  : Pictlib.Byte_Count) return Pictlib.Streams.Source_Result;
end Terminal.App.PICT_Adapter;

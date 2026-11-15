with Giflib;
with Giflib.Errors;
with Giflib.Streams;
with System;
with Terminal.App.Borrowed_Bytes;
with Terminal.App.Image_Media;

private package Terminal.App.GIF_Adapter is
   type Source is limited new Giflib.Streams.Source with private;

   procedure Open
     (Object  : in out Source;
      Storage : System.Address;
      Length  : Natural);

   procedure Set_Diagnostic
     (Target : in out Terminal.App.Image_Media.Decode_Diagnostic;
      Error  : Giflib.Errors.Error);

   procedure Set_Warning
     (Target  : in out Terminal.App.Image_Media.Decode_Diagnostic;
      Warning : Giflib.Errors.Warning);

private
   type Source is limited new Giflib.Streams.Source with record
      Data : Terminal.App.Borrowed_Bytes.Cursor;
   end record;

   overriding function Read
     (Object : in out Source;
      Buffer : out Giflib.Streams.Byte_Array)
      return Giflib.Streams.Source_Result;
   overriding function Offset
     (Object : Source) return Giflib.Source_Offset;
   overriding function Skip
     (Object : in out Source;
      Count  : Giflib.Byte_Count) return Giflib.Streams.Source_Result;
end Terminal.App.GIF_Adapter;

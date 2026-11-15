with Interfaces;
with Terminal.App.Borrowed_Stream;
with Terminal.App.Image_Media_Diagnostics;

package body Terminal.App.GIF_Adapter is
   use type Giflib.Byte_Count;
   use type Giflib.Errors.Error_Code;
   use type Giflib.Errors.Position_State;
   function Success
     (Count        : Giflib.Byte_Count;
      End_Of_Input : Boolean) return Giflib.Streams.Source_Result is
     ((Error        => Giflib.Errors.Make (Giflib.Errors.No_Error),
       Count        => Count,
       End_Of_Input => End_Of_Input));

   package Stream_Bridge is new Terminal.App.Borrowed_Stream.Adapter
     (External_Byte       => Giflib.Byte,
      External_Byte_Array => Giflib.Streams.Byte_Array,
      External_Count      => Giflib.Byte_Count,
      External_Offset     => Giflib.Source_Offset,
      External_Result     => Giflib.Streams.Source_Result,
      Success             => Success);

   function To_Decode_Limit
     (Item : Giflib.Limit_Kind)
      return Terminal.App.Image_Media.Decode_Limit_Kind is
     (case Item is
         when Giflib.No_Limit => Terminal.App.Image_Media.No_Limit,
         when Giflib.Logical_Width_Limit =>
           Terminal.App.Image_Media.Frame_Width_Limit,
         when Giflib.Logical_Height_Limit =>
           Terminal.App.Image_Media.Frame_Height_Limit,
         when Giflib.Canvas_Pixel_Limit =>
           Terminal.App.Image_Media.Canvas_Pixel_Limit,
         when Giflib.Canvas_Byte_Limit =>
           Terminal.App.Image_Media.Canvas_Byte_Limit,
         when Giflib.Frame_Count_Limit =>
           Terminal.App.Image_Media.Frame_Count_Limit,
         when Giflib.Frame_Pixel_Limit =>
           Terminal.App.Image_Media.Frame_Pixel_Limit,
         when Giflib.Total_Decoded_Pixel_Limit =>
           Terminal.App.Image_Media.Total_Decoded_Pixel_Limit,
         when Giflib.Compressed_Byte_Limit =>
           Terminal.App.Image_Media.Compressed_Byte_Limit,
         when Giflib.Extension_Count_Limit =>
           Terminal.App.Image_Media.Extension_Count_Limit,
         when Giflib.Retained_Metadata_Byte_Limit =>
           Terminal.App.Image_Media.Retained_Metadata_Byte_Limit,
         when Giflib.Per_Extension_Byte_Limit =>
           Terminal.App.Image_Media.Per_Extension_Byte_Limit,
         when Giflib.Allocation_Byte_Limit =>
           Terminal.App.Image_Media.Allocation_Byte_Limit,
         when Giflib.Output_Byte_Limit =>
           Terminal.App.Image_Media.Output_Byte_Limit,
         when Giflib.LZW_Work_Limit =>
           Terminal.App.Image_Media.LZW_Work_Limit,
         when Giflib.Quantization_Work_Limit =>
           Terminal.App.Image_Media.Quantization_Work_Limit,
         when Giflib.Optimization_Work_Limit =>
           Terminal.App.Image_Media.Optimization_Work_Limit,
         when Giflib.Warning_Record_Limit =>
           Terminal.App.Image_Media.Warning_Record_Limit,
         when Giflib.Snapshot_Byte_Limit =>
           Terminal.App.Image_Media.Snapshot_Byte_Limit);

   procedure Open
     (Object  : in out Source;
      Storage : System.Address;
      Length  : Natural) is
   begin
      Stream_Bridge.Open (Object.Data, Storage, Length);
   end Open;

   overriding function Read
     (Object : in out Source;
      Buffer : out Giflib.Streams.Byte_Array)
      return Giflib.Streams.Source_Result
   is (Stream_Bridge.Read (Object.Data, Buffer));

   overriding function Offset
     (Object : Source) return Giflib.Source_Offset is
     (Stream_Bridge.Offset (Object.Data));

   overriding function Skip
     (Object : in out Source;
      Count  : Giflib.Byte_Count) return Giflib.Streams.Source_Result
   is (Stream_Bridge.Skip (Object.Data, Count));

   procedure Set_Diagnostic
     (Target : in out Terminal.App.Image_Media.Decode_Diagnostic;
      Error  : Giflib.Errors.Error)
   is
      Name : constant String := Giflib.Errors.Identifier (Error);
   begin
      Terminal.App.Image_Media_Diagnostics.Initialize
        (Target, Error.Code /= Giflib.Errors.No_Error, Name);
      if Error.Context.Source_Position.State =
        Giflib.Errors.Position_Available
      then
         Target.Source_Offset := Interfaces.Unsigned_64
           (Error.Context.Source_Position.Value);
      end if;
      if Error.Context.Destination_Position.State =
        Giflib.Errors.Position_Available
      then
         Target.Destination_Offset := Interfaces.Unsigned_64
           (Error.Context.Destination_Position.Value);
      end if;
      Target.Expected := Interfaces.Unsigned_64 (Error.Context.Expected);
      Target.Actual := Interfaces.Unsigned_64 (Error.Context.Actual);
      Target.Limit := To_Decode_Limit (Error.Context.Limit);
      Target.Has_Underlying_Code := Error.Context.Underlying_Code.Present;
      if Error.Context.Underlying_Code.Present then
         Target.Underlying_Code := Error.Context.Underlying_Code.Value;
      end if;
   end Set_Diagnostic;

   procedure Set_Warning
     (Target  : in out Terminal.App.Image_Media.Decode_Diagnostic;
      Warning : Giflib.Errors.Warning)
   is
      As_Error : constant Giflib.Errors.Error :=
        (Code => Giflib.Errors.No_Error, Context => Warning.Context);
      Name : constant String := Giflib.Errors.Identifier (Warning);
   begin
      Set_Diagnostic (Target, As_Error);
      Target.Present := True;
      Terminal.App.Image_Media_Diagnostics.Replace_Identifier (Target, Name);
   end Set_Warning;
end Terminal.App.GIF_Adapter;

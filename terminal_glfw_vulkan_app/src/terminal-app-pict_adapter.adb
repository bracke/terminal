with Interfaces;
with Terminal.App.Borrowed_Stream;
with Terminal.App.Image_Media_Diagnostics;
with Terminal.Common.Bytes;

package body Terminal.App.PICT_Adapter is
   use type Pictlib.Byte_Count;
   use type Pictlib.Errors.Error_Code;

   pragma Compile_Time_Error
     (Terminal.Common.Bytes.Byte'Size /= Pictlib.Byte'Size,
      "terminal and pictlib byte representations must match");

   function Success
     (Count        : Pictlib.Byte_Count;
      End_Of_Input : Boolean) return Pictlib.Streams.Source_Result is
     ((Error        => Pictlib.Errors.Make (Pictlib.Errors.No_Error),
       Count        => Count,
       End_Of_Input => End_Of_Input));

   package Stream_Bridge is new Terminal.App.Borrowed_Stream.Adapter
     (External_Byte       => Pictlib.Byte,
      External_Byte_Array => Pictlib.Streams.Byte_Array,
      External_Count      => Pictlib.Byte_Count,
      External_Offset     => Pictlib.Source_Offset,
      External_Result     => Pictlib.Streams.Source_Result,
      Success             => Success);

   function To_Decode_Limit
     (Item : Pictlib.Limit_Kind)
      return Terminal.App.Image_Media.Decode_Limit_Kind is
     (case Item is
         when Pictlib.No_Limit => Terminal.App.Image_Media.No_Limit,
         when Pictlib.Frame_Width_Limit =>
           Terminal.App.Image_Media.Frame_Width_Limit,
         when Pictlib.Frame_Height_Limit =>
           Terminal.App.Image_Media.Frame_Height_Limit,
         when Pictlib.Canvas_Pixel_Limit =>
           Terminal.App.Image_Media.Canvas_Pixel_Limit,
         when Pictlib.Picture_Byte_Limit =>
           Terminal.App.Image_Media.Picture_Byte_Limit,
         when Pictlib.Opcode_Count_Limit =>
           Terminal.App.Image_Media.Opcode_Count_Limit,
         when Pictlib.Opcode_Byte_Limit =>
           Terminal.App.Image_Media.Opcode_Byte_Limit,
         when Pictlib.Region_Byte_Limit =>
           Terminal.App.Image_Media.Region_Byte_Limit,
         when Pictlib.Polygon_Point_Limit =>
           Terminal.App.Image_Media.Polygon_Point_Limit,
         when Pictlib.Drawing_Work_Limit =>
           Terminal.App.Image_Media.Drawing_Work_Limit,
         when Pictlib.Retained_Metadata_Byte_Limit =>
           Terminal.App.Image_Media.Retained_Metadata_Byte_Limit,
         when Pictlib.Metadata_Item_Limit =>
           Terminal.App.Image_Media.Metadata_Item_Limit,
         when Pictlib.Allocation_Byte_Limit =>
           Terminal.App.Image_Media.Allocation_Byte_Limit,
         when Pictlib.Total_Allocation_Byte_Limit =>
           Terminal.App.Image_Media.Total_Allocation_Byte_Limit,
         when Pictlib.Output_Byte_Limit =>
           Terminal.App.Image_Media.Output_Byte_Limit,
         when Pictlib.Embedded_Image_Byte_Limit =>
           Terminal.App.Image_Media.Embedded_Image_Byte_Limit,
         when Pictlib.Embedded_Image_Pixel_Limit =>
           Terminal.App.Image_Media.Embedded_Image_Pixel_Limit,
         when Pictlib.Warning_Record_Limit =>
           Terminal.App.Image_Media.Warning_Record_Limit);

   procedure Open
     (Object  : in out Source;
      Storage : System.Address;
      Length  : Natural) is
   begin
      Stream_Bridge.Open (Object.Data, Storage, Length);
   end Open;

   overriding function Read
     (Object : in out Source;
      Buffer : out Pictlib.Streams.Byte_Array)
      return Pictlib.Streams.Source_Result
   is (Stream_Bridge.Read (Object.Data, Buffer));

   overriding function Offset
     (Object : Source) return Pictlib.Source_Offset is
     (Stream_Bridge.Offset (Object.Data));

   overriding function Skip
     (Object : in out Source;
      Count  : Pictlib.Byte_Count) return Pictlib.Streams.Source_Result
   is (Stream_Bridge.Skip (Object.Data, Count));

   procedure Set_Diagnostic
     (Target  : in out Terminal.App.Image_Media.Decode_Diagnostic;
      Failure : Pictlib.Results.Result)
   is
      Error : constant Pictlib.Errors.Error := Failure.First_Error;
      Name : constant String :=
        Pictlib.Errors.Identifiers.To_String (Error.Identifier);
   begin
      Terminal.App.Image_Media_Diagnostics.Initialize
        (Target, Error.Code /= Pictlib.Errors.No_Error, Name);
      Target.Source_Offset := Interfaces.Unsigned_64 (Error.Context.Source);
      Target.Destination_Offset :=
        Interfaces.Unsigned_64 (Error.Context.Destination);
      Target.Has_Opcode := Error.Context.Has_Opcode;
      Target.Opcode := Natural (Error.Context.Op);
      Target.Opcode_Ordinal := Interfaces.Unsigned_64 (Error.Context.Ordinal);
      Target.Row := Interfaces.Unsigned_64 (Error.Context.Row);
      Target.Expected := Interfaces.Unsigned_64 (Error.Context.Expected);
      Target.Actual := Interfaces.Unsigned_64 (Error.Context.Actual);
      Target.Limit := To_Decode_Limit (Error.Context.Limit);
      Target.Has_Underlying_Code := Error.Context.Has_Underlying_Code;
      Target.Underlying_Code := Error.Context.Underlying_Code;
   end Set_Diagnostic;

   procedure Set_Warning
     (Target  : in out Terminal.App.Image_Media.Decode_Diagnostic;
      Warning : Pictlib.Errors.Warning)
   is
      Name : constant String :=
        Pictlib.Errors.Identifiers.To_String (Warning.Identifier);
   begin
      Terminal.App.Image_Media_Diagnostics.Initialize
        (Target, True, Name);
      Target.Source_Offset :=
        Interfaces.Unsigned_64 (Warning.Context.Source);
      Target.Destination_Offset :=
        Interfaces.Unsigned_64 (Warning.Context.Destination);
      Target.Has_Opcode := Warning.Context.Has_Opcode;
      Target.Opcode := Natural (Warning.Context.Op);
      Target.Opcode_Ordinal :=
        Interfaces.Unsigned_64 (Warning.Context.Ordinal);
      Target.Row := Interfaces.Unsigned_64 (Warning.Context.Row);
      Target.Expected := Interfaces.Unsigned_64 (Warning.Context.Expected);
      Target.Actual := Interfaces.Unsigned_64 (Warning.Context.Actual);
      Target.Limit := To_Decode_Limit (Warning.Context.Limit);
      Target.Has_Underlying_Code := Warning.Context.Has_Underlying_Code;
      Target.Underlying_Code := Warning.Context.Underlying_Code;
   end Set_Warning;
end Terminal.App.PICT_Adapter;

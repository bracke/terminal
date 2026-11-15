with Ada.Unchecked_Deallocation;
with Pictlib;
with Pictlib.Decoding;
with Pictlib.Errors;
with Pictlib.Fonts;
with Pictlib.Geometry;
with Pictlib.Images;
with Pictlib.Limits;
with Pictlib.Pictures;
with Pictlib.Results;
with Pictlib.Streams;
with Terminal.App.Cleanup_Diagnostics;
with Terminal.App.Fonts;
with Terminal.App.PICT_Adapter;

separate (Terminal.App.Image_Media)
procedure Decode_PICT
  (Data                    : Terminal.Common.Bytes.Byte_Array;
   Length                  : Natural;
   Maximum_Decoded_Bytes   : Decode_Byte_Limit;
   Maximum_Pixel_Dimension : Positive;
   Result                  : in out Decoded_Image;
   Status                  : out Decode_Status)
is
   use type Pictlib.Pixel_Count;
   use type Pictlib.Streams.Byte_Array_Access;
   procedure Free_PICT_Data is new Ada.Unchecked_Deallocation
     (Pictlib.Streams.Byte_Array, Pictlib.Streams.Byte_Array_Access);
   Source : aliased Terminal.App.PICT_Adapter.Source;
   Decoder : Pictlib.Decoding.Decoder;
   Options : Pictlib.Decoding.Options := (others => <>);
   Constraints : Pictlib.Limits.Limit_Set := Pictlib.Limits.Default_Limits;
   Outcome : Pictlib.Results.Result;
   Info : Pictlib.Pictures.Header_Info;
   Width : Natural := 0;
   Height : Natural := 0;
   Pixel_Count : Natural := 0;
   Frame_Bytes : Natural := 0;
   Decoder_Initialized : Boolean := False;
   Output : Pictlib.Streams.Byte_Array_Access := null;
   Decoder_Budget : constant Natural := Maximum_Decoded_Bytes;
   Adapter_Budget : constant Natural :=
     Saturating_Multiply (Maximum_Decoded_Bytes, 2);

   procedure Clean_Up is
   begin
      if Decoder_Initialized then
         begin
            Pictlib.Decoding.Finalize (Decoder);
         exception
            when E : others =>
               Terminal.App.Cleanup_Diagnostics.Note_Failure
                 (Terminal.App.Cleanup_Diagnostics.Media_Decoder,
                  E,
                  "finalize PICT decoder");
         end;
         Decoder_Initialized := False;
      end if;
      if Output /= null then
         begin
            Free_PICT_Data (Output);
         exception
            when E : others =>
               Terminal.App.Cleanup_Diagnostics.Note_Failure
                 (Terminal.App.Cleanup_Diagnostics.Media_Decoder,
                  E,
                  "release PICT decode output");
         end;
         Output := null;
      end if;
   end Clean_Up;

   function Failure_Status
     (Failure : Pictlib.Results.Result) return Decode_Status is
     (if Failure.First_Error.Code in
           Pictlib.Errors.Limit_Exceeded | Pictlib.Errors.Integer_Overflow
      then Decode_Too_Large
      else Decode_Invalid);

   procedure Fail_Adapter
     (Failure_Status : Decode_Status;
      Identifier     : String;
      Limit          : Decode_Limit_Kind := No_Limit;
      Expected       : Interfaces.Unsigned_64 := 0;
      Actual         : Interfaces.Unsigned_64 := 0) is
   begin
      Release (Result);
      Set_Adapter_Diagnostic
        (Result.Diagnostic, Identifier, Limit, Expected, Actual);
      Status := Failure_Status;
      Clean_Up;
   end Fail_Adapter;

   function Bounded_Work (Pixels : Natural) return Pictlib.Pixel_Count is
      Value : constant Pictlib.Pixel_Count := Pictlib.Pixel_Count (Pixels);
   begin
      if Value > Pictlib.Pixel_Count'Last / 64 then
         return Pictlib.Pixel_Count'Last;
      else
         return Value * 64;
      end if;
   end Bounded_Work;
begin
   Release (Result);
   Status := Decode_Invalid;
   if Length = 0 or else Length > Data'Length then
      Set_Adapter_Diagnostic
        (Result.Diagnostic,
         "pict_input_length_invalid",
         Picture_Byte_Limit,
         Interfaces.Unsigned_64 (Data'Length),
         Interfaces.Unsigned_64 (Length));
      return;
   end if;

   Constraints.Max_Frame_Width :=
     Pictlib.Image_Width
       (Natural'Min
          (Maximum_Pixel_Dimension, Natural (Pictlib.Image_Width'Last)));
   Constraints.Max_Frame_Height :=
     Pictlib.Image_Height
       (Natural'Min
          (Maximum_Pixel_Dimension, Natural (Pictlib.Image_Height'Last)));
   Constraints.Max_Canvas_Pixels :=
     Pictlib.Pixel_Count (Decoder_Budget / 4);
   Constraints.Max_Picture_Bytes := Pictlib.Byte_Count (Length);
   Constraints.Max_Opcodes := Pictlib.Opcode_Ordinal (Length);
   Constraints.Max_Opcode_Bytes := Pictlib.Byte_Count (Length);
   Constraints.Max_Region_Bytes := Pictlib.Byte_Count (Length);
   Constraints.Max_Polygon_Points := Length / 4;
   Constraints.Max_Drawing_Work :=
     Bounded_Work (Decoder_Budget / 4);
   Constraints.Max_Retained_Metadata_Bytes := 0;
   Constraints.Max_Metadata_Items := 0;
   Constraints.Max_Allocation_Bytes :=
     Pictlib.Byte_Count (Decoder_Budget);
   Constraints.Max_Total_Allocation_Bytes :=
     Pictlib.Byte_Count (Decoder_Budget);
   Constraints.Max_Output_Bytes :=
     Pictlib.Byte_Count (Adapter_Budget / 2);
   Constraints.Max_Embedded_Image_Bytes :=
     Pictlib.Byte_Count (Natural'Min (Length, Maximum_Decoded_Bytes));
   Constraints.Max_Embedded_Image_Pixels :=
     Pictlib.Pixel_Count (Maximum_Decoded_Bytes / 4);
   Constraints.Max_Warning_Records := 16;
   Options.Strictness := Pictlib.Compatible;

   declare
      Default_Path : constant String :=
        Terminal.App.Fonts.Default_Font_Path;
      procedure Map
        (ID : Pictlib.Fonts.Font_ID;
         Family : String;
         Style : Terminal.App.Fonts.Font_Style)
      is
         Path : constant String :=
           Terminal.App.Fonts.PICT_Font_Path (Family, Style);
      begin
         if Path /= "" then
            Pictlib.Fonts.Add (Options.Fonts, ID, Path);
            Pictlib.Fonts.Add (Options.Fonts, Family, Path);
         end if;
      end Map;
   begin
      if Default_Path /= "" then
         Pictlib.Fonts.Set_Default (Options.Fonts, Default_Path);
      end if;
      Map (0, "Chicago", Terminal.App.Fonts.Sans_Serif);
      Map (1, "Geneva", Terminal.App.Fonts.Sans_Serif);
      Map (3, "Geneva", Terminal.App.Fonts.Sans_Serif);
      Map (2, "New York", Terminal.App.Fonts.Serif);
      Map (4, "Monaco", Terminal.App.Fonts.Monospace);
      Map (5, "Venice", Terminal.App.Fonts.Serif);
      Map (6, "London", Terminal.App.Fonts.Serif);
      Map (7, "Athens", Terminal.App.Fonts.Sans_Serif);
      Map (8, "San Francisco", Terminal.App.Fonts.Sans_Serif);
      Map (9, "Toronto", Terminal.App.Fonts.Sans_Serif);
      Map (11, "Cairo", Terminal.App.Fonts.Sans_Serif);
      Map (12, "Los Angeles", Terminal.App.Fonts.Sans_Serif);
      Map (20, "Times", Terminal.App.Fonts.Serif);
      Map (21, "Helvetica", Terminal.App.Fonts.Sans_Serif);
      Map (22, "Courier", Terminal.App.Fonts.Monospace);
      Map (23, "Symbol", Terminal.App.Fonts.Symbol);
      Map (24, "Mobile", Terminal.App.Fonts.Sans_Serif);
   end;

   Terminal.App.PICT_Adapter.Open
     (Source, Data (Data'First)'Address, Length);
   Pictlib.Decoding.Initialize
     (Decoder, Source'Access, Options, Constraints);
   Decoder_Initialized := True;
   Outcome := Pictlib.Decoding.Read_Header (Decoder);
   if not Pictlib.Results.Succeeded (Outcome) then
      Terminal.App.PICT_Adapter.Set_Diagnostic
        (Result.Diagnostic, Outcome);
      Status := Failure_Status (Outcome);
      Clean_Up;
      return;
   end if;

   Info := Pictlib.Decoding.Header (Decoder);
   Width := Natural (Pictlib.Geometry.Width (Info.Frame));
   Height := Natural (Pictlib.Geometry.Height (Info.Frame));
   if Width = 0 or else Height = 0 then
      Fail_Adapter (Decode_Invalid, "pict_empty_image");
      return;
   elsif Width > Maximum_Pixel_Dimension then
      Fail_Adapter
        (Decode_Too_Large,
         "pict_dimension_limit",
         Frame_Width_Limit,
         Interfaces.Unsigned_64 (Maximum_Pixel_Dimension),
         Interfaces.Unsigned_64 (Width));
      return;
   elsif Height > Maximum_Pixel_Dimension then
      Fail_Adapter
        (Decode_Too_Large,
         "pict_dimension_limit",
         Frame_Height_Limit,
         Interfaces.Unsigned_64 (Maximum_Pixel_Dimension),
         Interfaces.Unsigned_64 (Height));
      return;
   elsif Width > Natural'Last / Height then
      Fail_Adapter (Decode_Too_Large, "pict_pixel_count_overflow");
      return;
   end if;
   Pixel_Count := Width * Height;
   if Pixel_Count > Natural'Last / 4 then
      Fail_Adapter (Decode_Too_Large, "pict_frame_byte_overflow");
      return;
   elsif Pixel_Count > Decoder_Budget / 4 then
      Fail_Adapter
        (Decode_Too_Large,
         "pict_canvas_pixel_limit",
         Canvas_Pixel_Limit,
         Interfaces.Unsigned_64 (Decoder_Budget / 4),
         Interfaces.Unsigned_64 (Pixel_Count));
      return;
   end if;
   Frame_Bytes := Pixel_Count * 4;
   if Frame_Bytes > Adapter_Budget / 2 then
      Fail_Adapter
        (Decode_Too_Large,
         "pict_adapter_byte_limit",
         Total_Allocation_Byte_Limit,
         Interfaces.Unsigned_64 (Adapter_Budget / 2),
         Interfaces.Unsigned_64 (Frame_Bytes));
      return;
   end if;
   Output := new Pictlib.Streams.Byte_Array (1 .. Frame_Bytes);
   Outcome :=
     Pictlib.Decoding.Render
       (Decoder,
        (Descriptor =>
           (Width => Pictlib.Image_Width (Width),
            Height => Pictlib.Image_Height (Height),
            Format => Pictlib.RGBA_32,
            Stride => Pictlib.Row_Stride (Width * 4),
            Accessible_Bytes => Pictlib.Byte_Count (Frame_Bytes)),
         Storage => Output));
   if not Pictlib.Results.Succeeded (Outcome) then
      Terminal.App.PICT_Adapter.Set_Diagnostic
        (Result.Diagnostic, Outcome);
      Status := Failure_Status (Outcome);
      Clean_Up;
      return;
   end if;
   Terminal.App.Owned_Image_Data.Allocate
     (Result.Storage.Bytes, Frame_Bytes);
   declare
      procedure Copy_Output
        (Bytes : in out Terminal.Common.Bytes.Byte_Array) is
      begin
         for Index in 1 .. Frame_Bytes loop
            Bytes (Index) := Terminal.Common.Bytes.Byte (Output (Index));
         end loop;
      end Copy_Output;
   begin
      Terminal.App.Owned_Image_Data.Modify
        (Result.Storage.Bytes, Copy_Output'Access);
   end;
   Free_PICT_Data (Output);

   Result.Pixel_Width := Width;
   Result.Pixel_Height := Height;
   Result.Frame_Count := 1;
   Result.Loop_Count := 1;
   Result.Frame_Bytes := Frame_Bytes;
   Result.Total_Bytes := Frame_Bytes;
   Result.Adapter_Buffer_Bytes := Saturating_Multiply (Frame_Bytes, 2);
   --  Pictlib admits all decoder-owned allocations against one monotonic
   --  session quota; released/replaced buffers do not replenish it.
   Result.Decoder_Configured_Bytes := Decoder_Budget;
   Result.Warning_Count := Pictlib.Decoding.Warning_Count (Decoder);
   if Result.Warning_Count > 0 then
      Terminal.App.PICT_Adapter.Set_Warning
        (Result.First_Warning, Pictlib.Decoding.Warning_At (Decoder, 1));
   end if;
   Status := Decode_Ok;
   Clean_Up;
exception
   when Storage_Error =>
      Release (Result);
      Clean_Up;
      Set_Adapter_Diagnostic
        (Result.Diagnostic, "pict_allocation_failed", Allocation_Byte_Limit);
      Status := Decode_Allocation_Failed;
   when others =>
      Release (Result);
      Clean_Up;
      raise;
end Decode_PICT;

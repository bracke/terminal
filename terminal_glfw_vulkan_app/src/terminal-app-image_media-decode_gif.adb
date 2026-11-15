with Ada.Unchecked_Deallocation;
with Giflib;
with Giflib.Animations;
with Giflib.Decoding;
with Giflib.Errors;
with Giflib.Limits;
with Giflib.Results;
with Giflib.Streams;
with Terminal.App.Cleanup_Diagnostics;
with Terminal.App.GIF_Adapter;

separate (Terminal.App.Image_Media)
procedure Decode_GIF
  (Data                    : Terminal.Common.Bytes.Byte_Array;
   Length                  : Natural;
   Maximum_Decoded_Bytes   : Decode_Byte_Limit;
   Maximum_Pixel_Dimension : Positive;
   Maximum_Frames          : Positive;
   Result                  : in out Decoded_Image;
   Status                  : out Decode_Status)
is
   use type Giflib.Byte_Count;
   use type Giflib.Decoding.Event_Kind;
   type GIF_Byte_Array_Access is access Giflib.Streams.Byte_Array;
   procedure Free_GIF_Data is new Ada.Unchecked_Deallocation
     (Giflib.Streams.Byte_Array, GIF_Byte_Array_Access);
   Canvas : GIF_Byte_Array_Access := null;
   Source : aliased Terminal.App.GIF_Adapter.Source;
   Decoder : Giflib.Decoding.Decoder (Source'Access);
   Options : Giflib.Decoding.Decode_Options :=
     Giflib.Decoding.Default_Options;
   Constraints : Giflib.Limits.Limit_Set := Giflib.Limits.Default_Limits;
   Header : Giflib.Decoding.Header_Info;
   Event : Giflib.Decoding.Decode_Event;
   Info : Giflib.Decoding.Frame_Info;
   Outcome : Giflib.Results.Result;
   Looping : Giflib.Animations.Loop_Info := Giflib.Animations.No_Loop;
   Frame_Count : Natural := 0;
   Decoded_Frames : Natural := 0;
   Width : Natural := 0;
   Height : Natural := 0;
   Pixel_Count : Natural := 0;
   Frame_Bytes : Natural := 0;
   Total_Bytes : Natural := 0;
   Delay_Bytes : Natural := 0;
   Adapter_Bytes : Natural := 0;
   Decoder_Initialized : Boolean := False;
   Decoder_Budget : constant Natural := Maximum_Decoded_Bytes;
   Adapter_Budget : constant Natural :=
     Saturating_Multiply (Maximum_Decoded_Bytes, 2);

   function Bounded_Multiple
     (Value  : Natural;
      Factor : Positive) return Giflib.Byte_Count
   is
   begin
      if Giflib.Byte_Count (Value) >
        Giflib.Byte_Count'Last / Giflib.Byte_Count (Factor)
      then
         return Giflib.Byte_Count'Last;
      end if;
      return Giflib.Byte_Count (Value) * Giflib.Byte_Count (Factor);
   end Bounded_Multiple;

   procedure Clean_Up is
   begin
      if Decoder_Initialized then
         begin
            Giflib.Decoding.Finalize (Decoder);
         exception
            when E : others =>
               Terminal.App.Cleanup_Diagnostics.Note_Failure
                 (Terminal.App.Cleanup_Diagnostics.Media_Decoder,
                  E,
                  "finalize GIF decoder");
         end;
         Decoder_Initialized := False;
      end if;
      if Canvas /= null then
         begin
            Free_GIF_Data (Canvas);
         exception
            when E : others =>
               Terminal.App.Cleanup_Diagnostics.Note_Failure
                 (Terminal.App.Cleanup_Diagnostics.Media_Decoder,
                  E,
                  "release GIF decode canvas");
         end;
         Canvas := null;
      end if;
   end Clean_Up;

   procedure Fail (Failure : Giflib.Results.Result) is
   begin
      Release (Result);
      Terminal.App.GIF_Adapter.Set_Diagnostic
        (Result.Diagnostic, Failure.First_Error);
      Status :=
        (if Failure.First_Error.Code in
               Giflib.Errors.Limit_Exceeded | Giflib.Errors.Integer_Overflow
         then Decode_Too_Large
         else Decode_Invalid);
      Clean_Up;
   end Fail;

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
begin
   Release (Result);
   Status := Decode_Invalid;
   if Length = 0 or else Length > Data'Length then
      Set_Adapter_Diagnostic
        (Result.Diagnostic,
         "gif_input_length_invalid",
         Compressed_Byte_Limit,
         Interfaces.Unsigned_64 (Data'Length),
         Interfaces.Unsigned_64 (Length));
      return;
   end if;

   Terminal.App.GIF_Adapter.Open
     (Source, Data (Data'First)'Address, Length);

   Constraints.Max_Logical_Width :=
     Giflib.Image_Width
       (Natural'Min (Maximum_Pixel_Dimension,
                     Natural (Giflib.Image_Width'Last)));
   Constraints.Max_Logical_Height :=
     Giflib.Image_Height
       (Natural'Min (Maximum_Pixel_Dimension,
                     Natural (Giflib.Image_Height'Last)));
   Constraints.Max_Canvas_Pixels :=
     Giflib.Pixel_Count (Decoder_Budget / 4);
   Constraints.Max_Canvas_Bytes :=
     Giflib.Byte_Count (Decoder_Budget);
   Constraints.Max_Frames := Giflib.Frame_Ordinal (Maximum_Frames);
   Constraints.Max_Frame_Pixels :=
     Giflib.Pixel_Count (Decoder_Budget / 4);
   Constraints.Max_Total_Decoded_Frame_Pixels :=
     Giflib.Pixel_Count (Maximum_Decoded_Bytes / 4);
   Constraints.Max_Compressed_Bytes := Giflib.Byte_Count (Length);
   --  Giflib accounts its simultaneously live buffers against this
   --  aggregate limit.  The adapter separately admits at most one result
   --  quota plus one canvas quota, giving a documented 3x peak ceiling.
   Constraints.Max_Allocation_Bytes := Giflib.Byte_Count (Decoder_Budget);
   Constraints.Max_Output_Bytes :=
     Giflib.Byte_Count (Adapter_Budget);
   Constraints.Max_LZW_Work :=
     Bounded_Multiple (Maximum_Decoded_Bytes, 16);
   Constraints.Max_Compositor_Snapshot_Bytes :=
     Giflib.Byte_Count (Decoder_Budget);

   --  Count frames first so the public result owns an exact-size bounded
   --  allocation. This pass skips compressed image data and also discovers
   --  the authoritative loop extension.
   Options.Mode := Giflib.Decoding.Raw_Indexed;
   Outcome :=
     Giflib.Decoding.Initialize
       (Decoder, Options, Constraints);
   Decoder_Initialized := Giflib.Results.Succeeded (Outcome);
   if not Decoder_Initialized then
      Fail (Outcome);
      return;
   end if;
   Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
   if not Giflib.Results.Succeeded (Outcome) then
      Fail (Outcome);
      return;
   end if;
   Width := Natural (Header.Width);
   Height := Natural (Header.Height);
   loop
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      if not Giflib.Results.Succeeded (Outcome) then
         Fail (Outcome);
         return;
      elsif Event.Kind = Giflib.Decoding.End_Event then
         exit;
      elsif Event.Kind = Giflib.Decoding.Image_Event then
         Frame_Count := Frame_Count + 1;
         if Frame_Count > Maximum_Frames then
            Fail_Adapter
              (Decode_Too_Large,
               "gif_frame_count_limit",
               Frame_Count_Limit,
               Interfaces.Unsigned_64 (Maximum_Frames),
               Interfaces.Unsigned_64 (Frame_Count));
            return;
         end if;
         Outcome := Giflib.Decoding.Skip_Frame (Decoder);
         if not Giflib.Results.Succeeded (Outcome) then
            Fail (Outcome);
            return;
         end if;
      end if;
   end loop;
   Looping := Giflib.Decoding.Looping (Decoder);
   if Frame_Count = 0 or else Width = 0
     or else Height = 0
   then
      Fail_Adapter (Decode_Invalid, "gif_empty_image");
      return;
   elsif Width > Maximum_Pixel_Dimension then
      Fail_Adapter
        (Decode_Too_Large,
         "gif_dimension_limit",
         Frame_Width_Limit,
         Interfaces.Unsigned_64 (Maximum_Pixel_Dimension),
         Interfaces.Unsigned_64 (Width));
      return;
   elsif Height > Maximum_Pixel_Dimension then
      Fail_Adapter
        (Decode_Too_Large,
         "gif_dimension_limit",
         Frame_Height_Limit,
         Interfaces.Unsigned_64 (Maximum_Pixel_Dimension),
         Interfaces.Unsigned_64 (Height));
      return;
   elsif Width > Natural'Last / Height
   then
      Fail_Adapter (Decode_Too_Large, "gif_pixel_count_overflow");
      return;
   end if;
   Pixel_Count := Width * Height;
   if Pixel_Count > Natural'Last / 4 then
      Fail_Adapter (Decode_Too_Large, "gif_frame_byte_overflow");
      return;
   end if;
   Frame_Bytes := Pixel_Count * 4;
   if Frame_Bytes = 0
     or else Frame_Bytes > Decoder_Budget
     or else Frame_Count > Maximum_Decoded_Bytes / Frame_Bytes
   then
      Fail_Adapter
        (Decode_Too_Large,
         "gif_decoded_byte_limit",
         Output_Byte_Limit,
         Interfaces.Unsigned_64 (Maximum_Decoded_Bytes),
         Interfaces.Unsigned_64
           (Saturating_Multiply (Frame_Count, Frame_Bytes)));
      return;
   end if;
   Total_Bytes := Frame_Count * Frame_Bytes;
   Delay_Bytes := Frame_Delay_Storage_Bytes (Frame_Count);
   Adapter_Bytes :=
     Saturating_Add
       (Saturating_Add (Frame_Bytes, Total_Bytes), Delay_Bytes);
   if Adapter_Bytes > Adapter_Budget then
      Fail_Adapter
        (Decode_Too_Large,
         "gif_adapter_byte_limit",
         Total_Allocation_Byte_Limit,
         Interfaces.Unsigned_64 (Adapter_Budget),
         Interfaces.Unsigned_64 (Adapter_Bytes));
      return;
   end if;
   Result.Delays_MS := new Frame_Delay_Array'(1 .. Frame_Count => 100);
   Terminal.App.Owned_Image_Data.Allocate
     (Result.Storage.Bytes, Total_Bytes);
   Canvas := new Giflib.Streams.Byte_Array (1 .. Frame_Bytes);

   --  Decode composited logical canvases so disposal and transparency are
   --  already resolved for the renderer's frame playback model.
   Options.Mode := Giflib.Decoding.Composited_RGBA;
   Terminal.App.GIF_Adapter.Open
     (Source, Data (Data'First)'Address, Length);
   Outcome :=
     Giflib.Decoding.Reset
       (Decoder, Options, Constraints);
   if not Giflib.Results.Succeeded (Outcome) then
      Fail (Outcome);
      return;
   end if;
   Outcome := Giflib.Decoding.Read_Header (Decoder, Header);
   if not Giflib.Results.Succeeded (Outcome)
     or else Natural (Header.Width) /= Width
     or else Natural (Header.Height) /= Height
   then
      if Giflib.Results.Succeeded (Outcome) then
         Outcome := Giflib.Results.Failure (Giflib.Errors.Invalid_Dimensions);
      end if;
      Fail (Outcome);
      return;
   end if;

   loop
      Outcome := Giflib.Decoding.Next_Event (Decoder, Event);
      if not Giflib.Results.Succeeded (Outcome) then
         Fail (Outcome);
         return;
      elsif Event.Kind = Giflib.Decoding.End_Event then
         exit;
      elsif Event.Kind = Giflib.Decoding.Image_Event then
         if Decoded_Frames = Frame_Count then
            Fail_Adapter (Decode_Invalid, "gif_frame_count_changed");
            return;
         end if;
         Outcome :=
           Giflib.Decoding.Decode_Composited_Frame
             (Decoder, Canvas.all, Info);
         if not Giflib.Results.Succeeded (Outcome) then
            Fail (Outcome);
            return;
         end if;
         Decoded_Frames := Decoded_Frames + 1;
         declare
            First : constant Positive :=
              1 + (Decoded_Frames - 1) * Frame_Bytes;
            procedure Copy_Canvas
              (Bytes : in out Terminal.Common.Bytes.Byte_Array) is
            begin
               for I in 0 .. Frame_Bytes - 1 loop
                  Bytes (First + I) :=
                    Terminal.Common.Bytes.Byte (Canvas (Canvas'First + I));
               end loop;
            end Copy_Canvas;
         begin
            Terminal.App.Owned_Image_Data.Modify
              (Result.Storage.Bytes, Copy_Canvas'Access);
         end;
         Result.Delays_MS (Decoded_Frames) :=
           Natural'Max (10, Natural (Info.Control.Delay_CS) * 10);
      end if;
   end loop;
   if Decoded_Frames /= Frame_Count then
      Fail_Adapter (Decode_Invalid, "gif_frame_count_mismatch");
      return;
   end if;

   Result.Pixel_Width := Width;
   Result.Pixel_Height := Height;
   Result.Frame_Count := Frame_Count;
   Result.Loop_Count :=
     (case Looping.State is
         when Giflib.Animations.No_Loop_Extension => 0,
         when Giflib.Animations.Infinite_Looping => 1,
         when Giflib.Animations.Finite_Loop_Count =>
           Giflib.Animations.Raw_Count (Looping) + 1);
   Result.Frame_Bytes := Frame_Bytes;
   Result.Total_Bytes := Total_Bytes;
   Result.Adapter_Buffer_Bytes := Adapter_Bytes;
   Result.Decoder_Configured_Bytes :=
     Decoder_Budget;
   Result.Warning_Count := Giflib.Decoding.Warning_Count (Decoder);
   if Result.Warning_Count > 0 then
      declare
         Warning : Giflib.Errors.Warning;
         Warning_Result : constant Giflib.Results.Result :=
           Giflib.Decoding.Warning_At (Decoder, 1, Warning);
      begin
         if Giflib.Results.Succeeded (Warning_Result) then
            Terminal.App.GIF_Adapter.Set_Warning
              (Result.First_Warning, Warning);
         end if;
      end;
   end if;
   Status := Decode_Ok;
   Clean_Up;
exception
   when Storage_Error =>
      Release (Result);
      Clean_Up;
      Set_Adapter_Diagnostic
        (Result.Diagnostic, "gif_allocation_failed", Allocation_Byte_Limit);
      Status := Decode_Allocation_Failed;
   when others =>
      Release (Result);
      Clean_Up;
      raise;
end Decode_GIF;

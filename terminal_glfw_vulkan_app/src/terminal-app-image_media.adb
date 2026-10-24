with Ada.Unchecked_Deallocation;
with Interfaces;
with System;
with System.Address_To_Access_Conversions;
with System.Storage_Elements;

with Giflib;
with Giflib.Animations;
with Giflib.Decoding;
with Giflib.Errors;
with Giflib.Limits;
with Giflib.Results;
with Giflib.Streams;
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
with Terminal.App.Fonts;

package body Terminal.App.Image_Media is
   package RM renames Terminal.App.Render_Model;

   use type Interfaces.Unsigned_64;
   use type Terminal.Common.Bytes.Byte;
   use type RM.Image_Data_Access;
   use type System.Address;
   use type Giflib.Animations.Loop_State;
   use type Giflib.Byte_Count;
   use type Giflib.Decoding.Event_Kind;
   use type Giflib.Errors.Error_Code;
   use type Pictlib.Byte_Count;
   use type Pictlib.Pixel_Count;
   use type Pictlib.Errors.Error_Code;
   use type Pictlib.Streams.Byte_Array_Access;

   pragma Compile_Time_Error
     (Terminal.Common.Bytes.Byte'Size /= Pictlib.Byte'Size,
      "terminal and pictlib byte representations must match");

   procedure Free_Image_Data is new Ada.Unchecked_Deallocation
     (Terminal.Common.Bytes.Byte_Array, RM.Image_Data_Access);
   type GIF_Byte_Array_Access is access Giflib.Streams.Byte_Array;
   procedure Free_GIF_Data is new Ada.Unchecked_Deallocation
     (Giflib.Streams.Byte_Array, GIF_Byte_Array_Access);
   procedure Free_PICT_Data is new Ada.Unchecked_Deallocation
     (Pictlib.Streams.Byte_Array, Pictlib.Streams.Byte_Array_Access);
   package Byte_Addresses is new System.Address_To_Access_Conversions
     (Terminal.Common.Bytes.Byte);
   use type System.Storage_Elements.Storage_Offset;

   type Borrowed_Source_State is record
      Storage  : System.Address := System.Null_Address;
      Length   : Natural := 0;
      Position : Natural := 0;
   end record;

   function Remaining (State : Borrowed_Source_State) return Natural is
     (State.Length - State.Position);

   function Next_Byte
     (State : in out Borrowed_Source_State)
      return Terminal.Common.Bytes.Byte
   is
      Result : constant Terminal.Common.Bytes.Byte :=
        Byte_Addresses.To_Pointer
          (State.Storage
           + System.Storage_Elements.Storage_Offset (State.Position)).all;
   begin
      State.Position := State.Position + 1;
      return Result;
   end Next_Byte;

   function Advance
     (State : in out Borrowed_Source_State;
      Count : Natural) return Natural
   is
      Amount : constant Natural := Natural'Min (Remaining (State), Count);
   begin
      State.Position := State.Position + Amount;
      return Amount;
   end Advance;

   type Terminal_GIF_Source is limited new Giflib.Streams.Source with record
      State : Borrowed_Source_State;
   end record;

   overriding function Read
     (Object : in out Terminal_GIF_Source;
      Buffer : out Giflib.Streams.Byte_Array)
      return Giflib.Streams.Source_Result;
   overriding function Offset
     (Object : Terminal_GIF_Source) return Giflib.Source_Offset;
   overriding function Skip
     (Object : in out Terminal_GIF_Source;
      Count  : Giflib.Byte_Count) return Giflib.Streams.Source_Result;

   type Terminal_PICT_Source is limited new Pictlib.Streams.Source with record
      State : Borrowed_Source_State;
   end record;

   overriding function Read
     (Object : in out Terminal_PICT_Source;
      Buffer : out Pictlib.Streams.Byte_Array)
      return Pictlib.Streams.Source_Result;
   overriding function Offset
     (Object : Terminal_PICT_Source) return Pictlib.Source_Offset;
   overriding function Skip
     (Object : in out Terminal_PICT_Source;
      Count : Pictlib.Byte_Count) return Pictlib.Streams.Source_Result;

   overriding function Read
     (Object : in out Terminal_GIF_Source;
      Buffer : out Giflib.Streams.Byte_Array)
      return Giflib.Streams.Source_Result
   is
      Amount : constant Natural :=
        Natural'Min (Remaining (Object.State), Buffer'Length);
   begin
      if Amount > 0 then
         for I in 0 .. Amount - 1 loop
            Buffer (Buffer'First + I) :=
              Giflib.Byte (Next_Byte (Object.State));
         end loop;
      end if;
      return
        (Error => Giflib.Errors.Make (Giflib.Errors.No_Error),
         Count => Giflib.Byte_Count (Amount),
         End_Of_Input => Remaining (Object.State) = 0);
   end Read;

   overriding function Offset
     (Object : Terminal_GIF_Source) return Giflib.Source_Offset is
     (Giflib.Source_Offset (Object.State.Position));

   overriding function Skip
     (Object : in out Terminal_GIF_Source;
      Count  : Giflib.Byte_Count) return Giflib.Streams.Source_Result
   is
      Requested : constant Natural :=
        (if Count > Giflib.Byte_Count (Natural'Last)
         then Natural'Last else Natural (Count));
      Amount : constant Natural := Advance (Object.State, Requested);
   begin
      return
        (Error => Giflib.Errors.Make (Giflib.Errors.No_Error),
         Count => Giflib.Byte_Count (Amount),
         End_Of_Input => Remaining (Object.State) = 0);
   end Skip;

   overriding function Read
     (Object : in out Terminal_PICT_Source;
      Buffer : out Pictlib.Streams.Byte_Array)
      return Pictlib.Streams.Source_Result
   is
      Amount : constant Natural :=
        Natural'Min (Remaining (Object.State), Buffer'Length);
   begin
      if Amount > 0 then
         for I in 0 .. Amount - 1 loop
            Buffer (Buffer'First + I) :=
              Pictlib.Byte (Next_Byte (Object.State));
         end loop;
      end if;
      return
        (Error => Pictlib.Errors.Make (Pictlib.Errors.No_Error),
         Count => Pictlib.Byte_Count (Amount),
         End_Of_Input => Remaining (Object.State) = 0);
   end Read;

   overriding function Offset
     (Object : Terminal_PICT_Source) return Pictlib.Source_Offset is
     (Pictlib.Source_Offset (Object.State.Position));

   overriding function Skip
     (Object : in out Terminal_PICT_Source;
      Count : Pictlib.Byte_Count) return Pictlib.Streams.Source_Result
   is
      Requested : constant Natural :=
        (if Count > Pictlib.Byte_Count (Natural'Last)
         then Natural'Last else Natural (Count));
      Amount : constant Natural := Advance (Object.State, Requested);
   begin
      return
        (Error => Pictlib.Errors.Make (Pictlib.Errors.No_Error),
         Count => Pictlib.Byte_Count (Amount),
         End_Of_Input => Remaining (Object.State) = 0);
   end Skip;

   function Diagnostic_Identifier (Item : Decode_Diagnostic) return String is
   begin
      if Item.Identifier_Length = 0 then
         return "";
      end if;
      return Item.Identifier (1 .. Item.Identifier_Length);
   end Diagnostic_Identifier;

   function To_Decode_Limit
     (Item : Pictlib.Limit_Kind) return Decode_Limit_Kind is
     (case Item is
         when Pictlib.No_Limit                      => No_Limit,
         when Pictlib.Frame_Width_Limit             => Frame_Width_Limit,
         when Pictlib.Frame_Height_Limit            => Frame_Height_Limit,
         when Pictlib.Canvas_Pixel_Limit            => Canvas_Pixel_Limit,
         when Pictlib.Picture_Byte_Limit            => Picture_Byte_Limit,
         when Pictlib.Opcode_Count_Limit            => Opcode_Count_Limit,
         when Pictlib.Opcode_Byte_Limit             => Opcode_Byte_Limit,
         when Pictlib.Region_Byte_Limit             => Region_Byte_Limit,
         when Pictlib.Polygon_Point_Limit           => Polygon_Point_Limit,
         when Pictlib.Drawing_Work_Limit            => Drawing_Work_Limit,
         when Pictlib.Retained_Metadata_Byte_Limit  =>
           Retained_Metadata_Byte_Limit,
         when Pictlib.Metadata_Item_Limit           => Metadata_Item_Limit,
         when Pictlib.Allocation_Byte_Limit         => Allocation_Byte_Limit,
         when Pictlib.Total_Allocation_Byte_Limit   =>
           Total_Allocation_Byte_Limit,
         when Pictlib.Output_Byte_Limit             => Output_Byte_Limit,
         when Pictlib.Embedded_Image_Byte_Limit     =>
           Embedded_Image_Byte_Limit,
         when Pictlib.Embedded_Image_Pixel_Limit    =>
           Embedded_Image_Pixel_Limit,
         when Pictlib.Warning_Record_Limit          => Warning_Record_Limit);

   procedure Set_PICT_Diagnostic
     (Result : in out Decoded_Image;
      Failure : Pictlib.Results.Result)
   is
      Error : constant Pictlib.Errors.Error := Failure.First_Error;
      Name : constant String :=
        Pictlib.Errors.Identifiers.To_String (Error.Identifier);
      Used : constant Natural :=
        Natural'Min (Name'Length, Max_Diagnostic_Identifier_Length);
   begin
      Result.Diagnostic := (others => <>);
      Result.Diagnostic.Present := Error.Code /= Pictlib.Errors.No_Error;
      Result.Diagnostic.Identifier_Length := Used;
      if Used > 0 then
         Result.Diagnostic.Identifier (1 .. Used) :=
           Name (Name'First .. Name'First + Used - 1);
      end if;
      Result.Diagnostic.Source_Offset :=
        Interfaces.Unsigned_64 (Error.Context.Source);
      Result.Diagnostic.Destination_Offset :=
        Interfaces.Unsigned_64 (Error.Context.Destination);
      Result.Diagnostic.Has_Opcode := Error.Context.Has_Opcode;
      Result.Diagnostic.Opcode := Natural (Error.Context.Op);
      Result.Diagnostic.Opcode_Ordinal :=
        Interfaces.Unsigned_64 (Error.Context.Ordinal);
      Result.Diagnostic.Row := Interfaces.Unsigned_64 (Error.Context.Row);
      Result.Diagnostic.Expected :=
        Interfaces.Unsigned_64 (Error.Context.Expected);
      Result.Diagnostic.Actual := Interfaces.Unsigned_64 (Error.Context.Actual);
      Result.Diagnostic.Limit := To_Decode_Limit (Error.Context.Limit);
      Result.Diagnostic.Has_Underlying_Code := Error.Context.Has_Underlying_Code;
      Result.Diagnostic.Underlying_Code := Error.Context.Underlying_Code;
   end Set_PICT_Diagnostic;

   procedure Set_PICT_Warning
     (Result : in out Decoded_Image;
      Warning : Pictlib.Errors.Warning)
   is
      Name : constant String :=
        Pictlib.Errors.Identifiers.To_String (Warning.Identifier);
      Used : constant Natural :=
        Natural'Min (Name'Length, Max_Diagnostic_Identifier_Length);
   begin
      Result.First_Warning := (others => <>);
      Result.First_Warning.Present := True;
      Result.First_Warning.Identifier_Length := Used;
      if Used > 0 then
         Result.First_Warning.Identifier (1 .. Used) :=
           Name (Name'First .. Name'First + Used - 1);
      end if;
      Result.First_Warning.Source_Offset :=
        Interfaces.Unsigned_64 (Warning.Context.Source);
      Result.First_Warning.Destination_Offset :=
        Interfaces.Unsigned_64 (Warning.Context.Destination);
      Result.First_Warning.Has_Opcode := Warning.Context.Has_Opcode;
      Result.First_Warning.Opcode := Natural (Warning.Context.Op);
      Result.First_Warning.Opcode_Ordinal :=
        Interfaces.Unsigned_64 (Warning.Context.Ordinal);
      Result.First_Warning.Row :=
        Interfaces.Unsigned_64 (Warning.Context.Row);
      Result.First_Warning.Expected :=
        Interfaces.Unsigned_64 (Warning.Context.Expected);
      Result.First_Warning.Actual :=
        Interfaces.Unsigned_64 (Warning.Context.Actual);
      Result.First_Warning.Limit := To_Decode_Limit (Warning.Context.Limit);
      Result.First_Warning.Has_Underlying_Code :=
        Warning.Context.Has_Underlying_Code;
      Result.First_Warning.Underlying_Code :=
        Warning.Context.Underlying_Code;
   end Set_PICT_Warning;

   function Saturating_Add (Left, Right : Natural) return Natural is
     (if Left > Natural'Last - Right then Natural'Last else Left + Right);

   function Saturating_Multiply (Left, Right : Natural) return Natural is
     (if Left = 0 or else Right = 0 then 0
      elsif Left > Natural'Last / Right then Natural'Last
      else Left * Right);

   function Available return Boolean is (True);

   function Is_GIF
     (Data : Terminal.Common.Bytes.Byte_Array;
      Length : Natural) return Boolean
   is
      Signature : String (1 .. 6);
   begin
      if Length < 6 or else Length > Data'Length then
         return False;
      end if;
      for I in Signature'Range loop
         Signature (I) := Character'Val (Data (Data'First + I - 1));
      end loop;
      return Signature in "GIF87a" | "GIF89a";
   end Is_GIF;

   function Is_Headered_PICT
     (Data : Terminal.Common.Bytes.Byte_Array;
      Length : Natural) return Boolean
   is
   begin
      --  Classic PICT files commonly carry a 512-byte all-zero file header.
      --  The image rectangle immediately following it must have increasing
      --  bottom/right coordinates. This also recognizes a truncated headered
      --  picture before the version opcode is available to Is_PICT.
      if Length < 522 or else Length > Data'Length then
         return False;
      end if;
      for Offset in 0 .. 511 loop
         if Data (Data'First + Offset) /= 0 then
            return False;
         end if;
      end loop;
      return
        (Natural (Data (Data'First + 516)) * 256
         + Natural (Data (Data'First + 517)))
        <
        (Natural (Data (Data'First + 520)) * 256
         + Natural (Data (Data'First + 521)))
        and then
        (Natural (Data (Data'First + 514)) * 256
         + Natural (Data (Data'First + 515)))
        <
        (Natural (Data (Data'First + 518)) * 256
         + Natural (Data (Data'First + 519)));
   end Is_Headered_PICT;

   function Is_PICT
     (Data : Terminal.Common.Bytes.Byte_Array;
      Length : Natural) return Boolean
   is
      function Has_Version_At (Offset : Natural) return Boolean is
      begin
         if Length < Offset + 2 then
            return False;
         end if;
         declare
            First : constant Positive := Data'First + Offset;
         begin
            return
              (Data (First) = 16#11# and then Data (First + 1) = 1)
              or else
                (Length >= Offset + 4
                 and then Data (First) = 0
                 and then Data (First + 1) = 16#11#
                 and then Data (First + 2) = 2
                 and then Data (First + 3) = 16#FF#);
         end;
      end Has_Version_At;
   begin
      if Length = 0 or else Length > Data'Length then
         return False;
      end if;
      --  The version opcode follows the two-byte size and eight-byte frame,
      --  either at the start of a raw picture or after the 512-byte file
      --  header. Checking it avoids running arbitrary optional media through
      --  the PICT parser merely to identify its format.
      return Has_Version_At (10) or else Has_Version_At (522);
   end Is_PICT;

   procedure Release (Result : in out Decoded_Image) is
   begin
      if Result.Bytes /= null then
         Free_Image_Data (Result.Bytes);
      end if;
      Result := (others => <>);
   end Release;

   procedure Decode_GIF
     (Data                    : Terminal.Common.Bytes.Byte_Array;
      Length                  : Natural;
      Maximum_Decoded_Bytes   : Positive;
      Maximum_Pixel_Dimension : Positive;
      Result                  : in out Decoded_Image;
      Status                  : out Decode_Status)
   is
      Canvas : GIF_Byte_Array_Access := null;
      Source : aliased Terminal_GIF_Source;
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
      Decoder_Initialized : Boolean := False;

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
            Giflib.Decoding.Finalize (Decoder);
            Decoder_Initialized := False;
         end if;
         if Canvas /= null then
            Free_GIF_Data (Canvas);
         end if;
      end Clean_Up;

      procedure Fail (Failure : Giflib.Results.Result) is
      begin
         Release (Result);
         Status :=
           (if Failure.First_Error.Code in
                  Giflib.Errors.Limit_Exceeded | Giflib.Errors.Integer_Overflow
            then Decode_Too_Large
            else Decode_Invalid);
         Clean_Up;
      end Fail;
   begin
      Release (Result);
      Status := Decode_Invalid;
      if Length = 0 or else Length > Data'Length then
         return;
      end if;

      Source.State :=
        (Storage  => Data (Data'First)'Address,
         Length   => Length,
         Position => 0);

      Constraints.Max_Logical_Width :=
        Giflib.Image_Width
          (Natural'Min (Maximum_Pixel_Dimension,
                        Natural (Giflib.Image_Width'Last)));
      Constraints.Max_Logical_Height :=
        Giflib.Image_Height
          (Natural'Min (Maximum_Pixel_Dimension,
                        Natural (Giflib.Image_Height'Last)));
      Constraints.Max_Canvas_Pixels :=
        Giflib.Pixel_Count (Maximum_Decoded_Bytes / 4);
      Constraints.Max_Canvas_Bytes :=
        Giflib.Byte_Count (Maximum_Decoded_Bytes);
      Constraints.Max_Frames := Giflib.Frame_Ordinal (Max_Frames);
      Constraints.Max_Frame_Pixels :=
        Giflib.Pixel_Count (Maximum_Decoded_Bytes / 4);
      Constraints.Max_Total_Decoded_Frame_Pixels :=
        Giflib.Pixel_Count (Maximum_Decoded_Bytes / 4);
      Constraints.Max_Compressed_Bytes := Giflib.Byte_Count (Length);
      Constraints.Max_Allocation_Bytes :=
        Bounded_Multiple (Maximum_Decoded_Bytes, 3);
      Constraints.Max_Output_Bytes :=
        Giflib.Byte_Count (Maximum_Decoded_Bytes);
      Constraints.Max_LZW_Work :=
        Bounded_Multiple (Maximum_Decoded_Bytes, 16);
      Constraints.Max_Compositor_Snapshot_Bytes :=
        Giflib.Byte_Count (Maximum_Decoded_Bytes);

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
            if Frame_Count > Max_Frames then
               Release (Result);
               Status := Decode_Too_Large;
               Clean_Up;
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
      if Frame_Count = 0
        or else Width = 0
        or else Height = 0
        or else Width > Maximum_Pixel_Dimension
        or else Height > Maximum_Pixel_Dimension
        or else Width > Natural'Last / Height
      then
         Release (Result);
         Status := Decode_Too_Large;
         Clean_Up;
         return;
      end if;
      Pixel_Count := Width * Height;
      if Pixel_Count > Natural'Last / 4 then
         Release (Result);
         Status := Decode_Too_Large;
         Clean_Up;
         return;
      end if;
      Frame_Bytes := Pixel_Count * 4;
      if Frame_Bytes = 0
        or else Frame_Count > Maximum_Decoded_Bytes / Frame_Bytes
      then
         Release (Result);
         Status := Decode_Too_Large;
         Clean_Up;
         return;
      end if;
      Total_Bytes := Frame_Count * Frame_Bytes;
      Result.Bytes :=
        new Terminal.Common.Bytes.Byte_Array (1 .. Total_Bytes);
      Canvas := new Giflib.Streams.Byte_Array (1 .. Frame_Bytes);

      --  Decode composited logical canvases so disposal and transparency are
      --  already resolved for the renderer's frame playback model.
      Options.Mode := Giflib.Decoding.Composited_RGBA;
      Source.State.Position := 0;
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
               Release (Result);
               Status := Decode_Invalid;
               Clean_Up;
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
                 Result.Bytes'First + (Decoded_Frames - 1) * Frame_Bytes;
            begin
               for I in 0 .. Frame_Bytes - 1 loop
                  Result.Bytes (First + I) :=
                    Terminal.Common.Bytes.Byte (Canvas (Canvas'First + I));
               end loop;
            end;
            Result.Delays_MS (Decoded_Frames) :=
              Natural'Max (10, Natural (Info.Control.Delay_CS) * 10);
         end if;
      end loop;
      if Decoded_Frames /= Frame_Count then
         Release (Result);
         Status := Decode_Invalid;
         Clean_Up;
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
              Looping.Raw_Count + 1);
      Result.Frame_Bytes := Frame_Bytes;
      Result.Total_Bytes := Total_Bytes;
      Result.Adapter_Buffer_Bytes :=
        Saturating_Add (Frame_Bytes, Total_Bytes);
      Result.Decoder_Configured_Bytes :=
        Saturating_Multiply (Maximum_Decoded_Bytes, 3);
      Status := Decode_Ok;
      Clean_Up;
   exception
      when Storage_Error =>
         Release (Result);
         Clean_Up;
         Status := Decode_Allocation_Failed;
      when others =>
         Release (Result);
         Clean_Up;
         raise;
   end Decode_GIF;

   procedure Decode_PICT
     (Data                    : Terminal.Common.Bytes.Byte_Array;
      Length                  : Natural;
      Maximum_Decoded_Bytes   : Positive;
      Maximum_Pixel_Dimension : Positive;
      Result                  : in out Decoded_Image;
      Status                  : out Decode_Status)
   is
      Source : aliased Terminal_PICT_Source;
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

      procedure Clean_Up is
      begin
         if Decoder_Initialized then
            Pictlib.Decoding.Finalize (Decoder);
            Decoder_Initialized := False;
         end if;
         if Output /= null then
            Free_PICT_Data (Output);
         end if;
      end Clean_Up;

      function Failure_Status
        (Failure : Pictlib.Results.Result) return Decode_Status is
        (if Failure.First_Error.Code in
              Pictlib.Errors.Limit_Exceeded | Pictlib.Errors.Integer_Overflow
         then Decode_Too_Large
         else Decode_Invalid);

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
        Pictlib.Pixel_Count (Maximum_Decoded_Bytes / 4);
      Constraints.Max_Picture_Bytes := Pictlib.Byte_Count (Length);
      Constraints.Max_Opcodes := Pictlib.Opcode_Ordinal (Length);
      Constraints.Max_Opcode_Bytes := Pictlib.Byte_Count (Length);
      Constraints.Max_Region_Bytes := Pictlib.Byte_Count (Length);
      Constraints.Max_Polygon_Points := Length / 4;
      Constraints.Max_Drawing_Work :=
        Bounded_Work (Maximum_Decoded_Bytes / 4);
      Constraints.Max_Retained_Metadata_Bytes := 0;
      Constraints.Max_Metadata_Items := 0;
      Constraints.Max_Allocation_Bytes :=
        Pictlib.Byte_Count (Maximum_Decoded_Bytes);
      Constraints.Max_Total_Allocation_Bytes :=
        Pictlib.Byte_Count (Maximum_Decoded_Bytes);
      Constraints.Max_Output_Bytes :=
        Pictlib.Byte_Count (Maximum_Decoded_Bytes);
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

      Source.State :=
        (Storage  => Data (Data'First)'Address,
         Length   => Length,
         Position => 0);
      Pictlib.Decoding.Initialize
        (Decoder, Source'Access, Options, Constraints);
      Decoder_Initialized := True;
      Outcome := Pictlib.Decoding.Read_Header (Decoder);
      if not Pictlib.Results.Succeeded (Outcome) then
         Set_PICT_Diagnostic (Result, Outcome);
         Status := Failure_Status (Outcome);
         Clean_Up;
         return;
      end if;

      Info := Pictlib.Decoding.Header (Decoder);
      Width := Natural (Pictlib.Geometry.Width (Info.Frame));
      Height := Natural (Pictlib.Geometry.Height (Info.Frame));
      if Width = 0 or else Height = 0
        or else Width > Maximum_Pixel_Dimension
        or else Height > Maximum_Pixel_Dimension
        or else Width > Natural'Last / Height
      then
         Status := Decode_Too_Large;
         Clean_Up;
         return;
      end if;
      Pixel_Count := Width * Height;
      if Pixel_Count > Natural'Last / 4
        or else Pixel_Count > Maximum_Decoded_Bytes / 4
      then
         Status := Decode_Too_Large;
         Clean_Up;
         return;
      end if;
      Frame_Bytes := Pixel_Count * 4;
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
         Set_PICT_Diagnostic (Result, Outcome);
         Status := Failure_Status (Outcome);
         Clean_Up;
         return;
      end if;
      Result.Bytes :=
        new Terminal.Common.Bytes.Byte_Array (1 .. Frame_Bytes);
      for Index in 1 .. Frame_Bytes loop
         Result.Bytes (Index) := Terminal.Common.Bytes.Byte (Output (Index));
      end loop;
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
      Result.Decoder_Configured_Bytes := Maximum_Decoded_Bytes;
      Result.Warning_Count := Pictlib.Decoding.Warning_Count (Decoder);
      if Result.Warning_Count > 0 then
         Set_PICT_Warning
           (Result, Pictlib.Decoding.Warning_At (Decoder, 1));
      end if;
      Status := Decode_Ok;
      Clean_Up;
   exception
      when Storage_Error =>
         Release (Result);
         Clean_Up;
         Status := Decode_Allocation_Failed;
      when others =>
         Release (Result);
         Clean_Up;
         raise;
   end Decode_PICT;

   procedure Decode
     (Data                    : Terminal.Common.Bytes.Byte_Array;
      Length                  : Natural;
      Maximum_Decoded_Bytes   : Positive;
      Maximum_Pixel_Dimension : Positive;
      Result                  : in out Decoded_Image;
      Status                  : out Decode_Status)
   is
   begin
      Release (Result);
      Status := Decode_Unavailable;
      if Length = 0 or else Length > Data'Length then
         return;
      elsif Is_GIF (Data, Length) then
         Decode_GIF
           (Data,
            Length,
            Maximum_Decoded_Bytes,
            Maximum_Pixel_Dimension,
            Result,
            Status);
      elsif Is_PICT (Data, Length) or else Is_Headered_PICT (Data, Length) then
         Decode_PICT
           (Data,
            Length,
            Maximum_Decoded_Bytes,
            Maximum_Pixel_Dimension,
            Result,
            Status);
      end if;
   end Decode;
end Terminal.App.Image_Media;

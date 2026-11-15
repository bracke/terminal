with Ada.Finalization;
with Ada.Unchecked_Deallocation;

with Jpeglib;
with Jpeglib.Decoding;
with Jpeglib.Errors;
with Jpeglib.Images;
with Jpeglib.Limits;
with Jpeglib.Results;
with Jpeglib.Streams;
with System;
with Terminal.App.Cleanup_Diagnostics;
with Terminal.App.Borrowed_Bytes;

package body Terminal.App.JPEG_Decoder is
   use type Terminal.Common.Bytes.Byte;
   use type Jpeglib.Byte_Count;
   use type Jpeglib.Results.Result;
   use type Jpeglib.Streams.Byte_Array_Access;
   procedure Free_JPEG_Data is new Ada.Unchecked_Deallocation
     (Jpeglib.Streams.Byte_Array,
      Jpeglib.Streams.Byte_Array_Access);

   JPEG_Workspace_Multiplier : constant Positive := 8;
   Minimum_JPEG_Workspace_Bytes : constant Positive := 1 * 1024 * 1024;

   type JPEG_Data_Holder is
     new Ada.Finalization.Limited_Controlled with record
      Data : Jpeglib.Streams.Byte_Array_Access := null;
   end record;
   overriding procedure Finalize (Holder : in out JPEG_Data_Holder);

   type Decoder_Holder is
     new Ada.Finalization.Limited_Controlled with record
      Decoder     : Jpeglib.Decoding.Decoder;
      Initialized : Boolean := False;
   end record;
   overriding procedure Finalize (Holder : in out Decoder_Holder);

   overriding procedure Finalize (Holder : in out JPEG_Data_Holder) is
   begin
      if Holder.Data /= null then
         Free_JPEG_Data (Holder.Data);
      end if;
   exception
      when E : others =>
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Media_Decoder,
            E,
            "release JPEG input data");
   end Finalize;

   overriding procedure Finalize (Holder : in out Decoder_Holder) is
   begin
      if Holder.Initialized then
         Jpeglib.Decoding.Finalize (Holder.Decoder);
         Holder.Initialized := False;
      end if;
   exception
      when E : others =>
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Media_Decoder,
            E,
            "finalize JPEG decoder");
   end Finalize;

   type Borrowed_Source is limited new Jpeglib.Streams.Source with record
      Data : Terminal.App.Borrowed_Bytes.Cursor;
   end record;

   overriding function Read
     (Source : in out Borrowed_Source;
      Buffer : out Jpeglib.Streams.Byte_Array)
      return Jpeglib.Streams.Source_Result;
   overriding function Offset
     (Source : Borrowed_Source) return Jpeglib.Source_Offset;
   overriding function Skip
     (Source : in out Borrowed_Source;
      Count  : Jpeglib.Byte_Count) return Jpeglib.Streams.Source_Result;

   procedure Open
     (Source  : out Borrowed_Source;
      Address : System.Address;
      Length  : Natural) is
   begin
      Terminal.App.Borrowed_Bytes.Open (Source.Data, Address, Length);
   end Open;

   overriding function Read
     (Source : in out Borrowed_Source;
      Buffer : out Jpeglib.Streams.Byte_Array)
      return Jpeglib.Streams.Source_Result
   is
      To_Copy   : Natural;
   begin
      To_Copy := Natural'Min
        (Buffer'Length, Terminal.App.Borrowed_Bytes.Remaining (Source.Data));
      if To_Copy > 0 then
         for I in 0 .. To_Copy - 1 loop
            Buffer (Buffer'First + I) := Jpeglib.Byte
              (Terminal.App.Borrowed_Bytes.Read_Byte (Source.Data));
         end loop;
      end if;
      return
        (Result => Jpeglib.Errors.Make (Jpeglib.Errors.No_Error),
         Count => Jpeglib.Byte_Count (To_Copy),
         End_Of_Input => To_Copy = 0);
   end Read;

   overriding function Offset
     (Source : Borrowed_Source) return Jpeglib.Source_Offset is
     (Jpeglib.Source_Offset
        (Terminal.App.Borrowed_Bytes.Offset (Source.Data)));

   overriding function Skip
     (Source : in out Borrowed_Source;
      Count  : Jpeglib.Byte_Count) return Jpeglib.Streams.Source_Result
   is
      Available : constant Natural :=
        Terminal.App.Borrowed_Bytes.Remaining (Source.Data);
      To_Skip   : Natural;
   begin
      To_Skip :=
        (if Count > Jpeglib.Byte_Count (Natural'Last)
         then Available
         else Natural'Min (Natural (Count), Available));
      To_Skip := Terminal.App.Borrowed_Bytes.Skip (Source.Data, To_Skip);
      return
        (Result => Jpeglib.Errors.Make (Jpeglib.Errors.No_Error),
         Count => Jpeglib.Byte_Count (To_Skip),
         End_Of_Input => To_Skip = 0);
   end Skip;

   function Is_JPEG
     (Data : Terminal.Common.Bytes.Byte_Array;
      Length : Natural) return Boolean is
     (Length >= 2
      and then Length <= Data'Length
      and then Data (Data'First) = 16#FF#
      and then Data (Data'First + 1) = 16#D8#);

   function RGBA_Length (Width, Height : Natural) return Natural is
   begin
      if Width = 0
        or else Height = 0
        or else Width > Natural'Last / 4
        or else Height > Natural'Last / (Width * 4)
      then
         return 0;
      end if;
      return Width * Height * 4;
   end RGBA_Length;

   function Limit_Exceeded (Outcome : Jpeglib.Results.Result) return Boolean is
     (Outcome.First_Error.Code in
        Jpeglib.Errors.Pixel_Count_Exceeded
        | Jpeglib.Errors.Metadata_Limit_Exceeded
        | Jpeglib.Errors.Output_Limit_Exceeded);

   procedure Decode
     (JPEG                    : Terminal.Common.Bytes.Byte_Array;
      Length                  : Natural;
      Maximum_Decoded_Bytes   : Decode_Byte_Limit;
      Maximum_Pixel_Dimension : Positive;
      Pixels                  : in out Terminal.App.Owned_Image_Data.Owner;
      Pixel_Width             : out Natural;
      Pixel_Height            : out Natural;
      Status                  : out Decode_Status)
   is
   begin
      Terminal.App.Owned_Image_Data.Release (Pixels);
      Pixel_Width := 0;
      Pixel_Height := 0;
      Status := Decode_Unsupported;
      if not Is_JPEG (JPEG, Length) then
         return;
      end if;

      declare
         Source  : aliased Borrowed_Source;
         Decoder : Decoder_Holder;
         Outcome : Jpeglib.Results.Result;
         Info    : Jpeglib.Decoding.Image_Info;
         Dimension_Limit : constant Natural := Natural'Min
           (Maximum_Pixel_Dimension, Natural (Jpeglib.Image_Width'Last));
         Byte_Limit : constant Jpeglib.Byte_Count :=
           Jpeglib.Byte_Count (Maximum_Decoded_Bytes);
         Workspace_Bytes : constant Jpeglib.Byte_Count :=
           Jpeglib.Byte_Count
             (Natural'Min
                (Terminal.Common.Graphics_Limits.Max_Image_Bytes,
                 Natural'Max
                   (Minimum_JPEG_Workspace_Bytes,
                    Maximum_Decoded_Bytes * JPEG_Workspace_Multiplier)));
         Metadata_Bytes : constant Jpeglib.Byte_Count :=
           Jpeglib.Byte_Count
             (Natural'Min
                (Length,
                 Terminal.Common.Graphics_Limits.Max_Image_Bytes));
         Limits : constant Jpeglib.Limits.Limit_Set :=
           (Jpeglib.Limits.Default_Limits with delta
              Max_Width => Jpeglib.Image_Width (Dimension_Limit),
              Max_Height => Jpeglib.Image_Height (Dimension_Limit),
              Max_Pixels =>
                Jpeglib.Pixel_Count (Maximum_Decoded_Bytes / 4),
              Max_Coefficient_Bytes => Workspace_Bytes,
              Max_Output_Bytes => Byte_Limit,
              Max_Allocation_Bytes => Workspace_Bytes,
              Max_Metadata_Bytes => Metadata_Bytes,
              Max_ICC_Profile_Bytes => Metadata_Bytes);
      begin
         Open (Source, JPEG (JPEG'First)'Address, Length);
         Jpeglib.Decoding.Initialize
           (Decoder.Decoder,
            Source'Access,
            (Output_Format => Jpeglib.Images.RGBA_32,
             Alpha_Fill    => 255,
             others        => <>),
            Limits);
         Decoder.Initialized := True;
         Outcome := Jpeglib.Decoding.Read_Header (Decoder.Decoder);
         if not Jpeglib.Results.Succeeded (Outcome) then
            Status :=
              (if Limit_Exceeded (Outcome)
               then Decode_Too_Large
               else Decode_Invalid);
            return;
         end if;

         Info := Jpeglib.Decoding.Header (Decoder.Decoder);
         Pixel_Width := Natural (Info.Width);
         Pixel_Height := Natural (Info.Height);
         declare
            RGBA_Bytes : constant Natural :=
              RGBA_Length (Pixel_Width, Pixel_Height);
         begin
            if Pixel_Width = 0
              or else Pixel_Height = 0
              or else Pixel_Width > Maximum_Pixel_Dimension
              or else Pixel_Height > Maximum_Pixel_Dimension
              or else RGBA_Bytes = 0
              or else RGBA_Bytes > Maximum_Decoded_Bytes
            then
               Status := Decode_Too_Large;
               return;
            end if;

            declare
               JPEG_Data : JPEG_Data_Holder;
               Result    : Terminal.App.Owned_Image_Data.Owner;
            begin
               JPEG_Data.Data :=
                 new Jpeglib.Streams.Byte_Array (1 .. RGBA_Bytes);
               declare
                  View : Jpeglib.Images.Mutable_Image_View :=
                    (Descriptor =>
                       (Width            => Info.Width,
                        Height           => Info.Height,
                        Format           => Jpeglib.Images.RGBA_32,
                        Stride           =>
                          Jpeglib.Row_Stride (Pixel_Width * 4),
                        Accessible_Bytes => Jpeglib.Byte_Count (RGBA_Bytes)),
                     Storage => JPEG_Data.Data);
               begin
                  Outcome :=
                    Jpeglib.Decoding.Decode_Image (Decoder.Decoder, View);
                  if not Jpeglib.Results.Succeeded (Outcome) then
                     Status :=
                       (if Limit_Exceeded (Outcome)
                        then Decode_Too_Large
                        else Decode_Invalid);
                     return;
                  end if;
               end;
               --  The public renderer buffer has a distinct Ada array type.
               --  Copy only after a successful decode so failures never
               --  publish or retain partially decoded pixels.
               Terminal.App.Owned_Image_Data.Allocate (Result, RGBA_Bytes);
               declare
                  procedure Copy_Output
                    (Data : in out Terminal.Common.Bytes.Byte_Array) is
                  begin
                     for Index in Data'Range loop
                        Data (Index) :=
                          Terminal.Common.Bytes.Byte (JPEG_Data.Data (Index));
                     end loop;
                  end Copy_Output;
               begin
                  Terminal.App.Owned_Image_Data.Modify
                    (Result, Copy_Output'Access);
               end;
               Terminal.App.Owned_Image_Data.Move (Result, Pixels);
               Status := Decode_Ok;
            end;
         end;
      end;
   exception
      when Storage_Error =>
         Terminal.App.Owned_Image_Data.Release (Pixels);
         Status := Decode_Allocation_Failed;
      when Constraint_Error =>
         Terminal.App.Owned_Image_Data.Release (Pixels);
         Status := Decode_Too_Large;
   end Decode;
end Terminal.App.JPEG_Decoder;

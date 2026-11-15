with Ada.Finalization;
with Terminal.Common.Bytes;
with Terminal.Common.Graphics_Limits;
with Terminal.App.Image_Decode;
with Terminal.App.Render_Model;
with Terminal.App.Owned_Image_Data;
with Interfaces;

package Terminal.App.Image_Media is
   --  Native decoders may retain one configured workspace quota while the
   --  adapter owns a result and one composition/output canvas.
   Max_Transient_Decode_Multiplier : constant := 3;
   Max_Frames : constant :=
     Terminal.Common.Graphics_Limits.Max_Animation_Frames;
   subtype Decode_Byte_Limit is Positive range
     1 .. Terminal.Common.Graphics_Limits.Max_Image_Bytes;

   subtype Decode_Status is Terminal.App.Image_Decode.Status;
   Decode_Ok : constant Decode_Status :=
     Terminal.App.Image_Decode.Decode_Ok;
   Decode_Unavailable : constant Decode_Status :=
     Terminal.App.Image_Decode.Decode_Unsupported_Format;
   Decode_Invalid : constant Decode_Status :=
     Terminal.App.Image_Decode.Decode_Invalid_Data;
   Decode_Too_Large : constant Decode_Status :=
     Terminal.App.Image_Decode.Decode_Too_Large;
   Decode_Allocation_Failed : constant Decode_Status :=
     Terminal.App.Image_Decode.Decode_Allocation_Failed;

   Max_Diagnostic_Identifier_Length : constant := 96;

   type Decode_Limit_Kind is
     (No_Limit,
      Frame_Width_Limit,
      Frame_Height_Limit,
      Frame_Count_Limit,
      Frame_Pixel_Limit,
      Canvas_Pixel_Limit,
      Canvas_Byte_Limit,
      Total_Decoded_Pixel_Limit,
      Picture_Byte_Limit,
      Compressed_Byte_Limit,
      Extension_Count_Limit,
      Per_Extension_Byte_Limit,
      Opcode_Count_Limit,
      Opcode_Byte_Limit,
      Region_Byte_Limit,
      Polygon_Point_Limit,
      Drawing_Work_Limit,
      LZW_Work_Limit,
      Quantization_Work_Limit,
      Optimization_Work_Limit,
      Retained_Metadata_Byte_Limit,
      Metadata_Item_Limit,
      Allocation_Byte_Limit,
      Total_Allocation_Byte_Limit,
      Output_Byte_Limit,
      Embedded_Image_Byte_Limit,
      Embedded_Image_Pixel_Limit,
      Warning_Record_Limit,
      Snapshot_Byte_Limit);

   type Decode_Diagnostic is record
      Present : Boolean := False;
      Identifier_Length : Natural range 0 .. Max_Diagnostic_Identifier_Length := 0;
      Identifier : String (1 .. Max_Diagnostic_Identifier_Length) :=
        (others => ASCII.NUL);
      Source_Offset : Interfaces.Unsigned_64 := 0;
      Destination_Offset : Interfaces.Unsigned_64 := 0;
      Has_Opcode : Boolean := False;
      Opcode : Natural := 0;
      Opcode_Ordinal : Interfaces.Unsigned_64 := 0;
      Row : Interfaces.Unsigned_64 := 0;
      Expected : Interfaces.Unsigned_64 := 0;
      Actual : Interfaces.Unsigned_64 := 0;
      Limit : Decode_Limit_Kind := No_Limit;
      Has_Underlying_Code : Boolean := False;
      Underlying_Code : Long_Long_Integer := 0;
   end record;

   function Diagnostic_Identifier (Item : Decode_Diagnostic) return String;

   type Decoded_Image is
     new Ada.Finalization.Limited_Controlled with private;

   overriding procedure Finalize (Result : in out Decoded_Image);
   function Pixel_Width (Result : Decoded_Image) return Natural;
   function Pixel_Height (Result : Decoded_Image) return Natural;
   function Frame_Count (Result : Decoded_Image) return Natural;
   function Loop_Count (Result : Decoded_Image) return Natural;
   function Frame_Bytes (Result : Decoded_Image) return Natural;
   function Total_Bytes (Result : Decoded_Image) return Natural;
   function Adapter_Buffer_Bytes (Result : Decoded_Image) return Natural;
   function Decoder_Configured_Bytes (Result : Decoded_Image) return Natural;
   function Delay_MS
     (Result : Decoded_Image;
      Frame  : Positive) return Natural;
   function Diagnostic (Result : Decoded_Image) return Decode_Diagnostic;
   function Warning_Count (Result : Decoded_Image) return Natural;
   function First_Warning (Result : Decoded_Image) return Decode_Diagnostic;
   function Has_Bytes (Result : Decoded_Image) return Boolean;
   function Byte_Length (Result : Decoded_Image) return Natural;
   function Byte_At
     (Result : Decoded_Image; Index : Positive)
      return Terminal.Common.Bytes.Byte;
   procedure Copy_Frame
     (Result : Decoded_Image;
      Frame  : Positive;
      Target : out Terminal.Common.Bytes.Byte_Array);

   --  Native GIF and PICT decoding is always available.
   function Available return Boolean;

   procedure Decode
     (Data                    : Terminal.Common.Bytes.Byte_Array;
      Length                  : Natural;
      Maximum_Decoded_Bytes   : Decode_Byte_Limit;
      Maximum_Pixel_Dimension : Positive;
      Result                  : in out Decoded_Image;
      Status                  : out Decode_Status;
      Maximum_Frames          : Positive := Max_Frames);

   procedure Release (Result : in out Decoded_Image);
   procedure Move_Bytes
     (Result : in out Decoded_Image;
      Target : in out Terminal.App.Owned_Image_Data.Owner);

private
   type Frame_Delay_Array is array (Positive range <>) of Natural;
   type Frame_Delay_Array_Access is access Frame_Delay_Array;
   type Decoded_Image_Storage is limited record
      Bytes : Terminal.App.Owned_Image_Data.Owner;
   end record;
   type Decoded_Image is new Ada.Finalization.Limited_Controlled with record
      Storage      : Decoded_Image_Storage;
      Pixel_Width  : Natural := 0;
      Pixel_Height : Natural := 0;
      Frame_Count  : Natural range 0 .. Max_Frames := 0;
      Loop_Count   : Natural := 1;
      Frame_Bytes  : Natural := 0;
      Total_Bytes  : Natural := 0;
      --  Adapter_Buffer_Bytes counts explicit encoded, canvas, result, and
      --  frame-delay buffers owned by this adapter at its widest point.
      --  Decoder_Configured_Bytes is the format-specific decoder allocation
      --  budget. Container nodes, allocator/runtime bookkeeping, font-library
      --  state, and GPU storage are excluded. Native PICT input is borrowed
      --  and renders directly into Bytes.
      Adapter_Buffer_Bytes : Natural := 0;
      Decoder_Configured_Bytes : Natural := 0;
      Delays_MS    : Frame_Delay_Array_Access := null;
      Diagnostic   : Decode_Diagnostic;
      Warning_Count : Natural := 0;
      First_Warning : Decode_Diagnostic;
   end record;
end Terminal.App.Image_Media;

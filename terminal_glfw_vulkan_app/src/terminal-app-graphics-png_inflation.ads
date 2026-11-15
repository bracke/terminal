with Ada.Finalization;
with Ada.Streams;
with Interfaces;
with Terminal.Common.Bytes;
with Terminal.App.Inflate_Filter;

private package Terminal.App.Graphics.PNG_Inflation is
   type Decoder is limited private;

   procedure Initialize
     (State : in out Decoder;
      Compressed_Length, Expected_Length : Natural;
      Source : not null access function
        (Index : Positive) return Terminal.Common.Bytes.Byte;
      Status : out Data_Decode_Status);

   function Next
     (State : in out Decoder;
      Source : not null access function
        (Index : Positive) return Terminal.Common.Bytes.Byte;
      Status : out Data_Decode_Status) return Terminal.Common.Bytes.Byte;

   procedure Finish
     (State : in out Decoder;
      Source : not null access function
        (Index : Positive) return Terminal.Common.Bytes.Byte;
      Status : out Data_Decode_Status);

   function Produced_Length (State : Decoder) return Natural;

private
   type Lifecycle_State is (Idle, Active, Ended, Failed);
   type Decoder is new Ada.Finalization.Limited_Controlled with record
      Filter          : Terminal.App.Inflate_Filter.Decoder;
      State           : Lifecycle_State := Idle;
      Deflate_Pos     : Natural := 0;
      Deflate_Last    : Natural := 0;
      Expected_Length : Natural := 0;
      Produced        : Natural := 0;
      Adler_A         : Interfaces.Unsigned_32 := 1;
      Adler_B         : Interfaces.Unsigned_32 := 0;
      Expected_Adler  : Interfaces.Unsigned_32 := 0;
      Output          : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Output_Last     : Ada.Streams.Stream_Element_Offset := 0;
      Output_Pos      : Ada.Streams.Stream_Element_Offset := 1;
   end record;

   overriding procedure Finalize (State : in out Decoder);
end Terminal.App.Graphics.PNG_Inflation;

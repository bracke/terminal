separate (Graphics_Capabilities_Smoke)
procedure Run_Decoding_Matrix is
   package Fixture_State is new Graphics_Capabilities_Fixtures;
   use Fixture_State;

   package Fixture_Helpers is
      function Base64_Encode
        (Data   : Jpeglib.Streams.Byte_Array;
         Length : Natural) return String;
      procedure Build_JPEG;
      procedure Reset_And_Initialize_Fixtures;
      procedure Capture_PNG_Row
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      function PNG_Source_Byte
        (Index : Positive) return Terminal.Common.Bytes.Byte;
      procedure Capture_PNG_Source_Row
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      function Base64_PNG_Text (Index : Positive) return String;
      function Base64_PNG_Invalid_Text (Index : Positive) return String;
      function Base64_PNG_Not_PNG_Text (Index : Positive) return String;
      function Base64_PNG_Trailing_Text (Index : Positive) return String;
      procedure Capture_Base64_PNG_Row
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      procedure Reject_Base64_PNG_Row
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      procedure Capture_Sixel_Row
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      procedure Capture_Raw_Row
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      function Raw_Chunk_Text (Index : Positive) return String;
      procedure Capture_Raw_Chunk_Row
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      function Zlib_Raw_Chunk_Text (Index : Positive) return String;
      function Zlib_Raw_Invalid_Text (Index : Positive) return String;
      procedure Capture_Zlib_Raw_Row
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      function Zlib_PNG_Chunk_Text (Index : Positive) return String;
      procedure Capture_Zlib_PNG_Row
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      function Base64_Chunk_Text (Index : Positive) return String;
      function Base64_Trailing_Text (Index : Positive) return String;
      procedure Capture_Base64_Byte
        (Value : Terminal.Common.Bytes.Byte;
         Continue : in out Boolean);
      procedure Count_Base64_Trailing_Byte
        (Value : Terminal.Common.Bytes.Byte;
         Continue : in out Boolean);
      function Adam7_Base64_Text (Index : Positive) return String;
      procedure Capture_Adam7_PNG_Byte
        (Value : Terminal.Common.Bytes.Byte;
         Continue : in out Boolean);
      procedure Capture_Adam7_Row
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
   end Fixture_Helpers;

   package body Fixture_Helpers is separate;
   use Fixture_Helpers;

   procedure Assert_Storage_Invariant
     (Data  : Graphics.Graphics_Data_Preview;
      Label : String) is
   begin
      Assert
        (not Data.Decode_Complete or else Data.Decoded_Length > 0,
         Label & " completed decode has a nonempty extent");
   end Assert_Storage_Invariant;

   procedure Run_Decode_Core is separate;
   procedure Run_Decode_Formats is separate;
begin
   Run_Decode_Core;
   Run_Decode_Formats;

end Run_Decoding_Matrix;

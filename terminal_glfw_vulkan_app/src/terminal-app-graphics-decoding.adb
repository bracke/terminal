with Terminal.App.Graphics.Transport_Decoders;

package body Terminal.App.Graphics.Decoding is
   procedure Decode_Base64_Preview
     (Text : String; Result : in out Graphics_Data_Preview;
      Expected_Decoded_Length : Natural := 0)
      renames Transport_Decoders.Decode_Base64_Preview;
   procedure Decode_Base64_Data
     (Text : String; Maximum_Decoded_Bytes : Positive;
      Data : in out Terminal.App.Owned_Image_Data.Owner;
      Length : out Natural; Status : out Data_Decode_Status)
      renames Transport_Decoders.Decode_Base64_Data;
   procedure Decode_Zlib_Data
     (Compressed : Terminal.Common.Bytes.Byte_Array; Length : Natural;
      Maximum_Length : Natural; Exact_Length : Boolean;
      Inflated : in out Terminal.App.Owned_Image_Data.Owner;
      Inflated_Length : out Natural; Status : out Data_Decode_Status)
      renames Transport_Decoders.Decode_Zlib_Data;
   procedure Decode_Base64_Chunk_Bytes
     (Chunk_Count : Natural;
      Chunk_Text : not null access function (Index : Positive) return String;
      Byte_Sink : not null access procedure
        (Value : Terminal.Common.Bytes.Byte; Continue : in out Boolean);
      Result : in out Graphics_Data_Preview)
      renames Transport_Decoders.Decode_Base64_Chunk_Bytes;
   procedure Decode_Base64_PNG_Chunk_Rows
     (Chunk_Count : Natural;
      Chunk_Text : not null access function (Index : Positive) return String;
      Encoded_Length, PNG_Length : out Natural;
      Row_Sink : not null access procedure
        (Y : Natural; Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result : in out Graphics_Data_Preview)
      renames Transport_Decoders.Decode_Base64_PNG_Chunk_Rows;
   procedure Decode_Base64_Raw_Rows
     (Text : String; Raw_Format, Pixel_Width, Pixel_Height : Natural;
      Row_Sink : not null access procedure
        (Y : Natural; Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result : in out Graphics_Data_Preview)
      renames Transport_Decoders.Decode_Base64_Raw_Rows;
   procedure Decode_Base64_Raw_Chunk_Rows
     (Chunk_Count : Natural;
      Chunk_Text : not null access function (Index : Positive) return String;
      Raw_Format, Pixel_Width, Pixel_Height : Natural;
      Row_Sink : not null access procedure
        (Y : Natural; Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result : in out Graphics_Data_Preview)
      renames Transport_Decoders.Decode_Base64_Raw_Chunk_Rows;
   procedure Decode_Base64_Zlib_Raw_Chunk_Rows
     (Chunk_Count : Natural;
      Chunk_Text : not null access function (Index : Positive) return String;
      Raw_Format, Pixel_Width, Pixel_Height : Natural;
      Row_Sink : not null access procedure
        (Y : Natural; Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result : in out Graphics_Data_Preview)
      renames Transport_Decoders.Decode_Base64_Zlib_Raw_Chunk_Rows;
   procedure Decode_Base64_Zlib_PNG_Chunk_Rows
     (Chunk_Count : Natural;
      Chunk_Text : not null access function (Index : Positive) return String;
      Inflated_Length : Natural; Encoded_Length : out Natural;
      Row_Sink : not null access procedure
        (Y : Natural; Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result : in out Graphics_Data_Preview)
      renames Transport_Decoders.Decode_Base64_Zlib_PNG_Chunk_Rows;
end Terminal.App.Graphics.Decoding;

with Terminal.Common.Base64;
with Terminal.App.Graphics.Base64_Sizing;
with Terminal.App.Graphics.Pixel_Layout;
with Terminal.App.Graphics.Preview_Storage;
with Terminal.App.Graphics.Media_Decoders;
with Terminal.App.Owned_Image_Data;
with Terminal.App.Zlib_Inflation;

package body Terminal.App.Graphics.Transport_Decoders is
   use type Terminal.Common.Base64.Decoder_Status;
   use type Terminal.Common.Bytes.Byte;
   use type Data_Decode_Status;
   use type Terminal.App.Render_Model.Image_Data_View;
   use Terminal.App.Graphics.Pixel_Layout;
   use Terminal.App.Graphics.Preview_Storage;

   function Base64_Decoded_Length
     (Text : String; Length : out Natural) return Boolean
      renames Terminal.App.Graphics.Base64_Sizing.Decoded_Length;

   subtype Image_Data_Holder is Terminal.App.Owned_Image_Data.Owner;

   procedure Decode_Base64_Preview
     (Text : String; Result : in out Graphics_Data_Preview;
      Expected_Decoded_Length : Natural := 0)
   is separate;

   procedure Decode_Base64_Data
     (Text : String; Maximum_Decoded_Bytes : Positive;
      Data : in out Terminal.App.Owned_Image_Data.Owner;
      Length : out Natural; Status : out Data_Decode_Status)
   is separate;

   procedure Decode_Base64_Chunk_Bytes
     (Chunk_Count : Natural;
      Chunk_Text : not null access function (Index : Positive) return String;
      Byte_Sink : not null access procedure
        (Value : Terminal.Common.Bytes.Byte; Continue : in out Boolean);
      Result : in out Graphics_Data_Preview)
   is separate;

   procedure Decode_Zlib_Data
     (Compressed : Terminal.Common.Bytes.Byte_Array; Length : Natural;
      Maximum_Length : Natural; Exact_Length : Boolean;
      Inflated : in out Terminal.App.Owned_Image_Data.Owner;
      Inflated_Length : out Natural; Status : out Data_Decode_Status)
   is separate;

   procedure Decode_Base64_Zlib_Chunks
     (Chunk_Count : Natural;
      Chunk_Text : not null access function (Index : Positive) return String;
      Maximum_Length : Natural; Exact_Length : Boolean;
      Inflated : in out Terminal.App.Owned_Image_Data.Owner;
      Inflated_Length : out Natural; Encoded_Length : out Natural;
      Status : out Data_Decode_Status)
   is separate;

   procedure Decode_Base64_Zlib_Raw_Chunk_Rows
     (Chunk_Count : Natural;
      Chunk_Text : not null access function (Index : Positive) return String;
      Raw_Format, Pixel_Width, Pixel_Height : Natural;
      Row_Sink : not null access procedure
        (Y : Natural; Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result : in out Graphics_Data_Preview)
   is separate;

   procedure Decode_Base64_Zlib_PNG_Chunk_Rows
     (Chunk_Count : Natural;
      Chunk_Text : not null access function (Index : Positive) return String;
      Inflated_Length : Natural; Encoded_Length : out Natural;
      Row_Sink : not null access procedure
        (Y : Natural; Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result : in out Graphics_Data_Preview)
   is separate;

   procedure Decode_Base64_PNG_Chunk_Rows
     (Chunk_Count : Natural;
      Chunk_Text : not null access function (Index : Positive) return String;
      Encoded_Length, PNG_Length : out Natural;
      Row_Sink : not null access procedure
        (Y : Natural; Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result : in out Graphics_Data_Preview)
   is separate;

   procedure Decode_Base64_Raw_Chunk_Rows
     (Chunk_Count : Natural;
      Chunk_Text : not null access function (Index : Positive) return String;
      Raw_Format, Pixel_Width, Pixel_Height : Natural;
      Row_Sink : not null access procedure
        (Y : Natural; Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result : in out Graphics_Data_Preview)
   is separate;

   procedure Decode_Base64_Raw_Rows
     (Text : String; Raw_Format, Pixel_Width, Pixel_Height : Natural;
      Row_Sink : not null access procedure
        (Y : Natural; Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result : in out Graphics_Data_Preview)
   is separate;
end Terminal.App.Graphics.Transport_Decoders;

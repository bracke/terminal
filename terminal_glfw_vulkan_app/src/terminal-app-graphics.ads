with Terminal.Common.Bytes;
with Terminal.App.Render_Model;
with Terminal.Core;

package Terminal.App.Graphics is
   Max_Status_Label_Length : constant := 64;
   Max_Data_Preview_Length : constant :=
     Terminal.App.Render_Model.Max_Image_Decoded_Data_Length;

   type Graphics_Protocol is
     (Sixel,
      Kitty,
      ITerm2);

   type Protocol_Capability is record
      Recognized : Boolean := True;
      Decoded    : Boolean := False;
      Rendered   : Boolean := False;
   end record;

   type Emoji_Capability is record
      Cluster_Preserved    : Boolean := True;
      Monochrome_Fallback  : Boolean := True;
      Color_Glyph_Rendered : Boolean := False;
   end record;

   type Graphics_Header is record
      Recognized       : Boolean := False;
      Has_Data         : Boolean := False;
      Kitty_More       : Boolean := False;
      Kitty_Action     : Character := ASCII.NUL;
      Kitty_ID         : Natural := 0;
      Kitty_Format     : Natural := 0;
      Raw_Format       : Natural := 0;
      Pixel_Width      : Natural := 0;
      Pixel_Height     : Natural := 0;
      ITerm2_Inline    : Boolean := False;
      ITerm2_Name_Length : Natural := 0;
      Placeholder_Cols : Positive := 4;
      Placeholder_Rows : Positive := 2;
   end record;

   subtype Data_Preview_Length_Range is Natural range 0 .. Max_Data_Preview_Length;

   type Data_Decode_Status is
     (Decode_Not_Attempted,
      Decode_Ok,
      Decode_Invalid_Byte,
      Decode_Trailing_Data,
      Decode_Preview_Truncated,
      Decode_Unsupported_Format);

   type Graphics_Data_Preview is record
      Header_Recognized : Boolean := False;
      Has_Data          : Boolean := False;
      Encoded_Length    : Natural := 0;
      Raw_Format        : Natural := 0;
      Pixel_Width       : Natural := 0;
      Pixel_Height      : Natural := 0;
      Decoded_Length    : Data_Preview_Length_Range := 0;
      Decoded_Row_Stride_Bytes : Natural := 0;
      Decode_Complete   : Boolean := False;
      Decode_Status     : Data_Decode_Status := Decode_Not_Attempted;
      Bytes             : Terminal.App.Render_Model.Image_Data_Access := null;
   end record;

   function Capability
     (Protocol : Graphics_Protocol) return Protocol_Capability;
   function Color_Emoji return Emoji_Capability;
   function Name (Protocol : Graphics_Protocol) return String;
   function Name (Protocol : Terminal.Core.Ignored_Graphics_Protocol)
                  return String;
   function Capability_Status_Label
     (Protocol : Graphics_Protocol) return String;
   function Header (Event : Terminal.Core.Graphics_Event) return Graphics_Header;
   function Header_Text
     (Protocol : Terminal.Core.Ignored_Graphics_Protocol;
      Text     : String) return Graphics_Header;
   function Data_Preview
     (Event : Terminal.Core.Graphics_Event) return Graphics_Data_Preview;
   function Data_Preview_Text
     (Protocol : Terminal.Core.Ignored_Graphics_Protocol;
      Text     : String) return Graphics_Data_Preview;
   procedure Decode_PNG_RGBA_Data
     (PNG    : Terminal.Common.Bytes.Byte_Array;
      Length : Natural;
      Result : in out Graphics_Data_Preview);
   procedure Decode_PNG_RGBA_Source_Rows
     (Length   : Natural;
      PNG_Byte : not null access function
        (Index : Positive) return Terminal.Common.Bytes.Byte;
      Row_Sink : not null access procedure
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result   : in out Graphics_Data_Preview);
   procedure Decode_PNG_RGBA_Rows
     (PNG      : Terminal.Common.Bytes.Byte_Array;
      Length   : Natural;
      Row_Sink : not null access procedure
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result   : in out Graphics_Data_Preview);
   procedure Decode_Sixel_Rows
     (Text     : String;
      Row_Sink : not null access procedure
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result   : in out Graphics_Data_Preview);
   procedure Decode_Base64_Chunk_Bytes
     (Chunk_Count : Natural;
      Chunk_Text  : not null access function (Index : Positive) return String;
      Byte_Sink   : not null access procedure
        (Value : Terminal.Common.Bytes.Byte;
         Continue : in out Boolean);
      Result      : in out Graphics_Data_Preview);
   procedure Decode_Base64_PNG_Chunk_Rows
     (Chunk_Count    : Natural;
      Chunk_Text     : not null access function (Index : Positive) return String;
      Encoded_Length : out Natural;
      PNG_Length     : out Natural;
      Row_Sink       : not null access procedure
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result         : in out Graphics_Data_Preview);
   procedure Decode_Base64_Raw_Rows
     (Text         : String;
      Raw_Format   : Natural;
      Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Row_Sink     : not null access procedure
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result       : in out Graphics_Data_Preview);
   procedure Decode_Base64_Raw_Chunk_Rows
     (Chunk_Count  : Natural;
      Chunk_Text   : not null access function (Index : Positive) return String;
      Raw_Format   : Natural;
      Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Row_Sink     : not null access procedure
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result       : in out Graphics_Data_Preview);
   procedure Release (Data : in out Graphics_Data_Preview);
   function Data_Decode_Status_Suffix
     (Status : Data_Decode_Status) return String;
   function Image_Decode_Status
     (Status : Data_Decode_Status)
      return Terminal.App.Render_Model.Image_Decode_Status;
   function Data_Status_Label
     (Event : Terminal.Core.Graphics_Event) return String;
   function Header_Status_Label
     (Event : Terminal.Core.Graphics_Event) return String;
   function Placeholder_Cols
     (Event : Terminal.Core.Graphics_Event) return Positive;
   function Placeholder_Rows
     (Event : Terminal.Core.Graphics_Event) return Positive;
   function Ignored_Status_Label
     (Diagnostics : Terminal.Core.Diagnostic_Snapshot) return String;
end Terminal.App.Graphics;

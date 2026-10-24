with Terminal.Common.Bytes;
with Terminal.App.Render_Model;
with Terminal.Core;

package Terminal.App.Graphics is
   Max_Status_Label_Length : constant := 64;
   Max_Data_Preview_Length : constant :=
     Terminal.App.Render_Model.Max_Image_Decoded_Data_Length;
   Max_Sixel_Pixel_Dimension : constant := 16_384;

   type Graphics_Protocol is
     (Sixel,
      Kitty,
      ITerm2);

   type Sixel_Color is record
      R : Terminal.Common.Bytes.Byte := 16#FF#;
      G : Terminal.Common.Bytes.Byte := 16#FF#;
      B : Terminal.Common.Bytes.Byte := 16#FF#;
      A : Terminal.Common.Bytes.Byte := 16#FF#;
   end record;
   type Sixel_Palette_State is
     array (Natural range 0 .. 255) of Sixel_Color;
   function Default_Sixel_Palette return Sixel_Palette_State;

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

   type ITerm2_Size_Unit is
     (ITerm2_Auto, ITerm2_Cells, ITerm2_Pixels, ITerm2_Percent);

   type Graphics_Header is record
      Recognized       : Boolean := False;
      Has_Data         : Boolean := False;
      Kitty_Control_Data_Valid : Boolean := True;
      Kitty_Action_Controls_Valid : Boolean := True;
      Kitty_More       : Boolean := False;
      Kitty_More_Specified : Boolean := False;
      Kitty_More_Valid : Boolean := True;
      Kitty_Action     : Character := ASCII.NUL;
      Kitty_Transmission : Character := ASCII.NUL;
      Kitty_Transmission_Specified : Boolean := False;
      Kitty_Transmission_Valid : Boolean := True;
      Kitty_Compression : Character := ASCII.NUL;
      Kitty_Compression_Specified : Boolean := False;
      Kitty_Compression_Valid : Boolean := True;
      Kitty_Delete     : Character := ASCII.NUL;
      Kitty_Delete_Controls_Valid : Boolean := True;
      Kitty_Delete_Range_First : Terminal.Core.Graphics_ID := 0;
      Kitty_Delete_Range_Last  : Terminal.Core.Graphics_ID := 0;
      Kitty_ID         : Terminal.Core.Graphics_ID := 0;
      Kitty_Image_Number : Terminal.Core.Graphics_ID := 0;
      Kitty_Placement_ID : Terminal.Core.Graphics_ID := 0;
      Kitty_Quiet      : Natural := 0;
      Kitty_Usage_Hint : Natural := 0;
      Kitty_Format     : Natural := 0;
      Raw_Format       : Natural := 0;
      Pixel_Width      : Natural := 0;
      Pixel_Height     : Natural := 0;
      Sixel_Transparent : Boolean := False;
      Kitty_Data_Size  : Natural := 0;
      Kitty_Data_Size_Specified : Boolean := False;
      Kitty_Data_Size_Valid : Boolean := True;
      Kitty_Data_Offset : Natural := 0;
      Kitty_Data_Offset_Specified : Boolean := False;
      Kitty_Data_Offset_Valid : Boolean := True;
      Kitty_Source_X   : Natural := 0;
      Kitty_Source_Y   : Natural := 0;
      Kitty_Source_Width : Natural := 0;
      Kitty_Source_Height : Natural := 0;
      Kitty_Cell_X     : Natural := 0;
      Kitty_Cell_Y     : Natural := 0;
      Kitty_Z_Index    : Integer := 0;
      Kitty_No_Cursor_Move : Boolean := False;
      Kitty_Virtual_Placement : Boolean := False;
      Kitty_Parent_ID  : Terminal.Core.Graphics_ID := 0;
      Kitty_Parent_Placement_ID : Terminal.Core.Graphics_ID := 0;
      Kitty_Parent_Offset_X : Integer := 0;
      Kitty_Parent_Offset_Y : Integer := 0;
      Kitty_Frame_Number : Natural := 0;
      Kitty_Base_Frame : Natural := 0;
      Kitty_Frame_Gap : Integer := 0;
      Kitty_Composition_Mode : Natural := 0;
      Kitty_Background_Color : Terminal.Core.Graphics_ID := 0;
      Kitty_Animation_State : Natural := 0;
      Kitty_Loop_Count : Natural := 0;
      ITerm2_Inline    : Boolean := False;
      ITerm2_Control_Data_Valid : Boolean := True;
      ITerm2_Name_Length : Natural := 0;
      ITerm2_Declared_Size : Natural := 0;
      ITerm2_Declared_Size_Valid : Boolean := True;
      ITerm2_Preserve_Aspect_Ratio : Boolean := True;
      ITerm2_Do_Not_Move_Cursor : Boolean := False;
      ITerm2_Width_Specified : Boolean := False;
      ITerm2_Height_Specified : Boolean := False;
      ITerm2_Width_Valid : Boolean := True;
      ITerm2_Height_Valid : Boolean := True;
      ITerm2_Width_Value : Natural := 0;
      ITerm2_Height_Value : Natural := 0;
      ITerm2_Width_Unit : ITerm2_Size_Unit := ITerm2_Auto;
      ITerm2_Height_Unit : ITerm2_Size_Unit := ITerm2_Auto;
      Kitty_Columns_Specified : Boolean := False;
      Kitty_Columns_Valid : Boolean := True;
      Kitty_Rows_Specified : Boolean := False;
      Kitty_Rows_Valid : Boolean := True;
      Kitty_Geometry_Controls_Valid : Boolean := True;
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
   procedure Decode_JPEG_RGBA_Data
     (JPEG   : Terminal.Common.Bytes.Byte_Array;
      Length : Natural;
      Result : in out Graphics_Data_Preview;
      Maximum_Decoded_Bytes : Positive := Max_Data_Preview_Length;
      Maximum_Pixel_Dimension : Positive := Positive'Last);
   function JPEG_Data_Preview_Text
     (Text                    : String;
      Maximum_Decoded_Bytes   : Positive;
      Maximum_Pixel_Dimension : Positive) return Graphics_Data_Preview;
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
      Result   : in out Graphics_Data_Preview;
      Maximum_Decoded_Bytes : Positive := Max_Data_Preview_Length;
      Maximum_Pixel_Dimension : Positive := Max_Sixel_Pixel_Dimension);
   procedure Decode_Sixel_Rows
     (Text          : String;
      Row_Sink      : not null access procedure
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Palette       : in out Sixel_Palette_State;
      Reset_Palette : Boolean;
      Result        : in out Graphics_Data_Preview;
      Maximum_Decoded_Bytes : Positive := Max_Data_Preview_Length;
      Maximum_Pixel_Dimension : Positive := Max_Sixel_Pixel_Dimension);
   procedure Decode_Base64_Chunk_Bytes
     (Chunk_Count : Natural;
      Chunk_Text  : not null access function (Index : Positive) return String;
      Byte_Sink   : not null access procedure
        (Value : Terminal.Common.Bytes.Byte;
         Continue : in out Boolean);
      Result      : in out Graphics_Data_Preview);
   procedure Decode_Base64_Data
     (Text                  : String;
      Maximum_Decoded_Bytes : Positive;
      Data                  : out Terminal.App.Render_Model.Image_Data_Access;
      Length                : out Natural;
      Status                : out Data_Decode_Status);
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
   procedure Decode_Base64_Zlib_Raw_Chunk_Rows
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
   procedure Decode_Base64_Zlib_PNG_Chunk_Rows
     (Chunk_Count    : Natural;
      Chunk_Text     : not null access function (Index : Positive) return String;
      Inflated_Length : Natural;
      Encoded_Length : out Natural;
      Row_Sink       : not null access procedure
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Result         : in out Graphics_Data_Preview);
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

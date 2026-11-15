with Jpeglib.Streams;
with Terminal.App.Graphics;
with Terminal.Common.Bytes;
with Terminal.Core;

generic
package Graphics_Capabilities_Fixtures is
   Kitty : Terminal.Core.Graphics_Event :=
     (Pending        => True,
      Protocol       => Terminal.Core.Kitty_Graphics,
      Cancelled      => False,
      Stream_ID      => 0,
      Sequence       => 0,
      Transaction_Generation => 0,
      Alternate_Screen => False,
      Screen_Generation => 0,
      Scroll_Sequence => 0,
      Sixel_Private_Colors => True,
      Row            => 1,
      Col            => 1,
      Payload_Length => 0,
      Preview_Length => 0,
      Preview        => (others => ASCII.NUL));
   ITerm2 : Terminal.Core.Graphics_Event :=
     (Pending        => True,
      Protocol       => Terminal.Core.ITerm2_Graphics,
      Cancelled      => False,
      Stream_ID      => 0,
      Sequence       => 0,
      Transaction_Generation => 0,
      Alternate_Screen => False,
      Screen_Generation => 0,
      Scroll_Sequence => 0,
      Sixel_Private_Colors => True,
      Row            => 1,
      Col            => 1,
      Payload_Length => 0,
      Preview_Length => 0,
      Preview        => (others => ASCII.NUL));
   ITerm2_PNG : Terminal.Core.Graphics_Event :=
     (Pending        => True,
      Protocol       => Terminal.Core.ITerm2_Graphics,
      Cancelled      => False,
      Stream_ID      => 0,
      Sequence       => 0,
      Transaction_Generation => 0,
      Alternate_Screen => False,
      Screen_Generation => 0,
      Scroll_Sequence => 0,
      Sixel_Private_Colors => True,
      Row            => 1,
      Col            => 1,
      Payload_Length => 0,
      Preview_Length => 0,
      Preview        => (others => ASCII.NUL));
   ITerm2_JPEG : Terminal.Core.Graphics_Event :=
     (Pending        => True,
      Protocol       => Terminal.Core.ITerm2_Graphics,
      Cancelled      => False,
      Stream_ID      => 0,
      Sequence       => 0,
      Transaction_Generation => 0,
      Alternate_Screen => False,
      Screen_Generation => 0,
      Scroll_Sequence => 0,
      Sixel_Private_Colors => True,
      Row            => 1,
      Col            => 1,
      Payload_Length => 0,
      Preview_Length => 0,
      Preview        => (others => ASCII.NUL));
   ITerm2_Gray_PNG : Terminal.Core.Graphics_Event :=
     (Pending        => True,
      Protocol       => Terminal.Core.ITerm2_Graphics,
      Cancelled      => False,
      Stream_ID      => 0,
      Sequence       => 0,
      Transaction_Generation => 0,
      Alternate_Screen => False,
      Screen_Generation => 0,
      Scroll_Sequence => 0,
      Sixel_Private_Colors => True,
      Row            => 1,
      Col            => 1,
      Payload_Length => 0,
      Preview_Length => 0,
      Preview        => (others => ASCII.NUL));
   ITerm2_Palette_PNG : Terminal.Core.Graphics_Event :=
     (Pending        => True,
      Protocol       => Terminal.Core.ITerm2_Graphics,
      Cancelled      => False,
      Stream_ID      => 0,
      Sequence       => 0,
      Transaction_Generation => 0,
      Alternate_Screen => False,
      Screen_Generation => 0,
      Scroll_Sequence => 0,
      Sixel_Private_Colors => True,
      Row            => 1,
      Col            => 1,
      Payload_Length => 0,
      Preview_Length => 0,
      Preview        => (others => ASCII.NUL));
   ITerm2_Gray1_PNG : Terminal.Core.Graphics_Event :=
     (Pending        => True,
      Protocol       => Terminal.Core.ITerm2_Graphics,
      Cancelled      => False,
      Stream_ID      => 0,
      Sequence       => 0,
      Transaction_Generation => 0,
      Alternate_Screen => False,
      Screen_Generation => 0,
      Scroll_Sequence => 0,
      Sixel_Private_Colors => True,
      Row            => 1,
      Col            => 1,
      Payload_Length => 0,
      Preview_Length => 0,
      Preview        => (others => ASCII.NUL));
   ITerm2_Gray2_PNG : Terminal.Core.Graphics_Event :=
     (Pending        => True,
      Protocol       => Terminal.Core.ITerm2_Graphics,
      Cancelled      => False,
      Stream_ID      => 0,
      Sequence       => 0,
      Transaction_Generation => 0,
      Alternate_Screen => False,
      Screen_Generation => 0,
      Scroll_Sequence => 0,
      Sixel_Private_Colors => True,
      Row            => 1,
      Col            => 1,
      Payload_Length => 0,
      Preview_Length => 0,
      Preview        => (others => ASCII.NUL));
   ITerm2_Gray4_PNG : Terminal.Core.Graphics_Event :=
     (Pending        => True,
      Protocol       => Terminal.Core.ITerm2_Graphics,
      Cancelled      => False,
      Stream_ID      => 0,
      Sequence       => 0,
      Transaction_Generation => 0,
      Alternate_Screen => False,
      Screen_Generation => 0,
      Scroll_Sequence => 0,
      Sixel_Private_Colors => True,
      Row            => 1,
      Col            => 1,
      Payload_Length => 0,
      Preview_Length => 0,
      Preview        => (others => ASCII.NUL));
   ITerm2_RGB16_PNG : Terminal.Core.Graphics_Event :=
     (Pending        => True,
      Protocol       => Terminal.Core.ITerm2_Graphics,
      Cancelled      => False,
      Stream_ID      => 0,
      Sequence       => 0,
      Transaction_Generation => 0,
      Alternate_Screen => False,
      Screen_Generation => 0,
      Scroll_Sequence => 0,
      Sixel_Private_Colors => True,
      Row            => 1,
      Col            => 1,
      Payload_Length => 0,
      Preview_Length => 0,
      Preview        => (others => ASCII.NUL));
   ITerm2_GA16_PNG : Terminal.Core.Graphics_Event :=
     (Pending        => True,
      Protocol       => Terminal.Core.ITerm2_Graphics,
      Cancelled      => False,
      Stream_ID      => 0,
      Sequence       => 0,
      Transaction_Generation => 0,
      Alternate_Screen => False,
      Screen_Generation => 0,
      Scroll_Sequence => 0,
      Sixel_Private_Colors => True,
      Row            => 1,
      Col            => 1,
      Payload_Length => 0,
      Preview_Length => 0,
      Preview        => (others => ASCII.NUL));
   ITerm2_RGBA16_PNG : Terminal.Core.Graphics_Event :=
     (Pending        => True,
      Protocol       => Terminal.Core.ITerm2_Graphics,
      Cancelled      => False,
      Stream_ID      => 0,
      Sequence       => 0,
      Transaction_Generation => 0,
      Alternate_Screen => False,
      Screen_Generation => 0,
      Scroll_Sequence => 0,
      Sixel_Private_Colors => True,
      Row            => 1,
      Col            => 1,
      Payload_Length => 0,
      Preview_Length => 0,
      Preview        => (others => ASCII.NUL));
   ITerm2_Palette1_PNG : Terminal.Core.Graphics_Event :=
     (Pending        => True,
      Protocol       => Terminal.Core.ITerm2_Graphics,
      Cancelled      => False,
      Stream_ID      => 0,
      Sequence       => 0,
      Transaction_Generation => 0,
      Alternate_Screen => False,
      Screen_Generation => 0,
      Scroll_Sequence => 0,
      Sixel_Private_Colors => True,
      Row            => 1,
      Col            => 1,
      Payload_Length => 0,
      Preview_Length => 0,
      Preview        => (others => ASCII.NUL));
   ITerm2_Adam7_PNG : Terminal.Core.Graphics_Event :=
     (Pending        => True,
      Protocol       => Terminal.Core.ITerm2_Graphics,
      Cancelled      => False,
      Stream_ID      => 0,
      Sequence       => 0,
      Transaction_Generation => 0,
      Alternate_Screen => False,
      Screen_Generation => 0,
      Scroll_Sequence => 0,
      Sixel_Private_Colors => True,
      Row            => 1,
      Col            => 1,
      Payload_Length => 0,
      Preview_Length => 0,
      Preview        => (others => ASCII.NUL));
   Kitty_Sized : Terminal.Core.Graphics_Event :=
     (Pending        => True,
      Protocol       => Terminal.Core.Kitty_Graphics,
      Cancelled      => False,
      Stream_ID      => 0,
      Sequence       => 0,
      Transaction_Generation => 0,
      Alternate_Screen => False,
      Screen_Generation => 0,
      Scroll_Sequence => 0,
      Sixel_Private_Colors => True,
      Row            => 1,
      Col            => 1,
      Payload_Length => 0,
      Preview_Length => 0,
      Preview        => (others => ASCII.NUL));
   Kitty_RGBA : Terminal.Core.Graphics_Event :=
     (Pending        => True,
      Protocol       => Terminal.Core.Kitty_Graphics,
      Cancelled      => False,
      Stream_ID      => 0,
      Sequence       => 0,
      Transaction_Generation => 0,
      Alternate_Screen => False,
      Screen_Generation => 0,
      Scroll_Sequence => 0,
      Sixel_Private_Colors => True,
      Row            => 1,
      Col            => 1,
      Payload_Length => 0,
      Preview_Length => 0,
      Preview        => (others => ASCII.NUL));
   Kitty_Chunk : Terminal.Core.Graphics_Event :=
     (Pending        => True,
      Protocol       => Terminal.Core.Kitty_Graphics,
      Cancelled      => False,
      Stream_ID      => 0,
      Sequence       => 0,
      Transaction_Generation => 0,
      Alternate_Screen => False,
      Screen_Generation => 0,
      Scroll_Sequence => 0,
      Sixel_Private_Colors => True,
      Row            => 1,
      Col            => 1,
      Payload_Length => 0,
      Preview_Length => 0,
      Preview        => (others => ASCII.NUL));
   Kitty_PNG : Terminal.Core.Graphics_Event :=
     (Pending        => True,
      Protocol       => Terminal.Core.Kitty_Graphics,
      Cancelled      => False,
      Stream_ID      => 0,
      Sequence       => 0,
      Transaction_Generation => 0,
      Alternate_Screen => False,
      Screen_Generation => 0,
      Scroll_Sequence => 0,
      Sixel_Private_Colors => True,
      Row            => 1,
      Col            => 1,
      Payload_Length => 0,
      Preview_Length => 0,
      Preview        => (others => ASCII.NUL));
   Kitty_JPEG : Terminal.Core.Graphics_Event :=
     (Pending        => True,
      Protocol       => Terminal.Core.Kitty_Graphics,
      Cancelled      => False,
      Stream_ID      => 0,
      Sequence       => 0,
      Transaction_Generation => 0,
      Alternate_Screen => False,
      Screen_Generation => 0,
      Scroll_Sequence => 0,
      Sixel_Private_Colors => True,
      Row            => 1,
      Col            => 1,
      Payload_Length => 0,
      Preview_Length => 0,
      Preview        => (others => ASCII.NUL));
   Kitty_Large_RGBA : Terminal.Core.Graphics_Event :=
     (Pending        => True,
      Protocol       => Terminal.Core.Kitty_Graphics,
      Cancelled      => False,
      Stream_ID      => 0,
      Sequence       => 0,
      Transaction_Generation => 0,
      Alternate_Screen => False,
      Screen_Generation => 0,
      Scroll_Sequence => 0,
      Sixel_Private_Colors => True,
      Row            => 1,
      Col            => 1,
      Payload_Length => 0,
      Preview_Length => 0,
      Preview        => (others => ASCII.NUL));
   Kitty_Oversized_RGBA : Terminal.Core.Graphics_Event :=
     (Pending        => True,
      Protocol       => Terminal.Core.Kitty_Graphics,
      Cancelled      => False,
      Stream_ID      => 0,
      Sequence       => 0,
      Transaction_Generation => 0,
      Alternate_Screen => False,
      Screen_Generation => 0,
      Scroll_Sequence => 0,
      Sixel_Private_Colors => True,
      Row            => 1,
      Col            => 1,
      Payload_Length => 0,
      Preview_Length => 0,
      Preview        => (others => ASCII.NUL));
   Kitty_Partial : Terminal.Core.Graphics_Event :=
     (Pending        => True,
      Protocol       => Terminal.Core.Kitty_Graphics,
      Cancelled      => False,
      Stream_ID      => 0,
      Sequence       => 0,
      Transaction_Generation => 0,
      Alternate_Screen => False,
      Screen_Generation => 0,
      Scroll_Sequence => 0,
      Sixel_Private_Colors => True,
      Row            => 1,
      Col            => 1,
      Payload_Length => 0,
      Preview_Length => 0,
      Preview        => (others => ASCII.NUL));
   Kitty_Trailing : Terminal.Core.Graphics_Event :=
     (Pending        => True,
      Protocol       => Terminal.Core.Kitty_Graphics,
      Cancelled      => False,
      Stream_ID      => 0,
      Sequence       => 0,
      Transaction_Generation => 0,
      Alternate_Screen => False,
      Screen_Generation => 0,
      Scroll_Sequence => 0,
      Sixel_Private_Colors => True,
      Row            => 1,
      Col            => 1,
      Payload_Length => 0,
      Preview_Length => 0,
      Preview        => (others => ASCII.NUL));
   Sixel : Terminal.Core.Graphics_Event :=
     (Pending        => True,
      Protocol       => Terminal.Core.Sixel_Graphics,
      Cancelled      => False,
      Stream_ID      => 0,
      Sequence       => 0,
      Transaction_Generation => 0,
      Alternate_Screen => False,
      Screen_Generation => 0,
      Scroll_Sequence => 0,
      Sixel_Private_Colors => True,
      Row            => 1,
      Col            => 1,
      Payload_Length => 0,
      Preview_Length => 0,
      Preview        => (others => ASCII.NUL));
   Kitty_Header : Terminal.App.Graphics.Graphics_Header;
   Kitty_Placement_Header : Terminal.App.Graphics.Graphics_Header;
   ITerm2_Header : Terminal.App.Graphics.Graphics_Header;
   Sized_Header : Terminal.App.Graphics.Graphics_Header;
   Kitty_Data : Terminal.App.Graphics.Graphics_Data_Preview;
   Kitty_RGBA_Data : Terminal.App.Graphics.Graphics_Data_Preview;
   Kitty_Chunk_Header : Terminal.App.Graphics.Graphics_Header;
   Kitty_PNG_Data : Terminal.App.Graphics.Graphics_Data_Preview;
   Kitty_JPEG_Data : Terminal.App.Graphics.Graphics_Data_Preview;
   Kitty_Large_RGBA_Data : Terminal.App.Graphics.Graphics_Data_Preview;
   Kitty_Oversized_RGBA_Data : Terminal.App.Graphics.Graphics_Data_Preview;
   Kitty_Partial_Data : Terminal.App.Graphics.Graphics_Data_Preview;
   Kitty_Trailing_Data : Terminal.App.Graphics.Graphics_Data_Preview;
   ITerm2_Data : Terminal.App.Graphics.Graphics_Data_Preview;
   ITerm2_PNG_Data : Terminal.App.Graphics.Graphics_Data_Preview;
   ITerm2_JPEG_Data : Terminal.App.Graphics.Graphics_Data_Preview;
   ITerm2_Gray_PNG_Data : Terminal.App.Graphics.Graphics_Data_Preview;
   ITerm2_Palette_PNG_Data : Terminal.App.Graphics.Graphics_Data_Preview;
   ITerm2_Gray1_PNG_Data : Terminal.App.Graphics.Graphics_Data_Preview;
   ITerm2_Gray2_PNG_Data : Terminal.App.Graphics.Graphics_Data_Preview;
   ITerm2_Gray4_PNG_Data : Terminal.App.Graphics.Graphics_Data_Preview;
   ITerm2_RGB16_PNG_Data : Terminal.App.Graphics.Graphics_Data_Preview;
   ITerm2_GA16_PNG_Data : Terminal.App.Graphics.Graphics_Data_Preview;
   ITerm2_RGBA16_PNG_Data : Terminal.App.Graphics.Graphics_Data_Preview;
   ITerm2_Palette1_PNG_Data : Terminal.App.Graphics.Graphics_Data_Preview;
   ITerm2_Adam7_PNG_Data : Terminal.App.Graphics.Graphics_Data_Preview;
   Sixel_Data : Terminal.App.Graphics.Graphics_Data_Preview;
   PNG_Row_Data : constant Terminal.Common.Bytes.Byte_Array (1 .. 69) :=
     (1 => 16#89#, 2 => 16#50#, 3 => 16#4E#, 4 => 16#47#,
      5 => 16#0D#, 6 => 16#0A#, 7 => 16#1A#, 8 => 16#0A#,
      9 => 16#00#, 10 => 16#00#, 11 => 16#00#, 12 => 16#0D#,
      13 => 16#49#, 14 => 16#48#, 15 => 16#44#, 16 => 16#52#,
      17 => 16#00#, 18 => 16#00#, 19 => 16#00#, 20 => 16#01#,
      21 => 16#00#, 22 => 16#00#, 23 => 16#00#, 24 => 16#01#,
      25 => 16#08#, 26 => 16#02#, 27 => 16#00#, 28 => 16#00#,
      29 => 16#00#, 30 => 16#90#, 31 => 16#77#, 32 => 16#53#,
      33 => 16#DE#, 34 => 16#00#, 35 => 16#00#, 36 => 16#00#,
      37 => 16#0C#, 38 => 16#49#, 39 => 16#44#, 40 => 16#41#,
      41 => 16#54#, 42 => 16#78#, 43 => 16#9C#, 44 => 16#63#,
      45 => 16#F8#, 46 => 16#CF#, 47 => 16#C0#, 48 => 16#00#,
      49 => 16#00#, 50 => 16#03#, 51 => 16#01#, 52 => 16#01#,
      53 => 16#00#, 54 => 16#C9#, 55 => 16#FE#, 56 => 16#92#,
      57 => 16#EF#, 58 => 16#00#, 59 => 16#00#, 60 => 16#00#,
      61 => 16#00#, 62 => 16#49#, 63 => 16#45#, 64 => 16#4E#,
      65 => 16#44#, 66 => 16#AE#, 67 => 16#42#, 68 => 16#60#,
      69 => 16#82#);
   PNG_Row_Result : Terminal.App.Graphics.Graphics_Data_Preview;
   PNG_Row_Count : Natural := 0;
   PNG_Row_Bytes : Terminal.Common.Bytes.Byte_Array (1 .. 4) :=
     (others => 0);
   PNG_Source_Row_Result : Terminal.App.Graphics.Graphics_Data_Preview;
   PNG_Source_Row_Count : Natural := 0;
   PNG_Source_Row_Bytes : Terminal.Common.Bytes.Byte_Array (1 .. 4) :=
     (others => 0);
   PNG_Corrupt_CRC : Terminal.Common.Bytes.Byte_Array (PNG_Row_Data'Range) :=
     PNG_Row_Data;
   PNG_Corrupt_CRC_Result : Terminal.App.Graphics.Graphics_Data_Preview;
   PNG_Corrupt_Adler : Terminal.Common.Bytes.Byte_Array (PNG_Row_Data'Range) :=
     PNG_Row_Data;
   PNG_Corrupt_Adler_Result : Terminal.App.Graphics.Graphics_Data_Preview;
   PNG_Huge_Chunk : constant Terminal.Common.Bytes.Byte_Array (1 .. 20) :=
     (1 => 16#89#, 2 => 16#50#, 3 => 16#4E#, 4 => 16#47#,
      5 => 16#0D#, 6 => 16#0A#, 7 => 16#1A#, 8 => 16#0A#,
      9 => 16#FF#, 10 => 16#FF#, 11 => 16#FF#, 12 => 16#FF#,
      13 => 16#49#, 14 => 16#44#, 15 => 16#41#, 16 => 16#54#,
      17 .. 20 => 0);
   PNG_Huge_Chunk_Result : Terminal.App.Graphics.Graphics_Data_Preview;
   PNG_Trailing : Terminal.Common.Bytes.Byte_Array (1 .. 71) :=
     (others => 0);
   PNG_Trailing_Result : Terminal.App.Graphics.Graphics_Data_Preview;
   Base64_PNG_Row_Result : Terminal.App.Graphics.Graphics_Data_Preview;
   Base64_PNG_Encoded_Length : Natural := 0;
   Base64_PNG_Length : Natural := 0;
   Base64_PNG_Row_Count : Natural := 0;
   Base64_PNG_Row_Bytes : Terminal.Common.Bytes.Byte_Array (1 .. 4) :=
     (others => 0);
   Base64_PNG_Invalid_Result : Terminal.App.Graphics.Graphics_Data_Preview;
   Base64_PNG_Invalid_Encoded_Length : Natural := 0;
   Base64_PNG_Invalid_Length : Natural := 0;
   Base64_PNG_Not_PNG_Result : Terminal.App.Graphics.Graphics_Data_Preview;
   Base64_PNG_Not_PNG_Encoded_Length : Natural := 0;
   Base64_PNG_Not_PNG_Length : Natural := 0;
   Base64_PNG_Trailing_Result : Terminal.App.Graphics.Graphics_Data_Preview;
   Base64_PNG_Trailing_Encoded_Length : Natural := 0;
   Base64_PNG_Trailing_Length : Natural := 0;
   Base64_PNG_Stop_Result : Terminal.App.Graphics.Graphics_Data_Preview;
   Base64_PNG_Stop_Encoded_Length : Natural := 0;
   Base64_PNG_Stop_Length : Natural := 0;
   Sixel_Row_Result : Terminal.App.Graphics.Graphics_Data_Preview;
   Sixel_Row_Count : Natural := 0;
   Sixel_First_Row : Terminal.Common.Bytes.Byte_Array (1 .. 4) :=
     (others => 0);
   Raw_Row_Result : Terminal.App.Graphics.Graphics_Data_Preview;
   Raw_Row_Count : Natural := 0;
   Raw_Row_Bytes : Terminal.Common.Bytes.Byte_Array (1 .. 4) :=
     (others => 0);
   Raw_Chunk_Row_Result : Terminal.App.Graphics.Graphics_Data_Preview;
   Raw_Chunk_Row_Count : Natural := 0;
   Raw_Chunk_Row_Bytes : Terminal.Common.Bytes.Byte_Array (1 .. 4) :=
     (others => 0);
   Zlib_Raw_Result : Terminal.App.Graphics.Graphics_Data_Preview;
   Zlib_Raw_Row_Count : Natural := 0;
   Zlib_Raw_Row_Bytes : Terminal.Common.Bytes.Byte_Array (1 .. 4) :=
     (others => 0);
   Zlib_Raw_Invalid_Result : Terminal.App.Graphics.Graphics_Data_Preview;
   Zlib_PNG_Result : Terminal.App.Graphics.Graphics_Data_Preview;
   Zlib_PNG_Encoded_Length : Natural := 0;
   Zlib_PNG_Row_Count : Natural := 0;
   Zlib_PNG_Row_Bytes : Terminal.Common.Bytes.Byte_Array (1 .. 4) :=
     (others => 0);
   Base64_Byte_Result : Terminal.App.Graphics.Graphics_Data_Preview;
   Base64_Byte_Count : Natural := 0;
   Base64_Bytes : Terminal.Common.Bytes.Byte_Array (1 .. 2) :=
     (others => 0);
   Base64_Byte_Trailing_Result : Terminal.App.Graphics.Graphics_Data_Preview;
   Base64_Byte_Trailing_Count : Natural := 0;
   Adam7_PNG_Bytes : Terminal.Common.Bytes.Byte_Array (1 .. 128) :=
     (others => 0);
   Adam7_PNG_Length : Natural := 0;
   Adam7_Base64_Result : Terminal.App.Graphics.Graphics_Data_Preview;
   Adam7_Row_Result : Terminal.App.Graphics.Graphics_Data_Preview;
   Adam7_Row_Count : Natural := 0;
   Adam7_First_Row : Terminal.Common.Bytes.Byte_Array (1 .. 8) :=
     (others => 0);
   Adam7_Second_Row : Terminal.Common.Bytes.Byte_Array (1 .. 8) :=
     (others => 0);
   JPEG_Input : aliased Jpeglib.Streams.Byte_Array :=
     (1 => 16#FF#, 2 => 16#00#, 3 => 16#00#);
   JPEG_Storage : aliased Jpeglib.Streams.Byte_Array :=
     (1 .. 2048 => 0);
   JPEG_Length : Natural := 0;
end Graphics_Capabilities_Fixtures;

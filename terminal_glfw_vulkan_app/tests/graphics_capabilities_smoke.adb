with AUnit.Assertions;

with Jpeglib.Encoding;
with Jpeglib.Images;
with Jpeglib.Results;
with Jpeglib.Streams;

with Terminal.App.Graphics;
with Terminal.App.Image_Media;
with Terminal.App.Render_Model;
with Terminal.Common.Bytes;
with Terminal.Common.Status;
with Terminal.Core;

procedure Graphics_Capabilities_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Graphics.Data_Decode_Status;
   use type Terminal.App.Graphics.ITerm2_Size_Unit;
   use type Terminal.App.Render_Model.Image_Data_Access;
   use type Terminal.App.Render_Model.Image_Decode_Status;
   use type Terminal.App.Render_Model.Image_Decoded_Source_Kind;
   use type Terminal.Common.Bytes.Byte;
   use type Terminal.Core.Graphics_ID;
   use type Jpeglib.Destination_Offset;

   package Graphics renames Terminal.App.Graphics;
   package RM renames Terminal.App.Render_Model;

   procedure Set_Preview
     (Event : in out Terminal.Core.Graphics_Event;
      Text  : String)
   is
   begin
      Event.Payload_Length := Text'Length;
      Event.Preview_Length := Text'Length;
      Event.Preview := (others => ASCII.NUL);
      Event.Preview (1 .. Text'Length) := Text;
   end Set_Preview;

   function Repeat_Char (Ch : Character; Count : Natural) return String is
      Result : String (1 .. Count);
   begin
      for I in Result'Range loop
         Result (I) := Ch;
      end loop;
      return Result;
   end Repeat_Char;

   procedure Assert_Protocol
     (Protocol : Graphics.Graphics_Protocol;
      Label    : String;
      Decoded  : Boolean := False)
   is
      Cap : constant Graphics.Protocol_Capability :=
        Graphics.Capability (Protocol);
   begin
      Assert (Cap.Recognized, Label & " should be recognized");
      Assert (Cap.Decoded = Decoded, Label & " decode support flag");
      Assert (Cap.Rendered, Label & " should report placeholder rendering support");
   end Assert_Protocol;

   procedure Assert_Ignored_Label
     (Protocol : Terminal.Core.Ignored_Graphics_Protocol;
      Payload_Length : Natural;
      Expected : String;
      Label    : String)
   is
      Diagnostics : Terminal.Core.Diagnostic_Snapshot :=
        (others => <>);
   begin
      Diagnostics.Graphics_Protocol_Ignored := 1;
      Diagnostics.Last_Graphics_Protocol := Protocol;
      Diagnostics.Last_Graphics_Payload_Length := Payload_Length;
      Assert
        (Graphics.Ignored_Status_Label (Diagnostics) = Expected,
         Label);
   end Assert_Ignored_Label;
begin
   declare
      Bytes : constant Terminal.Common.Bytes.Byte_Array :=
        (1 => 16#00#, 2 => 16#41#, 3 => 16#FF#, 4 => 16#10#, 5 => 16#22#);
   begin
      Assert
        (Terminal.Common.Status.Preview_Bytes_Label (Bytes, 0) = "",
         "empty preview byte label");
      Assert
        (Terminal.Common.Status.Preview_Bytes_Label (Bytes, 3) =
         " bytes=0041FF",
         "preview byte label should render requested bytes");
      Assert
        (Terminal.Common.Status.Preview_Bytes_Label (Bytes, 5) =
         " bytes=0041FF10",
         "preview byte label should default to four bytes");
      Assert
        (Terminal.Common.Status.Preview_Bytes_Label (Bytes, 5, 2) =
         " bytes=0041",
         "preview byte label should respect explicit limit");
   end;

   Assert_Protocol (Graphics.Sixel, "sixel", Decoded => True);
   Assert_Protocol (Graphics.Kitty, "kitty graphics", Decoded => True);
   Assert_Protocol (Graphics.ITerm2, "iTerm2 image", Decoded => True);

   declare
      Emoji : constant Graphics.Emoji_Capability := Graphics.Color_Emoji;
   begin
      Assert (Emoji.Cluster_Preserved, "emoji clusters should be preserved");
      Assert
        (Emoji.Monochrome_Fallback,
         "emoji should report monochrome fallback path");
      Assert
        (Emoji.Color_Glyph_Rendered,
         "emoji should report color glyph rendering");
   end;

   Assert (Graphics.Name (Graphics.Sixel) = "sixel", "sixel name");
   Assert (Graphics.Name (Graphics.Kitty) = "kitty", "kitty name");
   Assert (Graphics.Name (Graphics.ITerm2) = "iTerm2", "iTerm2 name");
   Assert
     (Graphics.Data_Decode_Status_Suffix (Graphics.Decode_Ok) = "",
      "ok data decode suffix");
   Assert
     (Graphics.Data_Decode_Status_Suffix (Graphics.Decode_Invalid_Byte) =
      " invalid-byte",
      "invalid-byte data decode suffix");
   Assert
     (Graphics.Data_Decode_Status_Suffix (Graphics.Decode_Trailing_Data) =
      " trailing-data",
      "trailing-data data decode suffix");
   Assert
     (Graphics.Data_Decode_Status_Suffix (Graphics.Decode_Preview_Truncated) =
      " truncated",
      "truncated data decode suffix");
   Assert
     (Graphics.Data_Decode_Status_Suffix (Graphics.Decode_Unsupported_Format) =
      " unsupported-format",
      "unsupported-format data decode suffix");
   Assert
     (Graphics.Image_Decode_Status (Graphics.Decode_Not_Attempted) =
      Terminal.App.Render_Model.Image_Decode_Not_Attempted,
      "not-attempted data decode maps to image decode");
   Assert
     (Graphics.Image_Decode_Status (Graphics.Decode_Ok) =
      Terminal.App.Render_Model.Image_Decode_Ok,
      "ok data decode maps to image decode");
   Assert
     (Graphics.Image_Decode_Status (Graphics.Decode_Invalid_Byte) =
      Terminal.App.Render_Model.Image_Decode_Invalid_Byte,
      "invalid-byte data decode maps to image decode");
   Assert
     (Graphics.Image_Decode_Status (Graphics.Decode_Trailing_Data) =
      Terminal.App.Render_Model.Image_Decode_Trailing_Data,
      "trailing-data data decode maps to image decode");
   Assert
     (Graphics.Image_Decode_Status (Graphics.Decode_Preview_Truncated) =
      Terminal.App.Render_Model.Image_Decode_Preview_Truncated,
      "truncated data decode maps to image decode");
   Assert
     (Graphics.Image_Decode_Status (Graphics.Decode_Unsupported_Format) =
      Terminal.App.Render_Model.Image_Decode_Unsupported_Format,
      "unsupported-format data decode maps to image decode");

   declare
      Tight_RGBA : aliased Terminal.Common.Bytes.Byte_Array :=
        (1 => 16#11#, 2 => 16#22#, 3 => 16#33#, 4 => 16#44#,
         5 => 16#55#, 6 => 16#66#, 7 => 16#77#, 8 => 16#88#);
      Strided_RGB : aliased Terminal.Common.Bytes.Byte_Array :=
        (1 => 16#10#, 2 => 16#20#, 3 => 16#30#,
         4 => 16#EE#, 5 => 16#EE#,
         6 => 16#40#, 7 => 16#50#, 8 => 16#60#);
      Too_Short : aliased Terminal.Common.Bytes.Byte_Array :=
        (1 => 16#AA#, 2 => 16#BB#, 3 => 16#CC#);
      Image : RM.Image_Command :=
        (Raw_Format => 32,
         Pixel_Width => 1,
         Pixel_Height => 2,
         Decoded_Byte_Length => Tight_RGBA'Length,
         Decoded_Row_Stride_Bytes => 0,
         Decoded_Source => RM.Image_Decoded_Source_Buffer,
         Decoded_Bytes => Tight_RGBA'Unchecked_Access,
         others => <>);
   begin
      Assert
        (RM.Image_Decoded_Source_Bytes (Image) = 8,
         "tight RGBA image source extent");
      Assert
        (RM.Image_Decoded_Source_Available (Image),
         "tight RGBA image source available");
      Assert
        (RM.Image_Decoded_Row_Byte (Image, 0, 0) = 16#11#
         and then RM.Image_Decoded_Row_Byte (Image, 1, 3) = 16#88#,
         "tight RGBA row source bytes");
      Assert
        (RM.Image_Decoded_Row_Byte (Image, 2, 0) = 0
         and then RM.Image_Decoded_Row_Byte (Image, 1, 4) = 0,
         "tight RGBA row source bounds");

      Image.Raw_Format := 24;
      Image.Pixel_Width := 1;
      Image.Pixel_Height := 2;
      Image.Decoded_Byte_Length := Strided_RGB'Length;
      Image.Decoded_Row_Stride_Bytes := 5;
      Image.Decoded_Bytes := Strided_RGB'Unchecked_Access;
      Assert
        (RM.Image_Decoded_Source_Bytes (Image) = 8,
         "strided RGB image source extent");
      Assert
        (RM.Image_Decoded_Source_Available (Image),
         "strided RGB image source available");
      Assert
        (RM.Image_Decoded_Row_Byte (Image, 0, 4) = 16#EE#
         and then RM.Image_Decoded_Row_Byte (Image, 1, 2) = 16#60#,
         "strided RGB row source bytes");

      Image.Decoded_Source := RM.Image_Decoded_Source_None;
      Assert
        (RM.Image_Decoded_Source_Bytes (Image) = 0
         and then not RM.Image_Decoded_Source_Available (Image)
         and then RM.Image_Decoded_Row_Byte (Image, 0, 0) = 0,
         "missing decoded source should be unavailable");

      Image.Decoded_Source := RM.Image_Decoded_Source_Buffer;
      Image.Decoded_Byte_Length := Too_Short'Length;
      Image.Decoded_Bytes := Too_Short'Unchecked_Access;
      Assert
        (not RM.Image_Decoded_Source_Available (Image),
         "short decoded buffer should be unavailable");

      Image.Pixel_Width := RM.Max_Image_Decoded_Data_Length;
      Image.Pixel_Height := RM.Max_Image_Decoded_Data_Length;
      Image.Decoded_Byte_Length := 0;
      Image.Decoded_Row_Stride_Bytes := 0;
      Image.Decoded_Bytes := null;
      Assert
        (RM.Image_Decoded_Source_Bytes (Image) = 0,
         "oversized decoded metadata should not overflow");
   end;

   Assert
     (Graphics.Capability_Status_Label (Graphics.Sixel) =
      "sixel graphics recognized; raster texture rendering available",
      "sixel capability status label");
   Assert
     (Graphics.Capability_Status_Label (Graphics.Kitty) =
      "kitty graphics; RGB/RGBA/indexed/PNG texture rendering",
      "kitty capability status label");
   Assert
     (Graphics.Capability_Status_Label (Graphics.ITerm2) =
      (if Terminal.App.Image_Media.Extended_Media_Available
       then "iTerm2 images; PNG/JPEG/GIF/PICT plus runtime media decoding"
       else "iTerm2 images; PNG/JPEG/GIF/PICT texture rendering"),
      "iTerm2 capability status label");
   Assert
     (Graphics.Capability_Status_Label (Graphics.ITerm2)'Length <=
      Graphics.Max_Status_Label_Length,
      "graphics capability status labels should be bounded");

   Assert
     (Graphics.Name (Terminal.Core.No_Graphics) = "",
      "no graphics diagnostic name");
   Assert
     (Graphics.Name (Terminal.Core.Sixel_Graphics) = "sixel",
      "sixel diagnostic name");
   Assert
     (Graphics.Name (Terminal.Core.Kitty_Graphics) = "kitty",
      "kitty diagnostic name");
   Assert
     (Graphics.Name (Terminal.Core.ITerm2_Graphics) = "iTerm2",
      "iTerm2 diagnostic name");

   declare
      Diagnostics : constant Terminal.Core.Diagnostic_Snapshot :=
        (others => <>);
   begin
      Assert
        (Graphics.Ignored_Status_Label (Diagnostics) = "",
         "empty ignored graphics status label");
   end;

   Assert_Ignored_Label
     (Terminal.Core.Sixel_Graphics,
      7,
      "Ignored sixel graphics payload (7 bytes)",
      "sixel ignored graphics status label");
   Assert_Ignored_Label
     (Terminal.Core.Kitty_Graphics,
      16,
      "Ignored kitty graphics payload (16 bytes)",
      "kitty ignored graphics status label");
   Assert_Ignored_Label
     (Terminal.Core.ITerm2_Graphics,
      25,
      "Ignored iTerm2 image payload (25 bytes)",
      "iTerm2 ignored graphics status label");

   declare
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
      Kitty_Header : Graphics.Graphics_Header;
      Kitty_Placement_Header : Graphics.Graphics_Header;
      ITerm2_Header : Graphics.Graphics_Header;
      Sized_Header : Graphics.Graphics_Header;
      Kitty_Data : Graphics.Graphics_Data_Preview;
      Kitty_RGBA_Data : Graphics.Graphics_Data_Preview;
      Kitty_Chunk_Header : Graphics.Graphics_Header;
      Kitty_PNG_Data : Graphics.Graphics_Data_Preview;
      Kitty_JPEG_Data : Graphics.Graphics_Data_Preview;
      Kitty_Large_RGBA_Data : Graphics.Graphics_Data_Preview;
      Kitty_Oversized_RGBA_Data : Graphics.Graphics_Data_Preview;
      Kitty_Partial_Data : Graphics.Graphics_Data_Preview;
      Kitty_Trailing_Data : Graphics.Graphics_Data_Preview;
      ITerm2_Data : Graphics.Graphics_Data_Preview;
      ITerm2_PNG_Data : Graphics.Graphics_Data_Preview;
      ITerm2_JPEG_Data : Graphics.Graphics_Data_Preview;
      ITerm2_Gray_PNG_Data : Graphics.Graphics_Data_Preview;
      ITerm2_Palette_PNG_Data : Graphics.Graphics_Data_Preview;
      ITerm2_Gray1_PNG_Data : Graphics.Graphics_Data_Preview;
      ITerm2_Gray2_PNG_Data : Graphics.Graphics_Data_Preview;
      ITerm2_Gray4_PNG_Data : Graphics.Graphics_Data_Preview;
      ITerm2_RGB16_PNG_Data : Graphics.Graphics_Data_Preview;
      ITerm2_GA16_PNG_Data : Graphics.Graphics_Data_Preview;
      ITerm2_RGBA16_PNG_Data : Graphics.Graphics_Data_Preview;
      ITerm2_Palette1_PNG_Data : Graphics.Graphics_Data_Preview;
      ITerm2_Adam7_PNG_Data : Graphics.Graphics_Data_Preview;
      Sixel_Data : Graphics.Graphics_Data_Preview;
      PNG_Row_Data : constant Terminal.Common.Bytes.Byte_Array (1 .. 70) :=
        (1 => 16#89#, 2 => 16#50#, 3 => 16#4E#, 4 => 16#47#,
         5 => 16#0D#, 6 => 16#0A#, 7 => 16#1A#, 8 => 16#0A#,
         9 => 16#00#, 10 => 16#00#, 11 => 16#00#, 12 => 16#0D#,
         13 => 16#49#, 14 => 16#48#, 15 => 16#44#, 16 => 16#52#,
         17 => 16#00#, 18 => 16#00#, 19 => 16#00#, 20 => 16#01#,
         21 => 16#00#, 22 => 16#00#, 23 => 16#00#, 24 => 16#01#,
         25 => 16#08#, 26 => 16#02#, 27 => 16#00#, 28 => 16#00#,
         29 => 16#00#, 30 => 16#90#, 31 => 16#77#, 32 => 16#53#,
         33 => 16#DE#, 34 => 16#00#, 35 => 16#00#, 36 => 16#00#,
         37 => 16#0D#, 38 => 16#49#, 39 => 16#44#, 40 => 16#41#,
         41 => 16#54#, 42 => 16#78#, 43 => 16#9C#, 44 => 16#63#,
         45 => 16#F8#, 46 => 16#CF#, 47 => 16#C0#, 48 => 16#00#,
         49 => 16#00#, 50 => 16#03#, 51 => 16#01#, 52 => 16#01#,
         53 => 16#00#, 54 => 16#C9#, 55 => 16#00#, 56 => 16#C6#,
         57 => 16#94#, 58 => 16#E2#, 59 => 16#00#, 60 => 16#00#,
         61 => 16#00#, 62 => 16#00#, 63 => 16#49#, 64 => 16#45#,
         65 => 16#4E#, 66 => 16#44#, 67 => 16#AE#, 68 => 16#42#,
         69 => 16#60#, 70 => 16#82#);
      PNG_Row_Result : Graphics.Graphics_Data_Preview;
      PNG_Row_Count : Natural := 0;
      PNG_Row_Bytes : Terminal.Common.Bytes.Byte_Array (1 .. 4) :=
        (others => 0);
      PNG_Source_Row_Result : Graphics.Graphics_Data_Preview;
      PNG_Source_Row_Count : Natural := 0;
      PNG_Source_Row_Bytes : Terminal.Common.Bytes.Byte_Array (1 .. 4) :=
        (others => 0);
      PNG_Corrupt_CRC : Terminal.Common.Bytes.Byte_Array (PNG_Row_Data'Range) :=
        PNG_Row_Data;
      PNG_Corrupt_CRC_Result : Graphics.Graphics_Data_Preview;
      PNG_Huge_Chunk : constant Terminal.Common.Bytes.Byte_Array (1 .. 20) :=
        (1 => 16#89#, 2 => 16#50#, 3 => 16#4E#, 4 => 16#47#,
         5 => 16#0D#, 6 => 16#0A#, 7 => 16#1A#, 8 => 16#0A#,
         9 => 16#FF#, 10 => 16#FF#, 11 => 16#FF#, 12 => 16#FF#,
         13 => 16#49#, 14 => 16#44#, 15 => 16#41#, 16 => 16#54#,
         17 .. 20 => 0);
      PNG_Huge_Chunk_Result : Graphics.Graphics_Data_Preview;
      PNG_Trailing : Terminal.Common.Bytes.Byte_Array (1 .. 71) :=
        (others => 0);
      PNG_Trailing_Result : Graphics.Graphics_Data_Preview;
      Base64_PNG_Row_Result : Graphics.Graphics_Data_Preview;
      Base64_PNG_Encoded_Length : Natural := 0;
      Base64_PNG_Length : Natural := 0;
      Base64_PNG_Row_Count : Natural := 0;
      Base64_PNG_Row_Bytes : Terminal.Common.Bytes.Byte_Array (1 .. 4) :=
        (others => 0);
      Base64_PNG_Invalid_Result : Graphics.Graphics_Data_Preview;
      Base64_PNG_Invalid_Encoded_Length : Natural := 0;
      Base64_PNG_Invalid_Length : Natural := 0;
      Base64_PNG_Not_PNG_Result : Graphics.Graphics_Data_Preview;
      Base64_PNG_Not_PNG_Encoded_Length : Natural := 0;
      Base64_PNG_Not_PNG_Length : Natural := 0;
      Base64_PNG_Trailing_Result : Graphics.Graphics_Data_Preview;
      Base64_PNG_Trailing_Encoded_Length : Natural := 0;
      Base64_PNG_Trailing_Length : Natural := 0;
      Base64_PNG_Stop_Result : Graphics.Graphics_Data_Preview;
      Base64_PNG_Stop_Encoded_Length : Natural := 0;
      Base64_PNG_Stop_Length : Natural := 0;
      Sixel_Row_Result : Graphics.Graphics_Data_Preview;
      Sixel_Row_Count : Natural := 0;
      Sixel_First_Row : Terminal.Common.Bytes.Byte_Array (1 .. 4) :=
        (others => 0);
      Raw_Row_Result : Graphics.Graphics_Data_Preview;
      Raw_Row_Count : Natural := 0;
      Raw_Row_Bytes : Terminal.Common.Bytes.Byte_Array (1 .. 4) :=
        (others => 0);
      Raw_Chunk_Row_Result : Graphics.Graphics_Data_Preview;
      Raw_Chunk_Row_Count : Natural := 0;
      Raw_Chunk_Row_Bytes : Terminal.Common.Bytes.Byte_Array (1 .. 4) :=
        (others => 0);
      Zlib_Raw_Result : Graphics.Graphics_Data_Preview;
      Zlib_Raw_Row_Count : Natural := 0;
      Zlib_Raw_Row_Bytes : Terminal.Common.Bytes.Byte_Array (1 .. 4) :=
        (others => 0);
      Zlib_Raw_Invalid_Result : Graphics.Graphics_Data_Preview;
      Zlib_PNG_Result : Graphics.Graphics_Data_Preview;
      Zlib_PNG_Encoded_Length : Natural := 0;
      Zlib_PNG_Row_Count : Natural := 0;
      Zlib_PNG_Row_Bytes : Terminal.Common.Bytes.Byte_Array (1 .. 4) :=
        (others => 0);
      Base64_Byte_Result : Graphics.Graphics_Data_Preview;
      Base64_Byte_Count : Natural := 0;
      Base64_Bytes : Terminal.Common.Bytes.Byte_Array (1 .. 2) :=
        (others => 0);
      Base64_Byte_Trailing_Result : Graphics.Graphics_Data_Preview;
      Base64_Byte_Trailing_Count : Natural := 0;
      Adam7_PNG_Bytes : Terminal.Common.Bytes.Byte_Array (1 .. 128) :=
        (others => 0);
      Adam7_PNG_Length : Natural := 0;
      Adam7_Base64_Result : Graphics.Graphics_Data_Preview;
      Adam7_Row_Result : Graphics.Graphics_Data_Preview;
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

      function Base64_Encode
        (Data   : Jpeglib.Streams.Byte_Array;
         Length : Natural) return String
      is
         Alphabet : constant String :=
           "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
         Result : String (1 .. ((Length + 2) / 3) * 4);
         Out_Pos : Natural := Result'First;
         In_Pos : Natural := Data'First;
      begin
         while In_Pos <= Data'First + Length - 1 loop
            declare
               Remaining : constant Natural :=
                 Data'First + Length - In_Pos;
               B1 : constant Natural := Natural (Data (In_Pos));
               B2 : constant Natural :=
                 (if Remaining >= 2 then Natural (Data (In_Pos + 1)) else 0);
               B3 : constant Natural :=
                 (if Remaining >= 3 then Natural (Data (In_Pos + 2)) else 0);
               Value : constant Natural := B1 * 16#10000# + B2 * 16#100# + B3;
            begin
               Result (Out_Pos) := Alphabet (Value / 16#40000# + 1);
               Result (Out_Pos + 1) :=
                 Alphabet ((Value / 16#1000#) mod 64 + 1);
               Result (Out_Pos + 2) :=
                 (if Remaining >= 2
                  then Alphabet ((Value / 16#40#) mod 64 + 1)
                  else '=');
               Result (Out_Pos + 3) :=
                 (if Remaining >= 3 then Alphabet (Value mod 64 + 1) else '=');
               Out_Pos := Out_Pos + 4;
               In_Pos := In_Pos + 3;
            end;
         end loop;
         return Result;
      end Base64_Encode;

      procedure Build_JPEG is
         Destination : aliased Jpeglib.Streams.Fixed_Buffer_Destination;
         Encoder : Jpeglib.Encoding.Encoder;
         Input : constant Jpeglib.Images.Image_View :=
           (Descriptor =>
              (Width => 1,
               Height => 1,
               Format => Jpeglib.Images.RGB_24,
               Stride => 3,
               Accessible_Bytes => 3),
            Storage => JPEG_Input'Unchecked_Access);
         Outcome : Jpeglib.Results.Result;
      begin
         Jpeglib.Streams.Open (Destination, JPEG_Storage'Unchecked_Access);
         Jpeglib.Encoding.Initialize
           (Encoder,
            Destination'Access,
            (Quality => 100,
             Subsampling => Jpeglib.Encoding.Subsampling_444,
             others => <>));
         Outcome := Jpeglib.Encoding.Encode_Image (Encoder, Input);
         Assert
           (Jpeglib.Results.Succeeded (Outcome),
            "test JPEG fixture should encode");
         JPEG_Length := Natural (Jpeglib.Streams.Offset (Destination));
         Assert (JPEG_Length > 0, "test JPEG fixture length");
      end Build_JPEG;

      procedure Capture_PNG_Row
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean)
      is
      begin
         PNG_Row_Count := PNG_Row_Count + 1;
         if Y /= 0 or else Row'Length /= 4 then
            Continue := False;
            return;
         end if;
         PNG_Row_Bytes := Row;
      end Capture_PNG_Row;

      function PNG_Source_Byte
        (Index : Positive) return Terminal.Common.Bytes.Byte
      is
      begin
         if Index > PNG_Row_Data'Last then
            return 0;
         end if;
         return PNG_Row_Data (Index);
      end PNG_Source_Byte;

      procedure Capture_PNG_Source_Row
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean)
      is
      begin
         PNG_Source_Row_Count := PNG_Source_Row_Count + 1;
         if Y /= 0 or else Row'Length /= 4 then
            Continue := False;
            return;
         end if;
         PNG_Source_Row_Bytes := Row;
      end Capture_PNG_Source_Row;

      function Base64_PNG_Text (Index : Positive) return String is
      begin
         case Index is
            when 1 =>
               return "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1Pe";
            when 2 =>
               return "AAAADUlEQVR4nGP4z8AAAAMBAQDJAMaU4gAAAABJRU5ErkJggg==";
            when others =>
               return "";
         end case;
      end Base64_PNG_Text;

      function Base64_PNG_Invalid_Text (Index : Positive) return String is
      begin
         if Index = 1 then
            return "%%%";
         else
            return "";
         end if;
      end Base64_PNG_Invalid_Text;

      function Base64_PNG_Not_PNG_Text (Index : Positive) return String is
      begin
         if Index = 1 then
            return "SGk=";
         else
            return "";
         end if;
      end Base64_PNG_Not_PNG_Text;

      function Base64_PNG_Trailing_Text (Index : Positive) return String is
      begin
         if Index = 1 then
            return "SGk=A";
         else
            return "";
         end if;
      end Base64_PNG_Trailing_Text;

      procedure Capture_Base64_PNG_Row
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean)
      is
      begin
         Base64_PNG_Row_Count := Base64_PNG_Row_Count + 1;
         if Y /= 0 or else Row'Length /= 4 then
            Continue := False;
            return;
         end if;
         Base64_PNG_Row_Bytes := Row;
      end Capture_Base64_PNG_Row;

      procedure Reject_Base64_PNG_Row
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean)
      is
         pragma Unreferenced (Y, Row);
      begin
         Continue := False;
      end Reject_Base64_PNG_Row;

      procedure Capture_Sixel_Row
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean)
      is
      begin
         Sixel_Row_Count := Sixel_Row_Count + 1;
         if Row'Length /= 4 then
            Continue := False;
            return;
         end if;
         if Y = 0 then
            Sixel_First_Row := Row;
         end if;
      end Capture_Sixel_Row;

      procedure Capture_Raw_Row
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean)
      is
      begin
         Raw_Row_Count := Raw_Row_Count + 1;
         if Y /= 0 or else Row'Length /= 4 then
            Continue := False;
            return;
         end if;
         Raw_Row_Bytes := Row;
      end Capture_Raw_Row;

      function Raw_Chunk_Text (Index : Positive) return String is
      begin
         case Index is
            when 1 =>
               return "/w";
            when 2 =>
               return "AA/w==";
            when others =>
               return "";
         end case;
      end Raw_Chunk_Text;

      procedure Capture_Raw_Chunk_Row
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean)
      is
      begin
         Raw_Chunk_Row_Count := Raw_Chunk_Row_Count + 1;
         if Y /= 0 or else Row'Length /= 4 then
            Continue := False;
            return;
         end if;
         Raw_Chunk_Row_Bytes := Row;
      end Capture_Raw_Chunk_Row;

      function Zlib_Raw_Chunk_Text (Index : Positive) return String is
      begin
         case Index is
            when 1 =>
               return "eJz7z8Dw";
            when 2 =>
               return "HwAE/wH/";
            when others =>
               return "";
         end case;
      end Zlib_Raw_Chunk_Text;

      function Zlib_Raw_Invalid_Text (Index : Positive) return String is
      begin
         if Index = 1 then
            return "eJz7z8DwHwAE/wHA";
         else
            return "";
         end if;
      end Zlib_Raw_Invalid_Text;

      procedure Capture_Zlib_Raw_Row
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean)
      is
      begin
         Zlib_Raw_Row_Count := Zlib_Raw_Row_Count + 1;
         if Y /= 0 or else Row'Length /= 4 then
            Continue := False;
            return;
         end if;
         Zlib_Raw_Row_Bytes := Row;
      end Capture_Zlib_Raw_Row;

      function Zlib_PNG_Chunk_Text (Index : Positive) return String is
      begin
         case Index is
            when 1 =>
               return "eJzrDPBz5+WS4mJgYOD19HAJAtKMIMzBBCQnlAff";
            when 2 =>
               return "A0u4OIZUzEn+cf4AAwMzIyPDSYZjUx4BJRg8Xf1c1jklNAEA1dYQSw==";
            when others =>
               return "";
         end case;
      end Zlib_PNG_Chunk_Text;

      procedure Capture_Zlib_PNG_Row
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean)
      is
      begin
         Zlib_PNG_Row_Count := Zlib_PNG_Row_Count + 1;
         if Y /= 0 or else Row'Length /= 4 then
            Continue := False;
            return;
         end if;
         Zlib_PNG_Row_Bytes := Row;
      end Capture_Zlib_PNG_Row;

      function Base64_Chunk_Text (Index : Positive) return String is
      begin
         case Index is
            when 1 =>
               return "SG";
            when 2 =>
               return "k=";
            when others =>
               return "";
         end case;
      end Base64_Chunk_Text;

      function Base64_Trailing_Text (Index : Positive) return String is
      begin
         if Index = 1 then
            return "SGk=A";
         else
            return "";
         end if;
      end Base64_Trailing_Text;

      procedure Capture_Base64_Byte
        (Value : Terminal.Common.Bytes.Byte;
         Continue : in out Boolean)
      is
      begin
         if Base64_Byte_Count >= Base64_Bytes'Length then
            Continue := False;
            return;
         end if;
         Base64_Byte_Count := Base64_Byte_Count + 1;
         Base64_Bytes (Base64_Byte_Count) := Value;
      end Capture_Base64_Byte;

      procedure Count_Base64_Trailing_Byte
        (Value : Terminal.Common.Bytes.Byte;
         Continue : in out Boolean)
      is
         pragma Unreferenced (Value, Continue);
      begin
         Base64_Byte_Trailing_Count := Base64_Byte_Trailing_Count + 1;
      end Count_Base64_Trailing_Byte;

      function Adam7_Base64_Text (Index : Positive) return String is
      begin
         if Index = 1 then
            return
              "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAAEFsT2yAAAAE0lEQVR4nGP4z8AARkCC4T8YAABLxwn3Qam/GAAAAABJRU5ErkJggg==";
         else
            return "";
         end if;
      end Adam7_Base64_Text;

      procedure Capture_Adam7_PNG_Byte
        (Value : Terminal.Common.Bytes.Byte;
         Continue : in out Boolean)
      is
      begin
         if Adam7_PNG_Length >= Adam7_PNG_Bytes'Length then
            Continue := False;
            return;
         end if;
         Adam7_PNG_Length := Adam7_PNG_Length + 1;
         Adam7_PNG_Bytes (Adam7_PNG_Length) := Value;
      end Capture_Adam7_PNG_Byte;

      procedure Capture_Adam7_Row
        (Y : Natural;
         Row : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean)
      is
      begin
         Adam7_Row_Count := Adam7_Row_Count + 1;
         if Row'Length /= 8 then
            Continue := False;
            return;
         end if;
         if Y = 0 then
            Adam7_First_Row := Row;
         elsif Y = 1 then
            Adam7_Second_Row := Row;
         else
            Continue := False;
         end if;
      end Capture_Adam7_Row;
   begin
      Set_Preview (Kitty, "Gf=32,a=T,i=42;SGk=");
      Set_Preview
        (ITerm2,
         "File=name=a;inline=1;width=12;height=5;doNotMoveCursor=1:SGk=");
      Set_Preview
        (ITerm2_PNG,
         "File=name=pixel.png;inline=1:iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJAMaU4gAAAABJRU5ErkJggg==");
      Build_JPEG;
      declare
         JPEG_Base64 : constant String :=
           Base64_Encode (JPEG_Storage, JPEG_Length);
      begin
         Set_Preview
           (ITerm2_JPEG,
            "File=name=pixel.jpg;inline=1:" & JPEG_Base64);
         Set_Preview
           (Kitty_JPEG,
            "Gf=100,a=T,c=1,r=1;" & JPEG_Base64);
      end;
      Set_Preview
        (ITerm2_Gray_PNG,
         "File=name=gray.png;inline=1:iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAADUlEQVR4AQECAP3/AIAAggCBw24l4AAAAABJRU5ErkJggg==");
      Set_Preview
        (ITerm2_Palette_PNG,
         "File=name=pal.png;inline=1:iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAMAAAAoyzS7AAAAA1BMVEURIjOi/NOrAAAAAXRSTlNEMVdd7wAAAA1JREFUeAEBAgD9/wAAAAIAAX4FDdIAAAAASUVORK5CYII=");
      Set_Preview
        (ITerm2_Gray1_PNG,
         "File=name=gray1.png;inline=1:iVBORw0KGgoAAAANSUhEUgAAAAgAAAABAQAAAADLe9LuAAAACklEQVR4nGNYBQAArACrZgvkawAAAABJRU5ErkJggg==");
      Set_Preview
        (ITerm2_Gray2_PNG,
         "File=name=gray2.png;inline=1:iVBORw0KGgoAAAANSUhEUgAAAAQAAAABAgAAAACW50iwAAAACklEQVR4nGOQBgAAHQAcjvT1IQAAAABJRU5ErkJggg==");
      Set_Preview
        (ITerm2_Gray4_PNG,
         "File=name=gray4.png;inline=1:iVBORw0KGgoAAAANSUhEUgAAAAIAAAABBAAAAAAUuc1XAAAACklEQVR4nGP4AAAA8gDxnPEd5gAAAABJRU5ErkJggg==");
      Set_Preview
        (ITerm2_RGB16_PNG,
         "File=name=rgb16.png;inline=1:iVBORw0KGgoAAAANSUhEUgAAAAEAAAABEAIAAADA54+dAAAAD0lEQVR4nGP4/7+BgYEBAAz8An+jd5TMAAAAAElFTkSuQmCC");
      Set_Preview
        (ITerm2_GA16_PNG,
         "File=name=ga16.png;inline=1:iVBORw0KGgoAAAANSUhEUgAAAAEAAAABEAQAAADljNBBAAAADUlEQVR4nGNoYGhgAAADBQEBbmqArgAAAABJRU5ErkJggg==");
      Set_Preview
        (ITerm2_RGBA16_PNG,
         "File=name=rgba16.png;inline=1:iVBORw0KGgoAAAANSUhEUgAAAAEAAAABEAYAAABPhRjKAAAAD0lEQVR4nGP4/5+BoQEIARH6Av/MYxcQAAAAAElFTkSuQmCC");
      Set_Preview
        (ITerm2_Palette1_PNG,
         "File=name=pal1.png;inline=1:iVBORw0KGgoAAAANSUhEUgAAAAIAAAABAQMAAADO7O3JAAAABlBMVEUAAAARIjOg4Ve+AAAAAnRSTlP/RJQGtcMAAAAKSURBVHicY2gAAACCAIF3zXK2AAAAAElFTkSuQmCC");
      Set_Preview
        (ITerm2_Adam7_PNG,
         "File=name=adam7.png;inline=1:iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAAEFsT2yAAAAE0lEQVR4nGP4z8AARkCC4T8YAABLxwn3Qam/GAAAAABJRU5ErkJggg==");
      Set_Preview (Kitty_Sized, "Gf=100,a=T,c=9,r=4;AAAA");
      Set_Preview (Kitty_RGBA, "Gf=32,s=1,v=1;/wAA/w==");
      Set_Preview (Kitty_Chunk, "Gf=32,s=2,v=1,m=1;/wAA");
      Set_Preview
        (Kitty_PNG,
         "Gf=100,a=T,c=1,r=1;iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJAMaU4gAAAABJRU5ErkJggg==");
      Set_Preview
        (Kitty_Large_RGBA,
         "Gf=32,s=33,v=32,c=33,r=32;" & Repeat_Char ('A', 5632));
      Set_Preview
        (Kitty_Oversized_RGBA,
         "Gf=32,s=16385,v=1024,c=40,r=20;AAAA");
      Set_Preview (Kitty_Partial, "Gf=100,a=T;SG$=");
      Set_Preview (Kitty_Trailing, "Gf=100,a=T;SGk=A");
      Set_Preview (Sixel, "q??~~");

      Kitty_Header := Graphics.Header (Kitty);
      Assert (Kitty_Header.Recognized, "kitty header recognized");
      Assert (Kitty_Header.Has_Data, "kitty header data marker");
      Assert (Kitty_Header.Kitty_Action = 'T', "kitty action field");
      Assert (Kitty_Header.Kitty_ID = 42, "kitty image id field");
      Assert (Kitty_Header.Kitty_Format = 32, "kitty format field");
      Assert
        (Graphics.Header (Kitty_RGBA).Kitty_Action = 't',
         "kitty omitted action defaults to transmit-only");
      Kitty_Placement_Header := Graphics.Header_Text
        (Terminal.Core.Kitty_Graphics,
         "Ga=p,i=42,I=43,p=44,t=d,o=z,q=1,N=1,S=45,O=46," &
         "x=2,y=3,w=4,h=5,X=6,Y=7,z=-8,C=1,U=1,P=9,Q=10," &
         "H=-11,V=12,d=p");
      Assert
        (Kitty_Placement_Header.Recognized
         and then Kitty_Placement_Header.Kitty_Action = 'p'
         and then Kitty_Placement_Header.Kitty_ID = 42
         and then Kitty_Placement_Header.Kitty_Image_Number = 43
         and then Kitty_Placement_Header.Kitty_Placement_ID = 44,
         "kitty placement identity fields");
      Assert
        (Kitty_Placement_Header.Kitty_Transmission = 'd'
         and then Kitty_Placement_Header.Kitty_Compression = 'z'
         and then Kitty_Placement_Header.Kitty_Delete = 'p'
         and then Kitty_Placement_Header.Kitty_Quiet = 1
         and then Kitty_Placement_Header.Kitty_Usage_Hint = 1
         and then Kitty_Placement_Header.Kitty_Data_Size = 45
         and then Kitty_Placement_Header.Kitty_Data_Offset = 46,
         "kitty control fields");
      Assert
        (Kitty_Placement_Header.Kitty_Source_X = 2
         and then Kitty_Placement_Header.Kitty_Source_Y = 3
         and then Kitty_Placement_Header.Kitty_Source_Width = 4
         and then Kitty_Placement_Header.Kitty_Source_Height = 5
         and then Kitty_Placement_Header.Kitty_Cell_X = 6
         and then Kitty_Placement_Header.Kitty_Cell_Y = 7,
         "kitty crop and cell offset fields");
      Assert
        (Kitty_Placement_Header.Kitty_Z_Index = -8
         and then Kitty_Placement_Header.Kitty_No_Cursor_Move
         and then Kitty_Placement_Header.Kitty_Virtual_Placement,
         "kitty placement behavior fields");
      Assert
        (Kitty_Placement_Header.Kitty_Parent_ID = 9
         and then Kitty_Placement_Header.Kitty_Parent_Placement_ID = 10
         and then Kitty_Placement_Header.Kitty_Parent_Offset_X = -11
         and then Kitty_Placement_Header.Kitty_Parent_Offset_Y = 12,
         "kitty relative placement fields");
      declare
         Max_ID_Header : constant Graphics.Graphics_Header :=
           Graphics.Header_Text
             (Terminal.Core.Kitty_Graphics,
              "Gi=4294967295,p=4294967295");
      begin
         Assert
           (Max_ID_Header.Kitty_ID = Terminal.Core.Graphics_ID'Last
            and then Max_ID_Header.Kitty_Placement_ID =
              Terminal.Core.Graphics_ID'Last,
            "kitty IDs should preserve all unsigned 32 bits");
      end;
      declare
         Duplicate : constant Graphics.Graphics_Header :=
           Graphics.Header_Text
             (Terminal.Core.Kitty_Graphics,
              "Ga=t,i=1,i=2,f=32,s=1,v=1;/wAA/w==");
         Malformed : constant Graphics.Graphics_Header :=
           Graphics.Header_Text
             (Terminal.Core.Kitty_Graphics,
              "Ga=t,i=1,f=32,s=bad,v=1;/wAA/w==");
         Bad_Action_Shape : constant Graphics.Graphics_Header :=
           Graphics.Header_Text
             (Terminal.Core.Kitty_Graphics,
              "Ga=p,i=1;AAAA");
         Default_Format : constant Graphics.Graphics_Header :=
           Graphics.Header_Text
             (Terminal.Core.Kitty_Graphics,
              "Ga=t,s=1,v=1;/wAA/w==");
      begin
         Assert
           (not Duplicate.Kitty_Control_Data_Valid,
            "kitty duplicate controls are invalid");
         Assert
           (not Malformed.Kitty_Control_Data_Valid,
            "kitty malformed numeric controls are invalid");
         Assert
           (not Bad_Action_Shape.Kitty_Action_Controls_Valid,
            "kitty put action rejects transmitted payload data");
         Assert
           (Default_Format.Kitty_Format = 32
            and then Default_Format.Raw_Format = 32
            and then Default_Format.Kitty_Action_Controls_Valid,
            "kitty omitted format defaults to RGBA");
      end;
      Assert (Graphics.Placeholder_Cols (Kitty) = 6, "kitty parsed placeholder cols");
      Assert (Graphics.Placeholder_Rows (Kitty) = 3, "kitty parsed placeholder rows");
      Assert
        (not Kitty_Header.Kitty_Columns_Specified
         and then Kitty_Header.Kitty_Columns_Valid
         and then not Kitty_Header.Kitty_Rows_Specified
         and then Kitty_Header.Kitty_Rows_Valid,
         "kitty omitted placement span validity");
      declare
         Exact_Span : constant Graphics.Graphics_Header :=
           Graphics.Header_Text
             (Terminal.Core.Kitty_Graphics, "Ga=p,c=1000,r=2000");
         Invalid_Span : constant Graphics.Graphics_Header :=
           Graphics.Header_Text
             (Terminal.Core.Kitty_Graphics, "Ga=p,c=0,r=bad");
         Omitted_Span : constant Graphics.Graphics_Header :=
           Graphics.Header_Text
             (Terminal.Core.Kitty_Graphics, "Ga=p,i=1");
         Invalid_Geometry : constant Graphics.Graphics_Header :=
           Graphics.Header_Text
             (Terminal.Core.Kitty_Graphics, "Ga=p,x=bad,w=999999999999999999999");
      begin
         Assert
           (Exact_Span.Placeholder_Cols = 1000
            and then Exact_Span.Placeholder_Rows = 2000,
            "kitty placement spans are not silently clamped");
         Assert
           (Invalid_Span.Kitty_Columns_Specified
            and then not Invalid_Span.Kitty_Columns_Valid
            and then Invalid_Span.Kitty_Rows_Specified
            and then not Invalid_Span.Kitty_Rows_Valid,
            "kitty invalid placement spans remain distinguishable");
         Assert
           (not Omitted_Span.Kitty_Columns_Specified
            and then not Omitted_Span.Kitty_Rows_Specified,
            "kitty omitted placement spans remain distinguishable");
         Assert
           (not Invalid_Geometry.Kitty_Geometry_Controls_Valid,
            "kitty malformed and overflowing geometry fields are invalid");
      end;
      Assert
        (Graphics.Header_Status_Label (Kitty) =
         "kitty header ready; format=32; data previewed",
         "kitty header status label");
      Kitty_Data := Graphics.Data_Preview (Kitty);
      Assert (Kitty_Data.Header_Recognized, "kitty data header recognized");
      Assert (Kitty_Data.Has_Data, "kitty data found");
      Assert (Kitty_Data.Encoded_Length = 4, "kitty encoded data preview length");
      Assert (Kitty_Data.Decoded_Length = 2, "kitty decoded data preview length");
      Assert (Kitty_Data.Decode_Complete, "kitty data preview decode complete");
      Assert
        (Kitty_Data.Decode_Status = Graphics.Decode_Ok,
         "kitty data preview decode status");
      Assert
        (Kitty_Data.Bytes (1) = Terminal.Common.Bytes.Byte (Character'Pos ('H'))
         and then Kitty_Data.Bytes (2) =
           Terminal.Common.Bytes.Byte (Character'Pos ('i')),
         "kitty decoded data preview bytes");
      Assert
        (Graphics.Data_Status_Label (Kitty) =
         "kitty data preview decoded=2/4 bytes=4869 decoded",
         "kitty data status label");

      Kitty_RGBA_Data := Graphics.Data_Preview (Kitty_RGBA);
      Assert
        (Kitty_RGBA_Data.Decoded_Length = 4,
         "padded kitty RGBA decoded data preview length");
      Assert
        (Kitty_RGBA_Data.Bytes /= null
         and then Kitty_RGBA_Data.Bytes'Length = 4,
         "padded kitty RGBA decoded buffer should be exact length");
      Assert
        (Kitty_RGBA_Data.Bytes (1) = 16#FF#
         and then Kitty_RGBA_Data.Bytes (2) = 16#00#
         and then Kitty_RGBA_Data.Bytes (3) = 16#00#
         and then Kitty_RGBA_Data.Bytes (4) = 16#FF#,
         "padded kitty RGBA decoded data preview bytes");

      Kitty_Chunk_Header := Graphics.Header (Kitty_Chunk);
      Assert
        (Kitty_Chunk_Header.Kitty_More
         and then Kitty_Chunk_Header.Kitty_More_Specified
         and then Kitty_Chunk_Header.Kitty_More_Valid,
         "kitty chunk continuation field");
      Assert
        (not Graphics.Header_Text
           (Terminal.Core.Kitty_Graphics, "Gm=2;AAAA").Kitty_More_Valid,
         "invalid kitty chunk continuation value");

      Kitty_PNG_Data := Graphics.Data_Preview (Kitty_PNG);
      Assert
        (Kitty_PNG_Data.Raw_Format = 32
         and then Kitty_PNG_Data.Pixel_Width = 1
         and then Kitty_PNG_Data.Pixel_Height = 1,
         "kitty PNG pixel metadata");
      Assert
        (Kitty_PNG_Data.Decoded_Length = 4,
         "kitty PNG decoded RGBA length");
      Assert
        (Kitty_PNG_Data.Bytes /= null
         and then Kitty_PNG_Data.Bytes'Length = 4,
         "kitty PNG decoded buffer should be exact length");
      Assert
        (Kitty_PNG_Data.Decode_Complete,
         "kitty PNG decode complete");
      Assert
        (Kitty_PNG_Data.Decode_Status = Graphics.Decode_Ok,
         "kitty PNG decode status");
      Assert
        (Kitty_PNG_Data.Bytes (1) = 16#FF#
         and then Kitty_PNG_Data.Bytes (2) = 16#00#
         and then Kitty_PNG_Data.Bytes (3) = 16#00#
         and then Kitty_PNG_Data.Bytes (4) = 16#FF#,
         "kitty PNG decoded RGBA bytes");

      Kitty_JPEG_Data := Graphics.Data_Preview (Kitty_JPEG);
      Assert
        (Kitty_JPEG_Data.Decoded_Length = 0
         and then not Kitty_JPEG_Data.Decode_Complete
         and then Kitty_JPEG_Data.Bytes = null
         and then Kitty_JPEG_Data.Decode_Status =
           Graphics.Decode_Unsupported_Format,
         "Kitty f=100 rejects non-PNG image data");

      Graphics.Decode_PNG_RGBA_Rows
        (PNG_Row_Data,
         PNG_Row_Data'Length,
         Capture_PNG_Row'Access,
         PNG_Row_Result);
      Assert
        (PNG_Row_Result.Raw_Format = 32
         and then PNG_Row_Result.Pixel_Width = 1
         and then PNG_Row_Result.Pixel_Height = 1
         and then PNG_Row_Result.Decoded_Row_Stride_Bytes = 4,
         "PNG row decoder pixel metadata");
      Assert
        (PNG_Row_Result.Decoded_Length = 4
         and then PNG_Row_Result.Decode_Complete
         and then PNG_Row_Result.Decode_Status = Graphics.Decode_Ok,
         "PNG row decoder completion");
      Assert
        (PNG_Row_Result.Bytes = null,
         "PNG row decoder should not allocate result image bytes");
      Assert
        (PNG_Row_Count = 1,
         "PNG row decoder row count");
      Assert
        (PNG_Row_Bytes (1) = 16#FF#
         and then PNG_Row_Bytes (2) = 16#00#
         and then PNG_Row_Bytes (3) = 16#00#
         and then PNG_Row_Bytes (4) = 16#FF#,
         "PNG row decoder RGBA bytes");

      Graphics.Decode_PNG_RGBA_Source_Rows
        (PNG_Row_Data'Length,
         PNG_Source_Byte'Access,
         Capture_PNG_Source_Row'Access,
         PNG_Source_Row_Result);
      Assert
        (PNG_Source_Row_Result.Raw_Format = 32
         and then PNG_Source_Row_Result.Pixel_Width = 1
         and then PNG_Source_Row_Result.Pixel_Height = 1
         and then PNG_Source_Row_Result.Decoded_Row_Stride_Bytes = 4,
         "PNG source row decoder pixel metadata");
      Assert
        (PNG_Source_Row_Result.Decoded_Length = 4
         and then PNG_Source_Row_Result.Decode_Complete
         and then PNG_Source_Row_Result.Decode_Status = Graphics.Decode_Ok,
         "PNG source row decoder completion");
      Assert
        (PNG_Source_Row_Result.Bytes = null,
         "PNG source row decoder should not allocate result image bytes");
      Assert
        (PNG_Source_Row_Count = 1,
         "PNG source row decoder row count");
      Assert
        (PNG_Source_Row_Bytes (1) = 16#FF#
         and then PNG_Source_Row_Bytes (2) = 16#00#
         and then PNG_Source_Row_Bytes (3) = 16#00#
         and then PNG_Source_Row_Bytes (4) = 16#FF#,
         "PNG source row decoder RGBA bytes");

      PNG_Corrupt_CRC (55) := 16#01#;
      Graphics.Decode_PNG_RGBA_Rows
        (PNG_Corrupt_CRC,
         PNG_Corrupt_CRC'Length,
         Capture_PNG_Row'Access,
         PNG_Corrupt_CRC_Result);
      Assert
        (not PNG_Corrupt_CRC_Result.Decode_Complete
         and then PNG_Corrupt_CRC_Result.Decode_Status =
           Graphics.Decode_Invalid_Byte,
         "PNG row decoder rejects a corrupt chunk CRC");

      Graphics.Decode_PNG_RGBA_Rows
        (PNG_Huge_Chunk,
         PNG_Huge_Chunk'Length,
         Capture_PNG_Row'Access,
         PNG_Huge_Chunk_Result);
      Assert
        (not PNG_Huge_Chunk_Result.Decode_Complete
         and then PNG_Huge_Chunk_Result.Decode_Status =
           Graphics.Decode_Invalid_Byte,
         "PNG row decoder rejects an overflowing chunk length");

      PNG_Trailing (PNG_Row_Data'Range) := PNG_Row_Data;
      PNG_Trailing (PNG_Trailing'Last) := 16#00#;
      Graphics.Decode_PNG_RGBA_Rows
        (PNG_Trailing,
         PNG_Trailing'Length,
         Capture_PNG_Row'Access,
         PNG_Trailing_Result);
      Assert
        (not PNG_Trailing_Result.Decode_Complete
         and then PNG_Trailing_Result.Decode_Status =
           Graphics.Decode_Trailing_Data,
         "PNG row decoder rejects bytes after IEND");

      Graphics.Decode_Base64_PNG_Chunk_Rows
        (2,
         Base64_PNG_Text'Access,
         Base64_PNG_Encoded_Length,
         Base64_PNG_Length,
         Capture_Base64_PNG_Row'Access,
         Base64_PNG_Row_Result);
      Assert
        (Base64_PNG_Encoded_Length = 96
         and then Base64_PNG_Length = PNG_Row_Data'Length,
         "Base64 PNG row decoder byte counts");
      Assert
        (Base64_PNG_Row_Result.Decoded_Length = 4
         and then Base64_PNG_Row_Result.Decode_Complete
         and then Base64_PNG_Row_Result.Decode_Status = Graphics.Decode_Ok,
         "Base64 PNG row decoder completion");
      Assert
        (Base64_PNG_Row_Result.Bytes = null,
         "Base64 PNG row decoder should not allocate result image bytes");
      Assert
        (Base64_PNG_Row_Count = 1,
         "Base64 PNG row decoder row count");
      Assert
        (Base64_PNG_Row_Bytes (1) = 16#FF#
         and then Base64_PNG_Row_Bytes (2) = 16#00#
         and then Base64_PNG_Row_Bytes (3) = 16#00#
         and then Base64_PNG_Row_Bytes (4) = 16#FF#,
         "Base64 PNG row decoder RGBA bytes");

      Graphics.Decode_Base64_PNG_Chunk_Rows
        (1,
         Base64_PNG_Invalid_Text'Access,
         Base64_PNG_Invalid_Encoded_Length,
         Base64_PNG_Invalid_Length,
         Capture_Base64_PNG_Row'Access,
         Base64_PNG_Invalid_Result);
      Assert
        (Base64_PNG_Invalid_Encoded_Length = 3
         and then Base64_PNG_Invalid_Length = 0
         and then not Base64_PNG_Invalid_Result.Decode_Complete
         and then Base64_PNG_Invalid_Result.Decode_Status =
           Graphics.Decode_Invalid_Byte,
         "invalid Base64 PNG row decoder status");

      Graphics.Decode_Base64_PNG_Chunk_Rows
        (1,
         Base64_PNG_Not_PNG_Text'Access,
         Base64_PNG_Not_PNG_Encoded_Length,
         Base64_PNG_Not_PNG_Length,
         Capture_Base64_PNG_Row'Access,
         Base64_PNG_Not_PNG_Result);
      Assert
        (Base64_PNG_Not_PNG_Encoded_Length = 4
         and then Base64_PNG_Not_PNG_Length = 2
         and then not Base64_PNG_Not_PNG_Result.Decode_Complete
         and then Base64_PNG_Not_PNG_Result.Decode_Status =
           Graphics.Decode_Unsupported_Format,
         "padded non-PNG Base64 row decoder status");

      Graphics.Decode_Base64_PNG_Chunk_Rows
        (1,
         Base64_PNG_Trailing_Text'Access,
         Base64_PNG_Trailing_Encoded_Length,
         Base64_PNG_Trailing_Length,
         Capture_Base64_PNG_Row'Access,
         Base64_PNG_Trailing_Result);
      Assert
        (Base64_PNG_Trailing_Encoded_Length = 5
         and then Base64_PNG_Trailing_Length = 2
         and then not Base64_PNG_Trailing_Result.Decode_Complete
         and then Base64_PNG_Trailing_Result.Decode_Status =
           Graphics.Decode_Trailing_Data,
         "trailing Base64 PNG row decoder status");

      Graphics.Decode_Base64_PNG_Chunk_Rows
        (2,
         Base64_PNG_Text'Access,
         Base64_PNG_Stop_Encoded_Length,
         Base64_PNG_Stop_Length,
         Reject_Base64_PNG_Row'Access,
         Base64_PNG_Stop_Result);
      Assert
        (Base64_PNG_Stop_Encoded_Length = 96
         and then Base64_PNG_Stop_Length = PNG_Row_Data'Length
         and then not Base64_PNG_Stop_Result.Decode_Complete
         and then Base64_PNG_Stop_Result.Decode_Status =
           Graphics.Decode_Invalid_Byte,
         "Base64 PNG row decoder sink stop status");

      Graphics.Decode_Sixel_Rows
        ("q~", Capture_Sixel_Row'Access, Sixel_Row_Result);
      Assert
        (Sixel_Row_Result.Raw_Format = 32
         and then Sixel_Row_Result.Pixel_Width = 1
         and then Sixel_Row_Result.Pixel_Height = 6
         and then Sixel_Row_Result.Decoded_Row_Stride_Bytes = 4,
         "sixel row decoder pixel metadata");
      Assert
        (Sixel_Row_Result.Decoded_Length = 24
         and then Sixel_Row_Result.Decode_Complete
         and then Sixel_Row_Result.Decode_Status = Graphics.Decode_Ok,
         "sixel row decoder completion");
      Assert
        (Sixel_Row_Result.Bytes = null,
         "sixel row decoder should not allocate result image bytes");
      Assert
        (Sixel_Row_Count = 6,
         "sixel row decoder row count");
      Assert
        (Sixel_First_Row (1) = 16#FF#
         and then Sixel_First_Row (2) = 16#FF#
         and then Sixel_First_Row (3) = 16#FF#
         and then Sixel_First_Row (4) = 16#FF#,
         "sixel row decoder first RGBA row");

      declare
         Oversized : Graphics.Graphics_Data_Preview;
      begin
         Sixel_Row_Count := 0;
         Graphics.Decode_Sixel_Rows
           ("q""1;1;999999999;999999999~",
            Capture_Sixel_Row'Access,
            Oversized,
            Maximum_Decoded_Bytes => 1_024,
            Maximum_Pixel_Dimension => 1_024);
         Assert
           (not Oversized.Decode_Complete
            and then Oversized.Decode_Status =
              Graphics.Decode_Preview_Truncated
            and then Sixel_Row_Count = 0,
            "oversized sixel raster is rejected before band allocation");
      end;

      declare
         Palette : Graphics.Sixel_Palette_State :=
           Graphics.Default_Sixel_Palette;
         Shared_Result : Graphics.Graphics_Data_Preview;
      begin
         Sixel_Row_Count := 0;
         Sixel_First_Row := (others => 0);
         Graphics.Decode_Sixel_Rows
           ("q#5;2;100;0;0~",
            Capture_Sixel_Row'Access,
            Palette,
            Reset_Palette => False,
            Result => Shared_Result);
         Graphics.Decode_Sixel_Rows
           ("q#5~",
            Capture_Sixel_Row'Access,
            Palette,
            Reset_Palette => False,
            Result => Shared_Result);
         Assert
           (Shared_Result.Decode_Complete
            and then Sixel_First_Row (1) = 16#FF#
            and then Sixel_First_Row (2) = 0
            and then Sixel_First_Row (3) = 0,
            "sixel shared palette definitions persist across graphics");
         Graphics.Decode_Sixel_Rows
           ("q#5~",
            Capture_Sixel_Row'Access,
            Palette,
            Reset_Palette => True,
            Result => Shared_Result);
         Assert
           (Sixel_First_Row (1) = 16#FF#
            and then Sixel_First_Row (2) = 16#FF#
            and then Sixel_First_Row (3) = 16#FF#,
            "sixel private palette resets for each graphic");
      end;

      declare
         Transparent_Raster : Graphics.Graphics_Data_Preview :=
           Graphics.Data_Preview_Text
             (Terminal.Core.Sixel_Graphics,
              "1;1q""1;1;3;8#2;2;100;0;0~");
         Opaque_Raster : Graphics.Graphics_Data_Preview :=
           Graphics.Data_Preview_Text
             (Terminal.Core.Sixel_Graphics, "q""1;1;2;7?");
         HLS_Raster : Graphics.Graphics_Data_Preview :=
           Graphics.Data_Preview_Text
             (Terminal.Core.Sixel_Graphics, "q#5;1;120;50;100~");
         Aspect_Raster : Graphics.Graphics_Data_Preview :=
           Graphics.Data_Preview_Text
             (Terminal.Core.Sixel_Graphics, "q""2;1;1;6~");
         DCS_Aspect_Raster : Graphics.Graphics_Data_Preview :=
           Graphics.Data_Preview_Text
             (Terminal.Core.Sixel_Graphics, "5q~");
      begin
         Assert
           (Transparent_Raster.Decode_Complete
            and then Transparent_Raster.Pixel_Width = 3
            and then Transparent_Raster.Pixel_Height = 8
            and then Transparent_Raster.Decoded_Length = 96,
            "sixel raster attributes should declare a minimum canvas");
         Assert
           (Transparent_Raster.Bytes /= null
            and then Transparent_Raster.Bytes (1) = 16#FF#
            and then Transparent_Raster.Bytes (2) = 0
            and then Transparent_Raster.Bytes (3) = 0
            and then Transparent_Raster.Bytes (4) = 16#FF#
            and then Transparent_Raster.Bytes (8) = 0,
            "sixel transparent background mode should preserve unset alpha");
         Assert
           (Opaque_Raster.Decode_Complete
            and then Opaque_Raster.Pixel_Width = 2
            and then Opaque_Raster.Pixel_Height = 7
            and then Opaque_Raster.Bytes /= null
            and then Opaque_Raster.Bytes (4) = 16#FF#,
            "sixel default background mode should erase to register zero");
         Assert
           (HLS_Raster.Decode_Complete
            and then HLS_Raster.Bytes /= null
            and then HLS_Raster.Bytes (1) = 16#FF#
            and then HLS_Raster.Bytes (2) = 0
            and then HLS_Raster.Bytes (3) = 0
            and then HLS_Raster.Bytes (4) = 16#FF#,
            "sixel HLS palette definitions should use the DEC color wheel");
         Assert
           (Aspect_Raster.Decode_Complete
            and then Aspect_Raster.Pixel_Width = 1
            and then Aspect_Raster.Pixel_Height = 12
            and then Aspect_Raster.Decoded_Length = 48,
            "sixel Pan/Pad should apply the vertical pixel aspect ratio");
         Assert
           (DCS_Aspect_Raster.Decode_Complete
            and then DCS_Aspect_Raster.Pixel_Width = 1
            and then DCS_Aspect_Raster.Pixel_Height = 12
            and then DCS_Aspect_Raster.Decoded_Length = 48,
            "sixel DCS aspect selector should scale raster rows");
         Graphics.Release (Transparent_Raster);
         Graphics.Release (Aspect_Raster);
         Graphics.Release (DCS_Aspect_Raster);
         Graphics.Release (Opaque_Raster);
         Graphics.Release (HLS_Raster);
      end;

      Graphics.Decode_Base64_Raw_Rows
        ("/wAA/w==", 32, 1, 1, Capture_Raw_Row'Access, Raw_Row_Result);
      Assert
        (Raw_Row_Result.Raw_Format = 32
         and then Raw_Row_Result.Pixel_Width = 1
         and then Raw_Row_Result.Pixel_Height = 1
         and then Raw_Row_Result.Decoded_Row_Stride_Bytes = 4,
         "raw row decoder pixel metadata");
      Assert
        (Raw_Row_Result.Decoded_Length = 4
         and then Raw_Row_Result.Decode_Complete
         and then Raw_Row_Result.Decode_Status = Graphics.Decode_Ok,
         "raw row decoder completion");
      Assert
        (Raw_Row_Result.Bytes = null,
         "raw row decoder should not allocate result image bytes");
      Assert
        (Raw_Row_Count = 1,
         "raw row decoder row count");
      Assert
        (Raw_Row_Bytes (1) = 16#FF#
         and then Raw_Row_Bytes (2) = 16#00#
         and then Raw_Row_Bytes (3) = 16#00#
         and then Raw_Row_Bytes (4) = 16#FF#,
         "raw row decoder RGBA bytes");

      Graphics.Decode_Base64_Raw_Chunk_Rows
        (2,
         Raw_Chunk_Text'Access,
         32,
         1,
         1,
         Capture_Raw_Chunk_Row'Access,
         Raw_Chunk_Row_Result);
      Assert
        (Raw_Chunk_Row_Result.Decoded_Length = 4
         and then Raw_Chunk_Row_Result.Decode_Complete
         and then Raw_Chunk_Row_Result.Decode_Status = Graphics.Decode_Ok,
         "chunked raw row decoder completion");
      Assert
        (Raw_Chunk_Row_Result.Encoded_Length = 8,
         "chunked raw row decoder encoded length");
      Assert
        (Raw_Chunk_Row_Result.Bytes = null,
         "chunked raw row decoder should not allocate result image bytes");
      Assert
        (Raw_Chunk_Row_Count = 1,
         "chunked raw row decoder row count");
      Assert
        (Raw_Chunk_Row_Bytes (1) = 16#FF#
         and then Raw_Chunk_Row_Bytes (2) = 16#00#
         and then Raw_Chunk_Row_Bytes (3) = 16#00#
         and then Raw_Chunk_Row_Bytes (4) = 16#FF#,
         "chunked raw row decoder RGBA bytes");

      Graphics.Decode_Base64_Zlib_Raw_Chunk_Rows
        (2,
         Zlib_Raw_Chunk_Text'Access,
         32,
         1,
         1,
         Capture_Zlib_Raw_Row'Access,
         Zlib_Raw_Result);
      Assert
        (Zlib_Raw_Result.Encoded_Length = 16
         and then Zlib_Raw_Result.Decoded_Length = 4
         and then Zlib_Raw_Result.Decode_Complete
         and then Zlib_Raw_Result.Decode_Status = Graphics.Decode_Ok,
         "zlib raw row decoder completion");
      Assert
        (Zlib_Raw_Row_Count = 1
         and then Zlib_Raw_Row_Bytes (1) = 16#FF#
         and then Zlib_Raw_Row_Bytes (2) = 16#00#
         and then Zlib_Raw_Row_Bytes (3) = 16#00#
         and then Zlib_Raw_Row_Bytes (4) = 16#FF#,
         "zlib raw row decoder bytes");

      Graphics.Decode_Base64_Zlib_Raw_Chunk_Rows
        (1,
         Zlib_Raw_Invalid_Text'Access,
         32,
         1,
         1,
         Capture_Zlib_Raw_Row'Access,
         Zlib_Raw_Invalid_Result);
      Assert
        (not Zlib_Raw_Invalid_Result.Decode_Complete
         and then Zlib_Raw_Invalid_Result.Decode_Status =
           Graphics.Decode_Invalid_Byte,
         "zlib raw decoder rejects invalid checksum");

      Graphics.Decode_Base64_Zlib_PNG_Chunk_Rows
        (2,
         Zlib_PNG_Chunk_Text'Access,
         70,
         Zlib_PNG_Encoded_Length,
         Capture_Zlib_PNG_Row'Access,
         Zlib_PNG_Result);
      Assert
        (Zlib_PNG_Encoded_Length = 96
         and then Zlib_PNG_Result.Decoded_Length = 4
         and then Zlib_PNG_Result.Decode_Complete
         and then Zlib_PNG_Result.Decode_Status = Graphics.Decode_Ok,
         "zlib PNG row decoder completion");
      Assert
        (Zlib_PNG_Row_Count = 1
         and then Zlib_PNG_Row_Bytes (1) = 16#FF#
         and then Zlib_PNG_Row_Bytes (2) = 16#00#
         and then Zlib_PNG_Row_Bytes (3) = 16#00#
         and then Zlib_PNG_Row_Bytes (4) = 16#FF#,
         "zlib PNG row decoder RGBA bytes");

      Zlib_PNG_Row_Count := 0;
      Zlib_PNG_Row_Bytes := (others => 0);
      Graphics.Decode_Base64_Zlib_PNG_Chunk_Rows
        (2,
         Zlib_PNG_Chunk_Text'Access,
         0,
         Zlib_PNG_Encoded_Length,
         Capture_Zlib_PNG_Row'Access,
         Zlib_PNG_Result);
      Assert
        (Zlib_PNG_Result.Decode_Complete
         and then Zlib_PNG_Result.Decode_Status = Graphics.Decode_Ok
         and then Zlib_PNG_Row_Count = 1
         and then Zlib_PNG_Row_Bytes (1) = 16#FF#,
         "bounded zlib PNG decoder discovers inflated length");

      Graphics.Decode_Base64_Chunk_Bytes
        (2,
         Base64_Chunk_Text'Access,
         Capture_Base64_Byte'Access,
         Base64_Byte_Result);
      Assert
        (Base64_Byte_Result.Encoded_Length = 4
         and then Base64_Byte_Result.Decoded_Length = 2
         and then Base64_Byte_Result.Decode_Complete
         and then Base64_Byte_Result.Decode_Status = Graphics.Decode_Ok,
         "chunked byte decoder completion");
      Assert
        (Base64_Byte_Result.Bytes = null,
         "chunked byte decoder should not allocate result bytes");
      Assert
        (Base64_Byte_Count = 2
         and then Base64_Bytes (1) =
           Terminal.Common.Bytes.Byte (Character'Pos ('H'))
         and then Base64_Bytes (2) =
           Terminal.Common.Bytes.Byte (Character'Pos ('i')),
         "chunked byte decoder bytes");

      Graphics.Decode_Base64_Chunk_Bytes
        (1,
         Base64_Trailing_Text'Access,
         Count_Base64_Trailing_Byte'Access,
         Base64_Byte_Trailing_Result);
      Assert
        (Base64_Byte_Trailing_Result.Encoded_Length = 5
         and then Base64_Byte_Trailing_Result.Decoded_Length = 2
         and then not Base64_Byte_Trailing_Result.Decode_Complete
         and then Base64_Byte_Trailing_Result.Decode_Status =
           Graphics.Decode_Trailing_Data,
         "chunked byte decoder trailing status");
      Assert
        (Base64_Byte_Trailing_Count = 2,
         "chunked byte decoder trailing bytes before error");

      Graphics.Decode_Base64_Chunk_Bytes
        (1,
         Adam7_Base64_Text'Access,
         Capture_Adam7_PNG_Byte'Access,
         Adam7_Base64_Result);
      Assert
        (Adam7_Base64_Result.Decode_Complete
         and then Adam7_Base64_Result.Decode_Status = Graphics.Decode_Ok
         and then Adam7_PNG_Length > 0,
         "Adam7 PNG fixture base64 decode");
      Graphics.Decode_PNG_RGBA_Rows
        (Adam7_PNG_Bytes,
         Adam7_PNG_Length,
         Capture_Adam7_Row'Access,
         Adam7_Row_Result);
      Assert
        (Adam7_Row_Result.Decoded_Length = 16
         and then Adam7_Row_Result.Decode_Complete
         and then Adam7_Row_Result.Decode_Status = Graphics.Decode_Ok,
         "Adam7 row decoder completion");
      Assert
        (Adam7_Row_Result.Bytes = null,
         "Adam7 row decoder should not allocate result image bytes");
      Assert
        (Adam7_Row_Count = 2,
         "Adam7 row decoder row count");
      Assert
        (Adam7_First_Row (1) = 16#FF#
         and then Adam7_First_Row (5) = 16#00#
         and then Adam7_First_Row (6) = 16#FF#
         and then Adam7_Second_Row (1) = 16#00#
         and then Adam7_Second_Row (2) = 16#00#
         and then Adam7_Second_Row (3) = 16#FF#
         and then Adam7_Second_Row (5) = 16#FF#
         and then Adam7_Second_Row (6) = 16#FF#
         and then Adam7_Second_Row (7) = 16#FF#,
         "Adam7 row decoder RGBA bytes");

      Kitty_Large_RGBA_Data := Graphics.Data_Preview (Kitty_Large_RGBA);
      Assert
        (Kitty_Large_RGBA_Data.Raw_Format = 32
         and then Kitty_Large_RGBA_Data.Pixel_Width = 33
         and then Kitty_Large_RGBA_Data.Pixel_Height = 32,
         "large kitty RGBA pixel metadata");
      Assert
        (Kitty_Large_RGBA_Data.Decoded_Length = 33 * 32 * 4,
         "large kitty RGBA decoded byte length");
      Assert
        (Kitty_Large_RGBA_Data.Bytes /= null
         and then Kitty_Large_RGBA_Data.Bytes'Length = 33 * 32 * 4,
         "large kitty RGBA decoded buffer should be exact length");
      Assert
        (Kitty_Large_RGBA_Data.Decode_Complete,
         "large kitty RGBA decode complete");
      Assert
        (Kitty_Large_RGBA_Data.Decode_Status = Graphics.Decode_Ok,
         "large kitty RGBA decode status");

      Kitty_Oversized_RGBA_Data := Graphics.Data_Preview (Kitty_Oversized_RGBA);
      Assert
        (Kitty_Oversized_RGBA_Data.Raw_Format = 32
         and then Kitty_Oversized_RGBA_Data.Pixel_Width = 16_385
         and then Kitty_Oversized_RGBA_Data.Pixel_Height = 1_024,
         "oversized kitty RGBA pixel metadata");
      Assert
        (Kitty_Oversized_RGBA_Data.Decoded_Length = 0
         and then Kitty_Oversized_RGBA_Data.Bytes = null
         and then not Kitty_Oversized_RGBA_Data.Decode_Complete
         and then Kitty_Oversized_RGBA_Data.Decode_Status =
           Graphics.Decode_Preview_Truncated,
         "oversized kitty RGBA decode should be rejected before allocation");

      Kitty_Partial_Data := Graphics.Data_Preview (Kitty_Partial);
      Assert
        (Kitty_Partial_Data.Decoded_Length = 0,
         "partial kitty decoded data preview length");
      Assert
        (not Kitty_Partial_Data.Decode_Complete,
         "partial kitty data preview decode should be incomplete");
      Assert
        (Kitty_Partial_Data.Decode_Status = Graphics.Decode_Invalid_Byte,
         "partial kitty data preview decode status");
      Assert
        (Graphics.Data_Status_Label (Kitty_Partial) =
         "kitty data preview decoded=0/4 partial invalid-byte",
         "partial kitty data status label");

      Kitty_Trailing_Data := Graphics.Data_Preview (Kitty_Trailing);
      Assert
        (Kitty_Trailing_Data.Decode_Status = Graphics.Decode_Trailing_Data,
         "trailing kitty data preview decode status");
      Assert
        (Graphics.Data_Status_Label (Kitty_Trailing) =
         "kitty data preview decoded=2/5 bytes=4869 partial trailing-data",
         "trailing kitty data status label");

      ITerm2_Header := Graphics.Header (ITerm2);
      Assert (ITerm2_Header.Recognized, "iTerm2 header recognized");
      Assert (ITerm2_Header.Has_Data, "iTerm2 header data marker");
      Assert (ITerm2_Header.ITerm2_Inline, "iTerm2 inline field");
      Assert (ITerm2_Header.ITerm2_Name_Length = 1, "iTerm2 name field length");
      Assert
        (ITerm2_Header.ITerm2_Width_Specified
         and then ITerm2_Header.ITerm2_Width_Valid
         and then ITerm2_Header.ITerm2_Width_Value = 12
         and then ITerm2_Header.ITerm2_Width_Unit = Graphics.ITerm2_Cells,
         "iTerm2 cell width parsed");
      Assert
        (ITerm2_Header.ITerm2_Height_Specified
         and then ITerm2_Header.ITerm2_Height_Valid
         and then ITerm2_Header.ITerm2_Height_Value = 5
         and then ITerm2_Header.ITerm2_Height_Unit = Graphics.ITerm2_Cells,
         "iTerm2 cell height parsed");
      Assert
        (Graphics.Placeholder_Cols (ITerm2) = 12,
         "iTerm2 numeric width placeholder cols");
      Assert
        (Graphics.Placeholder_Rows (ITerm2) = 5,
         "iTerm2 numeric height placeholder rows");
      declare
         Sized : constant Graphics.Graphics_Header := Graphics.Header_Text
           (Terminal.Core.ITerm2_Graphics,
            "File=inline=1;width=25%;height=40px;preserveAspectRatio=0;doNotMoveCursor=1:AAAA");
         Automatic : constant Graphics.Graphics_Header := Graphics.Header_Text
           (Terminal.Core.ITerm2_Graphics,
            "File=inline=1;width=auto;height=bad:AAAA");
         Invalid_Controls : constant Graphics.Graphics_Header :=
           Graphics.Header_Text
             (Terminal.Core.ITerm2_Graphics,
              "File=inline=2;size=bad;preserveAspectRatio=7;doNotMoveCursor=7:AAAA");
      begin
         Assert
           (Sized.ITerm2_Width_Unit = Graphics.ITerm2_Percent
            and then Sized.ITerm2_Width_Value = 25
            and then Sized.ITerm2_Height_Unit = Graphics.ITerm2_Pixels
            and then Sized.ITerm2_Height_Value = 40
            and then not Sized.ITerm2_Preserve_Aspect_Ratio
            and then Sized.ITerm2_Do_Not_Move_Cursor,
            "iTerm2 percent/pixel sizing parsed");
         Assert
           (Automatic.ITerm2_Width_Unit = Graphics.ITerm2_Auto
            and then Automatic.ITerm2_Width_Valid
            and then not Automatic.ITerm2_Height_Valid,
            "iTerm2 auto and invalid sizing parsed");
         Assert
           (not Invalid_Controls.ITerm2_Control_Data_Valid
            and then not Invalid_Controls.ITerm2_Declared_Size_Valid,
            "iTerm2 enumerated controls and declared size are validated");
      end;
      Assert
        (Graphics.Header_Status_Label (ITerm2) =
         "iTerm2 header ready; inline=yes; name bytes=1",
         "iTerm2 header status label");
      ITerm2_Data := Graphics.Data_Preview (ITerm2);
      Assert
        (ITerm2_Data.Encoded_Length = 4,
         "iTerm2 encoded data preview length");
      Assert
        (ITerm2_Data.Decoded_Length = 0,
         "non-PNG iTerm2 decoded image length");
      Assert
        (not ITerm2_Data.Decode_Complete,
         "non-PNG iTerm2 data should not decode as an image");
      Assert
        (ITerm2_Data.Decode_Status = Graphics.Decode_Unsupported_Format,
         "non-PNG iTerm2 data decode status");
      Assert
        (Graphics.Data_Status_Label (ITerm2) =
         "iTerm2 data preview decoded=0/4 partial unsupported-format",
         "iTerm2 data status label");

      ITerm2_PNG_Data := Graphics.Data_Preview (ITerm2_PNG);
      Assert
        (ITerm2_PNG_Data.Raw_Format = 32
         and then ITerm2_PNG_Data.Pixel_Width = 1
         and then ITerm2_PNG_Data.Pixel_Height = 1,
         "iTerm2 PNG pixel metadata");
      Assert
        (ITerm2_PNG_Data.Decoded_Length = 4,
         "iTerm2 PNG decoded RGBA length");
      Assert
        (ITerm2_PNG_Data.Decode_Complete,
         "iTerm2 PNG decode complete");
      Assert
        (ITerm2_PNG_Data.Decode_Status = Graphics.Decode_Ok,
         "iTerm2 PNG decode status");
      Assert
        (ITerm2_PNG_Data.Bytes (1) = 16#FF#
         and then ITerm2_PNG_Data.Bytes (2) = 16#00#
         and then ITerm2_PNG_Data.Bytes (3) = 16#00#
         and then ITerm2_PNG_Data.Bytes (4) = 16#FF#,
         "iTerm2 PNG decoded RGBA bytes");

      ITerm2_JPEG_Data := Graphics.Data_Preview (ITerm2_JPEG);
      Assert
        (ITerm2_JPEG_Data.Raw_Format = 32
         and then ITerm2_JPEG_Data.Pixel_Width = 1
         and then ITerm2_JPEG_Data.Pixel_Height = 1,
         "iTerm2 JPEG pixel metadata");
      Assert
        (ITerm2_JPEG_Data.Decoded_Length = 4
         and then ITerm2_JPEG_Data.Decode_Complete
         and then ITerm2_JPEG_Data.Decode_Status = Graphics.Decode_Ok,
         "iTerm2 JPEG decode complete");
      Assert
        (ITerm2_JPEG_Data.Bytes /= null
         and then ITerm2_JPEG_Data.Bytes (4) = 16#FF#,
         "iTerm2 JPEG decoded alpha");

      ITerm2_Gray_PNG_Data := Graphics.Data_Preview (ITerm2_Gray_PNG);
      Assert
        (ITerm2_Gray_PNG_Data.Decoded_Length = 4
         and then ITerm2_Gray_PNG_Data.Decode_Complete,
         "iTerm2 grayscale PNG decode complete");
      Assert
        (ITerm2_Gray_PNG_Data.Bytes (1) = 16#80#
         and then ITerm2_Gray_PNG_Data.Bytes (2) = 16#80#
         and then ITerm2_Gray_PNG_Data.Bytes (3) = 16#80#
         and then ITerm2_Gray_PNG_Data.Bytes (4) = 16#FF#,
         "iTerm2 grayscale PNG decoded RGBA bytes");

      ITerm2_Palette_PNG_Data := Graphics.Data_Preview (ITerm2_Palette_PNG);
      Assert
        (ITerm2_Palette_PNG_Data.Decoded_Length = 4
         and then ITerm2_Palette_PNG_Data.Decode_Complete,
         "iTerm2 palette PNG decode complete");
      Assert
        (ITerm2_Palette_PNG_Data.Bytes (1) = 16#11#
         and then ITerm2_Palette_PNG_Data.Bytes (2) = 16#22#
         and then ITerm2_Palette_PNG_Data.Bytes (3) = 16#33#
         and then ITerm2_Palette_PNG_Data.Bytes (4) = 16#44#,
         "iTerm2 palette PNG decoded RGBA bytes");

      ITerm2_Gray1_PNG_Data := Graphics.Data_Preview (ITerm2_Gray1_PNG);
      Assert
        (ITerm2_Gray1_PNG_Data.Decoded_Length = 32
         and then ITerm2_Gray1_PNG_Data.Decode_Complete,
         "iTerm2 1-bit grayscale PNG decode complete");
      Assert
        (ITerm2_Gray1_PNG_Data.Bytes (1) = 16#FF#
         and then ITerm2_Gray1_PNG_Data.Bytes (5) = 16#00#,
         "iTerm2 1-bit grayscale PNG decoded RGBA bytes");

      ITerm2_Gray2_PNG_Data := Graphics.Data_Preview (ITerm2_Gray2_PNG);
      Assert
        (ITerm2_Gray2_PNG_Data.Decoded_Length = 16
         and then ITerm2_Gray2_PNG_Data.Decode_Complete,
         "iTerm2 2-bit grayscale PNG decode complete");
      Assert
        (ITerm2_Gray2_PNG_Data.Bytes (1) = 16#00#
         and then ITerm2_Gray2_PNG_Data.Bytes (5) = 16#55#
         and then ITerm2_Gray2_PNG_Data.Bytes (9) = 16#AA#
         and then ITerm2_Gray2_PNG_Data.Bytes (13) = 16#FF#,
         "iTerm2 2-bit grayscale PNG decoded RGBA bytes");

      ITerm2_Gray4_PNG_Data := Graphics.Data_Preview (ITerm2_Gray4_PNG);
      Assert
        (ITerm2_Gray4_PNG_Data.Decoded_Length = 8
         and then ITerm2_Gray4_PNG_Data.Decode_Complete,
         "iTerm2 4-bit grayscale PNG decode complete");
      Assert
        (ITerm2_Gray4_PNG_Data.Bytes (1) = 16#FF#
         and then ITerm2_Gray4_PNG_Data.Bytes (5) = 16#00#,
         "iTerm2 4-bit grayscale PNG decoded RGBA bytes");

      ITerm2_RGB16_PNG_Data := Graphics.Data_Preview (ITerm2_RGB16_PNG);
      Assert
        (ITerm2_RGB16_PNG_Data.Decoded_Length = 4
         and then ITerm2_RGB16_PNG_Data.Decode_Complete,
         "iTerm2 16-bit RGB PNG decode complete");
      Assert
        (ITerm2_RGB16_PNG_Data.Bytes (1) = 16#FF#
         and then ITerm2_RGB16_PNG_Data.Bytes (2) = 16#80#
         and then ITerm2_RGB16_PNG_Data.Bytes (3) = 16#00#
         and then ITerm2_RGB16_PNG_Data.Bytes (4) = 16#FF#,
         "iTerm2 16-bit RGB PNG decoded RGBA bytes");

      ITerm2_GA16_PNG_Data := Graphics.Data_Preview (ITerm2_GA16_PNG);
      Assert
        (ITerm2_GA16_PNG_Data.Decoded_Length = 4
         and then ITerm2_GA16_PNG_Data.Decode_Complete,
         "iTerm2 16-bit grayscale-alpha PNG decode complete");
      Assert
        (ITerm2_GA16_PNG_Data.Bytes (1) = 16#80#
         and then ITerm2_GA16_PNG_Data.Bytes (4) = 16#80#,
         "iTerm2 16-bit grayscale-alpha PNG decoded RGBA bytes");

      ITerm2_RGBA16_PNG_Data := Graphics.Data_Preview (ITerm2_RGBA16_PNG);
      Assert
        (ITerm2_RGBA16_PNG_Data.Decoded_Length = 4
         and then ITerm2_RGBA16_PNG_Data.Decode_Complete,
         "iTerm2 16-bit RGBA PNG decode complete");
      Assert
        (ITerm2_RGBA16_PNG_Data.Bytes (1) = 16#FF#
         and then ITerm2_RGBA16_PNG_Data.Bytes (2) = 16#00#
         and then ITerm2_RGBA16_PNG_Data.Bytes (3) = 16#80#
         and then ITerm2_RGBA16_PNG_Data.Bytes (4) = 16#80#,
         "iTerm2 16-bit RGBA PNG decoded RGBA bytes");

      ITerm2_Palette1_PNG_Data := Graphics.Data_Preview (ITerm2_Palette1_PNG);
      Assert
        (ITerm2_Palette1_PNG_Data.Decoded_Length = 8
         and then ITerm2_Palette1_PNG_Data.Decode_Complete,
         "iTerm2 1-bit palette PNG decode complete");
      Assert
        (ITerm2_Palette1_PNG_Data.Bytes (1) = 16#11#
         and then ITerm2_Palette1_PNG_Data.Bytes (2) = 16#22#
         and then ITerm2_Palette1_PNG_Data.Bytes (3) = 16#33#
         and then ITerm2_Palette1_PNG_Data.Bytes (4) = 16#44#
         and then ITerm2_Palette1_PNG_Data.Bytes (5) = 16#00#
         and then ITerm2_Palette1_PNG_Data.Bytes (8) = 16#FF#,
         "iTerm2 1-bit palette PNG decoded RGBA bytes");

      ITerm2_Adam7_PNG_Data := Graphics.Data_Preview (ITerm2_Adam7_PNG);
      Assert
        (ITerm2_Adam7_PNG_Data.Decoded_Length = 16
         and then ITerm2_Adam7_PNG_Data.Decode_Complete,
         "iTerm2 Adam7 PNG decode complete");
      Assert
        (ITerm2_Adam7_PNG_Data.Pixel_Width = 2
         and then ITerm2_Adam7_PNG_Data.Pixel_Height = 2,
         "iTerm2 Adam7 PNG pixel metadata");
      Assert
        (ITerm2_Adam7_PNG_Data.Bytes (1) = 16#FF#
         and then ITerm2_Adam7_PNG_Data.Bytes (5) = 16#00#
         and then ITerm2_Adam7_PNG_Data.Bytes (6) = 16#FF#
         and then ITerm2_Adam7_PNG_Data.Bytes (9) = 16#00#
         and then ITerm2_Adam7_PNG_Data.Bytes (10) = 16#00#
         and then ITerm2_Adam7_PNG_Data.Bytes (11) = 16#FF#
         and then ITerm2_Adam7_PNG_Data.Bytes (13) = 16#FF#
         and then ITerm2_Adam7_PNG_Data.Bytes (14) = 16#FF#
         and then ITerm2_Adam7_PNG_Data.Bytes (15) = 16#FF#,
         "iTerm2 Adam7 PNG decoded RGBA bytes");

      Sized_Header := Graphics.Header (Kitty_Sized);
      Assert (Sized_Header.Kitty_Format = 100, "sized kitty format field");
      Assert
        (Graphics.Placeholder_Cols (Kitty_Sized) = 9,
         "kitty c field placeholder cols");
      Assert
        (Graphics.Placeholder_Rows (Kitty_Sized) = 4,
         "kitty r field placeholder rows");
      Sixel_Data := Graphics.Data_Preview (Sixel);
      Assert (Sixel_Data.Header_Recognized, "sixel data header recognized");
      Assert (Sixel_Data.Has_Data, "sixel raster data found");
      Assert (Sixel_Data.Encoded_Length = 4, "sixel raster data preview length");
      Assert (Sixel_Data.Decoded_Length = 96, "sixel raster decoded byte length");
      Assert
        (Sixel_Data.Bytes /= null
         and then Sixel_Data.Bytes'Length = 96,
         "sixel raster decoded buffer should be exact length");
      Assert (Sixel_Data.Decode_Complete, "sixel raster decode complete");
      Assert
        (Sixel_Data.Decode_Status = Graphics.Decode_Ok,
         "sixel raster decode status");
      Assert
        (Graphics.Header (Sixel).Pixel_Width = 4
         and then Graphics.Header (Sixel).Pixel_Height = 6
         and then Graphics.Header (Sixel).Raw_Format = 32,
         "sixel raster header pixel metadata");
      Assert
        (Graphics.Data_Status_Label (Sixel) =
         "sixel raster decoded=96/4 bytes=000000FF decoded",
         "sixel data status label");
   end;
end Graphics_Capabilities_Smoke;

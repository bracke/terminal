with AUnit.Assertions;

with Jpeglib.Encoding;
with Jpeglib.Images;
with Jpeglib.Results;
with Jpeglib.Streams;

with Terminal.App.Graphics;
with Terminal.App.Render_Model;
with Terminal.Common.Bytes;
with Terminal.Common.Status;
with Terminal.Core;

procedure Graphics_Capabilities_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Graphics.Data_Decode_Status;
   use type Terminal.App.Graphics.ITerm2_Size_Unit;
   use type Terminal.App.Render_Model.Image_Data_Access;
   use type Terminal.App.Render_Model.Image_Data_View;
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

   procedure Run_Decoding_Matrix is separate;
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
     (Graphics.Data_Decode_Status_Suffix (Graphics.Decode_Invalid_Data) =
      " invalid-data",
      "invalid-data decode suffix");
   Assert
     (Graphics.Data_Decode_Status_Suffix (Graphics.Decode_Too_Large) =
      " too-large",
      "too-large decode suffix");
   Assert
     (Graphics.Data_Decode_Status_Suffix (Graphics.Decode_Allocation_Failed) =
      " allocation-failed",
      "allocation-failed decode suffix");
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
     (Graphics.Image_Decode_Status (Graphics.Decode_Invalid_Data) =
      Terminal.App.Render_Model.Image_Decode_Invalid_Data,
      "invalid data maps to image decode");
   Assert
     (Graphics.Image_Decode_Status (Graphics.Decode_Too_Large) =
      Terminal.App.Render_Model.Image_Decode_Too_Large,
      "too-large data maps to image decode");
   Assert
     (Graphics.Image_Decode_Status (Graphics.Decode_Allocation_Failed) =
      Terminal.App.Render_Model.Image_Decode_Allocation_Failed,
      "allocation failure maps to image decode");
   Assert
     (Graphics.Image_Decode_Status (Graphics.Decode_Unsupported_Format) =
      Terminal.App.Render_Model.Image_Decode_Unsupported_Format,
      "unsupported-format data decode maps to image decode");

   declare
      Shared : aliased Terminal.Common.Bytes.Byte_Array := (1 => 16#A5#);
      Image : RM.Image_Command :=
        (Decoded_Byte_Length => 1,
         Decoded_Bytes => Shared'Unchecked_Access,
         Encoded_Source_Bytes => Shared'Unchecked_Access,
         Encoded_Source_Length => 1,
         Decoded_Preview_Length => 1,
         Decoded_Preview_Bytes => Shared'Unchecked_Access,
         others => <>);
      Copy : constant RM.Image_Command := Image;
   begin
      Assert
        (Copy.Decoded_Bytes = Image.Decoded_Bytes
         and then Copy.Encoded_Source_Bytes = Image.Encoded_Source_Bytes
         and then Copy.Decoded_Preview_Bytes = Image.Decoded_Preview_Bytes,
         "image commands are safely copyable borrowed views");
   end;

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
      "iTerm2 images; PNG/JPEG/GIF/PICT texture rendering",
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

   Run_Decoding_Matrix;
end Graphics_Capabilities_Smoke;

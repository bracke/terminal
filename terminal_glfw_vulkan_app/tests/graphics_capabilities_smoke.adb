with AUnit.Assertions;

with Terminal.App.Graphics;
with Terminal.App.Render_Model;
with Terminal.Common.Bytes;
with Terminal.Common.Status;
with Terminal.Core;

procedure Graphics_Capabilities_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Graphics.Data_Decode_Status;
   use type Terminal.App.Render_Model.Image_Data_Access;
   use type Terminal.App.Render_Model.Image_Decode_Status;
   use type Terminal.App.Render_Model.Image_Decoded_Source_Kind;
   use type Terminal.Common.Bytes.Byte;

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
        (not Emoji.Color_Glyph_Rendered,
         "emoji should not claim color glyph rendering");
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
      "kitty graphics recognized; raw/PNG texture rendering available",
      "kitty capability status label");
   Assert
     (Graphics.Capability_Status_Label (Graphics.ITerm2) =
      "iTerm2 images recognized; PNG texture rendering available",
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
         Row            => 1,
         Col            => 1,
         Payload_Length => 0,
         Preview_Length => 0,
         Preview        => (others => ASCII.NUL));
      ITerm2 : Terminal.Core.Graphics_Event :=
        (Pending        => True,
         Protocol       => Terminal.Core.ITerm2_Graphics,
         Row            => 1,
         Col            => 1,
         Payload_Length => 0,
         Preview_Length => 0,
         Preview        => (others => ASCII.NUL));
      ITerm2_PNG : Terminal.Core.Graphics_Event :=
        (Pending        => True,
         Protocol       => Terminal.Core.ITerm2_Graphics,
         Row            => 1,
         Col            => 1,
         Payload_Length => 0,
         Preview_Length => 0,
         Preview        => (others => ASCII.NUL));
      ITerm2_Gray_PNG : Terminal.Core.Graphics_Event :=
        (Pending        => True,
         Protocol       => Terminal.Core.ITerm2_Graphics,
         Row            => 1,
         Col            => 1,
         Payload_Length => 0,
         Preview_Length => 0,
         Preview        => (others => ASCII.NUL));
      ITerm2_Palette_PNG : Terminal.Core.Graphics_Event :=
        (Pending        => True,
         Protocol       => Terminal.Core.ITerm2_Graphics,
         Row            => 1,
         Col            => 1,
         Payload_Length => 0,
         Preview_Length => 0,
         Preview        => (others => ASCII.NUL));
      ITerm2_Gray1_PNG : Terminal.Core.Graphics_Event :=
        (Pending        => True,
         Protocol       => Terminal.Core.ITerm2_Graphics,
         Row            => 1,
         Col            => 1,
         Payload_Length => 0,
         Preview_Length => 0,
         Preview        => (others => ASCII.NUL));
      ITerm2_Gray2_PNG : Terminal.Core.Graphics_Event :=
        (Pending        => True,
         Protocol       => Terminal.Core.ITerm2_Graphics,
         Row            => 1,
         Col            => 1,
         Payload_Length => 0,
         Preview_Length => 0,
         Preview        => (others => ASCII.NUL));
      ITerm2_Gray4_PNG : Terminal.Core.Graphics_Event :=
        (Pending        => True,
         Protocol       => Terminal.Core.ITerm2_Graphics,
         Row            => 1,
         Col            => 1,
         Payload_Length => 0,
         Preview_Length => 0,
         Preview        => (others => ASCII.NUL));
      ITerm2_RGB16_PNG : Terminal.Core.Graphics_Event :=
        (Pending        => True,
         Protocol       => Terminal.Core.ITerm2_Graphics,
         Row            => 1,
         Col            => 1,
         Payload_Length => 0,
         Preview_Length => 0,
         Preview        => (others => ASCII.NUL));
      ITerm2_GA16_PNG : Terminal.Core.Graphics_Event :=
        (Pending        => True,
         Protocol       => Terminal.Core.ITerm2_Graphics,
         Row            => 1,
         Col            => 1,
         Payload_Length => 0,
         Preview_Length => 0,
         Preview        => (others => ASCII.NUL));
      ITerm2_RGBA16_PNG : Terminal.Core.Graphics_Event :=
        (Pending        => True,
         Protocol       => Terminal.Core.ITerm2_Graphics,
         Row            => 1,
         Col            => 1,
         Payload_Length => 0,
         Preview_Length => 0,
         Preview        => (others => ASCII.NUL));
      ITerm2_Palette1_PNG : Terminal.Core.Graphics_Event :=
        (Pending        => True,
         Protocol       => Terminal.Core.ITerm2_Graphics,
         Row            => 1,
         Col            => 1,
         Payload_Length => 0,
         Preview_Length => 0,
         Preview        => (others => ASCII.NUL));
      ITerm2_Adam7_PNG : Terminal.Core.Graphics_Event :=
        (Pending        => True,
         Protocol       => Terminal.Core.ITerm2_Graphics,
         Row            => 1,
         Col            => 1,
         Payload_Length => 0,
         Preview_Length => 0,
         Preview        => (others => ASCII.NUL));
      Kitty_Sized : Terminal.Core.Graphics_Event :=
        (Pending        => True,
         Protocol       => Terminal.Core.Kitty_Graphics,
         Row            => 1,
         Col            => 1,
         Payload_Length => 0,
         Preview_Length => 0,
         Preview        => (others => ASCII.NUL));
      Kitty_RGBA : Terminal.Core.Graphics_Event :=
        (Pending        => True,
         Protocol       => Terminal.Core.Kitty_Graphics,
         Row            => 1,
         Col            => 1,
         Payload_Length => 0,
         Preview_Length => 0,
         Preview        => (others => ASCII.NUL));
      Kitty_Chunk : Terminal.Core.Graphics_Event :=
        (Pending        => True,
         Protocol       => Terminal.Core.Kitty_Graphics,
         Row            => 1,
         Col            => 1,
         Payload_Length => 0,
         Preview_Length => 0,
         Preview        => (others => ASCII.NUL));
      Kitty_PNG : Terminal.Core.Graphics_Event :=
        (Pending        => True,
         Protocol       => Terminal.Core.Kitty_Graphics,
         Row            => 1,
         Col            => 1,
         Payload_Length => 0,
         Preview_Length => 0,
         Preview        => (others => ASCII.NUL));
      Kitty_Large_RGBA : Terminal.Core.Graphics_Event :=
        (Pending        => True,
         Protocol       => Terminal.Core.Kitty_Graphics,
         Row            => 1,
         Col            => 1,
         Payload_Length => 0,
         Preview_Length => 0,
         Preview        => (others => ASCII.NUL));
      Kitty_Oversized_RGBA : Terminal.Core.Graphics_Event :=
        (Pending        => True,
         Protocol       => Terminal.Core.Kitty_Graphics,
         Row            => 1,
         Col            => 1,
         Payload_Length => 0,
         Preview_Length => 0,
         Preview        => (others => ASCII.NUL));
      Kitty_Partial : Terminal.Core.Graphics_Event :=
        (Pending        => True,
         Protocol       => Terminal.Core.Kitty_Graphics,
         Row            => 1,
         Col            => 1,
         Payload_Length => 0,
         Preview_Length => 0,
         Preview        => (others => ASCII.NUL));
      Kitty_Trailing : Terminal.Core.Graphics_Event :=
        (Pending        => True,
         Protocol       => Terminal.Core.Kitty_Graphics,
         Row            => 1,
         Col            => 1,
         Payload_Length => 0,
         Preview_Length => 0,
         Preview        => (others => ASCII.NUL));
      Sixel : Terminal.Core.Graphics_Event :=
        (Pending        => True,
         Protocol       => Terminal.Core.Sixel_Graphics,
         Row            => 1,
         Col            => 1,
         Payload_Length => 0,
         Preview_Length => 0,
         Preview        => (others => ASCII.NUL));
      Kitty_Header : Graphics.Graphics_Header;
      ITerm2_Header : Graphics.Graphics_Header;
      Sized_Header : Graphics.Graphics_Header;
      Kitty_Data : Graphics.Graphics_Data_Preview;
      Kitty_RGBA_Data : Graphics.Graphics_Data_Preview;
      Kitty_Chunk_Header : Graphics.Graphics_Header;
      Kitty_PNG_Data : Graphics.Graphics_Data_Preview;
      Kitty_Large_RGBA_Data : Graphics.Graphics_Data_Preview;
      Kitty_Oversized_RGBA_Data : Graphics.Graphics_Data_Preview;
      Kitty_Partial_Data : Graphics.Graphics_Data_Preview;
      Kitty_Trailing_Data : Graphics.Graphics_Data_Preview;
      ITerm2_Data : Graphics.Graphics_Data_Preview;
      ITerm2_PNG_Data : Graphics.Graphics_Data_Preview;
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
         37 => 16#0D#, 38 => 16#49#, 39 => 16#44#, 40 => 16#41#,
         41 => 16#54#, 42 => 16#78#, 43 => 16#9C#, 44 => 16#63#,
         45 => 16#F8#, 46 => 16#CF#, 47 => 16#C0#, 48 => 16#00#,
         49 => 16#00#, 50 => 16#03#, 51 => 16#01#, 52 => 16#01#,
         53 => 16#00#, 54 => 16#C9#, 55 => 16#FE#, 56 => 16#92#,
         57 => 16#EF#, 58 => 16#00#, 59 => 16#00#, 60 => 16#00#,
         61 => 16#00#, 62 => 16#49#, 63 => 16#45#, 64 => 16#4E#,
         65 => 16#44#, 66 => 16#AE#, 67 => 16#42#, 68 => 16#60#,
         69 => 16#82#);
      PNG_Row_Result : Graphics.Graphics_Data_Preview;
      PNG_Row_Count : Natural := 0;
      PNG_Row_Bytes : Terminal.Common.Bytes.Byte_Array (1 .. 4) :=
        (others => 0);
      PNG_Source_Row_Result : Graphics.Graphics_Data_Preview;
      PNG_Source_Row_Count : Natural := 0;
      PNG_Source_Row_Bytes : Terminal.Common.Bytes.Byte_Array (1 .. 4) :=
        (others => 0);
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
               return "AAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC";
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
         "File=name=a;inline=1;width=12;height=5:SGk=");
      Set_Preview
        (ITerm2_PNG,
         "File=name=pixel.png;inline=1:iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC");
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
         "Gf=100,a=T,c=1,r=1;iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC");
      Set_Preview
        (Kitty_Large_RGBA,
         "Gf=32,s=33,v=32,c=33,r=32;" & Repeat_Char ('A', 5632));
      Set_Preview
        (Kitty_Oversized_RGBA,
         "Gf=32,s=513,v=512,c=40,r=20;AAAA");
      Set_Preview (Kitty_Partial, "Gf=100,a=T;SG$=");
      Set_Preview (Kitty_Trailing, "Gf=100,a=T;SGk=A");
      Set_Preview (Sixel, "q??~~");

      Kitty_Header := Graphics.Header (Kitty);
      Assert (Kitty_Header.Recognized, "kitty header recognized");
      Assert (Kitty_Header.Has_Data, "kitty header data marker");
      Assert (Kitty_Header.Kitty_Action = 'T', "kitty action field");
      Assert (Kitty_Header.Kitty_ID = 42, "kitty image id field");
      Assert (Kitty_Header.Kitty_Format = 32, "kitty format field");
      Assert (Graphics.Placeholder_Cols (Kitty) = 6, "kitty parsed placeholder cols");
      Assert (Graphics.Placeholder_Rows (Kitty) = 3, "kitty parsed placeholder rows");
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
        (Kitty_Chunk_Header.Kitty_More,
         "kitty chunk continuation field");

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

      Graphics.Decode_Base64_PNG_Chunk_Rows
        (2,
         Base64_PNG_Text'Access,
         Base64_PNG_Encoded_Length,
         Base64_PNG_Length,
         Capture_Base64_PNG_Row'Access,
         Base64_PNG_Row_Result);
      Assert
        (Base64_PNG_Encoded_Length = 92
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
        (Base64_PNG_Stop_Encoded_Length = 92
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
         and then Kitty_Oversized_RGBA_Data.Pixel_Width = 513
         and then Kitty_Oversized_RGBA_Data.Pixel_Height = 512,
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
        (Graphics.Placeholder_Cols (ITerm2) = 12,
         "iTerm2 numeric width placeholder cols");
      Assert
        (Graphics.Placeholder_Rows (ITerm2) = 5,
         "iTerm2 numeric height placeholder rows");
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
         "sixel raster decoded=96/4 bytes=00000000 decoded",
         "sixel data status label");
   end;
end Graphics_Capabilities_Smoke;

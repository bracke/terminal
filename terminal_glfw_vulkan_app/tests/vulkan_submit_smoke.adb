with AUnit.Assertions;
with System;

with Terminal.Common.Bytes;
with Terminal.App.Render_Model;
with Terminal.App.Vulkan_Submit;

procedure Vulkan_Submit_Smoke is
   use AUnit.Assertions;
   use type Terminal.Common.Bytes.Byte;
   use type Terminal.App.Render_Model.Image_Decode_Status;
   use type Terminal.App.Render_Model.Image_Decoded_Source_Kind;
   use type Terminal.App.Render_Model.Image_Protocol;
   use type Terminal.App.Render_Model.Text_Run_Array_Access;
   use type Terminal.App.Render_Model.Text_Run_Direction;
   use type Terminal.App.Render_Model.Text_Run_Kind;
   use type Terminal.App.Render_Model.Text_Run_Script;
   use type Terminal.App.Render_Model.Text_Run_Shape_Status;
   use type Terminal.App.Vulkan_Submit.Build_Status;
   use type Terminal.App.Vulkan_Submit.Texture_Source;
   use type Terminal.App.Vulkan_Submit.Vertex_Array_Access;

   package RM renames Terminal.App.Render_Model;
   package VS renames Terminal.App.Vulkan_Submit;

   Rects : aliased RM.Rectangle_Array :=
     [1 =>
        (X      => 0.0,
         Y      => 0.0,
         Width  => 50.0,
         Height => 20.0,
         Color  => (R => 1.0, G => 0.0, B => 0.0, A => 1.0))];
   Glyphs : aliased RM.Glyph_Array :=
     [1 =>
        (X         => 10.0,
         Y         => 4.0,
         Width     => 8.0,
         Height    => 12.0,
         U0        => 0.10,
         V0        => 0.20,
         U1        => 0.30,
         V1        => 0.40,
         Color     => (R => 0.9, G => 0.9, B => 0.9, A => 1.0),
         Codepoint => Character'Pos ('A'))];
   Red_RGBA : aliased Terminal.Common.Bytes.Byte_Array :=
     (1 => 16#FF#, 2 => 16#00#, 3 => 16#00#, 4 => 16#FF#);
   White_RGBA : aliased Terminal.Common.Bytes.Byte_Array :=
     (1 => 16#FF#, 2 => 16#FF#, 3 => 16#FF#, 4 => 16#FF#);
  Strided_RGBA : aliased Terminal.Common.Bytes.Byte_Array :=
     (1 => 16#FF#, 2 => 16#00#, 3 => 16#00#, 4 => 16#FF#,
      5 => 16#00#, 6 => 16#FF#, 7 => 16#00#, 8 => 16#FF#,
      9 .. 12 => 16#EE#,
      13 => 16#00#, 14 => 16#00#, 15 => 16#FF#, 16 => 16#FF#,
      17 => 16#FF#, 18 => 16#FF#, 19 => 16#FF#, 20 => 16#FF#);
   Raw_Base64_RGBA : aliased Terminal.Common.Bytes.Byte_Array :=
     (1 => Character'Pos ('/'), 2 => Character'Pos ('w'),
      3 => Character'Pos ('A'), 4 => Character'Pos ('A'),
      5 => Character'Pos ('/'), 6 => Character'Pos ('w'),
      7 => Character'Pos ('='), 8 => Character'Pos ('='));
   Large_RGBA : RM.Image_Data_Access :=
     new Terminal.Common.Bytes.Byte_Array'(1 .. 33 * 32 * 4 => 16#7F#);
   Images : aliased RM.Image_Array :=
     [1 =>
        (X              => 20.0,
         Y              => 8.0,
         Width          => 30.0,
         Height         => 16.0,
         Protocol       => RM.Image_Kitty,
         Placeholder    => True,
         Raw_Format     => 0,
         Pixel_Width    => 0,
         Pixel_Height   => 0,
         Payload_Length => 12,
         Staging_Byte_Length => 0,
         Payload_Preview_Complete => False,
         Encoded_Preview_Length => 4,
         Decoded_Byte_Length => 0,
         Decoded_Row_Stride_Bytes => 0,
         Decoded_Source => RM.Image_Decoded_Source_None,
         Decoded_Bytes => null,
         Decoded_Bytes_Owned => False,
         Encoded_Source_Bytes => null,
         Encoded_Source_Bytes_Owned => False,
         Encoded_Source_Length => 0,
         Decoded_Preview_Length => 3,
         Decoded_Preview_Bytes =>
           (1 => 16#41#, 2 => 16#42#, 3 => 16#43#, others => 0),
         Preview_Decode_Complete => True,
         Decode_Status => RM.Image_Decode_Ok,
         Tint           => (R => 0.1, G => 0.6, B => 0.9, A => 1.0))];
   Runs : aliased RM.Text_Run_Array :=
     [1 =>
        (X               => 10.0,
         Y               => 0.0,
         Cell_Width      => 18.0,
         Cell_Height     => 20.0,
         Cell_Span       => 2,
         Color           => (R => 0.9, G => 0.9, B => 0.9, A => 1.0),
         Bold            => False,
         Italic          => False,
         Codepoints      =>
           (1 => 16#1F469#,
            2 => 16#200D#,
            3 => 16#1F468#,
            4 => 16#1F3FD#,
            others => 0),
         Codepoint_Count => 4,
         Run_Kind        => RM.Joined_Emoji_Cluster,
         Shape_Status    => RM.Needs_Shaping_Backend,
         Direction       => RM.Direction_Left_To_Right,
         Script          => RM.Script_Emoji,
         Shaped_Glyphs   =>
           (1 =>
              (Glyph_ID     => 42,
               Font_Index   => 0,
               Codepoint    => 16#1F469#,
               Source_Index => 1,
               X_Offset     => 0.0,
               Y_Offset     => 0.0,
               X_Advance    => 18.0,
               Y_Advance    => 0.0),
            others => <>),
         Shaped_Glyph_Count => 1,
         Fallback_Glyphs => True)];

   Frame : RM.Frame_Commands :=
     (Width           => 100,
      Height          => 40,
      Rectangles      => Rects'Unchecked_Access,
      Rectangle_Count => 1,
      Glyphs          => Glyphs'Unchecked_Access,
      Glyph_Count     => 1,
      Images          => Images'Unchecked_Access,
      Image_Count     => 1,
      Text_Runs       => Runs'Unchecked_Access,
      Text_Run_Count  => 1,
      Atlas_Width     => 256,
      Atlas_Height    => 256,
      Atlas_Pixels    => System'To_Address (16#1000#),
      Atlas_Bytes     => 65_536,
      Atlas_Dirty     => True);

   Batch  : VS.Submission_Batch;
   Status : VS.Build_Status;
begin
   Assert
     (VS.Status_Label (VS.Ok) = "Submit build: Ok",
      "submit ok status label");
   Assert
     (VS.Status_Label (VS.Invalid_Frame) = "Submit build: Invalid Frame",
      "submit invalid status label");
   Assert
     (VS.Status_Label (VS.Allocation_Failed)'Length <=
      VS.Max_Status_Label_Length,
      "submit status label should be bounded");
   Assert
     (VS.Texture_Source_Label (VS.Texture_None) = "none",
      "none texture source label");
   Assert
     (VS.Texture_Source_Label (VS.Texture_Text_Atlas) = "text-atlas",
      "text atlas texture source label");
   Assert
     (VS.Texture_Source_Label (VS.Texture_Image) = "image",
      "image texture source label");
   Assert
     (RM.Image_Decode_Status_Suffix (RM.Image_Decode_Ok) = "",
      "ok image decode suffix");
   Assert
     (RM.Image_Decode_Status_Suffix (RM.Image_Decode_Invalid_Byte) =
      " invalid-byte",
      "invalid-byte image decode suffix");
   Assert
     (RM.Image_Decode_Status_Suffix (RM.Image_Decode_Trailing_Data) =
      " trailing-data",
      "trailing-data image decode suffix");
   Assert
     (RM.Image_Decode_Status_Suffix (RM.Image_Decode_Preview_Truncated) =
      " truncated",
      "truncated image decode suffix");

   VS.Build (Frame, Batch, Status);
   Assert (Status = VS.Ok, "batch build failed");
   Assert
     (VS.Status_Label (Status) = "Submit build: Ok",
      "built submit status label");
   Assert (VS.Width (Batch) = 100, "frame width not carried");
   Assert (VS.Height (Batch) = 40, "frame height not carried");
   Assert (VS.Vertex_Count (Batch) = 18, "three quads should produce 18 vertices");
   Assert (VS.Rectangle_Vertex_Count (Batch) = 6, "rectangle vertex count");
   Assert (VS.Glyph_Vertex_Count (Batch) = 6, "glyph vertex count");
   Assert (VS.Image_Vertex_Count (Batch) = 6, "image vertex count");
   Assert
     (VS.Image_Texture_Vertex_Count (Batch) = 0,
      "placeholder image texture vertex count");
   Assert (VS.Image_Command_Count (Batch) = 1, "image command count");
   Assert
     (VS.Last_Image_Protocol (Batch) = RM.Image_Kitty,
      "last image protocol");
   Assert
     (VS.Last_Image_Width (Batch) = 30,
      "last image width");
   Assert
     (VS.Last_Image_Height (Batch) = 16,
      "last image height");
   Assert
     (VS.Last_Image_Payload_Length (Batch) = 12,
      "last image payload length");
   Assert
     (not VS.Last_Image_Payload_Preview_Complete (Batch),
      "last image payload should be marked preview-only");
   Assert
     (VS.Last_Image_Encoded_Preview_Length (Batch) = 4,
      "last image encoded preview length");
   Assert
     (VS.Last_Image_Decoded_Preview_Length (Batch) = 3,
      "last image decoded preview length");
   Assert
     (VS.Last_Image_Decoded_Preview_Byte (Batch, 1) = 16#41#
      and then VS.Last_Image_Decoded_Preview_Byte (Batch, 2) = 16#42#
      and then VS.Last_Image_Decoded_Preview_Byte (Batch, 3) = 16#43#,
      "last image decoded preview bytes");
   Assert
     (VS.Last_Image_Preview_Decode_Complete (Batch),
      "last image preview decode complete");
   Assert
     (VS.Last_Image_Decode_Status (Batch) = RM.Image_Decode_Ok,
      "last image preview decode status");
   Assert
     (VS.Last_Image_Placeholder (Batch),
      "last image placeholder flag");
   Assert
     (not VS.Last_Image_Texture_Downgraded (Batch),
      "placeholder image should not report texture downgrade");
   Assert
     (VS.Last_Image_Texture_Source (Batch) = VS.Texture_None,
      "placeholder image texture source");
   Assert
     (VS.Last_Image_Decoded_Source (Batch) = RM.Image_Decoded_Source_None,
      "placeholder image decoded source");
   Assert
     (VS.Image_Status_Label (Batch) =
      "submit image kitty size=30x16 payload=12 payload-preview preview=3/4 bytes=414243 texture=none placeholder decoded",
      "submit image status label");
   Assert
     (VS.Image_Texture_Status_Label (Batch) =
      "submit image texture unavailable; texture=none vertices=0",
      "submit image texture status label");
   Assert
     (VS.Image_Texture_Status_Label (Batch)'Length <=
      VS.Max_Status_Label_Length,
      "submit image texture status label should be bounded");
   Assert (VS.Text_Run_Count (Batch) = 1, "text run count");
   Assert (VS.Shaped_Glyph_Count (Batch) = 1, "shaped glyph count");
   Assert (VS.Text_Runs (Batch) /= null, "text runs not copied");
   Assert
     (VS.Text_Runs (Batch) (1).Codepoint_Count = 4,
      "text run codepoint count");
   Assert
     (VS.Text_Runs (Batch) (1).Codepoints (3) = 16#1F468#,
      "text run joined scalar");
   Assert
     (VS.Text_Runs (Batch) (1).Run_Kind = RM.Joined_Emoji_Cluster,
      "text run class");
   Assert
     (VS.Text_Runs (Batch) (1).Shape_Status = RM.Needs_Shaping_Backend,
      "text run shape status");
   Assert
     (VS.Text_Runs (Batch) (1).Direction = RM.Direction_Left_To_Right,
      "text run direction");
   Assert
     (VS.Text_Runs (Batch) (1).Script = RM.Script_Emoji,
      "text run script");
   Assert
     (VS.Text_Runs (Batch) (1).Shaped_Glyph_Count = 1,
      "text run shaped glyph count");
   Assert
     (VS.Text_Runs (Batch) (1).Shaped_Glyphs (1).Glyph_ID = 42,
      "text run shaped glyph id");
   Assert
     (VS.Text_Runs (Batch) (1).Shaped_Glyphs (1).Font_Index = 0,
      "text run shaped glyph font index");
   Assert
     (VS.Text_Runs (Batch) (1).Fallback_Glyphs,
      "text run fallback flag");
   Runs (1).Codepoints (3) := 0;
   Assert
     (VS.Text_Runs (Batch) (1).Codepoints (3) = 16#1F468#,
      "batch should own text run copy");
   Assert (VS.Text_Atlas_Used (Batch), "glyph quad should use text atlas");
   Assert (VS.Atlas_Dirty (Batch), "atlas dirty flag not carried");
   Assert (VS.Atlas_Width (Batch) = 256, "atlas width");
   Assert (VS.Atlas_Height (Batch) = 256, "atlas height");
   Assert (VS.Atlas_Bytes (Batch) = 65_536, "atlas bytes");
   Assert (VS.Vertices (Batch) /= null, "vertices not allocated");
   Assert
     (VS.Vertices (Batch) (13).Texture = VS.Texture_Text_Atlas,
      "glyph vertices should be textured");
   Assert
     (not VS.Vertices (Batch) (7).Textured
      and then VS.Vertices (Batch) (7).Texture = VS.Texture_None,
      "image placeholder vertices should be untextured");
   Assert
     (VS.Vertices (Batch) (1).Y = -1.0,
      "top edge should map to Vulkan clip-space top");
   Assert
     (VS.Vertices (Batch) (3).Y = 0.0,
      "lower edge should map downward in Vulkan clip space");

   VS.Release (Batch);
   Assert (VS.Vertex_Count (Batch) = 0, "release should clear vertices");
   Assert (VS.Vertices (Batch) = null, "released batch vertices should be null");
   Assert (VS.Image_Command_Count (Batch) = 0, "release should clear image count");
   Assert
     (VS.Last_Image_Payload_Length (Batch) = 0,
      "release should clear image payload length");
   Assert
     (not VS.Last_Image_Payload_Preview_Complete (Batch),
      "release should clear image payload completeness");
   Assert
     (VS.Last_Image_Width (Batch) = 0
      and then VS.Last_Image_Height (Batch) = 0,
      "release should clear image dimensions");
   Assert
     (not VS.Last_Image_Preview_Decode_Complete (Batch),
      "release should clear image decode flag");
   Assert
     (VS.Last_Image_Decode_Status (Batch) = RM.Image_Decode_Not_Attempted,
      "release should clear image decode status");
   Assert
     (not VS.Last_Image_Placeholder (Batch),
      "release should clear image placeholder flag");
   Assert
     (not VS.Last_Image_Texture_Downgraded (Batch),
      "release should clear image downgrade flag");
   Assert
     (VS.Last_Image_Texture_Source (Batch) = VS.Texture_None,
      "release should clear image texture source");
   Assert
     (VS.Image_Texture_Vertex_Count (Batch) = 0,
      "release should clear image texture vertices");
   Assert
     (VS.Image_Status_Label (Batch) = "",
      "release should clear image status label");
   Assert
     (VS.Image_Texture_Status_Label (Batch) = "",
      "release should clear image texture status label");
   Assert (VS.Text_Run_Count (Batch) = 0, "release should clear text run count");
   Assert
     (VS.Shaped_Glyph_Count (Batch) = 0,
      "release should clear shaped glyph count");
   Assert (VS.Text_Runs (Batch) = null, "release should clear text runs");
   Assert (VS.Width (Batch) = 0, "release should clear frame width");
   Assert (not VS.Text_Atlas_Used (Batch), "release should clear atlas use");
   VS.Release (Batch);

   Images (1).Placeholder := False;
   VS.Build (Frame, Batch, Status);
   Assert (Status = VS.Ok, "texture image fallback batch build failed");
   Assert
     (VS.Last_Image_Placeholder (Batch),
      "texture image should be emitted as placeholder before image textures");
   Assert
     (VS.Last_Image_Texture_Downgraded (Batch),
      "texture image should report submit downgrade");
   Assert
     (VS.Last_Image_Texture_Source (Batch) = VS.Texture_None,
      "downgraded image should report no image texture source");
   Assert
     (VS.Image_Texture_Vertex_Count (Batch) = 0,
      "downgraded image texture vertex count");
   Assert
     (not VS.Vertices (Batch) (7).Textured
      and then VS.Vertices (Batch) (7).Texture = VS.Texture_None,
      "downgraded image vertices should remain untextured");
   Assert
     (VS.Image_Status_Label (Batch) =
      "submit image kitty size=30x16 payload=12 payload-preview preview=3/4 bytes=414243 texture=none placeholder downgraded decoded",
      "downgraded image status label");
   Assert
     (VS.Image_Texture_Status_Label (Batch) =
      "submit image texture downgraded; texture=none vertices=0",
      "downgraded image texture status label");
   Assert
     (VS.Image_Texture_Status_Label (Batch)'Length <=
      VS.Max_Status_Label_Length,
      "downgraded image texture status label should be bounded");
   VS.Release (Batch);

   Images (1).Placeholder := False;
   Images (1).Raw_Format := 32;
   Images (1).Pixel_Width := 1;
   Images (1).Pixel_Height := 1;
   Images (1).Payload_Length := 16;
   Images (1).Payload_Preview_Complete := True;
   Images (1).Encoded_Preview_Length := 8;
   Images (1).Decoded_Byte_Length := 4;
   Images (1).Decoded_Source := RM.Image_Decoded_Source_Buffer;
   Images (1).Decoded_Bytes := Red_RGBA'Unchecked_Access;
   Images (1).Decoded_Preview_Length := 4;
   Images (1).Decoded_Preview_Bytes :=
     (1 => 16#FF#, 2 => 16#00#, 3 => 16#00#, 4 => 16#FF#, others => 0);
   Images (1).Preview_Decode_Complete := True;
   Images (1).Decode_Status := RM.Image_Decode_Ok;
   VS.Build (Frame, Batch, Status);
   Assert (Status = VS.Ok, "raw image texture batch build failed");
   Assert
     (not VS.Last_Image_Placeholder (Batch),
      "raw image should remain textured in submit");
   Assert
     (not VS.Last_Image_Texture_Downgraded (Batch),
      "raw image should not report submit downgrade");
   Assert
     (VS.Last_Image_Texture_Source (Batch) = VS.Texture_Image,
      "raw image should use image texture source");
   Assert
     (VS.Last_Image_Decoded_Source (Batch) = RM.Image_Decoded_Source_Buffer,
      "raw image should report buffer decoded source");
   Assert
     (VS.Last_Image_Decoded_Row_Stride_Bytes (Batch) = 4,
      "raw image should infer tight decoded row stride");
   Assert
     (VS.Image_Texture_Vertex_Count (Batch) = 6,
      "raw image texture vertex count");
   Assert
     (VS.Vertices (Batch) (7).Textured
      and then VS.Vertices (Batch) (7).Texture = VS.Texture_Image,
      "raw image vertices should use image texture");
   Assert
     (VS.Image_Status_Label (Batch) =
      "submit image kitty size=30x16 pixels=1x1 format=32 payload=16 payload-complete preview=4/8 bytes=FF0000FF texture=image textured decoded",
      "raw image status label");
   Assert
     (VS.Image_Texture_Status_Label (Batch) =
      "submit image texture ready; vertices=6",
      "raw image texture status label");
   VS.Release (Batch);

   Images (1).Decoded_Source := RM.Image_Decoded_Source_Raw_Base64;
   Images (1).Decoded_Bytes := null;
   Images (1).Encoded_Source_Bytes := Raw_Base64_RGBA'Unchecked_Access;
   Images (1).Encoded_Source_Length := Raw_Base64_RGBA'Length;
   VS.Build (Frame, Batch, Status);
   Assert (Status = VS.Ok, "raw Base64 source image batch build failed");
   Assert
     (not VS.Last_Image_Placeholder (Batch),
      "raw Base64 source image should remain textured in submit");
   Assert
     (VS.Last_Image_Decoded_Source (Batch) =
      RM.Image_Decoded_Source_Raw_Base64,
      "raw Base64 source image should report encoded decoded source");
   Assert
     (VS.Last_Image_Decoded_Source_Available (Batch),
      "raw Base64 source image should expose rows");
   Assert
     (VS.Last_Image_Decoded_Row_Byte (Batch, 0, 0) = 16#FF#
      and then VS.Last_Image_Decoded_Row_Byte (Batch, 0, 3) = 16#FF#,
      "raw Base64 source image row bytes");
   VS.Release (Batch);

   Images (1).Decoded_Source := RM.Image_Decoded_Source_PNG_Base64;
   Images (1).Decoded_Bytes := null;
   Images (1).Encoded_Source_Bytes := Raw_Base64_RGBA'Unchecked_Access;
   Images (1).Encoded_Source_Length := Raw_Base64_RGBA'Length;
   VS.Build (Frame, Batch, Status);
   Assert (Status = VS.Ok, "PNG Base64 source image batch build failed");
   Assert
     (VS.Last_Image_Decoded_Source (Batch) =
      RM.Image_Decoded_Source_PNG_Base64,
      "PNG Base64 source image should report encoded decoded source");
   Assert
     (VS.Last_Image_Decoded_Source_Available (Batch),
      "PNG Base64 source image should expose deferred rows");
   VS.Release (Batch);

   Images (1).Protocol := RM.Image_Sixel;
   Images (1).Decoded_Source := RM.Image_Decoded_Source_Sixel_Text;
   Images (1).Decoded_Bytes := null;
   Images (1).Encoded_Source_Bytes := Raw_Base64_RGBA'Unchecked_Access;
   Images (1).Encoded_Source_Length := Raw_Base64_RGBA'Length;
   VS.Build (Frame, Batch, Status);
   Assert (Status = VS.Ok, "sixel text source image batch build failed");
   Assert
     (VS.Last_Image_Decoded_Source (Batch) =
      RM.Image_Decoded_Source_Sixel_Text,
      "sixel text source image should report encoded decoded source");
   Assert
     (VS.Last_Image_Decoded_Source_Available (Batch),
      "sixel text source image should expose deferred rows");
   VS.Release (Batch);
   Images (1).Protocol := RM.Image_Kitty;

   Images (1).Decoded_Source := RM.Image_Decoded_Source_None;
   Images (1).Encoded_Source_Bytes := null;
   Images (1).Encoded_Source_Length := 0;
   Images (1).Decoded_Bytes := Red_RGBA'Unchecked_Access;
   VS.Build (Frame, Batch, Status);
   Assert (Status = VS.Ok, "missing source image batch build failed");
   Assert
     (VS.Last_Image_Texture_Downgraded (Batch),
      "image bytes without source kind should downgrade");
   Assert
     (VS.Last_Image_Texture_Source (Batch) = VS.Texture_None,
      "image bytes without source kind should not texture");
   Assert
     (VS.Last_Image_Decoded_Source (Batch) = RM.Image_Decoded_Source_None,
      "downgraded image should clear decoded source");
   Assert
     (not VS.Last_Image_Decoded_Source_Available (Batch),
      "image bytes without source kind should not expose rows");
   VS.Release (Batch);

   Images (1).Protocol := RM.Image_Kitty;
   Images (1).Placeholder := False;
   Images (1).Raw_Format := 32;
   Images (1).Pixel_Width := 2;
   Images (1).Pixel_Height := 2;
   Images (1).Payload_Length := 32;
   Images (1).Payload_Preview_Complete := True;
   Images (1).Encoded_Preview_Length := 24;
   Images (1).Decoded_Byte_Length := 20;
   Images (1).Decoded_Row_Stride_Bytes := 12;
   Images (1).Decoded_Source := RM.Image_Decoded_Source_Buffer;
   Images (1).Decoded_Bytes := Strided_RGBA'Unchecked_Access;
   Images (1).Decoded_Preview_Length := 8;
   Images (1).Decoded_Preview_Bytes :=
     (1 => 16#FF#, 2 => 16#00#, 3 => 16#00#, 4 => 16#FF#,
      5 => 16#00#, 6 => 16#FF#, 7 => 16#00#, 8 => 16#FF#,
      others => 0);
   Images (1).Preview_Decode_Complete := True;
   Images (1).Decode_Status := RM.Image_Decode_Ok;
   VS.Build (Frame, Batch, Status);
   Assert (Status = VS.Ok, "strided image texture batch build failed");
   Assert
     (not VS.Last_Image_Texture_Downgraded (Batch),
      "strided image should not report submit downgrade");
   Assert
     (VS.Last_Image_Texture_Source (Batch) = VS.Texture_Image,
      "strided image should use image texture source");
   Assert
     (VS.Last_Image_Decoded_Row_Stride_Bytes (Batch) = 12,
      "strided image should carry decoded row stride");
   Assert
     (VS.Last_Image_Decoded_Data_Byte (Batch, 20) = 16#FF#,
      "strided image should expose full source row span");
   Assert
     (VS.Last_Image_Decoded_Source_Bytes (Batch) = 20,
      "strided image source byte extent");
   Assert
     (VS.Last_Image_Decoded_Source_Available (Batch),
      "strided image decoded source availability");
   Assert
     (VS.Last_Image_Decoded_Row_Byte (Batch, 0, 0) = 16#FF#
      and then VS.Last_Image_Decoded_Row_Byte (Batch, 0, 4) = 16#00#
      and then VS.Last_Image_Decoded_Row_Byte (Batch, 1, 0) = 16#00#
      and then VS.Last_Image_Decoded_Row_Byte (Batch, 1, 7) = 16#FF#,
      "strided image row byte access");
   Assert
     (VS.Last_Image_Decoded_Row_Byte (Batch, 2, 0) = 0
      and then VS.Last_Image_Decoded_Row_Byte (Batch, 1, 12) = 0,
      "strided image row byte bounds");
   VS.Release (Batch);
   Images (1).Decoded_Row_Stride_Bytes := 0;

   Images (1).Protocol := RM.Image_Sixel;
   Images (1).Placeholder := False;
   Images (1).Raw_Format := 32;
   Images (1).Pixel_Width := 1;
   Images (1).Pixel_Height := 1;
   Images (1).Payload_Length := 2;
   Images (1).Payload_Preview_Complete := True;
   Images (1).Encoded_Preview_Length := 1;
   Images (1).Decoded_Byte_Length := 4;
   Images (1).Decoded_Source := RM.Image_Decoded_Source_Buffer;
   Images (1).Decoded_Bytes := White_RGBA'Unchecked_Access;
   Images (1).Decoded_Preview_Length := 4;
   Images (1).Decoded_Preview_Bytes :=
     (1 => 16#FF#, 2 => 16#FF#, 3 => 16#FF#, 4 => 16#FF#, others => 0);
   Images (1).Preview_Decode_Complete := True;
   Images (1).Decode_Status := RM.Image_Decode_Ok;
   VS.Build (Frame, Batch, Status);
   Assert (Status = VS.Ok, "sixel image texture batch build failed");
   Assert
     (not VS.Last_Image_Placeholder (Batch),
      "sixel image should remain textured in submit");
   Assert
     (not VS.Last_Image_Texture_Downgraded (Batch),
      "sixel image should not report submit downgrade");
   Assert
     (VS.Last_Image_Texture_Source (Batch) = VS.Texture_Image,
      "sixel image should use image texture source");
   Assert
     (VS.Image_Texture_Vertex_Count (Batch) = 6,
      "sixel image texture vertex count");
   Assert
     (VS.Vertices (Batch) (7).Textured
      and then VS.Vertices (Batch) (7).Texture = VS.Texture_Image,
      "sixel image vertices should use image texture");
   Assert
     (VS.Image_Status_Label (Batch) =
      "submit image sixel size=30x16 pixels=1x1 format=32 payload=2 payload-complete preview=4/1 bytes=FFFFFFFF texture=image textured decoded",
      "sixel image status label");
   VS.Release (Batch);

   Images (1).Protocol := RM.Image_ITerm2;
   Images (1).Placeholder := False;
   Images (1).Raw_Format := 32;
   Images (1).Pixel_Width := 1;
   Images (1).Pixel_Height := 1;
   Images (1).Payload_Length := 108;
   Images (1).Payload_Preview_Complete := True;
   Images (1).Encoded_Preview_Length := 92;
   Images (1).Decoded_Byte_Length := 4;
   Images (1).Decoded_Source := RM.Image_Decoded_Source_Buffer;
   Images (1).Decoded_Bytes := Red_RGBA'Unchecked_Access;
   Images (1).Decoded_Preview_Length := 4;
   Images (1).Decoded_Preview_Bytes :=
     (1 => 16#FF#, 2 => 16#00#, 3 => 16#00#, 4 => 16#FF#, others => 0);
   Images (1).Preview_Decode_Complete := True;
   Images (1).Decode_Status := RM.Image_Decode_Ok;
   VS.Build (Frame, Batch, Status);
   Assert (Status = VS.Ok, "iTerm2 PNG image texture batch build failed");
   Assert
     (not VS.Last_Image_Placeholder (Batch),
      "iTerm2 PNG image should remain textured in submit");
   Assert
     (not VS.Last_Image_Texture_Downgraded (Batch),
      "iTerm2 PNG image should not report submit downgrade");
   Assert
     (VS.Last_Image_Texture_Source (Batch) = VS.Texture_Image,
      "iTerm2 PNG image should use image texture source");
   Assert
     (VS.Image_Texture_Vertex_Count (Batch) = 6,
      "iTerm2 PNG image texture vertex count");
   VS.Release (Batch);

   Images (1).Protocol := RM.Image_Kitty;
   Images (1).Placeholder := False;
   Images (1).Raw_Format := 32;
   Images (1).Pixel_Width := 33;
   Images (1).Pixel_Height := 32;
   Images (1).Payload_Length := 5_632;
   Images (1).Payload_Preview_Complete := True;
   Images (1).Encoded_Preview_Length := 5_632;
   Images (1).Decoded_Byte_Length := 33 * 32 * 4;
   Images (1).Decoded_Source := RM.Image_Decoded_Source_Buffer;
   Images (1).Decoded_Bytes := Large_RGBA;
   Images (1).Decoded_Preview_Length := RM.Max_Image_Decoded_Preview_Length;
   Images (1).Decoded_Preview_Bytes := (others => 16#7F#);
   Images (1).Preview_Decode_Complete := True;
   Images (1).Decode_Status := RM.Image_Decode_Ok;
   VS.Build (Frame, Batch, Status);
   Assert (Status = VS.Ok, "large image texture batch build failed");
   Assert
     (not VS.Last_Image_Placeholder (Batch),
      "large image should remain textured with capped diagnostics preview");
   Assert
     (VS.Last_Image_Texture_Source (Batch) = VS.Texture_Image,
      "large image should use image texture source");
   Assert
     (VS.Last_Image_Decoded_Preview_Length (Batch) =
      RM.Max_Image_Decoded_Preview_Length,
      "large image should keep capped decoded diagnostics preview");
   Assert
     (VS.Last_Image_Decoded_Data_Byte (Batch, 33 * 32 * 4) = 16#7F#,
      "large image should expose decoded bytes through row source");
   Assert
     (VS.Image_Texture_Vertex_Count (Batch) = 6,
      "large image texture vertex count");
   VS.Release (Batch);

   Frame.Width := 0;
   VS.Build (Frame, Batch, Status);
   Assert (Status = VS.Invalid_Frame, "zero-width frame should be rejected");
   Assert
     (VS.Status_Label (Status) = "Submit build: Invalid Frame",
      "invalid submit status label");
end Vulkan_Submit_Smoke;

with Terminal.App.Image_Data;
with AUnit.Assertions;
with Ada.Unchecked_Deallocation;
with Interfaces;
with System;
with Smoke_Case_Failures;

with Terminal.Common.Bytes;
with Terminal.App.Render_Model;
with Terminal.App.Bounded_Append;
with Terminal.App.Vulkan_Submit;
with Terminal.App.Vulkan_Submit.Testing;

procedure Vulkan_Submit_Smoke is
   use AUnit.Assertions;
   use type Terminal.Common.Bytes.Byte;
   use type Terminal.App.Render_Model.Image_Decode_Status;
   use type Terminal.App.Render_Model.Image_Decoded_Source_Kind;
   use type Terminal.App.Render_Model.Image_Data_View;
   use type Terminal.App.Render_Model.Image_Protocol;
   use type Terminal.App.Render_Model.Text_Run_Array_View;
   use type Terminal.App.Render_Model.Text_Run_Direction;
   use type Terminal.App.Render_Model.Text_Run_Kind;
   use type Terminal.App.Render_Model.Text_Run_Script;
   use type Terminal.App.Render_Model.Text_Run_Shape_Status;
   use type Terminal.App.Vulkan_Submit.Build_Status;
   use type Terminal.App.Vulkan_Submit.Image_Atlas_Limits;
   use type Terminal.App.Vulkan_Submit.Image_Source_Read_Status;
   use type Terminal.App.Vulkan_Submit.Texture_Source;
   use type Terminal.App.Vulkan_Submit.Vertex_Array_View;
   use type System.Address;
   use type Interfaces.Unsigned_64;
   package VST renames Terminal.App.Vulkan_Submit.Testing;

   package RM renames Terminal.App.Render_Model;
   package VS renames Terminal.App.Vulkan_Submit;

   Rects : aliased RM.Rectangle_Array :=
     [1 =>
        (X      => 0.0,
         Y      => 0.0,
         Width  => 50.0,
         Height => 20.0,
         Color  => (R => 1.0, G => 0.0, B => 0.0, A => 1.0),
         Layer  => RM.Rectangle_Base_Background)];
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
   Blue_RGBA : aliased Terminal.Common.Bytes.Byte_Array :=
     (1 => 16#00#, 2 => 16#00#, 3 => 16#FF#, 4 => 16#FF#);
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
   Preview_ABC : aliased Terminal.Common.Bytes.Byte_Array :=
     (1 => 16#41#, 2 => 16#42#, 3 => 16#43#);
   Atlas_Data : aliased Terminal.Common.Bytes.Byte_Array (1 .. 65_536) :=
     (others => 0);
   Large_RGBA : Terminal.App.Image_Data.Image_Data_Access :=
     new Terminal.Common.Bytes.Byte_Array'(1 .. 65 * 64 * 4 => 16#7F#);
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
         Encoded_Source_Bytes => null,
         Encoded_Source_Length => 0,
         Decoded_Preview_Length => 3,
         Decoded_Preview_Bytes => Preview_ABC'Unchecked_Access,
         Preview_Decode_Complete => True,
         Decode_Status => RM.Image_Decode_Ok,
         U0             => 0.0,
         V0             => 0.0,
         U1             => 1.0,
         V1             => 1.0,
         Image_ID       => 0,
         Content_Serial => 1,
         Z_Index        => 0,
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
      Colour_Glyphs   => null,
      Colour_Glyph_Count => 0,
      Colour_Sheet_Width => 0,
      Colour_Sheet_Height => 0,
      Colour_Sheet_Pixels => System.Null_Address,
      Colour_Sheet_Bytes => 0,
      Colour_Sheet_Dirty => True,
      Images          => Images'Unchecked_Access,
      Image_Count     => 1,
      Text_Runs       => Runs'Unchecked_Access,
      Text_Run_Count  => 1,
      Atlas_Width     => 256,
      Atlas_Height    => 256,
      Atlas_Pixels    => Atlas_Data'Address,
      Atlas_Bytes     => 65_536,
      Atlas_Dirty     => True);

   Batch  : VS.Submission_Batch;
   Status : VS.Build_Status;

   Initial_Rects        : constant RM.Rectangle_Array := Rects;
   Initial_Glyphs       : constant RM.Glyph_Array := Glyphs;
   Initial_Red_RGBA     : constant Terminal.Common.Bytes.Byte_Array := Red_RGBA;
   Initial_White_RGBA   : constant Terminal.Common.Bytes.Byte_Array := White_RGBA;
   Initial_Blue_RGBA    : constant Terminal.Common.Bytes.Byte_Array := Blue_RGBA;
   Initial_Strided_RGBA : constant Terminal.Common.Bytes.Byte_Array := Strided_RGBA;
   Initial_Images       : constant RM.Image_Array := Images;
   Initial_Runs         : constant RM.Text_Run_Array := Runs;
   Initial_Frame        : constant RM.Frame_Commands := Frame;

   procedure Reset_Fixture is
   begin
      VS.Release (Batch);
      Rects := Initial_Rects;
      Glyphs := Initial_Glyphs;
      Red_RGBA := Initial_Red_RGBA;
      White_RGBA := Initial_White_RGBA;
      Blue_RGBA := Initial_Blue_RGBA;
      Strided_RGBA := Initial_Strided_RGBA;
      Images := Initial_Images;
      Runs := Initial_Runs;
      Frame := Initial_Frame;
      VS.Set_Image_Atlas_Limits (Batch, VS.Default_Image_Atlas_Limits);
   end Reset_Fixture;

   procedure Configure_Raw_Image_Fixture is
   begin
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
      Images (1).Decoded_Preview_Bytes := Red_RGBA'Unchecked_Access;
      Images (1).Preview_Decode_Complete := True;
      Images (1).Decode_Status := RM.Image_Decode_Ok;
   end Configure_Raw_Image_Fixture;

   function Near (Left, Right : Float) return Boolean is
     (abs (Left - Right) < 0.000_01);
   procedure Validation_Cases is separate;
   procedure Baseline_Cases is separate;
   procedure Multi_Image_Cases is separate;
   procedure Source_Cases is separate;
   procedure Invalid_Frame_Cases is separate;
   procedure Extent_Cases is separate;
begin
   Validation_Cases;
   Baseline_Cases;
   Multi_Image_Cases;
   Source_Cases;
   Invalid_Frame_Cases;
   Extent_Cases;
end Vulkan_Submit_Smoke;

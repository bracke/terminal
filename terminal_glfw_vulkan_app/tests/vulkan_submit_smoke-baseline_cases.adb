separate (Vulkan_Submit_Smoke)
procedure Baseline_Cases is
begin
   Reset_Fixture;
   declare
   begin
      VS.Build (Frame, Batch, Status);
   Assert (Status = VS.Ok, "batch build failed");
   Assert
     (VS.Status_Label (Status) = "Submit build: Ok",
      "built submit status label");
   Assert (VS.Width (Batch) = 100, "frame width not carried");
   Assert (VS.Height (Batch) = 40, "frame height not carried");
   Assert
     (not VS.Colour_Atlas_Dirty (Batch),
      "an absent colour atlas is never marked dirty");
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
   Assert (VST.Text_Runs (Batch) /= null, "text runs not copied");
   Assert
     (VST.Text_Runs (Batch) (1).Codepoint_Count = 4,
      "text run codepoint count");
   Assert
     (VST.Text_Runs (Batch) (1).Codepoints (3) = 16#1F468#,
      "text run joined scalar");
   Assert
     (VST.Text_Runs (Batch) (1).Run_Kind = RM.Joined_Emoji_Cluster,
      "text run class");
   Assert
     (VST.Text_Runs (Batch) (1).Shape_Status = RM.Needs_Shaping_Backend,
      "text run shape status");
   Assert
     (VST.Text_Runs (Batch) (1).Direction = RM.Direction_Left_To_Right,
      "text run direction");
   Assert
     (VST.Text_Runs (Batch) (1).Script = RM.Script_Emoji,
      "text run script");
   Assert
     (VST.Text_Runs (Batch) (1).Shaped_Glyph_Count = 1,
      "text run shaped glyph count");
   Assert
     (VST.Text_Runs (Batch) (1).Shaped_Glyphs (1).Glyph_ID = 42,
      "text run shaped glyph id");
   Assert
     (VST.Text_Runs (Batch) (1).Shaped_Glyphs (1).Font_Index = 0,
      "text run shaped glyph font index");
   Assert
     (VST.Text_Runs (Batch) (1).Fallback_Glyphs,
      "text run fallback flag");
   declare
      Retained_Vertices : constant VS.Vertex_Array_View :=
        VST.Vertices (Batch);
      Retained_Runs : constant RM.Text_Run_Array_View :=
        VST.Text_Runs (Batch);
   begin
      Frame.Colour_Sheet_Dirty := False;
      VS.Build (Frame, Batch, Status);
      Assert (Status = VS.Ok, "retained-capacity batch rebuild");
      Assert
        (VST.Vertices (Batch) = Retained_Vertices
         and then VST.Text_Runs (Batch) = Retained_Runs,
         "equal-sized batch rebuild should retain storage");
      Assert
        (not VS.Colour_Atlas_Dirty (Batch),
         "clean colour atlas flag not carried");
   end;
   Runs (1).Codepoints (3) := 0;
   Assert
     (VST.Text_Runs (Batch) (1).Codepoints (3) = 16#1F468#,
      "batch should own text run copy");
   Assert (VS.Text_Atlas_Used (Batch), "glyph quad should use text atlas");
   Assert (VS.Atlas_Dirty (Batch), "atlas dirty flag not carried");
   Assert (VS.Atlas_Width (Batch) = 256, "atlas width");
   Assert (VS.Atlas_Height (Batch) = 256, "atlas height");
   Assert (VS.Atlas_Bytes (Batch) = 65_536, "atlas bytes");
   Assert
     (VST.Atlas_Pixels (Batch) /= System.Null_Address
      and then VST.Atlas_Pixels (Batch) /= Atlas_Data'Address,
      "submission batch owns the text atlas bytes");
   Assert (VST.Vertices (Batch) /= null, "vertices not allocated");
   Assert
     (VST.Vertices (Batch) (7).Texture = VS.Texture_Text_Atlas,
      "glyph vertices should be textured");
   Assert
     (not VST.Vertices (Batch) (13).Textured
      and then VST.Vertices (Batch) (13).Texture = VS.Texture_None,
      "non-negative image placeholder should be above text");
   Assert
     (VST.Vertices (Batch) (1).Y = -1.0,
      "top edge should map to Vulkan clip-space top");
   Assert
     (VST.Vertices (Batch) (3).Y = 0.0,
      "lower edge should map downward in Vulkan clip space");

   Images (1).Z_Index := -1;
   VS.Build (Frame, Batch, Status);
   Assert (Status = VS.Ok, "negative z-index batch build failed");
   Assert
     (VST.Vertices (Batch) (7).Texture = VS.Texture_None
      and then VST.Vertices (Batch) (13).Texture = VS.Texture_Text_Atlas,
      "negative z-index image should be submitted below text");

   Rects (1).Layer := RM.Rectangle_Cell_Background;
   Images (1).Z_Index := -1_073_741_825;
   VS.Build (Frame, Batch, Status);
   Assert (Status = VS.Ok, "deep negative z-index batch build failed");
   Assert
     (Near (VST.Vertices (Batch) (1).Color.R, 0.1)
      and then Near (VST.Vertices (Batch) (7).Color.R, 1.0)
      and then VST.Vertices (Batch) (13).Texture = VS.Texture_Text_Atlas,
      "deep negative image should be below non-default cell background");

   Images (1).Z_Index := -1_073_741_824;
   VS.Build (Frame, Batch, Status);
   Assert (Status = VS.Ok, "z-index threshold batch build failed");
   Assert
     (Near (VST.Vertices (Batch) (1).Color.R, 1.0)
      and then Near (VST.Vertices (Batch) (7).Color.R, 0.1),
      "INT32_MIN/2 threshold remains above cell background");

   Rects (1).Layer := RM.Rectangle_Base_Background;
   Images (1).Z_Index := 0;

   VS.Release (Batch);
   Assert (VS.Vertex_Count (Batch) = 0, "release should clear vertices");
   Assert (VST.Vertices (Batch) = null, "released batch vertices should be null");
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
   Assert (VST.Text_Runs (Batch) = null, "release should clear text runs");
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
     (not VST.Vertices (Batch) (13).Textured
      and then VST.Vertices (Batch) (13).Texture = VS.Texture_None,
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
   Images (1).Decoded_Preview_Bytes := Red_RGBA'Unchecked_Access;
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
     (VST.Vertices (Batch) (13).Textured
      and then VST.Vertices (Batch) (13).Texture = VS.Texture_Image,
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
   exception
      when E : others =>
         Smoke_Case_Failures.Reraise ("submission baseline", E);
   end;

end Baseline_Cases;

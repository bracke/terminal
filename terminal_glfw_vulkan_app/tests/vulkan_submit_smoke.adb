with AUnit.Assertions;
with System;

with Terminal.App.Render_Model;
with Terminal.App.Vulkan_Submit;

procedure Vulkan_Submit_Smoke is
   use AUnit.Assertions;
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

   Frame : RM.Frame_Commands :=
     (Width           => 100,
      Height          => 40,
      Rectangles      => Rects'Unchecked_Access,
      Rectangle_Count => 1,
      Glyphs          => Glyphs'Unchecked_Access,
      Glyph_Count     => 1,
      Atlas_Width     => 256,
      Atlas_Height    => 256,
      Atlas_Pixels    => System'To_Address (16#1000#),
      Atlas_Bytes     => 65_536,
      Atlas_Dirty     => True);

   Batch  : VS.Submission_Batch;
   Status : VS.Build_Status;
begin
   VS.Build (Frame, Batch, Status);
   Assert (Status = VS.Ok, "batch build failed");
   Assert (VS.Width (Batch) = 100, "frame width not carried");
   Assert (VS.Height (Batch) = 40, "frame height not carried");
   Assert (VS.Vertex_Count (Batch) = 12, "two quads should produce 12 vertices");
   Assert (VS.Rectangle_Vertex_Count (Batch) = 6, "rectangle vertex count");
   Assert (VS.Glyph_Vertex_Count (Batch) = 6, "glyph vertex count");
   Assert (VS.Text_Atlas_Used (Batch), "glyph quad should use text atlas");
   Assert (VS.Atlas_Dirty (Batch), "atlas dirty flag not carried");
   Assert (VS.Atlas_Width (Batch) = 256, "atlas width");
   Assert (VS.Atlas_Height (Batch) = 256, "atlas height");
   Assert (VS.Atlas_Bytes (Batch) = 65_536, "atlas bytes");
   Assert (VS.Vertices (Batch) /= null, "vertices not allocated");
   Assert
     (VS.Vertices (Batch) (7).Texture = VS.Texture_Text_Atlas,
      "glyph vertices should be textured");

   VS.Release (Batch);
   Assert (VS.Vertex_Count (Batch) = 0, "release should clear vertices");

   Frame.Width := 0;
   VS.Build (Frame, Batch, Status);
   Assert (Status = VS.Invalid_Frame, "zero-width frame should be rejected");
end Vulkan_Submit_Smoke;

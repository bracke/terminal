with Ada.Text_IO;
with AUnit.Assertions;

with Interfaces;

with Terminal.App.Render_Model;
with Terminal.App.Vulkan_Submit;

--  Colour glyphs pack into the image texture and draw from it.
--
--  A colour emoji cannot be a glyph command: those read the glyph atlas, which
--  is a single coverage channel with nowhere to keep a colour. It carries its
--  own pixels and the submission packs them into the one texture that is RGBA.
--
--  What this pins is the packing, because that is where it can go wrong quietly:
--  two occurrences of one emoji must share a tile, two different emoji must not,
--  and each quad must read its own rectangle of the sheet rather than the whole
--  of it, which is what the image protocols do.
procedure Colour_Glyph_Submit_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Vulkan_Submit.Build_Status;
   use type Terminal.App.Vulkan_Submit.Texture_Source;

   package RM renames Terminal.App.Render_Model;
   package VS renames Terminal.App.Vulkan_Submit;

   function Tile
     (Codepoint : Natural;
      X         : Float;
      Red       : Interfaces.Unsigned_8) return RM.Colour_Glyph_Command
   is
      Result : RM.Colour_Glyph_Command;
   begin
      Result.X := X;
      Result.Y := 0.0;
      Result.Width := 4;
      Result.Height := 4;
      Result.Length := 4 * 4 * 4;
      Result.Codepoint := Codepoint;

      for Pixel in 0 .. 15 loop
         Result.Pixels (Pixel * 4 + 1) := Red;
         Result.Pixels (Pixel * 4 + 2) := 0;
         Result.Pixels (Pixel * 4 + 3) := 0;
         Result.Pixels (Pixel * 4 + 4) := 255;
      end loop;

      return Result;
   end Tile;

   --  Two of one emoji and one of another: three drawn, two tiles packed.
   Colour : aliased RM.Colour_Glyph_Array :=
     [1 => Tile (16#1F389#, 0.0, 200),
      2 => Tile (16#1F600#, 20.0, 100),
      3 => Tile (16#1F389#, 40.0, 200)];

   Frame : RM.Frame_Commands;
   Batch : VS.Submission_Batch;
   Status : VS.Build_Status;
   Colour_Quads : Natural := 0;
   Distinct_U0  : Natural := 0;
   Seen_U0      : array (1 .. 8) of Float := [others => -1.0];
begin
   Frame.Width := 200;
   Frame.Height := 50;
   Frame.Colour_Glyphs := Colour'Unchecked_Access;
   Frame.Colour_Glyph_Count := 3;

   VS.Build (Frame, Batch, Status);
   Assert (Status = VS.Ok, "the frame builds");

   Assert (VS.Colour_Atlas_Bytes (Batch) > 0,
           "a sheet was packed for the colour glyphs");
   Assert (VS.Colour_Atlas_Width (Batch) > 0
             and then VS.Colour_Atlas_Height (Batch) > 0,
           "with a real size");

   --  Two distinct emoji, four pixels tall: one shelf is enough for both.
   Assert (VS.Colour_Atlas_Height (Batch) = 4,
           "packed onto one shelf, got"
           & Natural'Image (VS.Colour_Atlas_Height (Batch)));

   Assert (VS.Colour_Glyph_Vertex_Count (Batch) = 3 * 6,
           "all three occurrences drew, got"
           & Natural'Image (VS.Colour_Glyph_Vertex_Count (Batch)));

   declare
      Items : constant VS.Vertex_Array_Access := VS.Vertices (Batch);
   begin
      for Index in 1 .. VS.Vertex_Count (Batch) loop
         if Items (Index).Texture = VS.Texture_Image then
            Colour_Quads := Colour_Quads + 1;

            --  A whole-texture quad would read 0..1; each of these must read a
            --  rectangle of its own.
            Assert (Items (Index).U <= 1.0 and then Items (Index).V <= 1.0,
                    "the tile's coordinates stay inside the sheet");
         end if;
      end loop;

      Assert (Colour_Quads = 3 * 6,
              "every colour vertex is drawn from the image texture");

      --  The repeat must read the same rectangle as the first occurrence, and
      --  the different emoji a different one. Comparing the quads directly says
      --  that; counting distinct edge values does not, because two tiles packed
      --  side by side share the edge between them.
      declare
         type Quad_UV is record
            U0, U1 : Float := -1.0;
         end record;

         Quads : array (1 .. 3) of Quad_UV;
         Seen  : Natural := 0;
      begin
         for Index in 1 .. VS.Vertex_Count (Batch) loop
            if Items (Index).Texture = VS.Texture_Image then
               declare
                  Which : constant Natural := Seen / 6 + 1;
               begin
                  if Which <= Quads'Last then
                     if Quads (Which).U0 < 0.0
                       or else Items (Index).U < Quads (Which).U0
                     then
                        Quads (Which).U0 := Items (Index).U;
                     end if;

                     if Items (Index).U > Quads (Which).U1 then
                        Quads (Which).U1 := Items (Index).U;
                     end if;
                  end if;

                  Seen := Seen + 1;
               end;
            end if;
         end loop;

         Assert (abs (Quads (1).U0 - Quads (3).U0) < 0.000_1
                   and then abs (Quads (1).U1 - Quads (3).U1) < 0.000_1,
                 "the second occurrence of an emoji reads the first one's tile");
         Assert (abs (Quads (1).U0 - Quads (2).U0) > 0.000_1,
                 "while a different emoji reads a tile of its own");
      end;
   end;

   VS.Release (Batch);
   Ada.Text_IO.Put_Line ("colour glyph submit smoke: PASS");
end Colour_Glyph_Submit_Smoke;

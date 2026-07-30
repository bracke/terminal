with Ada.Text_IO;
with AUnit.Assertions;

with Interfaces;
with System;

with Terminal.Common.Bytes;
with Terminal.App.Render_Model;
with Terminal.App.Vulkan_Submit;

--  Colour glyphs pack into a sheet of their own and draw from it.
--
--  A colour emoji cannot be a glyph command: those read the glyph atlas, which
--  is a single coverage channel with nowhere to keep a colour. It carries its
--  own pixels and the submission packs them into an RGBA sheet, bound at a
--  binding of its own so an inline picture in the same frame does not displace
--  it.
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

   use type System.Address;

   --  A glyph as Textrender hands it over: a place on screen and a rectangle of
   --  the sheet. The packing that produced that rectangle is Textrender's, and
   --  is tested there.
   function Tile
     (Left  : Float;
      X     : Float) return RM.Colour_Glyph_Command
   is
      Result : RM.Colour_Glyph_Command;
   begin
      Result.X := X;
      Result.Y := 0.0;
      Result.Width := 4;
      Result.Height := 4;
      Result.U0 := Left;
      Result.V0 := 0.0;
      Result.U1 := Left + 0.05;
      Result.V1 := 0.05;
      return Result;
   end Tile;

   --  Two of one emoji and one of another: three drawn, two tiles packed.
   --  Two distinct glyphs, one of them drawn twice.
   Colour : aliased RM.Colour_Glyph_Array :=
     [1 => Tile (0.0, 0.0),
      2 => Tile (0.5, 20.0),
      3 => Tile (0.0, 40.0)];

   --  Stands in for Textrender's sheet; the submission only passes it along.
   Sheet : aliased constant Interfaces.Unsigned_8 := 0;

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
   Frame.Colour_Sheet_Width := 512;
   Frame.Colour_Sheet_Height := 512;
   Frame.Colour_Sheet_Pixels := Sheet'Address;

   VS.Build (Frame, Batch, Status);
   Assert (Status = VS.Ok, "the frame builds");

   Assert (VS.Colour_Atlas_Pixels (Batch) = Sheet'Address,
           "the sheet is passed through to the device, not copied");
   Assert (VS.Colour_Atlas_Width (Batch) = 512
             and then VS.Colour_Atlas_Height (Batch) = 512,
           "with the size Textrender gave it");

   Assert (VS.Colour_Glyph_Vertex_Count (Batch) = 3 * 6,
           "all three occurrences drew, got"
           & Natural'Image (VS.Colour_Glyph_Vertex_Count (Batch)));

   declare
      Items : constant VS.Vertex_Array_Access := VS.Vertices (Batch);
   begin
      for Index in 1 .. VS.Vertex_Count (Batch) loop
         if Items (Index).Texture = VS.Texture_Colour_Glyphs then
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
            if Items (Index).Texture = VS.Texture_Colour_Glyphs then
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

   --  The point of giving colour glyphs a binding of their own: a frame that
   --  also draws an inline picture must still draw its emoji. While the two
   --  shared the image texture, the picture took it and the emoji fell back to
   --  outlines.
   declare
      --  An inline picture that genuinely claims the image texture: everything
      --  the eligibility check asks for, including bytes to read.
      Decoded : constant RM.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 2 * 2 * 4 => 255);
      Images : aliased RM.Image_Array :=
        [1 =>
           (X => 0.0, Y => 0.0, Width => 10.0, Height => 10.0,
            Protocol => RM.Image_Sixel,
            Placeholder => False,
            Pixel_Width => 2,
            Pixel_Height => 2,
            Raw_Format => 32,
            Decoded_Row_Stride_Bytes => 2 * 4,
            Payload_Preview_Complete => True,
            Preview_Decode_Complete => True,
            Decode_Status => RM.Image_Decode_Ok,
            Decoded_Source => RM.Image_Decoded_Source_Buffer,
            Decoded_Bytes => Decoded,
            Decoded_Byte_Length => 2 * 2 * 4,
            others => <>)];
      With_Image : RM.Frame_Commands;
      Image_Batch : VS.Submission_Batch;
      Image_Status : VS.Build_Status;
      Colour_Vertices : Natural := 0;
   begin
      With_Image.Width := 200;
      With_Image.Height := 50;
      With_Image.Colour_Glyphs := Colour'Unchecked_Access;
      With_Image.Colour_Glyph_Count := 3;
      With_Image.Colour_Sheet_Width := 512;
      With_Image.Colour_Sheet_Height := 512;
      With_Image.Colour_Sheet_Pixels := Sheet'Address;
      With_Image.Images := Images'Unchecked_Access;
      With_Image.Image_Count := 1;

      VS.Build (With_Image, Image_Batch, Image_Status);
      Assert (Image_Status = VS.Ok, "a frame with both builds");

      declare
         Items : constant VS.Vertex_Array_Access := VS.Vertices (Image_Batch);
      begin
         for Index in 1 .. VS.Vertex_Count (Image_Batch) loop
            if Items (Index).Texture = VS.Texture_Colour_Glyphs then
               Colour_Vertices := Colour_Vertices + 1;
            end if;
         end loop;
      end;

      --  The fixture has to be an image that actually claims the texture, or
      --  this proves nothing: under the old arrangement the emoji were only
      --  dropped when the picture was eligible for it.
      Assert (VS.Last_Image_Texture_Source (Image_Batch) = VS.Texture_Image,
              "the fixture picture claims the image texture, got "
              & VS.Texture_Source_Label (VS.Last_Image_Texture_Source (Image_Batch)));

      Assert (Colour_Vertices = 3 * 6,
              "the emoji still draw alongside an inline picture, got"
              & Natural'Image (Colour_Vertices));
      Assert (VS.Colour_Atlas_Pixels (Image_Batch) = Sheet'Address,
              "and their sheet is still passed along");

      VS.Release (Image_Batch);
   end;

   Ada.Text_IO.Put_Line ("colour glyph submit smoke: PASS");
end Colour_Glyph_Submit_Smoke;

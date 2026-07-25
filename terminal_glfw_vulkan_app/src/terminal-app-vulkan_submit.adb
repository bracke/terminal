with Ada.Unchecked_Deallocation;

package body Terminal.App.Vulkan_Submit is
   package RM renames Terminal.App.Render_Model;

   use type RM.Glyph_Array_Access;
   use type RM.Rectangle_Array_Access;
   use type Vertex_Array_Access;

   procedure Free_Vertices is new Ada.Unchecked_Deallocation
     (Vertex_Array, Vertex_Array_Access);

   function Clip_X (Frame_Width : Natural; X : Float) return Float is
   begin
      return X / Float (Frame_Width) * 2.0 - 1.0;
   end Clip_X;

   function Clip_Y (Frame_Height : Natural; Y : Float) return Float is
   begin
      return Y / Float (Frame_Height) * 2.0 - 1.0;
   end Clip_Y;

   procedure Append_Vertex
     (Batch   : in out Submission_Batch;
      X       : Float;
      Y       : Float;
      U       : Float;
      V       : Float;
      Color   : RM.Pixel_Color;
      Textured : Boolean;
      Texture : Texture_Source)
   is
   begin
      if Batch.Items = null or else Batch.Count >= Batch.Items'Length then
         return;
      end if;

      Batch.Count := Batch.Count + 1;
      Batch.Items (Batch.Count) :=
        (X        => X,
         Y        => Y,
         U        => U,
         V        => V,
         Color    => Color,
         Textured => Textured,
         Texture  => Texture);
   end Append_Vertex;

   procedure Append_Quad
     (Batch   : in out Submission_Batch;
      Frame_W : Natural;
      Frame_H : Natural;
      X       : Float;
      Y       : Float;
      W       : Float;
      H       : Float;
      U0      : Float;
      V0      : Float;
      U1      : Float;
      V1      : Float;
      Color   : RM.Pixel_Color;
      Textured : Boolean;
      Texture : Texture_Source)
   is
      X0 : constant Float := Clip_X (Frame_W, X);
      Y0 : constant Float := Clip_Y (Frame_H, Y);
      X1 : constant Float := Clip_X (Frame_W, X + W);
      Y1 : constant Float := Clip_Y (Frame_H, Y + H);
   begin
      if W <= 0.0 or else H <= 0.0 then
         return;
      end if;

      Append_Vertex (Batch, X0, Y0, U0, V0, Color, Textured, Texture);
      Append_Vertex (Batch, X1, Y0, U1, V0, Color, Textured, Texture);
      Append_Vertex (Batch, X1, Y1, U1, V1, Color, Textured, Texture);

      Append_Vertex (Batch, X0, Y0, U0, V0, Color, Textured, Texture);
      Append_Vertex (Batch, X1, Y1, U1, V1, Color, Textured, Texture);
      Append_Vertex (Batch, X0, Y1, U0, V1, Color, Textured, Texture);
   end Append_Quad;

   procedure Release (Batch : in out Submission_Batch) is
   begin
      if Batch.Items /= null then
         Free_Vertices (Batch.Items);
      end if;

      Batch.Count := 0;
      Batch.Rectangle_Vertex_Total := 0;
      Batch.Glyph_Vertex_Total := 0;
      Batch.Frame_Width := 0;
      Batch.Frame_Height := 0;
      Batch.Uses_Text_Atlas := False;
      Batch.Text_Atlas_Width := 0;
      Batch.Text_Atlas_Height := 0;
      Batch.Text_Atlas_Pixels := System.Null_Address;
      Batch.Text_Atlas_Bytes := 0;
      Batch.Dirty_Atlas := False;
   end Release;

   overriding procedure Finalize (Batch : in out Submission_Batch) is
   begin
      Release (Batch);
   end Finalize;

   procedure Build
     (Frame  : RM.Frame_Commands;
      Batch  : in out Submission_Batch;
      Status : out Build_Status)
   is
      Max_Vertices : Natural;
   begin
      Release (Batch);

      if Frame.Width = 0
        or else Frame.Height = 0
        or else (Frame.Rectangle_Count > 0 and then Frame.Rectangles = null)
        or else (Frame.Glyph_Count > 0 and then Frame.Glyphs = null)
      then
         Status := Invalid_Frame;
         return;
      end if;

      Max_Vertices := (Frame.Rectangle_Count + Frame.Glyph_Count) * 6;
      if Max_Vertices = 0 then
         Batch.Frame_Width := Frame.Width;
         Batch.Frame_Height := Frame.Height;
         Batch.Text_Atlas_Width := Frame.Atlas_Width;
         Batch.Text_Atlas_Height := Frame.Atlas_Height;
         Batch.Text_Atlas_Pixels := Frame.Atlas_Pixels;
         Batch.Text_Atlas_Bytes := Frame.Atlas_Bytes;
         Status := Ok;
         return;
      end if;

      Batch.Items := new Vertex_Array (1 .. Max_Vertices);
      Batch.Frame_Width := Frame.Width;
      Batch.Frame_Height := Frame.Height;
      Batch.Text_Atlas_Width := Frame.Atlas_Width;
      Batch.Text_Atlas_Height := Frame.Atlas_Height;
      Batch.Text_Atlas_Pixels := Frame.Atlas_Pixels;
      Batch.Text_Atlas_Bytes := Frame.Atlas_Bytes;
      Batch.Dirty_Atlas := Frame.Atlas_Dirty;

      for I in 1 .. Frame.Rectangle_Count loop
         declare
            Rect : constant RM.Rectangle_Command := Frame.Rectangles (I);
            Before : constant Natural := Batch.Count;
         begin
            Append_Quad
              (Batch,
               Frame.Width,
               Frame.Height,
               Rect.X,
               Rect.Y,
               Rect.Width,
               Rect.Height,
               0.0,
               0.0,
               0.0,
               0.0,
               Rect.Color,
               False,
               Texture_None);
            Batch.Rectangle_Vertex_Total :=
              Batch.Rectangle_Vertex_Total + (Batch.Count - Before);
         end;
      end loop;

      for I in 1 .. Frame.Glyph_Count loop
         declare
            Glyph : constant RM.Glyph_Command := Frame.Glyphs (I);
            Before : constant Natural := Batch.Count;
         begin
            Append_Quad
              (Batch,
               Frame.Width,
               Frame.Height,
               Glyph.X,
               Glyph.Y,
               Glyph.Width,
               Glyph.Height,
               Glyph.U0,
               Glyph.V0,
               Glyph.U1,
               Glyph.V1,
               Glyph.Color,
               True,
               Texture_Text_Atlas);
            Batch.Glyph_Vertex_Total := Batch.Glyph_Vertex_Total + (Batch.Count - Before);
            if Batch.Count > Before then
               Batch.Uses_Text_Atlas := True;
            end if;
         end;
      end loop;

      Status := Ok;
   exception
      when Storage_Error =>
         Release (Batch);
         Status := Allocation_Failed;
   end Build;

   function Vertices (Batch : Submission_Batch) return Vertex_Array_Access is
     (Batch.Items);

   function Vertex_Count (Batch : Submission_Batch) return Natural is
     (Batch.Count);

   function Rectangle_Vertex_Count (Batch : Submission_Batch) return Natural is
     (Batch.Rectangle_Vertex_Total);

   function Glyph_Vertex_Count (Batch : Submission_Batch) return Natural is
     (Batch.Glyph_Vertex_Total);

   function Width (Batch : Submission_Batch) return Natural is
     (Batch.Frame_Width);

   function Height (Batch : Submission_Batch) return Natural is
     (Batch.Frame_Height);

   function Text_Atlas_Used (Batch : Submission_Batch) return Boolean is
     (Batch.Uses_Text_Atlas);

   function Atlas_Width (Batch : Submission_Batch) return Natural is
     (Batch.Text_Atlas_Width);

   function Atlas_Height (Batch : Submission_Batch) return Natural is
     (Batch.Text_Atlas_Height);

   function Atlas_Pixels (Batch : Submission_Batch) return System.Address is
     (Batch.Text_Atlas_Pixels);

   function Atlas_Bytes (Batch : Submission_Batch) return Natural is
     (Batch.Text_Atlas_Bytes);

   function Atlas_Dirty (Batch : Submission_Batch) return Boolean is
     (Batch.Dirty_Atlas);
end Terminal.App.Vulkan_Submit;

with Ada.Characters.Handling;
with Ada.Containers.Generic_Array_Sort;
with Ada.Unchecked_Deallocation;

with Terminal.Common.Bytes;
with Terminal.Common.Status;

package body Terminal.App.Vulkan_Submit is
   package RM renames Terminal.App.Render_Model;

   use type RM.Glyph_Array_Access;
   use type RM.Image_Array_Access;
   use type RM.Image_Data_Access;
   use type RM.Image_Decode_Status;
   use type RM.Image_Decoded_Source_Kind;
   use type RM.Image_Protocol;
   use type RM.Rectangle_Array_Access;
   use type RM.Rectangle_Layer;
   use type RM.Text_Run_Array_Access;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;
   use type Vertex_Array_Access;

   function Trimmed_Natural (Value : Natural) return String is
      Text : constant String := Natural'Image (Value);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Trimmed_Natural;

   function Humanize (Text : String) return String is
      Result : String (1 .. Text'Length);
      At_Word_Start : Boolean := True;
   begin
      for I in Text'Range loop
         declare
            Ch : constant Character := Text (I);
            Out_Index : constant Positive := I - Text'First + 1;
         begin
            if Ch = '_' then
               Result (Out_Index) := ' ';
               At_Word_Start := True;
            elsif At_Word_Start then
               Result (Out_Index) := Ada.Characters.Handling.To_Upper (Ch);
               At_Word_Start := False;
            else
               Result (Out_Index) := Ada.Characters.Handling.To_Lower (Ch);
            end if;
         end;
      end loop;
      return Result;
   end Humanize;

   function Status_Label (Status : Build_Status) return String is
      Label : constant String := "Submit build: " & Humanize (Build_Status'Image (Status));
   begin
      if Label'Length > Max_Status_Label_Length then
         return Label (1 .. Max_Status_Label_Length);
      else
         return Label;
      end if;
   end Status_Label;

   function Texture_Source_Label (Source : Texture_Source) return String is
   begin
      case Source is
         when Texture_None =>
            return "none";
         when Texture_Text_Atlas =>
            return "text-atlas";
         when Texture_Image =>
            return "image";
         when Texture_Colour_Glyphs =>
            return "colour-glyphs";
      end case;
   end Texture_Source_Label;

   use type System.Address;
   use type RM.Colour_Glyph_Array_Access;

   procedure Free_Vertices is new Ada.Unchecked_Deallocation
     (Vertex_Array, Vertex_Array_Access);
   procedure Free_Text_Runs is new Ada.Unchecked_Deallocation
     (RM.Text_Run_Array, RM.Text_Run_Array_Access);
   procedure Free_Image_Atlas_Sources is new Ada.Unchecked_Deallocation
     (Image_Atlas_Source_Array, Image_Atlas_Source_Array_Access);
   procedure Free_Image_Order is new Ada.Unchecked_Deallocation
     (Image_Order_Array, Image_Order_Array_Access);

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

   procedure Reset (Batch : in out Submission_Batch) is
   begin
      Batch.Count := 0;
      Batch.Rectangle_Vertex_Total := 0;
      Batch.Glyph_Vertex_Total := 0;
      Batch.Image_Vertex_Total := 0;
      Batch.Image_Texture_Vertex_Total := 0;
      Batch.Image_Command_Total := 0;
      Batch.Image_Order_Total := 0;
      Batch.Image_Atlas_Source_Total := 0;
      Batch.Image_Atlas_W := 0;
      Batch.Image_Atlas_H := 0;
      Batch.Image_Atlas_Byte_Count := 0;
      Batch.Image_Atlas_Content_Signature := 0;
      Batch.Colour_Sheet_Source := System.Null_Address;
      Batch.Colour_Atlas_W := 0;
      Batch.Colour_Atlas_H := 0;
      Batch.Colour_Atlas_Byte_Count := 0;
      Batch.Dirty_Colour_Atlas := False;
      Batch.Colour_Glyph_Vertex_Total := 0;
      Batch.Last_Image_Protocol := RM.Image_Sixel;
      Batch.Last_Image_Width := 0;
      Batch.Last_Image_Height := 0;
      Batch.Last_Image_Raw_Format := 0;
      Batch.Last_Image_Pixel_Width := 0;
      Batch.Last_Image_Pixel_Height := 0;
      Batch.Last_Image_Payload_Length := 0;
      Batch.Last_Image_Payload_Preview_Complete := False;
      Batch.Last_Image_Encoded_Preview_Length := 0;
      Batch.Last_Image_Decoded_Preview_Length := 0;
      Batch.Last_Image_Decoded_Source := RM.Image_Decoded_Source_None;
      Batch.Last_Image_Row_Source := (others => <>);
      Batch.Last_Image_Decoded_Row_Stride_Bytes := 0;
      Batch.Last_Image_Preview_Decode_Complete := False;
      Batch.Last_Image_Decode_Status := RM.Image_Decode_Not_Attempted;
      Batch.Last_Image_Placeholder := False;
      Batch.Last_Image_Texture_Downgraded := False;
      Batch.Last_Image_Texture_Source := Texture_None;
      Batch.Text_Run_Total := 0;
      Batch.Shaped_Glyph_Total := 0;
      Batch.Frame_Width := 0;
      Batch.Frame_Height := 0;
      Batch.Uses_Text_Atlas := False;
      Batch.Text_Atlas_Width := 0;
      Batch.Text_Atlas_Height := 0;
      Batch.Text_Atlas_Pixels := System.Null_Address;
      Batch.Text_Atlas_Bytes := 0;
      Batch.Dirty_Atlas := False;
   end Reset;

   procedure Release (Batch : in out Submission_Batch) is
   begin
      Reset (Batch);
      if Batch.Items /= null then
         Free_Vertices (Batch.Items);
      end if;
      if Batch.Text_Runs /= null then
         Free_Text_Runs (Batch.Text_Runs);
      end if;
      if Batch.Image_Atlas_Sources /= null then
         Free_Image_Atlas_Sources (Batch.Image_Atlas_Sources);
      end if;
      if Batch.Image_Order /= null then
         Free_Image_Order (Batch.Image_Order);
      end if;
   end Release;

   function Grown_Capacity
     (Current  : Natural;
      Required : Positive) return Positive
   is
   begin
      if Current >= Required then
         return Positive (Current);
      elsif Current = 0 then
         return Required;
      elsif Current <= Natural'Last / 2 then
         return Positive'Max (Required, Positive (Current * 2));
      else
         return Required;
      end if;
   end Grown_Capacity;

   procedure Set_Image_Atlas_Limits
     (Batch  : in out Submission_Batch;
      Limits : Image_Atlas_Limits) is
   begin
      Batch.Image_Atlas_Limit_Value := Limits;
   end Set_Image_Atlas_Limits;

   function Image_Atlas_Limit
     (Batch : Submission_Batch) return Image_Atlas_Limits is
     (Batch.Image_Atlas_Limit_Value);

   overriding procedure Finalize (Batch : in out Submission_Batch) is
   begin
      Release (Batch);
   end Finalize;

   function Colour_Atlas_Width (Batch : Submission_Batch) return Natural is
     (Batch.Colour_Atlas_W);

   function Colour_Atlas_Height (Batch : Submission_Batch) return Natural is
     (Batch.Colour_Atlas_H);

   function Colour_Atlas_Bytes (Batch : Submission_Batch) return Natural is
     (Batch.Colour_Atlas_Byte_Count);

   function Colour_Atlas_Pixels (Batch : Submission_Batch) return System.Address is
     (Batch.Colour_Sheet_Source);

   function Colour_Atlas_Dirty (Batch : Submission_Batch) return Boolean is
     (Batch.Dirty_Colour_Atlas);

   function Colour_Glyph_Vertex_Count (Batch : Submission_Batch) return Natural is
     (Batch.Colour_Glyph_Vertex_Total);

   --  Draw this frame's colour glyphs from the sheet Textrender packed.
   --
   --  There used to be a shelf packer here, and a map of which codepoint had
   --  already been packed. Both duplicated what Textrender does when it decodes
   --  a glyph: it caches by codepoint and hands out the rectangle it used.
   procedure Append_Colour_Glyphs
     (Frame : RM.Frame_Commands;
      Batch : in out Submission_Batch);

   procedure Append_Colour_Glyphs
     (Frame : RM.Frame_Commands;
      Batch : in out Submission_Batch) is
   begin
      if Frame.Colour_Glyphs = null or else Frame.Colour_Glyph_Count = 0 then
         return;
      end if;

      for Index in 1 .. Frame.Colour_Glyph_Count loop
         declare
            Tile : RM.Colour_Glyph_Command renames Frame.Colour_Glyphs (Index);
            Before : constant Natural := Batch.Count;
         begin
            if Tile.Width > 0 and then Tile.Height > 0 then
               Append_Quad
                 (Batch,
                  Frame.Width,
                  Frame.Height,
                  Tile.X,
                  Tile.Y,
                  Float (Tile.Width),
                  Float (Tile.Height),
                  Tile.U0,
                  Tile.V0,
                  Tile.U1,
                  Tile.V1,
                  (R => 1.0, G => 1.0, B => 1.0, A => 1.0),
                  True,
                  Texture_Colour_Glyphs);
               Batch.Colour_Glyph_Vertex_Total :=
                 Batch.Colour_Glyph_Vertex_Total + (Batch.Count - Before);
            end if;
         end;
      end loop;
   end Append_Colour_Glyphs;

   procedure Build
     (Frame  : RM.Frame_Commands;
      Batch  : in out Submission_Batch;
      Status : out Build_Status)
   is
      Max_Vertices : Natural;

      function Texture_Eligible (Image : RM.Image_Command) return Boolean is
         Bytes_Per_Pixel : constant Natural :=
           (if Image.Raw_Format = 24 then 3
            elsif Image.Raw_Format = 32 then 4
            else 0);
         Row_Bytes : constant Natural :=
           (if Bytes_Per_Pixel > 0
              and then Image.Pixel_Width <= Natural'Last / Bytes_Per_Pixel
            then Image.Pixel_Width * Bytes_Per_Pixel
            else 0);
         Row_Stride_Bytes : constant Natural :=
           (if Image.Decoded_Row_Stride_Bytes > 0
            then Image.Decoded_Row_Stride_Bytes
            else Row_Bytes);
      begin
         return not Image.Placeholder
           and then
             (Image.Protocol = RM.Image_Kitty
              or else Image.Protocol = RM.Image_Sixel
              or else Image.Protocol = RM.Image_ITerm2)
           and then Image.Pixel_Width > 0
           and then Image.Pixel_Height > 0
           and then Bytes_Per_Pixel > 0
           and then Row_Bytes > 0
           and then Image.Payload_Preview_Complete
           and then Image.Preview_Decode_Complete
           and then Image.Decode_Status = RM.Image_Decode_Ok
           and then Row_Stride_Bytes >= Row_Bytes
           and then RM.Image_Decoded_Source_Bytes (Image) > 0
           and then RM.Image_Decoded_Source_Available (Image);
      end Texture_Eligible;

      function Same_Source
        (Left  : RM.Image_Command;
         Right : RM.Image_Command) return Boolean
      is
      begin
         if Left.Decoded_Source /= Right.Decoded_Source
           or else Left.Raw_Format /= Right.Raw_Format
           or else Left.Pixel_Width /= Right.Pixel_Width
           or else Left.Pixel_Height /= Right.Pixel_Height
           or else Left.Decoded_Row_Stride_Bytes /=
             Right.Decoded_Row_Stride_Bytes
           or else Left.Decoded_Byte_Length /= Right.Decoded_Byte_Length
         then
            return False;
         end if;

         case Left.Decoded_Source is
            when RM.Image_Decoded_Source_Buffer =>
               return Left.Decoded_Bytes /= null
                 and then Left.Decoded_Bytes = Right.Decoded_Bytes;
            when RM.Image_Decoded_Source_Raw_Base64 |
                 RM.Image_Decoded_Source_PNG_Base64 |
                 RM.Image_Decoded_Source_Sixel_Text =>
               return Left.Encoded_Source_Bytes /= null
                 and then Left.Encoded_Source_Bytes = Right.Encoded_Source_Bytes
                 and then Left.Encoded_Source_Length =
                   Right.Encoded_Source_Length;
            when RM.Image_Decoded_Source_None =>
               return False;
         end case;
      end Same_Source;

      function Atlas_Source_Index (Image : RM.Image_Command) return Natural is
      begin
         if Batch.Image_Atlas_Sources = null then
            return 0;
         end if;
         for I in 1 .. Batch.Image_Atlas_Source_Total loop
            if Same_Source (Image, Batch.Image_Atlas_Sources (I).Command) then
               return I;
            end if;
         end loop;
         return 0;
      end Atlas_Source_Index;

      procedure Prepare_Image_Atlas is
         Width  : Natural := 0;
         Height : Natural := 0;
         Max_Source_Dimension : Natural := 1;
         Scale_Divisor : Positive := 1;
         Packed : Boolean := False;

         function Scaled
           (Value   : Positive;
            Divisor : Positive) return Positive is
           (1 + (Value - 1) / Divisor);

         function Try_Layout (Divisor : Positive) return Boolean is
            Candidate_Width  : Natural := 0;
            Candidate_Height : Natural := 0;
            Target_Width     : Positive;
            Target_Height    : Positive;
         begin
            for I in 1 .. Batch.Image_Atlas_Source_Total loop
               Target_Width := Scaled
                 (Batch.Image_Atlas_Sources (I).Command.Pixel_Width,
                  Divisor);
               Target_Height := Scaled
                 (Batch.Image_Atlas_Sources (I).Command.Pixel_Height,
                  Divisor);
               if Target_Width > Batch.Image_Atlas_Limit_Value.Dimension - 2
                 or else Target_Height >
                   Batch.Image_Atlas_Limit_Value.Dimension - 2
                 or else Candidate_Height >
                   Batch.Image_Atlas_Limit_Value.Dimension
                     - (Target_Height + 2)
               then
                  return False;
               end if;
               Batch.Image_Atlas_Sources (I).X := 1;
               Batch.Image_Atlas_Sources (I).Y := Candidate_Height + 1;
               Batch.Image_Atlas_Sources (I).Width := Target_Width;
               Batch.Image_Atlas_Sources (I).Height := Target_Height;
               Candidate_Width := Natural'Max
                 (Candidate_Width, Target_Width + 2);
               Candidate_Height := Candidate_Height + Target_Height + 2;
            end loop;

            if Candidate_Width = 0
              or else Candidate_Height = 0
              or else Candidate_Width >
                Batch.Image_Atlas_Limit_Value.Bytes / 4
              or else Candidate_Height >
                Batch.Image_Atlas_Limit_Value.Bytes /
                  (Candidate_Width * 4)
            then
               return False;
            end if;
            Width := Candidate_Width;
            Height := Candidate_Height;
            return True;
         end Try_Layout;
      begin
         if Frame.Image_Count = 0
           or else Batch.Image_Atlas_Limit_Value.Dimension <= 2
         then
            return;
         end if;

         declare
            Required : constant Positive := Positive
              (Natural'Min (Frame.Image_Count, Max_Image_Atlas_Sources));
         begin
            if Batch.Image_Atlas_Sources = null
              or else Batch.Image_Atlas_Sources'Length < Required
            then
               declare
                  Replacement : Image_Atlas_Source_Array_Access :=
                    new Image_Atlas_Source_Array
                      (1 .. Grown_Capacity
                        ((if Batch.Image_Atlas_Sources = null
                          then 0
                          else Batch.Image_Atlas_Sources'Length),
                         Required));
               begin
                  if Batch.Image_Atlas_Sources /= null then
                     Free_Image_Atlas_Sources (Batch.Image_Atlas_Sources);
                  end if;
                  Batch.Image_Atlas_Sources := Replacement;
               end;
            end if;
         end;
         for I in 1 .. Frame.Image_Count loop
            if Texture_Eligible (Frame.Images (I))
              and then Atlas_Source_Index (Frame.Images (I)) = 0
              and then Batch.Image_Atlas_Source_Total <
                Max_Image_Atlas_Sources
            then
               Batch.Image_Atlas_Source_Total :=
                 Batch.Image_Atlas_Source_Total + 1;
               Batch.Image_Atlas_Sources (Batch.Image_Atlas_Source_Total) :=
                 (Command => Frame.Images (I),
                  others  => <>);
               Max_Source_Dimension := Natural'Max
                 (Max_Source_Dimension,
                  Natural'Max
                    (Frame.Images (I).Pixel_Width,
                     Frame.Images (I).Pixel_Height));
            end if;
         end loop;

         if Batch.Image_Atlas_Source_Total = 0 then
            return;
         end if;

         --  The backend has one image descriptor for a frame. Keep the bounded
         --  source set in that atlas and reduce its stored resolution when the
         --  configured GPU budget cannot hold full-resolution copies. Sources
         --  beyond the descriptor bound are downgraded individually instead
         --  of invalidating textures already admitted to the atlas.
         loop
            Packed := Try_Layout (Scale_Divisor);
            exit when Packed or else Scale_Divisor >= Max_Source_Dimension;
            if Scale_Divisor > Max_Source_Dimension / 2 then
               Scale_Divisor := Positive (Max_Source_Dimension);
            else
               Scale_Divisor := Scale_Divisor * 2;
            end if;
         end loop;
         if not Packed then
            Batch.Image_Atlas_Source_Total := 0;
            return;
         end if;

         Batch.Image_Atlas_W := Width;
         Batch.Image_Atlas_H := Height;
         Batch.Image_Atlas_Byte_Count := Width * Height * 4;
         declare
            Signature : Interfaces.Unsigned_64 := 16#CBF29CE484222325#;

            procedure Mix (Value : Interfaces.Unsigned_64) is
            begin
               Signature :=
                 (Signature xor Value) * Interfaces.Unsigned_64'(16#100000001B3#);
            end Mix;
         begin
            Mix (Interfaces.Unsigned_64 (Width));
            Mix (Interfaces.Unsigned_64 (Height));
            Mix (Interfaces.Unsigned_64 (Batch.Image_Atlas_Source_Total));
            for I in 1 .. Batch.Image_Atlas_Source_Total loop
               declare
                  Source : constant Image_Atlas_Source :=
                    Batch.Image_Atlas_Sources (I);
               begin
                  Mix (Source.Command.Content_Serial);
                  Mix (Interfaces.Unsigned_64 (Source.Command.Image_ID));
                  Mix (Interfaces.Unsigned_64 (Source.Command.Pixel_Width));
                  Mix (Interfaces.Unsigned_64 (Source.Command.Pixel_Height));
                  Mix (Interfaces.Unsigned_64 (Source.Command.Raw_Format));
                  Mix
                    (Interfaces.Unsigned_64
                       (Source.Command.Decoded_Byte_Length));
                  Mix (Interfaces.Unsigned_64 (Source.X));
                  Mix (Interfaces.Unsigned_64 (Source.Y));
                  Mix (Interfaces.Unsigned_64 (Source.Width));
                  Mix (Interfaces.Unsigned_64 (Source.Height));
               end;
            end loop;
            --  Zero means "not cacheable" in the Vulkan device.
            Batch.Image_Atlas_Content_Signature :=
              (if Signature = 0 then 1 else Signature);
         end;
      end Prepare_Image_Atlas;

      procedure Append_Image_Command (Image : RM.Image_Command) is
         Before : constant Natural := Batch.Count;
         Bytes_Per_Pixel : constant Natural :=
           (if Image.Raw_Format = 24 then 3
            elsif Image.Raw_Format = 32 then 4
            else 0);
         Row_Bytes : constant Natural := Image.Pixel_Width * Bytes_Per_Pixel;
         Row_Stride_Bytes : constant Natural :=
           (if Image.Decoded_Row_Stride_Bytes > 0
            then Image.Decoded_Row_Stride_Bytes
            else Row_Bytes);
         Required_Decoded_Bytes : constant Natural :=
           RM.Image_Decoded_Source_Bytes (Image);
         Atlas_Index : constant Natural := Atlas_Source_Index (Image);
         Image_Texture_Eligible : constant Boolean :=
           Texture_Eligible (Image) and then Atlas_Index > 0;
         Source : constant Texture_Source :=
           (if Image_Texture_Eligible then Texture_Image else Texture_None);
         Atlas_U0 : Float := Image.U0;
         Atlas_V0 : Float := Image.V0;
         Atlas_U1 : Float := Image.U1;
         Atlas_V1 : Float := Image.V1;
      begin
         if Image_Texture_Eligible then
            Atlas_U0 :=
              (Float (Batch.Image_Atlas_Sources (Atlas_Index).X)
               + Image.U0
                 * Float (Batch.Image_Atlas_Sources (Atlas_Index).Width)) /
              Float (Batch.Image_Atlas_W);
            Atlas_U1 :=
              (Float (Batch.Image_Atlas_Sources (Atlas_Index).X)
               + Image.U1
                 * Float (Batch.Image_Atlas_Sources (Atlas_Index).Width)) /
              Float (Batch.Image_Atlas_W);
            Atlas_V0 :=
              (Float (Batch.Image_Atlas_Sources (Atlas_Index).Y)
               + Image.V0
                 * Float (Batch.Image_Atlas_Sources (Atlas_Index).Height)) /
              Float (Batch.Image_Atlas_H);
            Atlas_V1 :=
              (Float (Batch.Image_Atlas_Sources (Atlas_Index).Y)
               + Image.V1
                 * Float (Batch.Image_Atlas_Sources (Atlas_Index).Height)) /
              Float (Batch.Image_Atlas_H);
         end if;
         Batch.Image_Command_Total := Batch.Image_Command_Total + 1;
         Batch.Last_Image_Protocol := Image.Protocol;
         Batch.Last_Image_Width := Natural (Image.Width);
         Batch.Last_Image_Height := Natural (Image.Height);
         Batch.Last_Image_Raw_Format := Image.Raw_Format;
         Batch.Last_Image_Pixel_Width := Image.Pixel_Width;
         Batch.Last_Image_Pixel_Height := Image.Pixel_Height;
         Batch.Last_Image_Payload_Length := Image.Payload_Length;
         Batch.Last_Image_Payload_Preview_Complete :=
           Image.Payload_Preview_Complete;
         Batch.Last_Image_Encoded_Preview_Length :=
           Image.Encoded_Preview_Length;
         Batch.Last_Image_Decoded_Preview_Length :=
           Image.Decoded_Preview_Length;
         Batch.Last_Image_Decoded_Source :=
           (if Image_Texture_Eligible
            then Image.Decoded_Source
            else RM.Image_Decoded_Source_None);
         Batch.Last_Image_Row_Source := Image;
         Batch.Last_Image_Decoded_Row_Stride_Bytes :=
           (if Image_Texture_Eligible then Row_Stride_Bytes else 0);
         Batch.Last_Image_Preview_Decode_Complete :=
           Image.Preview_Decode_Complete;
         Batch.Last_Image_Decode_Status := Image.Decode_Status;
         Batch.Last_Image_Placeholder := not Image_Texture_Eligible;
         Batch.Last_Image_Texture_Downgraded :=
           not Image.Placeholder and then not Image_Texture_Eligible;
         Batch.Last_Image_Texture_Source := Source;
         Append_Quad
           (Batch,
            Frame.Width,
            Frame.Height,
            Image.X,
            Image.Y,
            Image.Width,
            Image.Height,
            Atlas_U0,
            Atlas_V0,
            Atlas_U1,
            Atlas_V1,
            Image.Tint,
            Source = Texture_Image,
            Source);
         Batch.Image_Vertex_Total :=
           Batch.Image_Vertex_Total + (Batch.Count - Before);
         if Batch.Last_Image_Texture_Source = Texture_Image then
            Batch.Image_Texture_Vertex_Total :=
              Batch.Image_Texture_Vertex_Total + (Batch.Count - Before);
         end if;
      end Append_Image_Command;

      type Image_Layer is
        (Image_Below_Cell_Background,
         Image_Below_Text,
         Image_Above_Text);

      Deep_Image_Threshold : constant Integer := -1_073_741_824;

      function In_Image_Layer
        (Image : RM.Image_Command;
         Layer : Image_Layer) return Boolean is
        (case Layer is
            when Image_Below_Cell_Background =>
              Image.Z_Index < Deep_Image_Threshold,
            when Image_Below_Text =>
              Image.Z_Index >= Deep_Image_Threshold
              and then Image.Z_Index < 0,
            when Image_Above_Text =>
              Image.Z_Index >= 0);

      function Image_Index_Less
        (Left  : Positive;
         Right : Positive) return Boolean
      is
         Left_Image  : RM.Image_Command renames Frame.Images (Left);
         Right_Image : RM.Image_Command renames Frame.Images (Right);
      begin
         return Left_Image.Z_Index < Right_Image.Z_Index
           or else
             (Left_Image.Z_Index = Right_Image.Z_Index
              and then
                (Left_Image.Image_ID < Right_Image.Image_ID
                 or else
                   (Left_Image.Image_ID = Right_Image.Image_ID
                    and then Left < Right)));
      end Image_Index_Less;

      procedure Sort_Image_Order is new Ada.Containers.Generic_Array_Sort
        (Index_Type   => Positive,
         Element_Type => Positive,
         Array_Type   => Image_Order_Array,
         "<"          => Image_Index_Less);

      procedure Prepare_Image_Order is
      begin
         if Frame.Image_Count = 0 then
            return;
         end if;

         if Batch.Image_Order = null
           or else Batch.Image_Order'Length < Frame.Image_Count
         then
            declare
               Replacement : Image_Order_Array_Access :=
                 new Image_Order_Array
                   (1 .. Grown_Capacity
                     ((if Batch.Image_Order = null
                       then 0
                       else Batch.Image_Order'Length),
                      Positive (Frame.Image_Count)));
            begin
               if Batch.Image_Order /= null then
                  Free_Image_Order (Batch.Image_Order);
               end if;
               Batch.Image_Order := Replacement;
            end;
         end if;

         for I in 1 .. Frame.Image_Count loop
            Batch.Image_Order (I) := I;
         end loop;
         Batch.Image_Order_Total := Frame.Image_Count;
         if Frame.Image_Count > 1 then
            Sort_Image_Order
              (Batch.Image_Order (1 .. Batch.Image_Order_Total));
         end if;
      end Prepare_Image_Order;

      procedure Append_Image_Layer (Layer : Image_Layer) is
      begin
         for Position in 1 .. Batch.Image_Order_Total loop
            declare
               Image_Index : constant Positive :=
                 Batch.Image_Order (Position);
            begin
               if In_Image_Layer (Frame.Images (Image_Index), Layer) then
                  Append_Image_Command (Frame.Images (Image_Index));
               end if;
            end;
         end loop;
      end Append_Image_Layer;

      procedure Append_Rectangle_Layer (Layer : RM.Rectangle_Layer) is
      begin
         for I in 1 .. Frame.Rectangle_Count loop
            if Frame.Rectangles (I).Layer = Layer then
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
            end if;
         end loop;
      end Append_Rectangle_Layer;
   begin
      Reset (Batch);

      if Frame.Width = 0
        or else Frame.Height = 0
        or else (Frame.Rectangle_Count > 0 and then Frame.Rectangles = null)
        or else (Frame.Glyph_Count > 0 and then Frame.Glyphs = null)
        or else (Frame.Image_Count > 0 and then Frame.Images = null)
        or else (Frame.Text_Run_Count > 0 and then Frame.Text_Runs = null)
      then
         Status := Invalid_Frame;
         return;
      end if;

      Max_Vertices :=
        (Frame.Rectangle_Count + Frame.Glyph_Count + Frame.Image_Count
         + Frame.Colour_Glyph_Count) * 6;
      if Max_Vertices = 0 then
         Batch.Frame_Width := Frame.Width;
         Batch.Frame_Height := Frame.Height;
         Batch.Text_Atlas_Width := Frame.Atlas_Width;
         Batch.Text_Atlas_Height := Frame.Atlas_Height;
         Batch.Text_Atlas_Pixels := Frame.Atlas_Pixels;
         Batch.Text_Atlas_Bytes := Frame.Atlas_Bytes;
         Batch.Dirty_Atlas := Frame.Atlas_Dirty;
         if Frame.Text_Run_Count > 0 then
            if Batch.Text_Runs = null
              or else Batch.Text_Runs'Length < Frame.Text_Run_Count
            then
               declare
                  Replacement : RM.Text_Run_Array_Access :=
                    new RM.Text_Run_Array
                      (1 .. Grown_Capacity
                        ((if Batch.Text_Runs = null
                          then 0
                          else Batch.Text_Runs'Length),
                         Positive (Frame.Text_Run_Count)));
               begin
                  if Batch.Text_Runs /= null then
                     Free_Text_Runs (Batch.Text_Runs);
                  end if;
                  Batch.Text_Runs := Replacement;
               end;
            end if;
            for I in 1 .. Frame.Text_Run_Count loop
               Batch.Text_Runs (I) := Frame.Text_Runs (I);
               Batch.Shaped_Glyph_Total :=
                 Batch.Shaped_Glyph_Total
                 + Natural (Frame.Text_Runs (I).Shaped_Glyph_Count);
            end loop;
            Batch.Text_Run_Total := Frame.Text_Run_Count;
         end if;
         Status := Ok;
         return;
      end if;

      if Batch.Items = null or else Batch.Items'Length < Max_Vertices then
         declare
            Replacement : Vertex_Array_Access :=
              new Vertex_Array
                (1 .. Grown_Capacity
                  ((if Batch.Items = null then 0 else Batch.Items'Length),
                   Positive (Max_Vertices)));
         begin
            if Batch.Items /= null then
               Free_Vertices (Batch.Items);
            end if;
            Batch.Items := Replacement;
         end;
      end if;
      if Frame.Text_Run_Count > 0 then
         if Batch.Text_Runs = null
           or else Batch.Text_Runs'Length < Frame.Text_Run_Count
         then
            declare
               Replacement : RM.Text_Run_Array_Access :=
                 new RM.Text_Run_Array
                   (1 .. Grown_Capacity
                     ((if Batch.Text_Runs = null
                       then 0
                       else Batch.Text_Runs'Length),
                      Positive (Frame.Text_Run_Count)));
            begin
               if Batch.Text_Runs /= null then
                  Free_Text_Runs (Batch.Text_Runs);
               end if;
               Batch.Text_Runs := Replacement;
            end;
         end if;
         for I in 1 .. Frame.Text_Run_Count loop
            Batch.Text_Runs (I) := Frame.Text_Runs (I);
            Batch.Shaped_Glyph_Total :=
              Batch.Shaped_Glyph_Total
              + Natural (Frame.Text_Runs (I).Shaped_Glyph_Count);
         end loop;
         Batch.Text_Run_Total := Frame.Text_Run_Count;
      end if;
      Batch.Frame_Width := Frame.Width;
      Batch.Frame_Height := Frame.Height;
      Batch.Text_Atlas_Width := Frame.Atlas_Width;
      Batch.Text_Atlas_Height := Frame.Atlas_Height;
      Batch.Text_Atlas_Pixels := Frame.Atlas_Pixels;
      Batch.Text_Atlas_Bytes := Frame.Atlas_Bytes;
      Batch.Dirty_Atlas := Frame.Atlas_Dirty;
      Prepare_Image_Order;
      Prepare_Image_Atlas;

      Append_Rectangle_Layer (RM.Rectangle_Base_Background);
      Append_Image_Layer (Image_Below_Cell_Background);
      Append_Rectangle_Layer (RM.Rectangle_Cell_Background);
      Append_Image_Layer (Image_Below_Text);
      Append_Rectangle_Layer (RM.Rectangle_Foreground);

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

      --  After the outlines, so an emoji sits over the cell background rather
      --  than under it. Unconditional: colour glyphs have a texture of their own,
      --  so an inline picture in the same frame does not displace them.
      Batch.Colour_Atlas_W := Frame.Colour_Sheet_Width;
      Batch.Colour_Atlas_H := Frame.Colour_Sheet_Height;
      Batch.Colour_Atlas_Byte_Count :=
        (if Frame.Colour_Sheet_Pixels = System.Null_Address then 0
         else Frame.Colour_Sheet_Width * Frame.Colour_Sheet_Height * 4);
      Batch.Colour_Sheet_Source := Frame.Colour_Sheet_Pixels;
      Batch.Dirty_Colour_Atlas := Frame.Colour_Sheet_Dirty;

      Append_Colour_Glyphs (Frame, Batch);

      --  Kitty reserves the range below INT32_MIN / 2 for images below
      --  non-default cell backgrounds. Other negative images remain below
      --  text, and non-negative images are above it. Each layer is emitted in
      --  ascending z-index order, then by ascending image ID.
      Append_Image_Layer (Image_Above_Text);

      --  Diagnostics need one bounded prefix, not one copy per image tile.
      --  Last_Image_Row_Source is a compact borrowed descriptor and remains
      --  valid through presentation of this batch.
      for I in 1 .. Natural'Min
        (Batch.Last_Image_Decoded_Preview_Length,
         RM.Max_Image_Decoded_Preview_Length)
      loop
         Batch.Last_Image_Decoded_Preview_Bytes (I) :=
           RM.Image_Decoded_Preview_Byte (Batch.Last_Image_Row_Source, I);
      end loop;
      if Batch.Last_Image_Texture_Source /= Texture_Image then
         Batch.Last_Image_Row_Source := (others => <>);
      end if;


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

   function Image_Vertex_Count (Batch : Submission_Batch) return Natural is
     (Batch.Image_Vertex_Total);

   function Image_Texture_Vertex_Count
     (Batch : Submission_Batch) return Natural is
     (Batch.Image_Texture_Vertex_Total);

   function Image_Command_Count (Batch : Submission_Batch) return Natural is
     (Batch.Image_Command_Total);

   function Image_Atlas_Width (Batch : Submission_Batch) return Natural is
     (Batch.Image_Atlas_W);

   function Image_Atlas_Height (Batch : Submission_Batch) return Natural is
     (Batch.Image_Atlas_H);

   function Image_Atlas_Bytes (Batch : Submission_Batch) return Natural is
     (Batch.Image_Atlas_Byte_Count);

   function Image_Atlas_Signature
     (Batch : Submission_Batch) return Interfaces.Unsigned_64 is
     (Batch.Image_Atlas_Content_Signature);

   function Image_Atlas_Source_Count (Batch : Submission_Batch) return Natural is
     (Batch.Image_Atlas_Source_Total);

   function Image_Atlas_Source_Command
     (Batch : Submission_Batch;
      Index : Positive) return RM.Image_Command is
   begin
      if Batch.Image_Atlas_Sources = null
        or else Index > Batch.Image_Atlas_Source_Total
      then
         return (others => <>);
      end if;
      return Batch.Image_Atlas_Sources (Index).Command;
   end Image_Atlas_Source_Command;

   function Image_Atlas_Source_X
     (Batch : Submission_Batch;
      Index : Positive) return Natural is
   begin
      if Batch.Image_Atlas_Sources = null
        or else Index > Batch.Image_Atlas_Source_Total
      then
         return 0;
      end if;
      return Batch.Image_Atlas_Sources (Index).X;
   end Image_Atlas_Source_X;

   function Image_Atlas_Source_Y
     (Batch : Submission_Batch;
      Index : Positive) return Natural is
   begin
      if Batch.Image_Atlas_Sources = null
        or else Index > Batch.Image_Atlas_Source_Total
      then
         return 0;
      end if;
      return Batch.Image_Atlas_Sources (Index).Y;
   end Image_Atlas_Source_Y;

   function Image_Atlas_Source_Width
     (Batch : Submission_Batch;
      Index : Positive) return Natural is
   begin
      if Batch.Image_Atlas_Sources = null
        or else Index > Batch.Image_Atlas_Source_Total
      then
         return 0;
      end if;
      return Batch.Image_Atlas_Sources (Index).Width;
   end Image_Atlas_Source_Width;

   function Image_Atlas_Source_Height
     (Batch : Submission_Batch;
      Index : Positive) return Natural is
   begin
      if Batch.Image_Atlas_Sources = null
        or else Index > Batch.Image_Atlas_Source_Total
      then
         return 0;
      end if;
      return Batch.Image_Atlas_Sources (Index).Height;
   end Image_Atlas_Source_Height;

   function Last_Image_Protocol
     (Batch : Submission_Batch) return RM.Image_Protocol is
     (Batch.Last_Image_Protocol);

   function Last_Image_Width (Batch : Submission_Batch) return Natural is
     (Batch.Last_Image_Width);

   function Last_Image_Height (Batch : Submission_Batch) return Natural is
     (Batch.Last_Image_Height);

   function Last_Image_Raw_Format (Batch : Submission_Batch) return Natural is
     (Batch.Last_Image_Raw_Format);

   function Last_Image_Pixel_Width (Batch : Submission_Batch) return Natural is
     (Batch.Last_Image_Pixel_Width);

   function Last_Image_Pixel_Height (Batch : Submission_Batch) return Natural is
     (Batch.Last_Image_Pixel_Height);

   function Last_Image_Payload_Length (Batch : Submission_Batch) return Natural is
     (Batch.Last_Image_Payload_Length);

   function Last_Image_Payload_Preview_Complete
     (Batch : Submission_Batch) return Boolean is
     (Batch.Last_Image_Payload_Preview_Complete);

   function Last_Image_Encoded_Preview_Length
     (Batch : Submission_Batch) return Natural is
     (Batch.Last_Image_Encoded_Preview_Length);

   function Last_Image_Decoded_Preview_Length
     (Batch : Submission_Batch) return Natural is
     (Batch.Last_Image_Decoded_Preview_Length);

   function Last_Image_Decoded_Preview_Byte
     (Batch : Submission_Batch;
      Index : Positive) return Terminal.Common.Bytes.Byte
   is
   begin
      if Index > Batch.Last_Image_Decoded_Preview_Length
        or else Index > RM.Max_Image_Decoded_Preview_Length
      then
         return 0;
      else
         return Batch.Last_Image_Decoded_Preview_Bytes (Index);
      end if;
   end Last_Image_Decoded_Preview_Byte;

   function Last_Image_Decoded_Data_Byte
     (Batch : Submission_Batch;
      Index : Positive) return Terminal.Common.Bytes.Byte
   is
      Source_Bytes : constant Natural := Last_Image_Decoded_Source_Bytes (Batch);
      Row_Stride : constant Natural := Batch.Last_Image_Decoded_Row_Stride_Bytes;
      Zero_Based : constant Natural := Index - 1;
   begin
      if Source_Bytes = 0
        or else Row_Stride = 0
        or else Index > Source_Bytes
      then
         return 0;
      end if;

      return Last_Image_Decoded_Row_Byte
        (Batch,
         Zero_Based / Row_Stride,
         Zero_Based mod Row_Stride);
   end Last_Image_Decoded_Data_Byte;

   function Last_Image_Decoded_Source
     (Batch : Submission_Batch) return RM.Image_Decoded_Source_Kind is
     (Batch.Last_Image_Decoded_Source);

   function Last_Image_Source_Command
     (Batch : Submission_Batch) return RM.Image_Command is
     (Batch.Last_Image_Row_Source);

   function Last_Image_Decoded_Source_Bytes
     (Batch : Submission_Batch) return Natural
   is
     (if Batch.Last_Image_Texture_Source = Texture_Image
      then RM.Image_Decoded_Source_Bytes (Batch.Last_Image_Row_Source)
      else 0);

   function Last_Image_Decoded_Source_Available
     (Batch : Submission_Batch) return Boolean
   is
     (Batch.Last_Image_Texture_Source = Texture_Image
      and then RM.Image_Decoded_Source_Available (Batch.Last_Image_Row_Source));

   function Last_Image_Decoded_Row_Byte
     (Batch       : Submission_Batch;
      Row         : Natural;
      Byte_Offset : Natural) return Terminal.Common.Bytes.Byte
   is
   begin
      if Batch.Last_Image_Texture_Source /= Texture_Image then
         return 0;
      end if;
      return RM.Image_Decoded_Row_Byte
        (Batch.Last_Image_Row_Source, Row, Byte_Offset);
   end Last_Image_Decoded_Row_Byte;

   function Last_Image_Decoded_Row_Stride_Bytes
     (Batch : Submission_Batch) return Natural is
     (Batch.Last_Image_Decoded_Row_Stride_Bytes);

   function Last_Image_Preview_Decode_Complete
     (Batch : Submission_Batch) return Boolean is
     (Batch.Last_Image_Preview_Decode_Complete);

   function Last_Image_Decode_Status
     (Batch : Submission_Batch)
      return RM.Image_Decode_Status is
     (Batch.Last_Image_Decode_Status);

   function Last_Image_Placeholder (Batch : Submission_Batch) return Boolean is
     (Batch.Last_Image_Placeholder);

   function Last_Image_Texture_Downgraded
     (Batch : Submission_Batch) return Boolean is
     (Batch.Last_Image_Texture_Downgraded);

   function Last_Image_Texture_Source
     (Batch : Submission_Batch) return Texture_Source is
     (Batch.Last_Image_Texture_Source);

   function Image_Status_Label (Batch : Submission_Batch) return String
   is
      function Protocol_Name return String is
      begin
         case Batch.Last_Image_Protocol is
            when RM.Image_Sixel =>
               return "sixel";
            when RM.Image_Kitty =>
               return "kitty";
            when RM.Image_ITerm2 =>
               return "iTerm2";
         end case;
      end Protocol_Name;
   begin
      if Batch.Image_Command_Total = 0 then
         return "";
      end if;

      return
        "submit image " & Protocol_Name
        & " size=" & Trimmed_Natural (Batch.Last_Image_Width)
        & "x" & Trimmed_Natural (Batch.Last_Image_Height)
        & (if Batch.Last_Image_Pixel_Width > 0
           and then Batch.Last_Image_Pixel_Height > 0
           then
             " pixels=" & Trimmed_Natural (Batch.Last_Image_Pixel_Width)
             & "x" & Trimmed_Natural (Batch.Last_Image_Pixel_Height)
             & " format=" & Trimmed_Natural (Batch.Last_Image_Raw_Format)
           else "")
        & " payload=" & Trimmed_Natural (Batch.Last_Image_Payload_Length)
        & RM.Image_Payload_Status_Suffix
            (Batch.Last_Image_Payload_Preview_Complete)
        & " preview="
        & Trimmed_Natural (Batch.Last_Image_Decoded_Preview_Length)
        & "/"
        & Trimmed_Natural (Batch.Last_Image_Encoded_Preview_Length)
        & Terminal.Common.Status.Preview_Bytes_Label
            (Batch.Last_Image_Decoded_Preview_Bytes,
             Batch.Last_Image_Decoded_Preview_Length)
        & " texture=" & Texture_Source_Label (Batch.Last_Image_Texture_Source)
        & (if Batch.Last_Image_Placeholder then " placeholder" else " textured")
        & (if Batch.Last_Image_Texture_Downgraded then " downgraded" else "")
        & (if Batch.Last_Image_Preview_Decode_Complete
           then " decoded"
           else " partial")
        & RM.Image_Decode_Status_Suffix (Batch.Last_Image_Decode_Status);
   end Image_Status_Label;

   function Image_Texture_Status_Label
     (Batch : Submission_Batch) return String
   is
   begin
      if Batch.Image_Command_Total = 0 then
         return "";
      elsif Batch.Last_Image_Texture_Downgraded then
         return
           "submit image texture downgraded; texture="
           & Texture_Source_Label (Batch.Last_Image_Texture_Source)
           & " vertices=" & Trimmed_Natural (Batch.Image_Texture_Vertex_Total);
      elsif Batch.Last_Image_Texture_Source = Texture_Image
        and then not Batch.Last_Image_Placeholder
      then
         return
           "submit image texture ready; vertices="
           & Trimmed_Natural (Batch.Image_Texture_Vertex_Total);
      else
         return
           "submit image texture unavailable; texture="
           & Texture_Source_Label (Batch.Last_Image_Texture_Source)
           & " vertices=" & Trimmed_Natural (Batch.Image_Texture_Vertex_Total);
      end if;
   end Image_Texture_Status_Label;

   function Text_Runs
     (Batch : Submission_Batch)
      return RM.Text_Run_Array_Access is
     (Batch.Text_Runs);

   function Text_Run_Count (Batch : Submission_Batch) return Natural is
     (Batch.Text_Run_Total);

   function Shaped_Glyph_Count (Batch : Submission_Batch) return Natural is
     (Batch.Shaped_Glyph_Total);

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

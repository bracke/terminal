with Ada.Containers.Generic_Array_Sort;
with Ada.Unchecked_Deallocation;
with System.Address_To_Access_Conversions;
with System.Storage_Elements;

with Terminal.Common.Bytes;
with Terminal.App.Bounded_Append;
with Terminal.App.Vulkan_Submit.Diagnostics;
with Terminal.App.Vulkan_Submit.Source_Rows;
with Terminal.App.Vulkan_Submit.Validation;

package body Terminal.App.Vulkan_Submit is
   package RM renames Terminal.App.Render_Model;

   use type RM.Glyph_Array_Access;
   use type RM.Glyph_Array_View;
   use type RM.Image_Array_Access;
   use type RM.Image_Array_View;
   use type RM.Image_Data_View;
   use type RM.Image_Decode_Status;
   use type RM.Image_Decoded_Source_Kind;
   use type RM.Image_Protocol;
   use type RM.Rectangle_Array_Access;
   use type RM.Rectangle_Array_View;
   use type RM.Rectangle_Layer;
   use type RM.Text_Run_Array_Access;
   use type RM.Text_Run_Array_View;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;
   use type Vertex_Array_Access;
   use type Vertex_Array_View;

   function Status_Label (Status : Build_Status) return String
     renames Diagnostics.Status_Label;

   function Texture_Source_Label (Source : Texture_Source) return String
     renames Diagnostics.Texture_Source_Label;

   use type System.Address;
   use System.Storage_Elements;
   use type RM.Colour_Glyph_Array_Access;
   use type RM.Colour_Glyph_Array_View;

   procedure Free_Vertices is new Ada.Unchecked_Deallocation
     (Vertex_Array, Vertex_Array_Access);
   procedure Free_Text_Runs is new Ada.Unchecked_Deallocation
     (RM.Text_Run_Array, RM.Text_Run_Array_Access);
   procedure Free_Image_Atlas_Sources is new Ada.Unchecked_Deallocation
     (Image_Atlas_Source_Array, Image_Atlas_Source_Array_Access);
   procedure Free_Image_Order is new Ada.Unchecked_Deallocation
     (Image_Order_Array, Image_Order_Array_Access);

   procedure Append_Bounded_Vertex is new Terminal.App.Bounded_Append
     (Vertex, Vertex_Array, Vertex_Array_Access);

   package Byte_Addresses is new System.Address_To_Access_Conversions
     (Terminal.Common.Bytes.Byte);

   procedure Copy_Address
     (Source : System.Address;
      Length : Natural;
      Target : in out Terminal.App.Owned_Image_Data.Owner)
   is
      Replacement : Terminal.App.Owned_Image_Data.Owner;

      procedure Fill (Data : in out Terminal.Common.Bytes.Byte_Array) is
      begin
         for Offset in 0 .. Length - 1 loop
            Data (Data'First + Offset) := Byte_Addresses.To_Pointer
              (Source + System.Storage_Elements.Storage_Offset (Offset)).all;
         end loop;
      end Fill;
   begin
      if Length = 0 or else Source = System.Null_Address then
         Terminal.App.Owned_Image_Data.Release (Target);
         return;
      end if;
      Terminal.App.Owned_Image_Data.Allocate (Replacement, Positive (Length));
      Terminal.App.Owned_Image_Data.Modify (Replacement, Fill'Access);
      Terminal.App.Owned_Image_Data.Release (Target);
      Terminal.App.Owned_Image_Data.Move (Replacement, Target);
   end Copy_Address;

   procedure Release_Image_Source (Source : in out Image_Atlas_Source) is
   begin
      Terminal.App.Shared_Image_Data.Reset (Source.Decoded);
      Terminal.App.Shared_Image_Data.Reset (Source.Encoded);
      Terminal.App.Shared_Image_Data.Reset (Source.Preview);
      Source.Command := (others => <>);
      Source.Input_Decoded := null;
      Source.Input_Encoded := null;
      Source.X := 0;
      Source.Y := 0;
      Source.Width := 0;
      Source.Height := 0;
   end Release_Image_Source;

   function Source_View_Length
     (View : RM.Image_Data_View;
      Declared_Length : Natural) return Natural is
     (if View = null then 0
      else Natural'Min (Declared_Length, View'Length));

   function Image_Source_Copy_Bytes
     (Command : RM.Image_Command) return Natural
   is
      Decoded_Length : constant Natural := Source_View_Length
        (Command.Decoded_Bytes, Command.Decoded_Byte_Length);
      Encoded_Length : constant Natural := Source_View_Length
        (Command.Encoded_Source_Bytes, Command.Encoded_Source_Length);
      Preview_Length : constant Natural := Source_View_Length
        (Command.Decoded_Preview_Bytes, Command.Decoded_Preview_Length);
      Total : Natural := Decoded_Length;
   begin
      if Encoded_Length > 0
        and then not
          (Command.Encoded_Source_Bytes = Command.Decoded_Bytes
           and then Encoded_Length <= Decoded_Length)
      then
         if Encoded_Length > Natural'Last - Total then
            return Natural'Last;
         end if;
         Total := Total + Encoded_Length;
      end if;
      if Preview_Length > 0
        and then not
          ((Command.Decoded_Preview_Bytes = Command.Decoded_Bytes
            and then Preview_Length <= Decoded_Length)
           or else
             (Command.Decoded_Preview_Bytes = Command.Encoded_Source_Bytes
              and then Preview_Length <= Encoded_Length))
      then
         if Preview_Length > Natural'Last - Total then
            return Natural'Last;
         end if;
         Total := Total + Preview_Length;
      end if;
      return Total;
   end Image_Source_Copy_Bytes;

   procedure Own_Image_Source
     (Command : RM.Image_Command;
      Source  : in out Image_Atlas_Source)
   is
      Decoded_Length : constant Natural := Source_View_Length
        (Command.Decoded_Bytes, Command.Decoded_Byte_Length);
      Encoded_Length : constant Natural := Source_View_Length
        (Command.Encoded_Source_Bytes, Command.Encoded_Source_Length);
      Preview_Length : constant Natural := Source_View_Length
        (Command.Decoded_Preview_Bytes, Command.Decoded_Preview_Length);
   begin
      Release_Image_Source (Source);
      Source.Command := Command;
      Source.Input_Decoded := Command.Decoded_Bytes;
      Source.Input_Encoded := Command.Encoded_Source_Bytes;
      Terminal.App.Shared_Image_Data.Set
        (Source.Decoded, Command.Decoded_Bytes, Decoded_Length);
      if Encoded_Length > 0
        and then Command.Encoded_Source_Bytes = Command.Decoded_Bytes
        and then Encoded_Length <= Decoded_Length
      then
         Source.Encoded := Source.Decoded;
      else
         Terminal.App.Shared_Image_Data.Set
           (Source.Encoded,
            Command.Encoded_Source_Bytes,
            Encoded_Length);
      end if;
      if Preview_Length > 0
        and then Command.Decoded_Preview_Bytes = Command.Decoded_Bytes
        and then Preview_Length <= Decoded_Length
      then
         Source.Preview := Source.Decoded;
      elsif Preview_Length > 0
        and then Command.Decoded_Preview_Bytes = Command.Encoded_Source_Bytes
        and then Preview_Length <= Encoded_Length
      then
         Source.Preview := Source.Encoded;
      else
         Terminal.App.Shared_Image_Data.Set
           (Source.Preview,
            Command.Decoded_Preview_Bytes,
            Preview_Length);
      end if;
      Source.Command.Decoded_Bytes :=
        Terminal.App.Shared_Image_Data.View (Source.Decoded);
      Source.Command.Encoded_Source_Bytes :=
        Terminal.App.Shared_Image_Data.View (Source.Encoded);
      Source.Command.Decoded_Preview_Bytes :=
        Terminal.App.Shared_Image_Data.View (Source.Preview);
   exception
      when others =>
         Release_Image_Source (Source);
         raise;
   end Own_Image_Source;

   function Owner_Address
     (Owner : Terminal.App.Owned_Image_Data.Owner) return System.Address
   is
      View : constant RM.Image_Data_View :=
        Terminal.App.Owned_Image_Data.Unsafe_View (Owner);
   begin
      return
        (if View = null then System.Null_Address else View.all'Address);
   end Owner_Address;

   procedure Publish_Text_Atlas
     (Frame : RM.Frame_Commands;
      Batch : in out Submission_Batch)
   is
      Required : Natural := 0;
   begin
      if Frame.Glyph_Count > 0 then
         --  Validation has already proved this multiplication and the backend
         --  limits safe.  Copy only the texels glyph commands can address,
         --  never an arbitrary producer capacity.
         Required := Frame.Atlas_Width * Frame.Atlas_Height;
      end if;
      if Required = 0 or else Frame.Atlas_Pixels = System.Null_Address
      then
         Terminal.App.Owned_Image_Data.Release (Batch.Text_Atlas_Owner);
      elsif Frame.Atlas_Dirty
        or else Terminal.App.Owned_Image_Data.Length
          (Batch.Text_Atlas_Owner) /= Required
      then
         Copy_Address
           (Frame.Atlas_Pixels, Required, Batch.Text_Atlas_Owner);
      end if;
      Batch.Text_Atlas_Width := (if Required = 0 then 0 else Frame.Atlas_Width);
      Batch.Text_Atlas_Height := (if Required = 0 then 0 else Frame.Atlas_Height);
      Batch.Text_Atlas_Pixels := Owner_Address (Batch.Text_Atlas_Owner);
      Batch.Text_Atlas_Bytes :=
        Terminal.App.Owned_Image_Data.Length (Batch.Text_Atlas_Owner);
      Batch.Dirty_Atlas := Required > 0 and then Frame.Atlas_Dirty;
   end Publish_Text_Atlas;

   procedure Publish_Colour_Atlas
     (Frame : RM.Frame_Commands;
      Batch : in out Submission_Batch)
   is
      Byte_Count : Natural := 0;
   begin
      if Frame.Colour_Glyph_Count > 0
        and then Frame.Colour_Sheet_Pixels /= System.Null_Address
      then
         Byte_Count :=
           Frame.Colour_Sheet_Width * Frame.Colour_Sheet_Height * 4;
      end if;
      if Byte_Count = 0 then
         Terminal.App.Owned_Image_Data.Release (Batch.Colour_Sheet_Owner);
      elsif Frame.Colour_Sheet_Dirty
        or else Terminal.App.Owned_Image_Data.Length
          (Batch.Colour_Sheet_Owner) /= Byte_Count
      then
         Copy_Address
           (Frame.Colour_Sheet_Pixels, Byte_Count, Batch.Colour_Sheet_Owner);
      end if;
      if Byte_Count > 0 then
         Batch.Colour_Atlas_W := Frame.Colour_Sheet_Width;
         Batch.Colour_Atlas_H := Frame.Colour_Sheet_Height;
         Batch.Colour_Atlas_Byte_Count := Byte_Count;
         Batch.Colour_Sheet_Source := Owner_Address (Batch.Colour_Sheet_Owner);
         Batch.Dirty_Colour_Atlas := Frame.Colour_Sheet_Dirty;
      end if;
   end Publish_Colour_Atlas;

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
      Appended : Boolean;
   begin
      Append_Bounded_Vertex
        (Batch.Items,
         Batch.Count,
         (X        => X,
          Y        => Y,
          U        => U,
          V        => V,
          Color    => Color,
          Textured => Textured,
          Texture  => Texture),
         Appended);
      if not Appended then
         Batch.Vertex_Overflowed := True;
      end if;
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
      if Batch.Image_Atlas_Sources /= null then
         for I in 1 .. Batch.Image_Atlas_Cached_Source_Total loop
            Batch.Image_Atlas_Sources (I).Input_Decoded := null;
            Batch.Image_Atlas_Sources (I).Input_Encoded := null;
         end loop;
      end if;
      Batch.Count := 0;
      Batch.Vertex_Overflowed := False;
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

   procedure Invalidate (Batch : in out Submission_Batch) is
   begin
      Reset (Batch);
   end Invalidate;

   procedure Release (Batch : in out Submission_Batch) is
   begin
      Reset (Batch);
      Terminal.App.Owned_Image_Data.Release (Batch.Text_Atlas_Owner);
      Terminal.App.Owned_Image_Data.Release (Batch.Colour_Sheet_Owner);
      if Batch.Items /= null then
         Free_Vertices (Batch.Items);
      end if;
      if Batch.Text_Runs /= null then
         Free_Text_Runs (Batch.Text_Runs);
      end if;
      if Batch.Image_Atlas_Sources /= null then
         Free_Image_Atlas_Sources (Batch.Image_Atlas_Sources);
      end if;
      Batch.Image_Atlas_Cached_Source_Total := 0;
      Batch.Image_Atlas_Cached_Byte_Count := 0;
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

   function Has_Vertex_Data (Batch : Submission_Batch) return Boolean is
     (Batch.Items /= null and then Batch.Count > 0);

   function Vertex_At
     (Batch : Submission_Batch;
      Index : Positive) return Vertex
   is
   begin
      if Batch.Items = null or else Index > Batch.Count then
         raise Constraint_Error with "submission vertex index out of range";
      end if;
      return Batch.Items (Index);
   end Vertex_At;

   function Has_Colour_Atlas_Pixels
     (Batch : Submission_Batch) return Boolean is
     (Batch.Colour_Sheet_Source /= System.Null_Address
      and then Batch.Colour_Atlas_Byte_Count > 0);

   procedure Visit_Colour_Atlas_Pixels
     (Batch : Submission_Batch;
      Visit : not null access procedure (Pixels : System.Address)) is
   begin
      if Has_Colour_Atlas_Pixels (Batch) then
         Visit (Batch.Colour_Sheet_Source);
      end if;
   end Visit_Colour_Atlas_Pixels;

   function Has_Atlas_Pixels (Batch : Submission_Batch) return Boolean is
     (Batch.Text_Atlas_Pixels /= System.Null_Address
      and then Batch.Text_Atlas_Bytes > 0);

   procedure Visit_Atlas_Pixels
     (Batch : Submission_Batch;
      Visit : not null access procedure (Pixels : System.Address)) is
   begin
      if Has_Atlas_Pixels (Batch) then
         Visit (Batch.Text_Atlas_Pixels);
      end if;
   end Visit_Atlas_Pixels;

   overriding procedure Finalize (Batch : in out Submission_Batch) is
   begin
      Release (Batch);
   end Finalize;

   function Colour_Atlas_Width (Batch : Submission_Batch) return Natural
     is (Batch.Colour_Atlas_W);
   function Colour_Atlas_Height (Batch : Submission_Batch) return Natural
     is (Batch.Colour_Atlas_H);
   function Colour_Atlas_Bytes (Batch : Submission_Batch) return Natural
     is (Batch.Colour_Atlas_Byte_Count);
   function Colour_Atlas_Dirty (Batch : Submission_Batch) return Boolean
     is (Batch.Dirty_Colour_Atlas);
   function Colour_Glyph_Vertex_Count (Batch : Submission_Batch) return Natural
     is (Batch.Colour_Glyph_Vertex_Total);

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
        and then Image.Protocol in
          RM.Image_Kitty | RM.Image_Sixel | RM.Image_ITerm2
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

   function Same_Image_Layout
     (Left  : RM.Image_Command;
      Right : RM.Image_Command) return Boolean is
     (Left.Decoded_Source = Right.Decoded_Source
      and then Left.Raw_Format = Right.Raw_Format
      and then Left.Pixel_Width = Right.Pixel_Width
      and then Left.Pixel_Height = Right.Pixel_Height
      and then Left.Decoded_Row_Stride_Bytes =
        Right.Decoded_Row_Stride_Bytes
      and then Left.Decoded_Byte_Length = Right.Decoded_Byte_Length
      and then Left.Encoded_Source_Length = Right.Encoded_Source_Length);

   function Same_Image_Source
     (Left  : RM.Image_Command;
      Right : RM.Image_Command) return Boolean
   is
   begin
      if not Same_Image_Layout (Left, Right) then
         return False;
      end if;

      if Left.Content_Serial /= 0 and then Right.Content_Serial /= 0 then
         return Left.Content_Serial = Right.Content_Serial
           and then Left.Image_ID = Right.Image_ID;
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
              and then Left.Encoded_Source_Length = Right.Encoded_Source_Length;
         when RM.Image_Decoded_Source_None =>
            return False;
      end case;
   end Same_Image_Source;

   function Atlas_Source_Index
     (Batch : Submission_Batch;
      Image : RM.Image_Command) return Natural is
   begin
      if Batch.Image_Atlas_Sources = null then
         return 0;
      end if;
      for I in 1 .. Batch.Image_Atlas_Source_Total loop
         if Same_Image_Source (Image, Batch.Image_Atlas_Sources (I).Command)
           or else
             (Image.Decoded_Source = RM.Image_Decoded_Source_Buffer
              and then Image.Decoded_Bytes /= null
              and then Image.Decoded_Bytes =
                Batch.Image_Atlas_Sources (I).Input_Decoded
              and then Same_Image_Layout
                (Image, Batch.Image_Atlas_Sources (I).Command))
           or else
             (Image.Decoded_Source in
                RM.Image_Decoded_Source_Raw_Base64 |
                RM.Image_Decoded_Source_PNG_Base64 |
                RM.Image_Decoded_Source_Sixel_Text
              and then Image.Encoded_Source_Bytes /= null
              and then Image.Encoded_Source_Bytes =
                Batch.Image_Atlas_Sources (I).Input_Encoded
              and then Same_Image_Layout
                (Image, Batch.Image_Atlas_Sources (I).Command))
         then
            return I;
         end if;
      end loop;
      return 0;
   end Atlas_Source_Index;

   procedure Prepare_Image_Atlas
     (Frame : RM.Frame_Commands;
      Batch : in out Submission_Batch) is separate;

   procedure Copy_Text_Runs
     (Frame : RM.Frame_Commands;
      Batch : in out Submission_Batch) is separate;

   procedure Append_Image_Command
     (Frame : RM.Frame_Commands;
      Batch : in out Submission_Batch;
      Image : RM.Image_Command) is separate;

   procedure Build
     (Frame  : RM.Frame_Commands;
      Batch  : in out Submission_Batch;
      Status : out Build_Status) is separate;

   function Vertex_Count (Batch : Submission_Batch) return Natural
     is (Batch.Count);
   function Rectangle_Vertex_Count (Batch : Submission_Batch) return Natural
     is (Batch.Rectangle_Vertex_Total);
   function Glyph_Vertex_Count (Batch : Submission_Batch) return Natural
     is (Batch.Glyph_Vertex_Total);
   function Image_Vertex_Count (Batch : Submission_Batch) return Natural
     is (Batch.Image_Vertex_Total);
   function Image_Texture_Vertex_Count
     (Batch : Submission_Batch) return Natural
     is (Batch.Image_Texture_Vertex_Total);
   function Image_Command_Count (Batch : Submission_Batch) return Natural
     is (Batch.Image_Command_Total);
   function Image_Atlas_Width (Batch : Submission_Batch) return Natural
     is (Batch.Image_Atlas_W);
   function Image_Atlas_Height (Batch : Submission_Batch) return Natural
     is (Batch.Image_Atlas_H);
   function Image_Atlas_Bytes (Batch : Submission_Batch) return Natural
     is (Batch.Image_Atlas_Byte_Count);
   function Image_Atlas_Signature
     (Batch : Submission_Batch) return Interfaces.Unsigned_64
     is (Batch.Image_Atlas_Content_Signature);
   function Image_Atlas_Source_Count (Batch : Submission_Batch) return Natural
     is (Batch.Image_Atlas_Source_Total);
   function Image_Atlas_Source_Raw_Format
     (Batch : Submission_Batch; Index : Positive) return Natural
     renames Source_Rows.Raw_Format;
   function Image_Atlas_Source_Pixel_Width
     (Batch : Submission_Batch; Index : Positive) return Natural
     renames Source_Rows.Pixel_Width;
   function Image_Atlas_Source_Pixel_Height
     (Batch : Submission_Batch; Index : Positive) return Natural
     renames Source_Rows.Pixel_Height;
   procedure Read_Image_Atlas_Source_Rows
     (Batch : Submission_Batch;
      Index : Positive;
      Write : not null access procedure
        (Y        : Natural;
         Row      : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Status : out Image_Source_Read_Status)
     renames Source_Rows.Read;
   function Image_Atlas_Source_X
     (Batch : Submission_Batch; Index : Positive) return Natural
     is (if Batch.Image_Atlas_Sources = null
           or else Index > Batch.Image_Atlas_Source_Total
         then 0 else Batch.Image_Atlas_Sources (Index).X);
   function Image_Atlas_Source_Y
     (Batch : Submission_Batch; Index : Positive) return Natural
     is (if Batch.Image_Atlas_Sources = null
           or else Index > Batch.Image_Atlas_Source_Total
         then 0 else Batch.Image_Atlas_Sources (Index).Y);
   function Image_Atlas_Source_Width
     (Batch : Submission_Batch; Index : Positive) return Natural
     is (if Batch.Image_Atlas_Sources = null
           or else Index > Batch.Image_Atlas_Source_Total
         then 0 else Batch.Image_Atlas_Sources (Index).Width);
   function Image_Atlas_Source_Height
     (Batch : Submission_Batch; Index : Positive) return Natural
     is (if Batch.Image_Atlas_Sources = null
           or else Index > Batch.Image_Atlas_Source_Total
         then 0 else Batch.Image_Atlas_Sources (Index).Height);
   function Last_Image_Protocol
     (Batch : Submission_Batch) return RM.Image_Protocol
     is (Batch.Last_Image_Protocol);
   function Last_Image_Width (Batch : Submission_Batch) return Natural
     is (Batch.Last_Image_Width);
   function Last_Image_Height (Batch : Submission_Batch) return Natural
     is (Batch.Last_Image_Height);
   function Last_Image_Raw_Format (Batch : Submission_Batch) return Natural
     is (Batch.Last_Image_Raw_Format);
   function Last_Image_Pixel_Width (Batch : Submission_Batch) return Natural
     is (Batch.Last_Image_Pixel_Width);
   function Last_Image_Pixel_Height (Batch : Submission_Batch) return Natural
     is (Batch.Last_Image_Pixel_Height);
   function Last_Image_Payload_Length (Batch : Submission_Batch) return Natural
     is (Batch.Last_Image_Payload_Length);
   function Last_Image_Payload_Preview_Complete
     (Batch : Submission_Batch) return Boolean
     is (Batch.Last_Image_Payload_Preview_Complete);
   function Last_Image_Encoded_Preview_Length
     (Batch : Submission_Batch) return Natural
     is (Batch.Last_Image_Encoded_Preview_Length);
   function Last_Image_Decoded_Preview_Length
     (Batch : Submission_Batch) return Natural
     is (Batch.Last_Image_Decoded_Preview_Length);
   function Last_Image_Decoded_Preview_Byte
     (Batch : Submission_Batch; Index : Positive)
      return Terminal.Common.Bytes.Byte
     is (if Index > Batch.Last_Image_Decoded_Preview_Length
           or else Index > RM.Max_Image_Decoded_Preview_Length
         then 0 else Batch.Last_Image_Decoded_Preview_Bytes (Index));
   function Last_Image_Decoded_Data_Byte
     (Batch : Submission_Batch; Index : Positive)
      return Terminal.Common.Bytes.Byte
   is
      Accessible_Bytes : constant Natural :=
        Last_Image_Decoded_Random_Access_Bytes (Batch);
      Row_Stride : constant Natural :=
        Batch.Last_Image_Decoded_Row_Stride_Bytes;
      Zero_Based : constant Natural := Index - 1;
   begin
      if Accessible_Bytes = 0 or else Row_Stride = 0
        or else Index > Accessible_Bytes
      then
         return 0;
      end if;
      return Last_Image_Decoded_Row_Byte
        (Batch, Zero_Based / Row_Stride, Zero_Based mod Row_Stride);
   end Last_Image_Decoded_Data_Byte;
   function Last_Image_Decoded_Source
     (Batch : Submission_Batch) return RM.Image_Decoded_Source_Kind
     is (Batch.Last_Image_Decoded_Source);
   function Last_Image_Decoded_Source_Bytes
     (Batch : Submission_Batch) return Natural
     is (if Batch.Last_Image_Texture_Source = Texture_Image
         then RM.Image_Decoded_Source_Bytes (Batch.Last_Image_Row_Source)
         else 0);
   function Last_Image_Decoded_Random_Access_Bytes
     (Batch : Submission_Batch) return Natural
     is (if Batch.Last_Image_Texture_Source = Texture_Image
         then RM.Image_Decoded_Random_Access_Bytes
           (Batch.Last_Image_Row_Source)
         else 0);
   function Last_Image_Decoded_Source_Available
     (Batch : Submission_Batch) return Boolean
     is (Batch.Last_Image_Texture_Source = Texture_Image
         and then RM.Image_Decoded_Source_Available
           (Batch.Last_Image_Row_Source));
   function Last_Image_Decoded_Row_Byte
     (Batch : Submission_Batch; Row, Byte_Offset : Natural)
      return Terminal.Common.Bytes.Byte
     is (if Batch.Last_Image_Texture_Source /= Texture_Image then 0
         else RM.Image_Decoded_Row_Byte
           (Batch.Last_Image_Row_Source, Row, Byte_Offset));
   function Last_Image_Decoded_Row_Stride_Bytes
     (Batch : Submission_Batch) return Natural
     is (Batch.Last_Image_Decoded_Row_Stride_Bytes);
   function Last_Image_Preview_Decode_Complete
     (Batch : Submission_Batch) return Boolean
     is (Batch.Last_Image_Preview_Decode_Complete);
   function Last_Image_Decode_Status
     (Batch : Submission_Batch) return RM.Image_Decode_Status
     is (Batch.Last_Image_Decode_Status);
   function Last_Image_Placeholder (Batch : Submission_Batch) return Boolean
     is (Batch.Last_Image_Placeholder);
   function Last_Image_Texture_Downgraded
     (Batch : Submission_Batch) return Boolean
     is (Batch.Last_Image_Texture_Downgraded);
   function Last_Image_Texture_Source
     (Batch : Submission_Batch) return Texture_Source
     is (Batch.Last_Image_Texture_Source);

   function Image_Status_Label (Batch : Submission_Batch) return String
     renames Diagnostics.Image_Status_Label;

   function Image_Texture_Status_Label
     (Batch : Submission_Batch) return String
     renames Diagnostics.Image_Texture_Status_Label;

   function Text_Run_Count (Batch : Submission_Batch) return Natural
     is (Batch.Text_Run_Total);
   function Shaped_Glyph_Count (Batch : Submission_Batch) return Natural
     is (Batch.Shaped_Glyph_Total);
   function Width (Batch : Submission_Batch) return Natural
     is (Batch.Frame_Width);
   function Height (Batch : Submission_Batch) return Natural
     is (Batch.Frame_Height);
   function Text_Atlas_Used (Batch : Submission_Batch) return Boolean
     is (Batch.Uses_Text_Atlas);
   function Atlas_Width (Batch : Submission_Batch) return Natural
     is (Batch.Text_Atlas_Width);
   function Atlas_Height (Batch : Submission_Batch) return Natural
     is (Batch.Text_Atlas_Height);
   function Atlas_Bytes (Batch : Submission_Batch) return Natural
     is (Batch.Text_Atlas_Bytes);
   function Atlas_Dirty (Batch : Submission_Batch) return Boolean
     is (Batch.Dirty_Atlas);
end Terminal.App.Vulkan_Submit;

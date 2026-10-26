with Ada.Finalization;
with Interfaces;
with System;

with Terminal.Common.Bytes;
with Terminal.App.Render_Model;

--  Converts terminal render commands into Vulkan-style triangle batches.
--
--  This package does not own a Vulkan device or terminal state. It prepares the
--  deterministic vertex data that the df_vulkan adapter will upload and draw.
package Terminal.App.Vulkan_Submit is
   Max_Status_Label_Length : constant := 96;
   Max_Image_Atlas_Sources : constant := 256;
   Max_Image_Atlas_Bytes : constant := 64 * 1024 * 1024;
   Max_Image_Atlas_Dimension : constant := 16_384;
   --  One RGBA texel plus a one-pixel gutter on every side for each source.
   --  The current vertical layout must be able to retain every image object
   --  even after all sources have been reduced to one texel.
   Min_Image_Atlas_Bytes : constant :=
     Max_Image_Atlas_Sources * 3 * 3 * 4;
   Min_Image_Atlas_Dimension : constant :=
     Max_Image_Atlas_Sources * 3;
   Default_Image_Atlas_Bytes : constant := 4 * 1024 * 1024;
   Default_Image_Atlas_Dimension : constant := 4_096;

   type Image_Atlas_Limits is record
      Bytes : Positive range Min_Image_Atlas_Bytes .. Max_Image_Atlas_Bytes :=
        Default_Image_Atlas_Bytes;
      Dimension : Positive range
        Min_Image_Atlas_Dimension .. Max_Image_Atlas_Dimension :=
        Default_Image_Atlas_Dimension;
   end record;

   Default_Image_Atlas_Limits : constant Image_Atlas_Limits := (others => <>);

   type Build_Status is
     (Ok,
      Invalid_Frame,
      Allocation_Failed);

   type Texture_Source is
     (Texture_None,
      Texture_Text_Atlas,
      Texture_Image,

      --  Colour glyphs, in a sheet of their own. Not Texture_Image: that holds
      --  one inline picture at a time, and a line of emoji beside a Sixel has
      --  to be able to draw.
      Texture_Colour_Glyphs);

   type Vertex is record
      X        : Float := 0.0;
      Y        : Float := 0.0;
      U        : Float := 0.0;
      V        : Float := 0.0;
      Color    : Terminal.App.Render_Model.Pixel_Color;
      Textured : Boolean := False;
      Texture  : Texture_Source := Texture_None;
   end record;

   type Vertex_Array is array (Positive range <>) of Vertex;
   type Vertex_Array_Access is access all Vertex_Array;
   type Vertex_Array_View is access constant Vertex_Array;

   type Submission_Batch is new Ada.Finalization.Limited_Controlled with private;

   procedure Build
     (Frame  : Terminal.App.Render_Model.Frame_Commands;
      Batch  : in out Submission_Batch;
      Status : out Build_Status);

   --  Drop all frame-specific state, including borrowed image and atlas views,
   --  while retaining allocated working capacity for the next Build call.
   procedure Invalidate (Batch : in out Submission_Batch);
   procedure Release (Batch : in out Submission_Batch);
   procedure Set_Image_Atlas_Limits
     (Batch  : in out Submission_Batch;
      Limits : Image_Atlas_Limits);
   function Image_Atlas_Limit
     (Batch : Submission_Batch) return Image_Atlas_Limits;

   function Vertices (Batch : Submission_Batch) return Vertex_Array_View;
   function Vertex_Count (Batch : Submission_Batch) return Natural;
   function Rectangle_Vertex_Count (Batch : Submission_Batch) return Natural;
   function Glyph_Vertex_Count (Batch : Submission_Batch) return Natural;
   function Image_Vertex_Count (Batch : Submission_Batch) return Natural;

   --  The colour glyphs of this frame, packed into one RGBA sheet.
   --
   --  Packed rather than uploaded one at a time, because a frame may show many
   --  emoji at once and a texture holds one picture.
   --
   --  Empty when the frame has no colour glyphs.
   function Colour_Atlas_Width (Batch : Submission_Batch) return Natural;
   function Colour_Atlas_Height (Batch : Submission_Batch) return Natural;
   function Colour_Atlas_Bytes (Batch : Submission_Batch) return Natural;
   function Colour_Atlas_Pixels (Batch : Submission_Batch) return System.Address;
   function Colour_Atlas_Dirty (Batch : Submission_Batch) return Boolean;
   function Colour_Glyph_Vertex_Count (Batch : Submission_Batch) return Natural;
   function Image_Texture_Vertex_Count (Batch : Submission_Batch) return Natural;
   function Image_Command_Count (Batch : Submission_Batch) return Natural;
   function Image_Atlas_Width (Batch : Submission_Batch) return Natural;
   function Image_Atlas_Height (Batch : Submission_Batch) return Natural;
   function Image_Atlas_Bytes (Batch : Submission_Batch) return Natural;
   function Image_Atlas_Signature
     (Batch : Submission_Batch) return Interfaces.Unsigned_64;
   function Image_Atlas_Source_Count (Batch : Submission_Batch) return Natural;
   function Image_Atlas_Source_Command
     (Batch : Submission_Batch;
      Index : Positive) return Terminal.App.Render_Model.Image_Command;
   function Image_Atlas_Source_X
     (Batch : Submission_Batch;
      Index : Positive) return Natural;
   function Image_Atlas_Source_Y
     (Batch : Submission_Batch;
      Index : Positive) return Natural;
   function Image_Atlas_Source_Width
     (Batch : Submission_Batch;
      Index : Positive) return Natural;
   function Image_Atlas_Source_Height
     (Batch : Submission_Batch;
      Index : Positive) return Natural;
   function Last_Image_Protocol
     (Batch : Submission_Batch)
      return Terminal.App.Render_Model.Image_Protocol;
   function Last_Image_Width (Batch : Submission_Batch) return Natural;
   function Last_Image_Height (Batch : Submission_Batch) return Natural;
   function Last_Image_Raw_Format (Batch : Submission_Batch) return Natural;
   function Last_Image_Pixel_Width (Batch : Submission_Batch) return Natural;
   function Last_Image_Pixel_Height (Batch : Submission_Batch) return Natural;
   function Last_Image_Payload_Length (Batch : Submission_Batch) return Natural;
   function Last_Image_Payload_Preview_Complete
     (Batch : Submission_Batch) return Boolean;
   function Last_Image_Encoded_Preview_Length
     (Batch : Submission_Batch) return Natural;
   function Last_Image_Decoded_Preview_Length
     (Batch : Submission_Batch) return Natural;
   function Last_Image_Decoded_Preview_Byte
     (Batch : Submission_Batch;
      Index : Positive) return Terminal.Common.Bytes.Byte;
   function Last_Image_Decoded_Data_Byte
     (Batch : Submission_Batch;
      Index : Positive) return Terminal.Common.Bytes.Byte;
   function Last_Image_Decoded_Source
     (Batch : Submission_Batch)
      return Terminal.App.Render_Model.Image_Decoded_Source_Kind;
   function Last_Image_Source_Command
     (Batch : Submission_Batch) return Terminal.App.Render_Model.Image_Command;
   function Last_Image_Decoded_Source_Available
     (Batch : Submission_Batch) return Boolean;
   function Last_Image_Decoded_Source_Bytes
     (Batch : Submission_Batch) return Natural;
   function Last_Image_Decoded_Row_Byte
     (Batch       : Submission_Batch;
      Row         : Natural;
      Byte_Offset : Natural) return Terminal.Common.Bytes.Byte;
   function Last_Image_Decoded_Row_Stride_Bytes
     (Batch : Submission_Batch) return Natural;
   function Last_Image_Preview_Decode_Complete
     (Batch : Submission_Batch) return Boolean;
   function Last_Image_Decode_Status
     (Batch : Submission_Batch)
      return Terminal.App.Render_Model.Image_Decode_Status;
   function Last_Image_Placeholder (Batch : Submission_Batch) return Boolean;
   function Last_Image_Texture_Downgraded
     (Batch : Submission_Batch) return Boolean;
   function Last_Image_Texture_Source
     (Batch : Submission_Batch) return Texture_Source;
   function Text_Runs
     (Batch : Submission_Batch)
      return Terminal.App.Render_Model.Text_Run_Array_View;
   function Text_Run_Count (Batch : Submission_Batch) return Natural;
   function Shaped_Glyph_Count (Batch : Submission_Batch) return Natural;
   function Width (Batch : Submission_Batch) return Natural;
   function Height (Batch : Submission_Batch) return Natural;
   function Text_Atlas_Used (Batch : Submission_Batch) return Boolean;
   function Atlas_Width (Batch : Submission_Batch) return Natural;
   function Atlas_Height (Batch : Submission_Batch) return Natural;
   function Atlas_Pixels (Batch : Submission_Batch) return System.Address;
   function Atlas_Bytes (Batch : Submission_Batch) return Natural;
   function Atlas_Dirty (Batch : Submission_Batch) return Boolean;
   function Status_Label (Status : Build_Status) return String;
   function Texture_Source_Label (Source : Texture_Source) return String;
   function Image_Status_Label (Batch : Submission_Batch) return String;
   function Image_Texture_Status_Label (Batch : Submission_Batch) return String;

private
   type Image_Atlas_Source is record
      Command : Terminal.App.Render_Model.Image_Command;
      X       : Natural := 0;
      Y       : Natural := 0;
      Width   : Natural := 0;
      Height  : Natural := 0;
   end record;
   type Image_Atlas_Source_Array is
     array (Positive range <>) of Image_Atlas_Source;
   type Image_Atlas_Source_Array_Access is access all Image_Atlas_Source_Array;

   type Image_Order_Array is array (Positive range <>) of Positive;
   type Image_Order_Array_Access is access all Image_Order_Array;

   type Submission_Batch is new Ada.Finalization.Limited_Controlled with record
      Items                  : Vertex_Array_Access := null;
      Count                  : Natural := 0;
      Rectangle_Vertex_Total : Natural := 0;
      Glyph_Vertex_Total     : Natural := 0;
      Image_Vertex_Total     : Natural := 0;
      Image_Texture_Vertex_Total : Natural := 0;
      Image_Command_Total    : Natural := 0;
      Image_Order            : Image_Order_Array_Access := null;
      Image_Order_Total      : Natural := 0;
      Image_Atlas_Sources    : Image_Atlas_Source_Array_Access := null;
      Image_Atlas_Source_Total : Natural := 0;
      Image_Atlas_W          : Natural := 0;
      Image_Atlas_H          : Natural := 0;
      Image_Atlas_Byte_Count : Natural := 0;
      Image_Atlas_Content_Signature : Interfaces.Unsigned_64 := 0;
      Image_Atlas_Limit_Value : Image_Atlas_Limits :=
        Default_Image_Atlas_Limits;
      Colour_Sheet_Source    : System.Address := System.Null_Address;
      Colour_Atlas_W         : Natural := 0;
      Colour_Atlas_H         : Natural := 0;
      Colour_Atlas_Byte_Count : Natural := 0;
      Dirty_Colour_Atlas     : Boolean := False;
      Colour_Glyph_Vertex_Total : Natural := 0;
      Last_Image_Protocol    : Terminal.App.Render_Model.Image_Protocol :=
        Terminal.App.Render_Model.Image_Sixel;
      Last_Image_Width : Natural := 0;
      Last_Image_Height : Natural := 0;
      Last_Image_Raw_Format : Natural := 0;
      Last_Image_Pixel_Width : Natural := 0;
      Last_Image_Pixel_Height : Natural := 0;
      Last_Image_Payload_Length : Natural := 0;
      Last_Image_Payload_Preview_Complete : Boolean := False;
      Last_Image_Encoded_Preview_Length : Natural := 0;
      Last_Image_Decoded_Preview_Length : Natural := 0;
      Last_Image_Decoded_Source :
        Terminal.App.Render_Model.Image_Decoded_Source_Kind :=
          Terminal.App.Render_Model.Image_Decoded_Source_None;
      Last_Image_Row_Source : Terminal.App.Render_Model.Image_Command;
      Last_Image_Decoded_Row_Stride_Bytes : Natural := 0;
      Last_Image_Decoded_Preview_Bytes : Terminal.Common.Bytes.Byte_Array
        (1 .. Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length) :=
          (others => 0);
      Last_Image_Preview_Decode_Complete : Boolean := False;
      Last_Image_Decode_Status :
        Terminal.App.Render_Model.Image_Decode_Status :=
          Terminal.App.Render_Model.Image_Decode_Not_Attempted;
      Last_Image_Placeholder : Boolean := False;
      Last_Image_Texture_Downgraded : Boolean := False;
      Last_Image_Texture_Source : Texture_Source := Texture_None;
      Text_Runs              : Terminal.App.Render_Model.Text_Run_Array_Access :=
        null;
      Text_Run_Total         : Natural := 0;
      Shaped_Glyph_Total     : Natural := 0;
      Frame_Width            : Natural := 0;
      Frame_Height           : Natural := 0;
      Uses_Text_Atlas        : Boolean := False;
      Text_Atlas_Width       : Natural := 0;
      Text_Atlas_Height      : Natural := 0;
      Text_Atlas_Pixels      : System.Address := System.Null_Address;
      Text_Atlas_Bytes       : Natural := 0;
      Dirty_Atlas            : Boolean := False;
   end record;

   overriding procedure Finalize (Batch : in out Submission_Batch);
end Terminal.App.Vulkan_Submit;

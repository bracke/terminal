with Ada.Finalization;
with System;

with Terminal.App.Render_Model;

--  Converts terminal render commands into Vulkan-style triangle batches.
--
--  This package does not own a Vulkan device or terminal state. It prepares the
--  deterministic vertex data that the df_vulkan adapter will upload and draw.
package Terminal.App.Vulkan_Submit is
   type Build_Status is
     (Ok,
      Invalid_Frame,
      Allocation_Failed);

   type Texture_Source is
     (Texture_None,
      Texture_Text_Atlas);

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

   type Submission_Batch is new Ada.Finalization.Limited_Controlled with private;

   procedure Build
     (Frame  : Terminal.App.Render_Model.Frame_Commands;
      Batch  : in out Submission_Batch;
      Status : out Build_Status);

   procedure Release (Batch : in out Submission_Batch);

   function Vertices (Batch : Submission_Batch) return Vertex_Array_Access;
   function Vertex_Count (Batch : Submission_Batch) return Natural;
   function Rectangle_Vertex_Count (Batch : Submission_Batch) return Natural;
   function Glyph_Vertex_Count (Batch : Submission_Batch) return Natural;
   function Width (Batch : Submission_Batch) return Natural;
   function Height (Batch : Submission_Batch) return Natural;
   function Text_Atlas_Used (Batch : Submission_Batch) return Boolean;
   function Atlas_Width (Batch : Submission_Batch) return Natural;
   function Atlas_Height (Batch : Submission_Batch) return Natural;
   function Atlas_Pixels (Batch : Submission_Batch) return System.Address;
   function Atlas_Bytes (Batch : Submission_Batch) return Natural;
   function Atlas_Dirty (Batch : Submission_Batch) return Boolean;

private
   type Submission_Batch is new Ada.Finalization.Limited_Controlled with record
      Items                  : Vertex_Array_Access := null;
      Count                  : Natural := 0;
      Rectangle_Vertex_Total : Natural := 0;
      Glyph_Vertex_Total     : Natural := 0;
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

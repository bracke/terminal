with Terminal.Common.Bytes;
with Terminal.Core;
with Terminal.App.Render_Model;
with Terminal.App.Theme;
with Terminal.App.Vulkan_Context;
with Terminal.App.Vulkan_Presenter;
with Terminal.App.Vulkan_Submit;
with Textrender;

package Terminal.App.Renderer is
   Content_Margin : constant Natural := 6;
   Max_Status_Label_Length : constant := 64;

   type Renderer is limited private;

   type Init_Status is (Ok, Vulkan_Adapter_Missing, Failed);
   type Render_Status is
     (Ok,
      Not_Initialized,
      Invalid_Snapshot,
      Allocation_Failed,
      Glyph_Load_Failed,
      Batch_Build_Failed,
      Failed);

   type Renderer_Diagnostics is record
      Initialized         : Boolean := False;
      Text_Loaded         : Boolean := False;
      Last_Cell_Count     : Natural := 0;
      Last_Dirty_Rows     : Natural := 0;
      Last_Rectangle_Count : Natural := 0;
      Last_Glyph_Count    : Natural := 0;
      Last_Image_Count    : Natural := 0;
      Last_Image_Protocol : Terminal.App.Render_Model.Image_Protocol :=
        Terminal.App.Render_Model.Image_Sixel;
      Last_Image_Width : Natural := 0;
      Last_Image_Height : Natural := 0;
      Last_Image_Raw_Format : Natural := 0;
      Last_Image_Pixel_Width : Natural := 0;
      Last_Image_Pixel_Height : Natural := 0;
      Last_Image_Payload_Length : Natural := 0;
      Last_Image_Staging_Byte_Length : Natural := 0;
      Last_Image_Payload_Preview_Complete : Boolean := False;
      Last_Image_Encoded_Preview_Length : Natural := 0;
      Last_Image_Decoded_Preview_Length : Natural := 0;
      Last_Image_Decoded_Preview_Bytes : Terminal.Common.Bytes.Byte_Array
        (1 .. Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length) :=
          (others => 0);
      Last_Image_Preview_Decode_Complete : Boolean := False;
      Last_Image_Decode_Status :
        Terminal.App.Render_Model.Image_Decode_Status :=
          Terminal.App.Render_Model.Image_Decode_Not_Attempted;
      Last_Image_Placeholder : Boolean := False;
      Last_Text_Run_Count : Natural := 0;
      Last_Shaped_Glyph_Count : Natural := 0;
      Last_Shaping_Fallback_Count : Natural := 0;
      Last_Text_Fallback_Run_Count : Natural := 0;
      Last_Color_Emoji_Fallback_Count : Natural := 0;
      Last_Paragraph_Bidi_Fallback_Count : Natural := 0;
      Last_Vertex_Count   : Natural := 0;
      Missing_Glyph_Count : Natural := 0;
      Atlas_Dirty         : Boolean := False;
      Last_Render_Status  : Render_Status := Not_Initialized;
   end record;

   procedure Initialize
     (R       : out Renderer;
      Context : Terminal.App.Vulkan_Context.Context;
      Status  : out Init_Status);
   procedure Initialize_Headless
     (R      : out Renderer;
      Status : out Init_Status);
   procedure Render
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot;
      Status   : out Render_Status);
   procedure Set_Framebuffer_Size
     (R      : in out Renderer;
      Width  : Natural;
      Height : Natural);
   procedure Set_Theme
     (R : in out Renderer;
      T : Terminal.App.Theme.Theme);
   procedure Set_Hovered_Link
     (R    : in out Renderer;
      Link : Terminal.Core.Hyperlink);
   procedure Present
     (R         : Renderer;
      Context   : Terminal.App.Vulkan_Context.Context;
      Presenter : in out Terminal.App.Vulkan_Presenter.Presenter;
      Status    : out Terminal.App.Vulkan_Presenter.Present_Status);
   procedure Finalize (R : in out Renderer);

   function Cell_Width (R : Renderer) return Positive;
   function Cell_Height (R : Renderer) return Positive;
   function Diagnostics (R : Renderer) return Renderer_Diagnostics;
   function Color_Emoji_Status_Label
     (Diagnostics : Renderer_Diagnostics) return String;
   function Paragraph_Bidi_Status_Label
     (Diagnostics : Renderer_Diagnostics) return String;
   function Image_Status_Label
     (Diagnostics : Renderer_Diagnostics) return String;
   function Last_Frame (R : Renderer) return Terminal.App.Render_Model.Frame_Commands;

private
   type String_Access is access all String;

   type Kitty_Chunk_Segment;
   type Kitty_Chunk_Segment_Access is access Kitty_Chunk_Segment;
   type Kitty_Chunk_Segment is record
      Text : String_Access := null;
      Next : Kitty_Chunk_Segment_Access := null;
   end record;

   type Image_Object;
   type Image_Object_Access is access Image_Object;

   type Image_Object is record
      ID             : Natural := 0;
      Protocol       : Terminal.App.Render_Model.Image_Protocol :=
        Terminal.App.Render_Model.Image_Kitty;
      Raw_Format     : Natural := 0;
      Pixel_Width    : Natural := 0;
      Pixel_Height   : Natural := 0;
      Decoded_Length : Natural := 0;
      Decoded_Row_Stride_Bytes : Natural := 0;
      Bytes          : Terminal.App.Render_Model.Image_Data_Access := null;
      Next           : Image_Object_Access := null;
   end record;

   type Renderer is limited record
      Initialized : Boolean := False;
      Has_Context : Boolean := False;
      Text        : Textrender.Renderer;
      Text_Loaded : Boolean := False;
      CW          : Positive := 10;
      CH          : Positive := 20;
      Rectangles  : Terminal.App.Render_Model.Rectangle_Array_Access := null;
      Glyphs      : Terminal.App.Render_Model.Glyph_Array_Access := null;
      Colour_Glyphs : Terminal.App.Render_Model.Colour_Glyph_Array_Access := null;
      Images      : Terminal.App.Render_Model.Image_Array_Access := null;
      Text_Runs   : Terminal.App.Render_Model.Text_Run_Array_Access := null;
      Batch       : Terminal.App.Vulkan_Submit.Submission_Batch;
      Rectangle_Count : Natural := 0;
      Glyph_Count : Natural := 0;
      Colour_Glyph_Count : Natural := 0;
      Image_Count : Natural := 0;
      Text_Run_Count : Natural := 0;
      Shaped_Glyph_Count : Natural := 0;
      Shaping_Fallback_Count : Natural := 0;
      Text_Fallback_Run_Count : Natural := 0;
      Color_Emoji_Fallback_Count : Natural := 0;
      Paragraph_Bidi_Fallback_Count : Natural := 0;
      Vertex_Count : Natural := 0;
      Missing_Glyph_Count : Natural := 0;
      Last_Cell_Count : Natural := 0;
      Last_Dirty_Rows : Natural := 0;
      Last_Frame_Width : Natural := 0;
      Last_Frame_Height : Natural := 0;
      Target_Frame_Width : Natural := 0;
      Target_Frame_Height : Natural := 0;
      Color_Theme : Terminal.App.Theme.Theme :=
        Terminal.App.Theme.Built_In (Terminal.App.Theme.Default_Dark);
      Hovered_Link : Terminal.Core.Hyperlink;
      Atlas_Dirty : Boolean := False;
      Kitty_Chunk_Head : Kitty_Chunk_Segment_Access := null;
      Kitty_Chunk_Tail : Kitty_Chunk_Segment_Access := null;
      Kitty_Chunk_Length : Natural := 0;
      Image_Objects : Image_Object_Access := null;
      Last_Render_Status : Render_Status := Not_Initialized;
   end record;
end Terminal.App.Renderer;

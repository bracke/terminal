with Terminal.Core;
with Terminal.App.Render_Model;
with Terminal.App.Vulkan_Context;
with Terminal.App.Vulkan_Presenter;
with Terminal.App.Vulkan_Submit;
with Textrender;

package Terminal.App.Renderer is
   Content_Margin : constant Natural := 6;

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
      Last_Text_Run_Count : Natural := 0;
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
   procedure Present
     (R         : Renderer;
      Context   : Terminal.App.Vulkan_Context.Context;
      Presenter : in out Terminal.App.Vulkan_Presenter.Presenter;
      Status    : out Terminal.App.Vulkan_Presenter.Present_Status);
   procedure Finalize (R : in out Renderer);

   function Cell_Width (R : Renderer) return Positive;
   function Cell_Height (R : Renderer) return Positive;
   function Diagnostics (R : Renderer) return Renderer_Diagnostics;
   function Last_Frame (R : Renderer) return Terminal.App.Render_Model.Frame_Commands;

private
   type Renderer is limited record
      Initialized : Boolean := False;
      Has_Context : Boolean := False;
      Text        : Textrender.Renderer;
      Text_Loaded : Boolean := False;
      CW          : Positive := 10;
      CH          : Positive := 20;
      Rectangles  : Terminal.App.Render_Model.Rectangle_Array_Access := null;
      Glyphs      : Terminal.App.Render_Model.Glyph_Array_Access := null;
      Text_Runs   : Terminal.App.Render_Model.Text_Run_Array_Access := null;
      Batch       : Terminal.App.Vulkan_Submit.Submission_Batch;
      Rectangle_Count : Natural := 0;
      Glyph_Count : Natural := 0;
      Text_Run_Count : Natural := 0;
      Vertex_Count : Natural := 0;
      Missing_Glyph_Count : Natural := 0;
      Last_Cell_Count : Natural := 0;
      Last_Dirty_Rows : Natural := 0;
      Last_Frame_Width : Natural := 0;
      Last_Frame_Height : Natural := 0;
      Target_Frame_Width : Natural := 0;
      Target_Frame_Height : Natural := 0;
      Atlas_Dirty : Boolean := False;
      Last_Render_Status : Render_Status := Not_Initialized;
   end record;
end Terminal.App.Renderer;

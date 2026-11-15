with Terminal.App.Vulkan_Submit;

private package Terminal.App.Renderer.Frame_Lifecycle is
   procedure Reset_Counters (R : in out Renderer);
   procedure Reset (R : in out Renderer);
   procedure Release (R : in out Renderer);
   procedure Ensure_Capacity
     (R               : in out Renderer;
      Rectangle_Count : Positive;
      Glyph_Count     : Positive;
      Colour_Count    : Positive;
      Image_Count     : Positive;
      Text_Run_Count  : Positive;
      Map_Cell_Count  : Positive;
      Success         : out Boolean);

   procedure Ensure_Rectangle_Capacity
     (R : in out Renderer; Required : Positive; Success : out Boolean);
   procedure Ensure_Glyph_Capacity
     (R : in out Renderer; Required : Positive; Success : out Boolean);
   procedure Ensure_Colour_Capacity
     (R : in out Renderer; Required : Positive; Success : out Boolean);
   procedure Ensure_Text_Run_Capacity
     (R : in out Renderer; Required : Positive; Success : out Boolean);

   function Submission_Render_Status
     (Status : Terminal.App.Vulkan_Submit.Build_Status) return Render_Status;

   procedure Begin_Frame
     (Transaction : in out Graphics_Transaction_State;
      Frame       : in out Renderer_Frame_State;
      Cell_Count : Natural;
      Width      : Natural;
      Height     : Natural);

   procedure Record_Dirty_Rows
     (Frame    : in out Renderer_Frame_State;
      Snapshot : Terminal.Core.Render_Snapshot);

   procedure Build_Submission_Batch
     (Commands : Terminal.App.Render_Model.Frame_Commands;
      Text     : in out Renderer_Text_State;
      Frame    : in out Renderer_Frame_State;
      Status : out Render_Status);

   procedure Prepare
     (R               : in out Renderer;
      Cell_Count      : Natural;
      Width           : Natural;
      Height          : Natural;
      Rectangle_Count : Positive;
      Glyph_Count     : Positive;
      Colour_Count    : Positive;
      Image_Count     : Positive;
      Text_Run_Count  : Positive;
      Map_Cell_Count  : Positive;
      Status          : out Render_Status);

   procedure Record_Dirty_Rows
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot);

   procedure Finish (R : in out Renderer; Status : out Render_Status);
end Terminal.App.Renderer.Frame_Lifecycle;

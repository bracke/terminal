with Terminal.Common.Bytes;
with Terminal.App.Render_Model;
with Terminal.App.Vulkan_Context;
with Terminal.App.Vulkan_Device;
with Terminal.App.Vulkan_Submit;

package Terminal.App.Vulkan_Presenter is
   Max_Status_Label_Length : constant := 96;

   type Presenter is limited private;

   type Init_Status is
     (Ok,
      Context_Not_Initialized,
      Surface_Unavailable,
      Surface_Query_Failed,
      No_Suitable_Device,
      Swapchain_Extension_Missing,
      Create_Device_Failed,
      Queue_Unavailable,
      Invalid_Extent,
      Create_Swapchain_Failed,
      Get_Swapchain_Images_Failed,
      Too_Many_Swapchain_Images,
      Create_Image_View_Failed,
      Create_Render_Pass_Failed,
      Create_Framebuffer_Failed,
      Create_Command_Pool_Failed,
      Allocate_Command_Buffers_Failed,
      Create_Sync_Failed,
      Create_Pipeline_Layout_Failed,
      Create_Descriptor_Set_Layout_Failed,
      Create_Descriptor_Pool_Failed,
      Allocate_Descriptor_Set_Failed,
      Create_Atlas_Sampler_Failed,
      Shader_Load_Failed,
      Create_Shader_Module_Failed,
      Create_Graphics_Pipeline_Failed,
      Vertex_Buffer_Too_Large,
      Create_Vertex_Buffer_Failed,
      Allocate_Vertex_Memory_Failed,
      Bind_Vertex_Buffer_Failed,
      Map_Vertex_Buffer_Failed,
      Atlas_Too_Large,
      Create_Atlas_Image_Failed,
      Allocate_Atlas_Memory_Failed,
      Bind_Atlas_Image_Failed,
      Create_Atlas_View_Failed,
      Create_Atlas_Staging_Buffer_Failed,
      Allocate_Atlas_Staging_Memory_Failed,
      Bind_Atlas_Staging_Buffer_Failed,
      Map_Atlas_Staging_Buffer_Failed,
      Copy_Atlas_Failed);

   type Present_Status is
     (Ok,
      Validated_Not_Presented,
      Not_Initialized,
      Invalid_Context,
      Invalid_Batch,
      Upload_Failed,
      Atlas_Upload_Failed,
      Render_Failed,
      Acquire_Image_Failed,
      Swapchain_Out_Of_Date,
      Wait_Fence_Failed,
      Reset_Fence_Failed,
      Reset_Command_Buffer_Failed,
      Begin_Command_Buffer_Failed,
      End_Command_Buffer_Failed,
      Queue_Submit_Failed,
      Queue_Present_Failed);

   type Diagnostic_Snapshot is record
      Initialized       : Boolean := False;
      Context_Ready     : Boolean := False;
      Surface_Ready     : Boolean := False;
      Accepted_Frames   : Natural := 0;
      Rejected_Frames   : Natural := 0;
      Last_Status       : Present_Status := Not_Initialized;
      Last_Vertex_Count : Natural := 0;
      Last_Image_Command_Count : Natural := 0;
      Last_Image_Vertex_Count : Natural := 0;
      Last_Image_Texture_Vertex_Count : Natural := 0;
      Last_Image_Protocol : Terminal.App.Render_Model.Image_Protocol :=
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
      Last_Image_Decoded_Preview_Bytes : Terminal.Common.Bytes.Byte_Array
        (1 .. Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length) :=
          (others => 0);
      Last_Image_Preview_Decode_Complete : Boolean := False;
      Last_Image_Decode_Status :
        Terminal.App.Render_Model.Image_Decode_Status :=
          Terminal.App.Render_Model.Image_Decode_Not_Attempted;
      Last_Image_Placeholder : Boolean := False;
      Last_Image_Texture_Downgraded : Boolean := False;
      Last_Image_Texture_Source :
        Terminal.App.Vulkan_Submit.Texture_Source :=
          Terminal.App.Vulkan_Submit.Texture_None;
      Last_Text_Run_Count : Natural := 0;
      Last_Shaped_Glyph_Count : Natural := 0;
      Last_Frame_Width  : Natural := 0;
      Last_Frame_Height : Natural := 0;
      Last_Atlas_Bytes  : Natural := 0;
      Atlas_Dirty       : Boolean := False;
      Device            : Terminal.App.Vulkan_Device.Diagnostic_Snapshot;
      Logical_Device    : Terminal.App.Vulkan_Device.Device_Diagnostic_Snapshot;
   end record;

   procedure Initialize
     (P       : out Presenter;
      Context : Terminal.App.Vulkan_Context.Context;
      Status  : out Init_Status;
      Desired_Width : Natural := 0;
      Desired_Height : Natural := 0);

   procedure Present
     (P       : in out Presenter;
      Context : Terminal.App.Vulkan_Context.Context;
      Batch   : Terminal.App.Vulkan_Submit.Submission_Batch;
      Status  : out Present_Status);

   procedure Finalize (P : in out Presenter);

   function Diagnostics (P : Presenter) return Diagnostic_Snapshot;
   function Status_Label (Status : Present_Status) return String;
   function Image_Status_Label
     (Diagnostics : Diagnostic_Snapshot) return String;
   function Image_Texture_Status_Label
     (Diagnostics : Diagnostic_Snapshot) return String;
   function Image_Texture_Resource_Status_Label
     (Diagnostics : Diagnostic_Snapshot) return String;

private
   type Presenter is limited record
      Initialized       : Boolean := False;
      Context_Ready     : Boolean := False;
      Surface_Ready     : Boolean := False;
      Accepted_Frames   : Natural := 0;
      Rejected_Frames   : Natural := 0;
      Last_Status       : Present_Status := Not_Initialized;
      Last_Vertex_Count : Natural := 0;
      Last_Image_Command_Count : Natural := 0;
      Last_Image_Vertex_Count : Natural := 0;
      Last_Image_Texture_Vertex_Count : Natural := 0;
      Last_Image_Protocol : Terminal.App.Render_Model.Image_Protocol :=
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
      Last_Image_Decoded_Preview_Bytes : Terminal.Common.Bytes.Byte_Array
        (1 .. Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length) :=
          (others => 0);
      Last_Image_Preview_Decode_Complete : Boolean := False;
      Last_Image_Decode_Status :
        Terminal.App.Render_Model.Image_Decode_Status :=
          Terminal.App.Render_Model.Image_Decode_Not_Attempted;
      Last_Image_Placeholder : Boolean := False;
      Last_Image_Texture_Downgraded : Boolean := False;
      Last_Image_Texture_Source :
        Terminal.App.Vulkan_Submit.Texture_Source :=
          Terminal.App.Vulkan_Submit.Texture_None;
      Last_Text_Run_Count : Natural := 0;
      Last_Shaped_Glyph_Count : Natural := 0;
      Last_Frame_Width  : Natural := 0;
      Last_Frame_Height : Natural := 0;
      Last_Atlas_Bytes  : Natural := 0;
      Atlas_Dirty       : Boolean := False;
      Device            : Terminal.App.Vulkan_Device.Selection;
      Logical_Device    : Terminal.App.Vulkan_Device.Logical_Device;
   end record;
end Terminal.App.Vulkan_Presenter;

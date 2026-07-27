with System;
with Terminal.Common.Bytes;
with Terminal.App.Render_Model;
with Terminal.App.Vulkan_Context;
with Terminal.App.Vulkan_Submit;
with Vk;

package Terminal.App.Vulkan_Device is
   Max_Physical_Devices : constant := 16;
   Max_Queue_Families   : constant := 64;
   Max_Device_Extensions : constant := 256;
   Max_Surface_Formats   : constant := 64;
   Max_Present_Modes     : constant := 16;
   Max_Swapchain_Images   : constant := 8;
   Max_Upload_Vertices    : constant := 1_048_576;
   Max_Status_Label_Length : constant := 96;

   type Selection is private;
   type Logical_Device is limited private;

   type Select_Status is
     (Ok,
      Context_Not_Initialized,
      No_Physical_Devices,
      Surface_Query_Failed,
      No_Suitable_Device);

   type Diagnostic_Snapshot is record
      Selected              : Boolean := False;
      Physical_Device_Count : Natural := 0;
      Devices_Inspected     : Natural := 0;
      Queue_Families_Checked : Natural := 0;
      Queue_Family_Index    : Natural := 0;
      Surface_Format_Count  : Natural := 0;
      Present_Mode_Count    : Natural := 0;
      Device_Extensions_Checked : Natural := 0;
      Swapchain_Extension_Found : Boolean := False;
      Last_Status           : Select_Status := Context_Not_Initialized;
   end record;

   type Create_Status is
     (Ok,
      Selection_Not_Ready,
      Swapchain_Extension_Missing,
      Create_Device_Failed,
      Queue_Unavailable,
      Surface_Query_Failed,
      Invalid_Extent,
      Create_Swapchain_Failed,
      Get_Swapchain_Images_Failed,
      Too_Many_Swapchain_Images,
      Create_Image_View_Failed,
      Create_Color_Target_Failed,
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

   type Device_Diagnostic_Snapshot is record
      Initialized        : Boolean := False;
      Queue_Family_Index : Natural := 0;
      Swapchain_Created  : Boolean := False;
      Swapchain_Image_Count : Natural := 0;
      Swapchain_View_Count : Natural := 0;
      Framebuffer_Count : Natural := 0;
      Render_Pass_Created : Boolean := False;
      Command_Pool_Created : Boolean := False;
      Command_Buffer_Count : Natural := 0;
      Sync_Frame_Count   : Natural := 0;
      Pipeline_Layout_Created : Boolean := False;
      Graphics_Pipeline_Created : Boolean := False;
      Descriptor_Set_Layout_Created : Boolean := False;
      Descriptor_Pool_Created : Boolean := False;
      Descriptor_Set_Allocated : Boolean := False;
      Vertex_Buffer_Created : Boolean := False;
      Vertex_Buffer_Bytes : Natural := 0;
      Uploaded_Vertex_Count : Natural := 0;
      Uploaded_Image_Command_Count : Natural := 0;
      Uploaded_Image_Vertex_Count : Natural := 0;
      Uploaded_Image_Texture_Vertex_Count : Natural := 0;
      Uploaded_Image_Protocol : Terminal.App.Render_Model.Image_Protocol :=
        Terminal.App.Render_Model.Image_Sixel;
      Uploaded_Image_Width : Natural := 0;
      Uploaded_Image_Height : Natural := 0;
      Uploaded_Image_Raw_Format : Natural := 0;
      Uploaded_Image_Pixel_Width : Natural := 0;
      Uploaded_Image_Pixel_Height : Natural := 0;
      Uploaded_Image_Payload_Length : Natural := 0;
      Uploaded_Image_Texture_Staging_Bytes : Natural := 0;
      Uploaded_Image_Payload_Preview_Complete : Boolean := False;
      Uploaded_Image_Encoded_Preview_Length : Natural := 0;
      Uploaded_Image_Decoded_Preview_Length : Natural := 0;
      Uploaded_Image_Decoded_Preview_Bytes : Terminal.Common.Bytes.Byte_Array
        (1 .. Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length) :=
          (others => 0);
      Uploaded_Image_Preview_Decode_Complete : Boolean := False;
      Uploaded_Image_Decode_Status :
        Terminal.App.Render_Model.Image_Decode_Status :=
          Terminal.App.Render_Model.Image_Decode_Not_Attempted;
      Uploaded_Image_Placeholder : Boolean := False;
      Uploaded_Image_Texture_Downgraded : Boolean := False;
      Uploaded_Image_Texture_Source :
        Terminal.App.Vulkan_Submit.Texture_Source :=
          Terminal.App.Vulkan_Submit.Texture_None;
      Uploaded_Text_Run_Count : Natural := 0;
      Uploaded_Shaped_Glyph_Count : Natural := 0;
      Rendered_Frame_Count : Natural := 0;
      Color_Sample_Count : Natural := 1;
      Color_MSAA_Created : Boolean := False;
      Atlas_Image_Created : Boolean := False;
      Atlas_View_Created : Boolean := False;
      Atlas_Sampler_Created : Boolean := False;
      Image_Texture_Descriptor_Capacity : Natural := 0;
      Image_Texture_Descriptor_Bound_Count : Natural := 0;
      Atlas_Width : Natural := 0;
      Atlas_Height : Natural := 0;
      Atlas_Bytes : Natural := 0;
      Atlas_Upload_Count : Natural := 0;
      Swapchain_Width    : Natural := 0;
      Swapchain_Height   : Natural := 0;
      Last_Status        : Create_Status := Selection_Not_Ready;
   end record;

   type Render_Status is
     (Ok,
      Not_Initialized,
      No_Uploaded_Vertices,
      Acquire_Image_Failed,
      Swapchain_Out_Of_Date,
      Wait_Fence_Failed,
      Reset_Fence_Failed,
      Reset_Command_Buffer_Failed,
      Begin_Command_Buffer_Failed,
      End_Command_Buffer_Failed,
      Queue_Submit_Failed,
      Queue_Present_Failed);

   procedure Select_Physical_Device
     (Context : Terminal.App.Vulkan_Context.Context;
      Choice  : out Selection;
      Status  : out Select_Status);

   function Is_Selected (Choice : Selection) return Boolean;
   function Physical_Device (Choice : Selection) return Vk.Physical_Device_T;
   function Queue_Family_Index (Choice : Selection) return Natural;
   function Diagnostics (Choice : Selection) return Diagnostic_Snapshot;

   procedure Create_Logical_Device
     (Choice : Selection;
      Surface : Vk.Surface_KHR_T;
      Desired_Width : Natural;
      Desired_Height : Natural;
      Device : out Logical_Device;
      Status : out Create_Status);

   procedure Finalize (Device : in out Logical_Device);

   procedure Upload
     (Device : in out Logical_Device;
      Choice : Selection;
      Batch  : Terminal.App.Vulkan_Submit.Submission_Batch;
      Status : out Create_Status);

   procedure Render
     (Device : in out Logical_Device;
      Status : out Render_Status);

   function Is_Initialized (Device : Logical_Device) return Boolean;
   function Device_Handle (Device : Logical_Device) return Vk.Device_T;
   function Graphics_Queue (Device : Logical_Device) return Vk.Queue_T;
   function Queue_Family_Index (Device : Logical_Device) return Natural;
   function Diagnostics (Device : Logical_Device) return Device_Diagnostic_Snapshot;

   function Select_Status_Label (Status : Select_Status) return String;
   function Create_Status_Label (Status : Create_Status) return String;
   function Render_Status_Label (Status : Render_Status) return String;
   function Image_Status_Label
     (Diagnostics : Device_Diagnostic_Snapshot) return String;
   function Image_Texture_Status_Label
     (Diagnostics : Device_Diagnostic_Snapshot) return String;
   function Image_Texture_Resource_Status_Label
     (Diagnostics : Device_Diagnostic_Snapshot) return String;

private
   subtype Swapchain_Image_Range is Positive range 1 .. Max_Swapchain_Images;
   type Swapchain_Image_Array is array (Swapchain_Image_Range) of Vk.Image_T;
   type Swapchain_Image_View_Array is
     array (Swapchain_Image_Range) of Vk.Image_View_T;
   type Framebuffer_Array is array (Swapchain_Image_Range) of Vk.Framebuffer_T;
   type Command_Buffer_Array is array (Swapchain_Image_Range) of Vk.Command_Buffer_T;
   type Semaphore_Array is array (Swapchain_Image_Range) of Vk.Semaphore_T;
   type Fence_Array is array (Swapchain_Image_Range) of Vk.Fence_T;

   type Selection is record
      Selected              : Boolean := False;
      Physical_Device       : Vk.Physical_Device_T := System.Null_Address;
      Queue_Family_Index    : Natural := 0;
      Physical_Device_Count : Natural := 0;
      Devices_Inspected     : Natural := 0;
      Queue_Families_Checked : Natural := 0;
      Surface_Format_Count  : Natural := 0;
      Present_Mode_Count    : Natural := 0;
      Device_Extensions_Checked : Natural := 0;
      Swapchain_Extension_Found : Boolean := False;
      Last_Status           : Select_Status := Context_Not_Initialized;
   end record;

   type Logical_Device is limited record
      Initialized        : Boolean := False;
      Device             : Vk.Device_T := System.Null_Address;
      Queue              : Vk.Queue_T := System.Null_Address;
      Swapchain          : Vk.Swapchain_KHR_T := System.Null_Address;
      Swapchain_Format   : Vk.Format_T := Vk.FORMAT_UNDEFINED;
      Render_Pass        : Vk.Render_Pass_T := System.Null_Address;
      Pipeline_Layout    : Vk.Pipeline_Layout_T := System.Null_Address;
      Graphics_Pipeline  : Vk.Pipeline_T := System.Null_Address;
      Descriptor_Set_Layout : Vk.Descriptor_Set_Layout_T := System.Null_Address;
      Descriptor_Pool    : Vk.Descriptor_Pool_T := System.Null_Address;
      Descriptor_Set     : Vk.Descriptor_Set_T := System.Null_Address;
      Command_Pool       : Vk.Command_Pool_T := System.Null_Address;
      Vertex_Buffer      : Vk.Buffer_T := System.Null_Address;
      Vertex_Memory      : Vk.Device_Memory_T := System.Null_Address;
      Color_MSAA_Image   : Vk.Image_T := System.Null_Address;
      Color_MSAA_Memory  : Vk.Device_Memory_T := System.Null_Address;
      Color_MSAA_View    : Vk.Image_View_T := System.Null_Address;
      Color_Sample_Count : Vk.Sample_Count_Flag_Bits_T := Vk.SAMPLE_COUNT_1_BIT;
      Atlas_Image        : Vk.Image_T := System.Null_Address;
      Atlas_Memory       : Vk.Device_Memory_T := System.Null_Address;
      Atlas_View         : Vk.Image_View_T := System.Null_Address;
      Atlas_Sampler      : Vk.Sampler_T := System.Null_Address;
      Image_Texture_Image : Vk.Image_T := System.Null_Address;
      Image_Texture_Memory : Vk.Device_Memory_T := System.Null_Address;
      Image_Texture_View : Vk.Image_View_T := System.Null_Address;
      Image_Texture_Width : Natural := 0;
      Image_Texture_Height : Natural := 0;
      Image_Texture_Bytes : Natural := 0;
      Image_Texture_Descriptor_Capacity : Natural := 0;
      Image_Texture_Descriptor_Bound_Count : Natural := 0;
      Swapchain_Images   : Swapchain_Image_Array := (others => System.Null_Address);
      Swapchain_Views    : Swapchain_Image_View_Array :=
        (others => System.Null_Address);
      Framebuffers       : Framebuffer_Array := (others => System.Null_Address);
      Command_Buffers    : Command_Buffer_Array := (others => System.Null_Address);
      Image_Available    : Semaphore_Array := (others => System.Null_Address);
      Render_Finished    : Semaphore_Array := (others => System.Null_Address);
      In_Flight          : Fence_Array := (others => System.Null_Address);
      Queue_Family_Index : Natural := 0;
      Swapchain_Image_Count : Natural := 0;
      Swapchain_View_Count : Natural := 0;
      Framebuffer_Count  : Natural := 0;
      Command_Buffer_Count : Natural := 0;
      Sync_Frame_Count   : Natural := 0;
      Vertex_Buffer_Bytes : Natural := 0;
      Uploaded_Vertex_Count : Natural := 0;
      Uploaded_Image_Command_Count : Natural := 0;
      Uploaded_Image_Vertex_Count : Natural := 0;
      Uploaded_Image_Texture_Vertex_Count : Natural := 0;
      Uploaded_Image_Protocol : Terminal.App.Render_Model.Image_Protocol :=
        Terminal.App.Render_Model.Image_Sixel;
      Uploaded_Image_Width : Natural := 0;
      Uploaded_Image_Height : Natural := 0;
      Uploaded_Image_Raw_Format : Natural := 0;
      Uploaded_Image_Pixel_Width : Natural := 0;
      Uploaded_Image_Pixel_Height : Natural := 0;
      Uploaded_Image_Payload_Length : Natural := 0;
      Uploaded_Image_Texture_Staging_Bytes : Natural := 0;
      Uploaded_Image_Payload_Preview_Complete : Boolean := False;
      Uploaded_Image_Encoded_Preview_Length : Natural := 0;
      Uploaded_Image_Decoded_Preview_Length : Natural := 0;
      Uploaded_Image_Decoded_Preview_Bytes : Terminal.Common.Bytes.Byte_Array
        (1 .. Terminal.App.Render_Model.Max_Image_Decoded_Preview_Length) :=
          (others => 0);
      Uploaded_Image_Preview_Decode_Complete : Boolean := False;
      Uploaded_Image_Decode_Status :
        Terminal.App.Render_Model.Image_Decode_Status :=
          Terminal.App.Render_Model.Image_Decode_Not_Attempted;
      Uploaded_Image_Placeholder : Boolean := False;
      Uploaded_Image_Texture_Downgraded : Boolean := False;
      Uploaded_Image_Texture_Source :
        Terminal.App.Vulkan_Submit.Texture_Source :=
          Terminal.App.Vulkan_Submit.Texture_None;
      Uploaded_Text_Run_Count : Natural := 0;
      Uploaded_Shaped_Glyph_Count : Natural := 0;
      Rendered_Frame_Count : Natural := 0;
      Current_Frame      : Natural := 1;
      Atlas_Width        : Natural := 0;
      Atlas_Height       : Natural := 0;
      Atlas_Bytes        : Natural := 0;
      Atlas_Upload_Count : Natural := 0;
      Swapchain_Width    : Natural := 0;
      Swapchain_Height   : Natural := 0;
      Last_Status        : Create_Status := Selection_Not_Ready;
   end record;
end Terminal.App.Vulkan_Device;

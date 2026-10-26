package Terminal.App.Cleanup_Diagnostics is
   type Component is
     (Session_Runtime,
      Session_Table,
      Theme_Transaction,
      Image_Install,
      Renderer_State,
      Frame_Image_Storage,
      Vulkan_Context,
      Vulkan_Device,
      Vulkan_Presenter);
   type Failure_Counts is array (Component) of Natural;

   procedure Note_Failure (Source : Component);
   function Snapshot return Failure_Counts;
   function Total (Counts : Failure_Counts) return Natural;
   function Status_Label (Counts : Failure_Counts) return String;
end Terminal.App.Cleanup_Diagnostics;

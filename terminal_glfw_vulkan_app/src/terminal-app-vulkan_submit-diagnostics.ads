private package Terminal.App.Vulkan_Submit.Diagnostics is
   function Status_Label (Status : Build_Status) return String;
   function Texture_Source_Label (Source : Texture_Source) return String;
   function Image_Status_Label (Batch : Submission_Batch) return String;
   function Image_Texture_Status_Label
     (Batch : Submission_Batch) return String;
end Terminal.App.Vulkan_Submit.Diagnostics;

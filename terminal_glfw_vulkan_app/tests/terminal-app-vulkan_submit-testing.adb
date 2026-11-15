package body Terminal.App.Vulkan_Submit.Testing is
   function Vertices
     (Batch : Submission_Batch) return Vertex_Array_View is
     (Vertex_Array_View (Batch.Items));

   function Text_Runs
     (Batch : Submission_Batch)
      return Terminal.App.Render_Model.Text_Run_Array_View is
     (Terminal.App.Render_Model.Text_Run_Array_View (Batch.Text_Runs));

   function Colour_Atlas_Pixels
     (Batch : Submission_Batch) return System.Address is
     (Batch.Colour_Sheet_Source);

   function Atlas_Pixels
     (Batch : Submission_Batch) return System.Address is
     (Batch.Text_Atlas_Pixels);

   function Owned_Image_Source_Bytes
     (Batch : Submission_Batch) return Natural is
     (Batch.Image_Atlas_Cached_Byte_Count);
end Terminal.App.Vulkan_Submit.Testing;

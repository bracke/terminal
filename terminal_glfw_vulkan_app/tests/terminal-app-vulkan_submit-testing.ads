with System;
with Terminal.App.Render_Model;

--  White-box access to submission storage.  This child is compiled only by
--  the test project; production callers cannot retain these views.
package Terminal.App.Vulkan_Submit.Testing is
   function Vertices
     (Batch : Submission_Batch) return Vertex_Array_View;
   function Text_Runs
     (Batch : Submission_Batch)
      return Terminal.App.Render_Model.Text_Run_Array_View;
   function Colour_Atlas_Pixels
     (Batch : Submission_Batch) return System.Address;
   function Atlas_Pixels
     (Batch : Submission_Batch) return System.Address;
   function Owned_Image_Source_Bytes
     (Batch : Submission_Batch) return Natural;
end Terminal.App.Vulkan_Submit.Testing;

with Terminal.App.Render_Model;

private package Terminal.App.Vulkan_Submit.Validation is
   function Is_Valid
     (Frame : Terminal.App.Render_Model.Frame_Commands) return Boolean;
   function Vertex_Capacity
     (Frame : Terminal.App.Render_Model.Frame_Commands) return Natural;
end Terminal.App.Vulkan_Submit.Validation;

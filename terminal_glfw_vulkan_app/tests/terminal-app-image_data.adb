package body Terminal.App.Image_Data is
   function Read_Only
     (Data : Image_Data_Access)
      return Terminal.App.Render_Model.Image_Data_View is
     (Terminal.App.Render_Model.Image_Data_View (Data));
end Terminal.App.Image_Data;

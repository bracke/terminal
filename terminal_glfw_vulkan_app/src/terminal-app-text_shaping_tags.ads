with Terminal.App.Render_Model;

private package Terminal.App.Text_Shaping_Tags is
   function Direction_Tag
     (Direction : Terminal.App.Render_Model.Text_Run_Direction) return String;
   function Script_Tag
     (Script : Terminal.App.Render_Model.Text_Run_Script) return String;
   function Language_Tag return String;
end Terminal.App.Text_Shaping_Tags;

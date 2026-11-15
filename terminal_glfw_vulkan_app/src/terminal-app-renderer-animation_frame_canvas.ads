with Terminal.App.Graphics;
with Terminal.App.Owned_Image_Data;
with Terminal.Core;

private package Terminal.App.Renderer.Animation_Frame_Canvas is
   procedure Prepare
     (Object        : Image_Object_Access;
      Target_Number : Positive;
      New_Frame     : Boolean;
      Header        : Terminal.App.Graphics.Graphics_Header;
      Canvas        : in out Terminal.App.Owned_Image_Data.Owner;
      Success       : out Boolean;
      Failure       : out Terminal.Core.Graphics_Completion_Code);
end Terminal.App.Renderer.Animation_Frame_Canvas;

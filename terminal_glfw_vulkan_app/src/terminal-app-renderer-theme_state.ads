with Terminal.App.Graphics;

private package Terminal.App.Renderer.Theme_State is
   function Prepare_Theme_Baseline
     (Object          : Image_Object_Access;
      Head            : out Theme_Operation_Access;
      Tail            : out Theme_Operation_Access;
      Required_Bytes  : out Natural;
      Required_Count  : out Natural) return Boolean;

   function Prepare_Theme_Frame_Operation
     (R             : in out Renderer;
      Object        : Image_Object_Access;
      Header        : Terminal.App.Graphics.Graphics_Header;
      Data          : Terminal.App.Graphics.Graphics_Data_Preview;
      Target_Number : Positive;
      New_Frame     : Boolean;
      Operation     : out Theme_Operation_Access) return Boolean;

   function Prepare_Theme_Composition_Operation
     (R           : in out Renderer;
      Object      : Image_Object_Access;
      Header      : Terminal.App.Graphics.Graphics_Header;
      Source      : Positive;
      Target      : Positive;
      Width       : Natural;
      Height      : Natural;
      Operation   : out Theme_Operation_Access) return Boolean;

   function Replay_Theme_Operations
     (R      : in out Renderer;
      Object : Image_Object_Access) return Boolean;
end Terminal.App.Renderer.Theme_State;

with Terminal.App.Graphics_Transport;
with Terminal.App.ITerm2_Files;
with Terminal.Core;

package Terminal.App.Renderer.Graphics is
   procedure Set_Resource_Limits
     (R      : in out Renderer;
      Limits : Graphics_Resource_Limits);
   function Resource_Limits (R : Renderer) return Graphics_Resource_Limits;

   procedure Set_Access_Policy
     (R      : in out Renderer;
      Policy : Terminal.App.Graphics_Transport.Access_Policy);
   function Access_Policy
     (R : Renderer) return Terminal.App.Graphics_Transport.Access_Policy;

   procedure Set_ITerm2_Download_Policy
     (R      : in out Renderer;
      Policy : Terminal.App.ITerm2_Files.Download_Policy);
   function ITerm2_Download_Policy
     (R : Renderer) return Terminal.App.ITerm2_Files.Download_Policy;

   procedure Stage_Event
     (R       : in out Renderer;
      Event   : Terminal.Core.Graphics_Event;
      Payload : String);
   procedure Commit_Visible_Events (R : in out Renderer);
   procedure Commit_Offscreen_Events (R : in out Renderer);
   procedure Release_Stream
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID);
   function Result
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event)
      return Terminal.Core.Kitty_Graphics_Result;
   function Event_Processed
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event) return Boolean;
   function Animation_Frame_Due (R : Renderer) return Boolean;
end Terminal.App.Renderer.Graphics;

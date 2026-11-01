package body Terminal.App.Renderer.Graphics is
   procedure Set_Resource_Limits
     (R      : in out Renderer;
      Limits : Graphics_Resource_Limits) is
   begin
      Set_Graphics_Resource_Limits (R, Limits);
   end Set_Resource_Limits;

   function Resource_Limits (R : Renderer) return Graphics_Resource_Limits is
     (Graphics_Resource_Limit (R));

   procedure Set_Access_Policy
     (R      : in out Renderer;
      Policy : Terminal.App.Graphics_Transport.Access_Policy) is
   begin
      Set_Graphics_Access_Policy (R, Policy);
   end Set_Access_Policy;

   function Access_Policy
     (R : Renderer) return Terminal.App.Graphics_Transport.Access_Policy is
     (Graphics_Access_Policy (R));

   procedure Set_ITerm2_Download_Policy
     (R      : in out Renderer;
      Policy : Terminal.App.ITerm2_Files.Download_Policy) is
   begin
      Terminal.App.Renderer.Set_ITerm2_Download_Policy (R, Policy);
   end Set_ITerm2_Download_Policy;

   function ITerm2_Download_Policy
     (R : Renderer) return Terminal.App.ITerm2_Files.Download_Policy is
     (Terminal.App.Renderer.ITerm2_Download_Policy (R));

   procedure Stage_Event
     (R       : in out Renderer;
      Event   : Terminal.Core.Graphics_Event;
      Payload : String) is
   begin
      Stage_Graphics_Event (R, Event, Payload);
   end Stage_Event;

   procedure Commit_Visible_Events (R : in out Renderer) is
   begin
      Commit_Graphics_Events (R);
   end Commit_Visible_Events;

   procedure Commit_Offscreen_Events (R : in out Renderer) is
   begin
      Commit_Offscreen_Graphics_Events (R);
   end Commit_Offscreen_Events;

   procedure Release_Stream
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID) is
   begin
      Release_Graphics_Stream (R, Stream_ID);
   end Release_Stream;

   function Result
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event)
      return Terminal.Core.Kitty_Graphics_Result is
     (Graphics_Result (R, Event));

   function Event_Processed
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event) return Boolean is
     (Graphics_Event_Processed (R, Event));

   function Animation_Frame_Due (R : Renderer) return Boolean is
     (Terminal.App.Renderer.Animation_Frame_Due (R));
end Terminal.App.Renderer.Graphics;

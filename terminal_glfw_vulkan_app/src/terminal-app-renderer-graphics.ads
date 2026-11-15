with Terminal.App.Graphics_Transport;
with Terminal.App.ITerm2_Files;
with Terminal.App.Renderer.Event_Stage_Types;
with Terminal.Core;

package Terminal.App.Renderer.Graphics is
   type Resource_Limit_Update_Status is
     (Limits_Applied, Limits_Applied_Overcommitted);
   procedure Set_Resource_Limits
     (R      : in out Renderer;
      Limits : Graphics_Resource_Limits;
      Status : out Resource_Limit_Update_Status);
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

   subtype Stage_Event_Status is Event_Stage_Types.Status;
   Stage_Stored : constant Stage_Event_Status := Event_Stage_Types.Stored;
   Stage_Already_Stored : constant Stage_Event_Status :=
     Event_Stage_Types.Already_Stored;
   Stage_Not_Required : constant Stage_Event_Status :=
     Event_Stage_Types.Not_Required;
   Stage_Invalid_Event : constant Stage_Event_Status :=
     Event_Stage_Types.Invalid_Event;
   Stage_Quota_Exceeded : constant Stage_Event_Status :=
     Event_Stage_Types.Quota_Exceeded;
   Stage_Allocation_Failed : constant Stage_Event_Status :=
     Event_Stage_Types.Allocation_Failed;

   function Stage_Event
     (R       : in out Renderer;
      Event   : Terminal.Core.Graphics_Event;
      Payload : String) return Stage_Event_Status;
   function Stage_Event
     (R     : in out Renderer;
      T     : Terminal.Core.Terminal;
      Event : Terminal.Core.Graphics_Event) return Stage_Event_Status;
   procedure Commit_Visible_Events (R : in out Renderer);
   procedure Commit_Offscreen_Event
     (R     : in out Renderer;
      Event : Terminal.Core.Graphics_Event);
   procedure Release_Stream
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID);
   function Result
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event)
      return Terminal.Core.Graphics_Completion;
   function Event_Processed
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event) return Boolean;
   function Rejection_Result
     (Event : Terminal.Core.Graphics_Event;
      Code  : Terminal.Core.Graphics_Completion_Code)
      return Terminal.Core.Graphics_Completion;
   function Animation_Frame_Due (R : in out Renderer) return Boolean;
   function Animation_Wait_Duration
     (R       : in out Renderer;
      Maximum : Duration) return Duration;
end Terminal.App.Renderer.Graphics;

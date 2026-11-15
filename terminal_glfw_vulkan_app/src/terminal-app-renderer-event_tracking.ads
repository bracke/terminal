with Terminal.App.Renderer.Event_Stage_Types;

private package Terminal.App.Renderer.Event_Tracking is
   function Stage
     (R       : in out Renderer;
      Event   : Terminal.Core.Graphics_Event;
      Payload : String)
      return Terminal.App.Renderer.Event_Stage_Types.Status;
   procedure With_Complete_Event_Text
     (R     : in out Renderer;
      Event : Terminal.Core.Graphics_Event;
      Process : not null access procedure (Text : String));
   function Payload_Available
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event) return Boolean;
   function Already_Processed
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event) return Boolean;
   function Can_Remember
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event) return Boolean;
   procedure Remember
     (R      : in out Renderer;
      Event  : Terminal.Core.Graphics_Event;
      Result : Terminal.Core.Graphics_Completion);
   procedure Clear (R : in out Renderer);
   procedure Remove
     (R              : in out Renderer;
      Stream_ID      : Terminal.Core.Graphics_Stream_ID;
      Sequence       : Terminal.Core.Graphics_Event_Sequence;
      Match_Sequence : Boolean);
   procedure Release (Object : in out Renderer_Graphics_State);
end Terminal.App.Renderer.Event_Tracking;

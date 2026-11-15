with Terminal.App.Renderer.Animations;
with Terminal.App.Renderer.Event_Tracking;
with Terminal.App.Renderer.Frame_Lifecycle;
with Terminal.App.Renderer.Image_Objects;
with Terminal.App.Renderer.Placement_State;
with Terminal.Common.Counters;

package body Terminal.App.Renderer.Graphics is
   use type Terminal.Core.Graphics_ID;
   use type Terminal.Core.Graphics_Event_Sequence;
   use type Terminal.Core.Graphics_Stream_ID;
   use type Terminal.Core.Graphics_Protocol_Kind;
   use type Interfaces.Unsigned_64;
   use type Image_Object_Access;
   use type Staged_Graphics_Event_Access;

   procedure Set_Resource_Limits
     (R      : in out Renderer;
      Limits : Graphics_Resource_Limits;
      Status : out Resource_Limit_Update_Status)
   is
      function Object_Exceeds_Item_Limits
        (Object : not null Image_Object_Access) return Boolean is
        (Terminal.App.Image_Store.Owned_Bytes (Object.all) >
           Limits.Per_Image_Bytes
         or else Terminal.App.Image_Store.Pixel_Width (Object.all) >
           Limits.Pixel_Dimension
         or else Terminal.App.Image_Store.Pixel_Height (Object.all) >
           Limits.Pixel_Dimension);

      function Aggregate_Image_State_Exceeds_Limits return Boolean is
        (Terminal.App.Image_Store.Object_Count
           (R.Graphics_State.Resources.Image_Objects) > Limits.Image_Objects
         or else Terminal.App.Image_Store.Byte_Count
           (R.Graphics_State.Resources.Image_Objects) > Limits.Image_Bytes
         or else Terminal.App.Image_Store.Animation_Frame_Count
           (R.Graphics_State.Resources.Image_Objects) >
             Limits.Animation_Frames);

      function Any_Object_Exceeds_Item_Limits return Boolean is
         Object : Image_Object_Access;
      begin
         Object := Terminal.App.Image_Store.First
           (R.Graphics_State.Resources.Image_Objects);
         while Object /= null loop
            if Object_Exceeds_Item_Limits (Object) then
               return True;
            end if;
            Object := Terminal.App.Image_Store.Next_Object (Object);
         end loop;
         return False;
      end Any_Object_Exceeds_Item_Limits;

      function Evict_One_Oversized_Unplaced_Image return Boolean is
         Object : Image_Object_Access := Terminal.App.Image_Store.First
           (R.Graphics_State.Resources.Image_Objects);
         Candidate : Image_Object_Access := null;
      begin
         while Object /= null loop
            if Object_Exceeds_Item_Limits (Object)
              and then not Terminal.App.Renderer.Placement_State.
                Has_Image_Placement (R, Object)
              and then
                (Candidate = null
                 or else Object.Storage_Order < Candidate.Storage_Order)
            then
               Candidate := Object;
            end if;
            Object := Terminal.App.Image_Store.Next_Object (Object);
         end loop;
         if Candidate = null then
            return False;
         end if;
         Image_Objects.Delete_By_Storage_Order
           (R, Candidate.Stream_ID, Candidate.Storage_Order);
         Terminal.Common.Counters.Increment_Saturating
           (R.Graphics_State.Telemetry.Image_Eviction_Count);
         return True;
      end Evict_One_Oversized_Unplaced_Image;

      Overcommitted : Boolean;
   begin
      Frame_Lifecycle.Reset (R);
      R.Graphics_State.Policy.Limits := Limits;
      Terminal.App.Vulkan_Submit.Set_Image_Atlas_Limits
        (R.Frame_State.Batch,
         (Bytes     => Limits.GPU_Atlas_Bytes,
          Dimension => Limits.GPU_Atlas_Dimension));
      --  Per-object violations can only be repaired by removing the object
      --  that violates the limit.  Evicting unrelated valid images cannot
      --  make progress and can otherwise destroy useful retained content.
      while Any_Object_Exceeds_Item_Limits
        and then Evict_One_Oversized_Unplaced_Image
      loop
         null;
      end loop;
      while Aggregate_Image_State_Exceeds_Limits
        and then Image_Objects.Evict_One_Unplaced (R, 0, 0)
      loop
         null;
      end loop;
      Overcommitted :=
        Aggregate_Image_State_Exceeds_Limits
        or else Any_Object_Exceeds_Item_Limits
        or else Terminal.App.Renderer.Placement_State.Stored_Placement_Count
          (R) > Limits.Placements;
      Status :=
        (if Overcommitted
         then Limits_Applied_Overcommitted
         else Limits_Applied);
   end Set_Resource_Limits;

   function Resource_Limits (R : Renderer) return Graphics_Resource_Limits is
     (R.Graphics_State.Policy.Limits);

   procedure Set_Access_Policy
     (R      : in out Renderer;
      Policy : Terminal.App.Graphics_Transport.Access_Policy) is
   begin
      R.Graphics_State.Policy.Access_Policy := Policy;
   end Set_Access_Policy;

   function Access_Policy
     (R : Renderer) return Terminal.App.Graphics_Transport.Access_Policy is
     (R.Graphics_State.Policy.Access_Policy);

   procedure Set_ITerm2_Download_Policy
     (R      : in out Renderer;
      Policy : Terminal.App.ITerm2_Files.Download_Policy) is
   begin
      R.Graphics_State.Policy.ITerm2_Downloads := Policy;
   end Set_ITerm2_Download_Policy;

   function ITerm2_Download_Policy
     (R : Renderer) return Terminal.App.ITerm2_Files.Download_Policy is
     (R.Graphics_State.Policy.ITerm2_Downloads);

   function Stage_Event
     (R       : in out Renderer;
      Event   : Terminal.Core.Graphics_Event;
      Payload : String) return Stage_Event_Status
   is (Event_Tracking.Stage (R, Event, Payload));

   function Stage_Event
     (R     : in out Renderer;
      T     : Terminal.Core.Terminal;
      Event : Terminal.Core.Graphics_Event) return Stage_Event_Status
   is
      Status : Stage_Event_Status := Stage_Invalid_Event;
      Visited : Boolean;
      procedure Stage (Payload : String) is
      begin
         Status := Event_Tracking.Stage (R, Event, Payload);
      end Stage;
   begin
      Terminal.Core.Visit_Graphics_Event_Payload
        (T, Event, Stage'Access, Visited);
      return (if Visited then Status else Stage_Invalid_Event);
   end Stage_Event;

   procedure Commit_Visible_Events (R : in out Renderer) is
   begin
      Commit_Graphics_Events (R);
   end Commit_Visible_Events;

   procedure Commit_Offscreen_Event
     (R     : in out Renderer;
      Event : Terminal.Core.Graphics_Event) is
   begin
      Commit_Offscreen_Graphics_Event (R, Event);
   end Commit_Offscreen_Event;

   procedure Release_Stream
     (R         : in out Renderer;
      Stream_ID : Terminal.Core.Graphics_Stream_ID) is
   begin
      Release_Graphics_Stream (R, Stream_ID);
   end Release_Stream;

   function Processed_Event_Index
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event)
      return Natural
   is
   begin
      for I in 1 .. R.Graphics_State.Transaction.Processed_Event_Count loop
         if R.Graphics_State.Transaction.Processed_Events (I).Stream_ID = Event.Stream_ID
           and then R.Graphics_State.Transaction.Processed_Events (I).Sequence = Event.Sequence
         then
            return I;
         end if;
      end loop;
      return 0;
   end Processed_Event_Index;

   function Result
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event)
      return Terminal.Core.Graphics_Completion
   is
      Index : constant Natural := Processed_Event_Index (R, Event);
   begin
      return
        (if Index = 0
         then (others => <>)
         else R.Graphics_State.Transaction.Processed_Events (Index).Result);
   end Result;

   function Event_Processed
     (R     : Renderer;
      Event : Terminal.Core.Graphics_Event) return Boolean
   is (Processed_Event_Index (R, Event) /= 0);

   function Rejection_Result
     (Event : Terminal.Core.Graphics_Event;
      Code  : Terminal.Core.Graphics_Completion_Code)
      return Terminal.Core.Graphics_Completion
   is
      Result : Terminal.Core.Graphics_Completion :=
        (Code => Code, others => <>);
   begin
      if Event.Protocol = Terminal.Core.Kitty_Graphics then
         declare
            Header : constant Terminal.App.Graphics.Graphics_Header :=
              Terminal.App.Graphics.Header (Event);
         begin
            Result :=
              Terminal.App.Graphics.Kitty_Result_From_Header
                (Header, Code);
         end;
      end if;
      return Result;
   end Rejection_Result;

   function Animation_Frame_Due (R : in out Renderer) return Boolean is
     (Terminal.App.Renderer.Animations.Frame_Due (R));

   function Animation_Wait_Duration
     (R       : in out Renderer;
      Maximum : Duration) return Duration is
     (Terminal.App.Renderer.Animations.Wait_Duration
        (R, Ada.Real_Time.Clock, Maximum));
end Terminal.App.Renderer.Graphics;

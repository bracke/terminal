with Terminal.App.Image_Store.Frames;

package body Terminal.App.Image_Store.Playback_State is
   procedure Require_Object (Object : Image_Object_Access) is
   begin
      if Object = null then
         raise Program_Error with "playback state requires an image object";
      end if;
   end Require_Object;

   function Root_Gap_MS (Object : Image_Object) return Integer is
     (Object.State.Root_Gap_MS);
   function Current_Frame (Object : Image_Object) return Positive is
     (Object.State.Current_Frame);
   function Playback (Object : Image_Object) return Animation_Playback_State is
     (Object.State.Playback);
   function Loop_Count (Object : Image_Object) return Positive is
     (Object.State.Loop_Count);
   function Loops_Completed (Object : Image_Object) return Natural is
     (Object.State.Loops_Completed);
   function Next_Frame_At (Object : Image_Object) return Ada.Real_Time.Time is
     (Object.State.Next_Frame_At);
   function Deadline_Set (Object : Image_Object) return Boolean is
     (Object.State.Deadline_Set);

   function Value (Object : Image_Object) return State is
     (Root_Gap_MS     => Object.State.Root_Gap_MS,
      Current_Frame   => Object.State.Current_Frame,
      Mode            => Object.State.Playback,
      Loop_Count      => Object.State.Loop_Count,
      Loops_Completed => Object.State.Loops_Completed,
      Next_Frame_At   => Object.State.Next_Frame_At,
      Deadline_Set    => Object.State.Deadline_Set);

   procedure Replace (Object : Image_Object_Access; Value : State) is
   begin
      Require_Object (Object);
      if not Terminal.App.Image_Store.Frames.Exists
        (Object, Value.Current_Frame)
      then
         raise Constraint_Error with "current animation frame does not exist";
      elsif Value.Mode = Animation_Stopped and then Value.Deadline_Set then
         raise Constraint_Error with
           "a stopped animation cannot retain a playback deadline";
      elsif Value.Loop_Count = 1 and then Value.Loops_Completed /= 0 then
         raise Constraint_Error with
           "an infinitely looping animation cannot count completed loops";
      elsif Value.Loop_Count > 1
        and then Value.Loops_Completed >= Value.Loop_Count
      then
         raise Constraint_Error with
           "completed animation loops must be below the loop limit";
      end if;
      Object.State.Root_Gap_MS := Value.Root_Gap_MS;
      Object.State.Current_Frame := Value.Current_Frame;
      Object.State.Playback := Value.Mode;
      Object.State.Loop_Count := Value.Loop_Count;
      Object.State.Loops_Completed := Value.Loops_Completed;
      Object.State.Next_Frame_At := Value.Next_Frame_At;
      Object.State.Deadline_Set := Value.Deadline_Set;
   end Replace;

   procedure Reset
     (Object      : Image_Object_Access;
      Root_Gap_MS : Integer := 0) is
   begin
      Replace
        (Object,
         (Root_Gap_MS => Root_Gap_MS,
          others      => <>));
   end Reset;
end Terminal.App.Image_Store.Playback_State;

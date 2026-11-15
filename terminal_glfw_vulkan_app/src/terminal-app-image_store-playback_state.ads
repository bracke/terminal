with Ada.Real_Time;

package Terminal.App.Image_Store.Playback_State is
   type State is record
      Root_Gap_MS     : Integer := 0;
      Current_Frame   : Positive := 1;
      Mode            : Animation_Playback_State := Animation_Stopped;
      Loop_Count      : Positive := 1;
      Loops_Completed : Natural := 0;
      Next_Frame_At   : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Deadline_Set    : Boolean := False;
   end record;

   function Value (Object : Image_Object) return State;
   procedure Replace (Object : Image_Object_Access; Value : State);
   procedure Reset
     (Object      : Image_Object_Access;
      Root_Gap_MS : Integer := 0);

   function Root_Gap_MS (Object : Image_Object) return Integer;
   function Current_Frame (Object : Image_Object) return Positive;
   function Playback (Object : Image_Object) return Animation_Playback_State;
   function Loop_Count (Object : Image_Object) return Positive;
   function Loops_Completed (Object : Image_Object) return Natural;
   function Next_Frame_At (Object : Image_Object) return Ada.Real_Time.Time;
   function Deadline_Set (Object : Image_Object) return Boolean;

end Terminal.App.Image_Store.Playback_State;

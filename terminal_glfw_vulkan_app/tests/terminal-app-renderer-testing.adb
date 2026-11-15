with Terminal.App.Image_Data;
with Terminal.Core.Snapshot_Editing;
with Ada.Real_Time;
with Ada.Unchecked_Deallocation;
with AUnit.Assertions;
with Interfaces;

with Terminal.App.Frame_Image_Storage;
with Terminal.App.Graphics;
with Terminal.App.Image_Placements;
with Terminal.App.Image_Placements.Testing;
with Terminal.App.Image_Store;
with Terminal.App.Image_Store.Testing;
with Terminal.App.Image_Store.Themes;
with Terminal.App.Owned_Image_Data;
with Terminal.App.Placeholder_Index;
with Terminal.App.Renderer.Animations;
with Terminal.App.Renderer.Event_Tracking;
with Terminal.App.Renderer.Frame_Lifecycle;
with Terminal.App.Renderer.Image_Objects;
with Terminal.App.Renderer.Placement_State;
with Terminal.Common.Bytes;
with Terminal.Core.Snapshot_Testing;

package body Terminal.App.Renderer.Testing is
   function Last_Frame
     (R : Renderer) return Terminal.App.Render_Model.Frame_Commands is
     (Terminal.App.Renderer.Last_Frame (R));

   procedure Fail_Image_Allocation_After
     (R        : in out Renderer;
      Attempts : Natural) is
   begin
      Terminal.App.Image_Store.Testing.Fail_Allocation_After
        (R.Graphics_State.Resources.Allocation_Control, Attempts);
   end Fail_Image_Allocation_After;

   function Submission_Render_Status
     (Status : Terminal.App.Vulkan_Submit.Build_Status) return Render_Status is
     (Terminal.App.Renderer.Submission_Render_Status (Status));

   function Placement_Index_Is_Dirty (R : Renderer) return Boolean is
     (R.Frame_State.Placement_Index_Dirty);

   function Animation_Frame_Due_At
     (R   : in out Renderer;
      Now : Ada.Real_Time.Time) return Boolean is
     (Terminal.App.Renderer.Animations.Frame_Due (R, Now));

   function Animation_Wait_Duration_At
     (R       : in out Renderer;
      Now     : Ada.Real_Time.Time;
      Maximum : Duration) return Duration is
     (Terminal.App.Renderer.Animations.Wait_Duration (R, Now, Maximum));

   procedure Advance_Animations_At
     (R   : in out Renderer;
      Now : Ada.Real_Time.Time) is
   begin
      Terminal.App.Renderer.Animations.Advance (R, Now);
   end Advance_Animations_At;

   procedure Hide_All_Graphics_Views (R : in out Renderer) is
   begin
      R.Graphics_State.Visible_Views := (others => <>);
      R.Graphics_State.Visible_View_Count := 0;
      R.Graphics_State.Animation_Schedule_Valid := False;
   end Hide_All_Graphics_Views;

end Terminal.App.Renderer.Testing;

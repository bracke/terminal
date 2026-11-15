with Ada.Real_Time;
with Terminal.App.Vulkan_Submit;

package Terminal.App.Renderer.Testing is
   --  The returned view borrows renderer and atlas storage and is valid only
   --  until the next Render/Render_App, Set_Theme,
   --  Set_Graphics_Resource_Limits, Release_Graphics_Stream, or Finalize call
   --  for R.
   function Last_Frame
     (R : Renderer) return Terminal.App.Render_Model.Frame_Commands;

   --  Reject the Nth subsequent encoded-source copy.
   procedure Fail_Image_Allocation_After
     (R        : in out Renderer;
      Attempts : Natural);

   function Submission_Render_Status
     (Status : Terminal.App.Vulkan_Submit.Build_Status) return Render_Status;

   function Placement_Index_Is_Dirty (R : Renderer) return Boolean;

   function Animation_Frame_Due_At
     (R   : in out Renderer;
      Now : Ada.Real_Time.Time) return Boolean;
   function Animation_Wait_Duration_At
     (R       : in out Renderer;
      Now     : Ada.Real_Time.Time;
      Maximum : Duration) return Duration;
   procedure Advance_Animations_At
     (R   : in out Renderer;
      Now : Ada.Real_Time.Time);
   procedure Hide_All_Graphics_Views (R : in out Renderer);
end Terminal.App.Renderer.Testing;

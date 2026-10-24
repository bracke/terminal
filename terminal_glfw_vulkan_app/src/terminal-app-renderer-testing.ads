package Terminal.App.Renderer.Testing is
   --  The returned view borrows renderer and atlas storage and is valid only
   --  until the next Render/Render_App, Release_Graphics_Stream, or Finalize
   --  call for R.  This white-box accessor is not a production API.
   function Last_Frame
     (R : Renderer) return Terminal.App.Render_Model.Frame_Commands;

   --  Reject the Nth subsequent encoded-source copy.  This is deliberately a
   --  child package so production users of Renderer do not see test controls.
   procedure Fail_Image_Allocation_After
     (R      : in out Renderer;
      Attempts : Natural);
end Terminal.App.Renderer.Testing;

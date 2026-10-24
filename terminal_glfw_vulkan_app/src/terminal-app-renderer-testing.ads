package Terminal.App.Renderer.Testing is
   --  Reject the Nth subsequent encoded-source copy.  This is deliberately a
   --  child package so production users of Renderer do not see test controls.
   procedure Fail_Image_Allocation_After
     (R      : in out Renderer;
      Attempts : Natural);
end Terminal.App.Renderer.Testing;

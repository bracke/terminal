with Terminal.App.Image_Store;

package body Terminal.App.Renderer.Testing is
   procedure Fail_Image_Allocation_After
     (R      : in out Renderer;
      Attempts : Natural) is
   begin
      Terminal.App.Image_Store.Fail_Allocation_After
        (R.Image_Allocation_Control, Attempts);
   end Fail_Image_Allocation_After;
end Terminal.App.Renderer.Testing;

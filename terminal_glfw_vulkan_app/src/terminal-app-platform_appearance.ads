with System;

package Terminal.App.Platform_Appearance is
   type Blur_Status is
     (Blur_Applied, Blur_Unsupported, Blur_Invalid_Window, Blur_Failed);

   --  Window is the borrowed GLFWwindow pointer returned by Native_Handle.
   procedure Set_Background_Blur
     (Window  : System.Address;
      Enabled : Boolean;
      Status  : out Blur_Status);
end Terminal.App.Platform_Appearance;

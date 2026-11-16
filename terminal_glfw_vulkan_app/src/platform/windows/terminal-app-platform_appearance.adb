with Interfaces.C;
with System;

package body Terminal.App.Platform_Appearance is
   function Native_Set_Blur
     (Window  : System.Address;
      Enabled : Interfaces.C.int) return Interfaces.C.int
   with Import, Convention => C,
        External_Name => "terminal_native_set_background_blur";

   procedure Set_Background_Blur
     (Window  : System.Address;
      Enabled : Boolean;
      Status  : out Blur_Status)
   is
      Result : constant Interfaces.C.int :=
        Native_Set_Blur (Window, (if Enabled then 1 else 0));
   begin
      Status :=
        (case Result is
           when 0 => Blur_Applied,
           when 1 => Blur_Unsupported,
           when 2 => Blur_Invalid_Window,
           when others => Blur_Failed);
   end Set_Background_Blur;
end Terminal.App.Platform_Appearance;

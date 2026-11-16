package Terminal.App.Global_Hotkey is
   type Register_Status is
     (Registered, Disabled, Invalid_Binding, Unsupported, Registration_Failed);

   procedure Register (Binding : String; Status : out Register_Status);
   procedure Unregister;
   function Poll return Boolean;
end Terminal.App.Global_Hotkey;

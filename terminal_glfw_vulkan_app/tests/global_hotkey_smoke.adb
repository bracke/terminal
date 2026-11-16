with AUnit.Assertions;
with Terminal.App.Global_Hotkey;

procedure Global_Hotkey_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Global_Hotkey.Register_Status;
   Status : Terminal.App.Global_Hotkey.Register_Status;
begin
   Terminal.App.Global_Hotkey.Register ("", Status);
   Assert (Status = Terminal.App.Global_Hotkey.Disabled,
           "empty global hotkey disables registration");
   Terminal.App.Global_Hotkey.Register ("ctrl+alt+bad+key", Status);
   Assert (Status = Terminal.App.Global_Hotkey.Invalid_Binding,
           "ambiguous global hotkey is rejected before display access");
   Assert (not Terminal.App.Global_Hotkey.Poll,
           "disabled global hotkey has no pending activation");
   Terminal.App.Global_Hotkey.Unregister;
end Global_Hotkey_Smoke;

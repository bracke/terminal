with Ada.Text_IO;
with System;
with Terminal.App.Platform_IME;

procedure Platform_IME_Smoke is
   use type Terminal.App.Platform_IME.Install_Status;
   Status : Terminal.App.Platform_IME.Install_Status;
   Code_Point : Wide_Wide_Character;
   Available : Boolean;
begin
   Terminal.App.Platform_IME.Initialize (System.Null_Address, Status);
   pragma Assert (Status = Terminal.App.Platform_IME.Unsupported);
   pragma Assert (not Terminal.App.Platform_IME.Active);
   pragma Assert (not Terminal.App.Platform_IME.Preedit_Active);
   pragma Assert (Terminal.App.Platform_IME.Preedit_Text = "");
   pragma Assert (Terminal.App.Platform_IME.Status_Label = "");
   pragma Assert (not Terminal.App.Platform_IME.Suppress_Next_GLFW_Character);
   Terminal.App.Platform_IME.Poll_Commit (Code_Point, Available);
   pragma Assert (not Available);
   Terminal.App.Platform_IME.Set_Focused (True);
   Terminal.App.Platform_IME.Set_Cursor_Rectangle (10, 20, 8, 16);
   Terminal.App.Platform_IME.Finalize;
   Terminal.App.Platform_IME.Finalize;
   Ada.Text_IO.Put_Line ("platform ime smoke: ok");
end Platform_IME_Smoke;

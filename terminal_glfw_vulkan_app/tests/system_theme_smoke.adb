with Ada.Environment_Variables;
with AUnit.Assertions;
with System;

with Terminal.App.Platform_Appearance;
with Terminal.App.System_Theme;

procedure System_Theme_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.System_Theme.Preference;
   use type Terminal.App.Platform_Appearance.Blur_Status;
   Name : constant String := "BRACKE_TERMINAL_COLOR_SCHEME";
   Was_Set : constant Boolean := Ada.Environment_Variables.Exists (Name);
   Previous : constant String :=
     (if Was_Set then Ada.Environment_Variables.Value (Name) else "");

   procedure Restore is
   begin
      if Was_Set then
         Ada.Environment_Variables.Set (Name, Previous);
      else
         Ada.Environment_Variables.Clear (Name);
      end if;
   end Restore;
begin
   declare
      Status : Terminal.App.Platform_Appearance.Blur_Status;
   begin
      Terminal.App.Platform_Appearance.Set_Background_Blur
        (System.Null_Address, True, Status);
      Assert
        (Status = Terminal.App.Platform_Appearance.Blur_Invalid_Window,
         "native blur rejects a missing window");
   end;
   Ada.Environment_Variables.Set (Name, "light");
   Assert
     (Terminal.App.System_Theme.Current =
        Terminal.App.System_Theme.Prefer_Light,
      "explicit light system-theme preference");
   Ada.Environment_Variables.Set (Name, "Adwaita:dark");
   Assert
     (Terminal.App.System_Theme.Current =
        Terminal.App.System_Theme.Prefer_Dark,
      "toolkit-style dark system-theme preference");
   Ada.Environment_Variables.Set (Name, "invalid");
   Assert
     (Terminal.App.System_Theme.Current = Terminal.App.System_Theme.Unknown,
      "invalid explicit system-theme preference fails closed");
   Assert
     (Terminal.App.System_Theme.Image
        (Terminal.App.System_Theme.Prefer_Dark) = "dark",
      "system-theme diagnostic image");
   Restore;
exception
   when others =>
      Restore;
      raise;
end System_Theme_Smoke;

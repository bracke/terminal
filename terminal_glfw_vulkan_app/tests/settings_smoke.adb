with AUnit.Assertions;
with Terminal.App.Config;
with Terminal.App.Settings;
with Terminal.App.Theme;
with Terminal.Common;

procedure Settings_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Theme.Theme_Name;
   Config : Terminal.App.Config.Config;
   Settings : Terminal.App.Settings.State;
   Boolean_Settings : Terminal.App.Settings.State;
   Changed : Boolean;
   Initial_Size : constant Positive := Config.Font_Pixel_Size;
   Line : constant String := "theme = light";
begin
   Terminal.App.Settings.Enter (Settings);
   Assert (Terminal.App.Settings.Active (Settings), "settings enters");
   Terminal.App.Settings.Move (Settings, 2);
   Terminal.App.Settings.Adjust (Settings, Config, 1, Changed);
   Assert (Changed, "font setting changes");
   Assert (Config.Font_Pixel_Size = Initial_Size + 1, "font size increments");
   Terminal.App.Settings.Adjust
     (Settings, Config, Integer'First, Changed);
   Assert
     (Changed
      and then Config.Font_Pixel_Size =
        Terminal.App.Config.Min_Font_Pixel_Size,
      "font adjustment clamps without overflowing");
   Terminal.App.Settings.Adjust
     (Settings, Config, Integer'First, Changed);
   Assert (not Changed, "clamped font adjustment reports no change");

   Terminal.App.Settings.Enter (Boolean_Settings);
   Terminal.App.Settings.Move (Boolean_Settings, 11);
   Terminal.App.Settings.Adjust
     (Boolean_Settings, Config, 0, Changed);
   Assert
     (not Changed and then Config.Desktop_Notifications,
      "zero adjustment does not toggle a Boolean setting");
   Terminal.App.Settings.Adjust
     (Boolean_Settings, Config, Integer'Last, Changed);
   Assert
     (Changed and then not Config.Desktop_Notifications,
      "nonzero Boolean adjustment toggles once without overflowing");

   for I in 1 .. 14 loop
      Terminal.App.Settings.Move (Settings, 1);
   end loop;
   Terminal.App.Settings.Begin_Edit (Settings);
   Assert (Terminal.App.Settings.Editing (Settings), "config line editor enters");
   for Ch of Line loop
      Terminal.App.Settings.Append
        (Settings, Terminal.Common.Code_Point (Character'Pos (Ch)));
   end loop;
   Terminal.App.Settings.Apply_Edit (Settings, Config, Changed);
   Assert (Changed, "valid config line accepted");
   Assert
     (Config.Color_Theme = Terminal.App.Theme.Light,
      "config line updates theme");
   Terminal.App.Settings.Leave (Settings);
   Assert (not Terminal.App.Settings.Active (Settings), "settings leaves");
end Settings_Smoke;

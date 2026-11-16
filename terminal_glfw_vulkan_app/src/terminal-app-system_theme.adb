with Ada.Characters.Handling;
with Ada.Environment_Variables;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;

package body Terminal.App.System_Theme is
   function Lower (Value : String) return String is
     (Ada.Characters.Handling.To_Lower
        (Ada.Strings.Fixed.Trim (Value, Ada.Strings.Both)));

   function Classified (Value : String) return Preference is
      Text : constant String := Lower (Value);
   begin
      if Text = "light" or else Text = "prefer-light" then
         return Prefer_Light;
      elsif Text = "dark" or else Text = "prefer-dark"
        or else Ada.Strings.Fixed.Index (Text, "-dark") > 0
        or else Ada.Strings.Fixed.Index (Text, ":dark") > 0
      then
         return Prefer_Dark;
      else
         return Unknown;
      end if;
   end Classified;

   function Config_Home return String is
   begin
      if Ada.Environment_Variables.Exists ("XDG_CONFIG_HOME") then
         return Ada.Environment_Variables.Value ("XDG_CONFIG_HOME");
      elsif Ada.Environment_Variables.Exists ("HOME") then
         return Ada.Environment_Variables.Value ("HOME") & "/.config";
      else
         return "";
      end if;
   exception
      when others => return "";
   end Config_Home;

   function From_GTK_File (Path : String) return Preference is
      File : Ada.Text_IO.File_Type;
      Line : String (1 .. 1_024);
      Last : Natural;
   begin
      if Path = "" then return Unknown; end if;
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Ada.Text_IO.Get_Line (File, Line, Last);
         if Last > 0 then
            declare
               Text : constant String := Lower (Line (1 .. Last));
               Equal : constant Natural := Ada.Strings.Fixed.Index (Text, "=");
            begin
               if Equal > 0 then
                  declare
                     Key : constant String := Ada.Strings.Fixed.Trim
                       (Text (Text'First .. Equal - 1), Ada.Strings.Both);
                     Value : constant String := Ada.Strings.Fixed.Trim
                       (Text (Equal + 1 .. Text'Last), Ada.Strings.Both);
                  begin
                     if Key = "gtk-application-prefer-dark-theme" then
                        if Value = "1" or else Value = "true" then
                           Ada.Text_IO.Close (File);
                           return Prefer_Dark;
                        end if;
                     elsif Key = "gtk-theme-name" then
                        declare
                           Result : constant Preference := Classified (Value);
                        begin
                           if Result /= Unknown then
                              Ada.Text_IO.Close (File);
                              return Result;
                           end if;
                        end;
                     end if;
                  end;
               end if;
            end;
         end if;
      end loop;
      Ada.Text_IO.Close (File);
      return Unknown;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then Ada.Text_IO.Close (File); end if;
         return Unknown;
   end From_GTK_File;

   function From_KDE_File (Path : String) return Preference is
      File : Ada.Text_IO.File_Type;
      Line : String (1 .. 1_024);
      Last : Natural;
      In_Colors : Boolean := False;
   begin
      if Path = "" then return Unknown; end if;
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Ada.Text_IO.Get_Line (File, Line, Last);
         if Last > 0 then
            declare
               Text : constant String := Lower (Line (1 .. Last));
            begin
               if Text'Length > 2 and then Text (Text'First) = '[' then
                  In_Colors := Text = "[colors:window]";
               elsif In_Colors and then Text'Length > 11
                 and then Text (Text'First .. Text'First + 10) = "background="
               then
                  declare
                     Value : constant String :=
                       Text (Text'First + 11 .. Text'Last);
                     First_Comma : constant Natural :=
                       Ada.Strings.Fixed.Index (Value, ",");
                     Second_Comma : constant Natural :=
                       (if First_Comma = 0 then 0
                        else Ada.Strings.Fixed.Index
                          (Value, ",", From => First_Comma + 1));
                  begin
                     if First_Comma > 0 and then Second_Comma > First_Comma then
                        declare
                           R : constant Natural := Natural'Value
                             (Value (Value'First .. First_Comma - 1));
                           G : constant Natural := Natural'Value
                             (Value (First_Comma + 1 .. Second_Comma - 1));
                           B : constant Natural := Natural'Value
                             (Value (Second_Comma + 1 .. Value'Last));
                        begin
                           Ada.Text_IO.Close (File);
                           return
                             (if R * 299 + G * 587 + B * 114 < 128_000
                              then Prefer_Dark else Prefer_Light);
                        end;
                     end if;
                  exception
                     when Constraint_Error => null;
                  end;
               end if;
            end;
         end if;
      end loop;
      Ada.Text_IO.Close (File);
      return Unknown;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then Ada.Text_IO.Close (File); end if;
         return Unknown;
   end From_KDE_File;

   function Current return Preference is
      Config : constant String := Config_Home;
      Result : Preference;
   begin
      if Ada.Environment_Variables.Exists ("BRACKE_TERMINAL_COLOR_SCHEME") then
         return Classified
           (Ada.Environment_Variables.Value ("BRACKE_TERMINAL_COLOR_SCHEME"));
      end if;
      if Ada.Environment_Variables.Exists ("GTK_THEME") then
         Result := Classified (Ada.Environment_Variables.Value ("GTK_THEME"));
         if Result /= Unknown then return Result; end if;
      end if;
      Result := From_GTK_File (Config & "/gtk-4.0/settings.ini");
      if Result /= Unknown then return Result; end if;
      Result := From_GTK_File (Config & "/gtk-3.0/settings.ini");
      if Result /= Unknown then return Result; end if;
      Result := From_KDE_File (Config & "/kdeglobals");
      if Result /= Unknown then return Result; end if;
      if Ada.Environment_Variables.Exists ("COLORFGBG") then
         declare
            Value : constant String :=
              Ada.Environment_Variables.Value ("COLORFGBG");
            Sep : constant Natural := Ada.Strings.Fixed.Index
              (Value, ";", Going => Ada.Strings.Backward);
         begin
            if Sep > 0 and then Sep < Value'Last then
               declare
                  Background : constant Natural :=
                    Natural'Value (Value (Sep + 1 .. Value'Last));
               begin
                  return (if Background in 0 .. 6 or else Background = 8
                          then Prefer_Dark else Prefer_Light);
               end;
            end if;
         exception
            when Constraint_Error => null;
         end;
      end if;
      return Unknown;
   exception
      when others => return Unknown;
   end Current;

   function Image (Value : Preference) return String is
     (case Value is
        when Unknown => "unknown",
        when Prefer_Light => "light",
        when Prefer_Dark => "dark");
end Terminal.App.System_Theme;

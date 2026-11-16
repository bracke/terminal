with Ada.Directories;
with Ada.Environment_Variables;
with Ada.IO_Exceptions;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;

with Ada.Characters.Handling;
with Terminal.Common.Status;
with Terminal.App.Key_Bindings;
with Terminal.App.Platform_Files;
with Terminal.App.Session_Profiles;
with Terminal.App.Session_Profile_Discovery;

package body Terminal.App.Config is
   Max_Config_Line_Length : constant := 4_096;

   function Trimmed (Text : String) return String is
     (Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both));

   function Trim_Image (Value : Natural) return String
      renames Terminal.Common.Status.Trimmed_Natural;

   procedure Apply_Line
     (C      : in out Config;
      Line   : String;
      Status : out Line_Status)
   is
      Clean : constant String := Trimmed (Line);
      Sep   : Natural := 0;

      function Parse_Natural
        (Text  : String;
         Value : out Natural) return Boolean
      is
      begin
         if Text'Length = 0 then
            return False;
         end if;

         for Ch of Text loop
            if Ch not in '0' .. '9' then
               return False;
            end if;
         end loop;

         Value := Natural'Value (Text);
         return True;
      exception
         when Constraint_Error =>
            return False;
      end Parse_Natural;

      function Parse_Boolean
        (Text  : String;
         Value : out Boolean) return Boolean
      is
         Lower : constant String :=
           Ada.Characters.Handling.To_Lower (Trimmed (Text));
      begin
         if Lower in "true" | "yes" | "on" | "allow" | "1" then
            Value := True;
            return True;
         elsif Lower in "false" | "no" | "off" | "deny" | "0" then
            Value := False;
            return True;
         end if;
         return False;
      end Parse_Boolean;

      function Hex_Value (Ch : Character; Valid : out Boolean) return Natural is
         Upper : constant Character := Ada.Characters.Handling.To_Upper (Ch);
      begin
         Valid := True;
         if Upper in '0' .. '9' then
            return Character'Pos (Upper) - Character'Pos ('0');
         elsif Upper in 'A' .. 'F' then
            return Character'Pos (Upper) - Character'Pos ('A') + 10;
         end if;
         Valid := False;
         return 0;
      end Hex_Value;

      function Parse_Color
        (Text : String;
         Color : out Terminal.App.Theme.RM.Pixel_Color) return Boolean
      is
         Clean_Color : constant String := Trimmed (Text);
         Values : array (1 .. 4) of Natural := (0, 0, 0, 255);
         High_Ok, Low_Ok : Boolean;
      begin
         if Clean_Color'Length not in 7 | 9
           or else Clean_Color (Clean_Color'First) /= '#'
         then
            return False;
         end if;
         for I in 1 .. (Clean_Color'Length - 1) / 2 loop
            Values (I) :=
              Hex_Value (Clean_Color (Clean_Color'First + I * 2 - 1), High_Ok)
                * 16
              + Hex_Value (Clean_Color (Clean_Color'First + I * 2), Low_Ok);
            if not High_Ok or else not Low_Ok then return False; end if;
         end loop;
         Color :=
           (R => Float (Values (1)) / 255.0,
            G => Float (Values (2)) / 255.0,
            B => Float (Values (3)) / 255.0,
            A => Float (Values (4)) / 255.0);
         return True;
      end Parse_Color;
   begin
      if Clean'Length = 0 then
         Status := Ignored_Blank;
         return;
      elsif Clean (Clean'First) = '#' then
         Status := Ignored_Comment;
         return;
      end if;

      for I in Clean'Range loop
         if Clean (I) = '=' then
            Sep := I;
            exit;
         end if;
      end loop;

      if Sep = 0 then
         Status := Missing_Separator;
         return;
      end if;

      declare
         Key : constant String :=
           Ada.Characters.Handling.To_Lower
             (Trimmed (Clean (Clean'First .. Sep - 1)));
         Value : constant String := Trimmed (Clean (Sep + 1 .. Clean'Last));
         Name : Terminal.App.Theme.Theme_Name;
         Scrollback : Natural;
         Wheel_Lines : Natural;
         Dimension : Natural;
         Cells : Natural;
         Limit : Natural;
         Enabled : Boolean;
         Font_Size : Natural;
         Binding : Terminal.App.Key_Bindings.Binding;
         Binding_Action : Terminal.App.Key_Bindings.Configurable_Action;
         Profile_Accepted : Boolean;
         Parsed_Color : Terminal.App.Theme.RM.Pixel_Color;
         Palette_Index : Natural;
         Tab_Mode : Terminal.App.Theme.Tab_Bar_Mode;
      begin
         if Key = "theme" or else Key = "color-theme" then
            if Terminal.App.Theme.Parse_Name (Value, Name) then
               C.Color_Theme := Name;
               C.Use_Custom_Theme := False;
               C.Custom_Theme := Terminal.App.Theme.Built_In (Name);
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "follow-system-theme" then
            if Parse_Boolean (Value, Enabled) then
               C.Follow_System_Theme := Enabled;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key in "foreground" | "background" | "cursor-foreground"
           | "cursor-background" | "selection-foreground"
           | "selection-background" | "url-highlight"
         then
            if Parse_Color (Value, Parsed_Color) then
               if not C.Use_Custom_Theme then
                  C.Custom_Theme := Terminal.App.Theme.Built_In (C.Color_Theme);
               end if;
               C.Use_Custom_Theme := True;
               if Key = "foreground" then
                  C.Custom_Theme.Default_FG := Parsed_Color;
               elsif Key = "background" then
                  C.Custom_Theme.Default_BG := Parsed_Color;
               elsif Key = "cursor-foreground" then
                  C.Custom_Theme.Cursor_FG := Parsed_Color;
               elsif Key = "cursor-background" then
                  C.Custom_Theme.Cursor_BG := Parsed_Color;
               elsif Key = "selection-foreground" then
                  C.Custom_Theme.Selection_FG := Parsed_Color;
               elsif Key = "selection-background" then
                  C.Custom_Theme.Selection_BG := Parsed_Color;
               else
                  C.Custom_Theme.URL_Highlight := Parsed_Color;
               end if;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key'Length > 8
           and then Key (Key'First .. Key'First + 7) = "palette-"
         then
            if Parse_Natural (Key (Key'First + 8 .. Key'Last), Palette_Index)
              and then Palette_Index <= 15
              and then Parse_Color (Value, Parsed_Color)
            then
               if not C.Use_Custom_Theme then
                  C.Custom_Theme := Terminal.App.Theme.Built_In (C.Color_Theme);
               end if;
               C.Use_Custom_Theme := True;
               C.Custom_Theme.Palette (Palette_Index) := Parsed_Color;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "scrollback-limit" or else Key = "scrollback-rows" then
            if Parse_Natural (Value, Scrollback)
              and then Scrollback <= Max_Scrollback_Limit
            then
               C.Scrollback_Limit := Scrollback;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "wheel-scroll-lines" or else Key = "scroll-lines" then
            if Parse_Natural (Value, Wheel_Lines)
              and then Wheel_Lines >= 1
              and then Wheel_Lines <= Max_Wheel_Scroll_Lines
            then
               C.Wheel_Scroll_Lines := Positive (Wheel_Lines);
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "window-width" then
            if Parse_Natural (Value, Dimension)
              and then Dimension >= 1
              and then Dimension <= Max_Window_Dimension
            then
               C.Window_Width := Positive (Dimension);
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "window-height" then
            if Parse_Natural (Value, Dimension)
              and then Dimension >= 1
              and then Dimension <= Max_Window_Dimension
            then
               C.Window_Height := Positive (Dimension);
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "window-opacity" then
            if Parse_Natural (Value, Dimension)
              and then Dimension in Min_Window_Opacity_Percent .. 100
            then
               C.Window_Opacity_Percent := Positive (Dimension);
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "background-blur" or else Key = "blur" then
            if Parse_Boolean (Value, Enabled) then
               C.Background_Blur := Enabled;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "background-image" then
            if Value = "" or else Ada.Characters.Handling.To_Lower (Value) = "none"
            then
               C.Background_Image := (others => <>);
               Status := Accepted;
            elsif Value'Length <= Max_Font_Path_Length then
               C.Background_Image := (others => <>);
               C.Background_Image.Length := Value'Length;
               C.Background_Image.Text (1 .. Value'Length) := Value;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "background-image-opacity" then
            if Parse_Natural (Value, Dimension) and then Dimension <= 100 then
               C.Background_Image_Opacity_Percent := Dimension;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "always-on-top" then
            if Parse_Boolean (Value, Enabled) then
               C.Always_On_Top := Enabled;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "window-decorations" then
            if Parse_Boolean (Value, Enabled) then
               C.Window_Decorations := Enabled;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "focus-mode" then
            if Parse_Boolean (Value, Enabled) then
               C.Focus_Mode := Enabled;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "global-hotkey" then
            if Value = "none" or else Value = "off" or else Value = "" then
               C.Global_Hotkey := (others => <>);
               Status := Accepted;
            elsif Value'Length <= Max_Font_Path_Length then
               C.Global_Hotkey := (others => <>);
               C.Global_Hotkey.Length := Value'Length;
               C.Global_Hotkey.Text (1 .. Value'Length) := Value;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "padding" or else Key = "content-padding" then
            if Parse_Natural (Value, Dimension)
              and then Dimension <= Max_Content_Padding
            then
               C.Content_Padding := Dimension;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "tab-bar" then
            if Terminal.App.Theme.Parse_Tab_Bar_Mode (Value, Tab_Mode) then
               C.Tab_Bar := Tab_Mode;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key in "tab-bar-background" | "active-tab-background"
           | "inactive-tab-background"
         then
            if Parse_Color (Value, Parsed_Color) then
               if Key = "tab-bar-background" then
                  C.Tabs.Bar_Background := Parsed_Color;
               elsif Key = "active-tab-background" then
                  C.Tabs.Active_Background := Parsed_Color;
               else
                  C.Tabs.Inactive_Background := Parsed_Color;
               end if;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "startup-rows" then
            if Parse_Natural (Value, Cells)
              and then Cells >= 1
              and then Cells <= Max_Startup_Dimension
            then
               C.Startup_Rows := Positive (Cells);
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "startup-cols" then
            if Parse_Natural (Value, Cells)
              and then Cells >= 1
              and then Cells <= Max_Startup_Dimension
            then
               C.Startup_Cols := Positive (Cells);
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "font" or else Key = "font-path" then
            if Value = "default" or else Value = "auto" then
               C.Font_Path := (others => <>);
               Status := Accepted;
            elsif Value'Length in 1 .. Max_Font_Path_Length then
               C.Font_Path := (others => <>);
               C.Font_Path.Length := Value'Length;
               C.Font_Path.Text (1 .. Value'Length) := Value;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "font-size" then
            if Parse_Natural (Value, Font_Size)
              and then Font_Size in Min_Font_Pixel_Size .. Max_Font_Pixel_Size
            then
               C.Font_Pixel_Size := Positive (Font_Size);
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key in "font-bold-path" | "font-italic-path"
           | "font-bold-italic-path" | "font-features" | "font-variations"
         then
            if Value'Length <= Max_Font_Path_Length then
               declare
                  Target : Font_Path_Value := (others => <>);
               begin
                  Target.Length := Value'Length;
                  if Value /= "" then Target.Text (1 .. Value'Length) := Value; end if;
                  if Key = "font-bold-path" then C.Font_Bold_Path := Target;
                  elsif Key = "font-italic-path" then C.Font_Italic_Path := Target;
                  elsif Key = "font-bold-italic-path" then
                     C.Font_Bold_Italic_Path := Target;
                  elsif Key = "font-features" then C.Font_Features := Target;
                  else C.Font_Variations := Target;
                  end if;
                  Status := Accepted;
               end;
            else
               Status := Invalid_Value;
            end if;
         elsif Key'Length > 5
           and then Key (Key'First .. Key'First + 4) = "bind-"
           and then Terminal.App.Key_Bindings.Parse_Action_Name
             (Key (Key'First + 5 .. Key'Last), Binding_Action)
         then
            if Terminal.App.Key_Bindings.Parse (Value, Binding) then
               C.Bindings (Binding_Action) := Binding;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "notifications" or else Key = "desktop-notifications" then
            if Parse_Boolean (Value, Enabled) then
               C.Desktop_Notifications := Enabled;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "bell-notifications" then
            if Parse_Boolean (Value, Enabled) then
               C.Bell_Notifications := Enabled;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "command-completion-notifications" then
            if Parse_Boolean (Value, Enabled) then
               C.Command_Completion_Notifications := Enabled;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "protected-input" then
            if Parse_Boolean (Value, Enabled) then
               C.Protected_Input := Enabled;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "shell-integration" then
            if Parse_Boolean (Value, Enabled) then
               C.Shell_Integration := Enabled;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "workspace-file" then
            if Value'Length in 1 .. Max_Font_Path_Length then
               C.Workspace_Path := (others => <>);
               C.Workspace_Path.Length := Value'Length;
               C.Workspace_Path.Text (1 .. Value'Length) := Value;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "restore-workspace" then
            if Parse_Boolean (Value, Enabled) then
               C.Restore_Workspace := Enabled;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "save-workspace" then
            if Parse_Boolean (Value, Enabled) then
               C.Save_Workspace := Enabled;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "startup-command" then
            if Value'Length <= Max_Startup_Command_Length then
               C.Startup_Command := (others => <>);
               C.Startup_Command.Length := Value'Length;
               if Value'Length > 0 then
                  C.Startup_Command.Text (1 .. Value'Length) := Value;
               end if;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "default-profile" then
            Terminal.App.Session_Profiles.Set_Default
              (C.Session_Profiles, Value, Profile_Accepted);
            Status := (if Profile_Accepted then Accepted else Invalid_Value);
         elsif Key = "discover-ssh-profiles" then
            if Parse_Boolean (Value, Enabled) then
               C.Discover_SSH_Profiles := Enabled;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key'Length > 8
           and then Key (Key'First .. Key'First + 7) = "profile."
         then
            Terminal.App.Session_Profiles.Apply_Field
              (C.Session_Profiles,
               Key (Key'First + 8 .. Key'Last),
               Value,
               Profile_Accepted);
            Status := (if Profile_Accepted then Accepted else Invalid_Value);
         elsif Key'Length > 15
           and then Key (Key'First .. Key'First + 14) = "output-trigger."
         then
            Terminal.App.Output_Triggers.Apply
              (C.Output_Trigger_Rules,
               Key (Key'First + 15 .. Key'Last),
               Value,
               Profile_Accepted);
            Status := (if Profile_Accepted then Accepted else Invalid_Value);
         elsif Key = "kitty-file-transfer" then
            if Parse_Boolean (Value, Enabled) then
               C.Kitty_File_Transfer := Enabled;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "kitty-temporary-transfer" then
            if Parse_Boolean (Value, Enabled) then
               C.Kitty_Temporary_Transfer := Enabled;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "kitty-shared-memory" then
            if Parse_Boolean (Value, Enabled) then
               C.Kitty_Shared_Memory := Enabled;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "iterm2-file-downloads" then
            if Parse_Boolean (Value, Enabled) then
               C.ITerm2_File_Downloads := Enabled;
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "graphics-transaction-bytes" then
            if Parse_Natural (Value, Limit)
              and then Limit in 1 .. Max_Graphics_Transaction_Bytes
            then
               C.Graphics_Transaction_Bytes := Positive (Limit);
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "graphics-pending-events" then
            if Parse_Natural (Value, Limit)
              and then Limit in 1 .. Max_Graphics_Pending_Events
            then
               C.Graphics_Pending_Events := Positive (Limit);
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "graphics-pending-bytes" then
            if Parse_Natural (Value, Limit)
              and then Limit in 1 .. Max_Graphics_Pending_Bytes
            then
               C.Graphics_Pending_Bytes := Positive (Limit);
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "graphics-deferred-input-bytes" then
            if Parse_Natural (Value, Limit)
              and then Limit in 1 .. Max_Graphics_Deferred_Input_Bytes
            then
               C.Graphics_Deferred_Input_Bytes := Positive (Limit);
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "graphics-image-objects" then
            if Parse_Natural (Value, Limit)
              and then Limit in 1 .. Max_Graphics_Image_Objects
            then
               C.Graphics_Image_Objects := Positive (Limit);
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "graphics-image-bytes" then
            if Parse_Natural (Value, Limit)
              and then Limit in 1 .. Max_Graphics_Image_Bytes
            then
               C.Graphics_Image_Bytes := Positive (Limit);
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "graphics-per-image-bytes" then
            if Parse_Natural (Value, Limit)
              and then Limit in 1 .. Max_Graphics_Image_Bytes
            then
               C.Graphics_Per_Image_Bytes := Positive (Limit);
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "graphics-placements" then
            if Parse_Natural (Value, Limit)
              and then Limit in 1 .. Max_Graphics_Placements
            then
               C.Graphics_Placements := Positive (Limit);
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "graphics-animation-frames" then
            if Parse_Natural (Value, Limit)
              and then Limit in 1 .. Max_Graphics_Animation_Frames
            then
               C.Graphics_Animation_Frames := Positive (Limit);
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "graphics-pixel-dimension" then
            if Parse_Natural (Value, Limit)
              and then Limit in 1 .. Max_Graphics_Pixel_Dimension
            then
               C.Graphics_Pixel_Dimension := Positive (Limit);
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "graphics-gpu-atlas-bytes" then
            if Parse_Natural (Value, Limit)
              and then Limit in
                Min_Graphics_GPU_Atlas_Bytes .. Max_Graphics_GPU_Atlas_Bytes
            then
               C.Graphics_GPU_Atlas_Bytes := Positive (Limit);
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "graphics-gpu-atlas-dimension" then
            if Parse_Natural (Value, Limit)
              and then Limit in
                Min_Graphics_GPU_Atlas_Dimension ..
                  Max_Graphics_GPU_Atlas_Dimension
            then
               C.Graphics_GPU_Atlas_Dimension := Positive (Limit);
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         else
            Status := Unknown_Key;
         end if;
      end;
   end Apply_Line;

   procedure Apply_Line
     (C        : in out Config;
      Line     : String;
      Accepted : out Boolean)
   is
      Status : Line_Status;
   begin
      Apply_Line (C, Line, Status);
      Accepted :=
        Status = Terminal.App.Config.Accepted
        or else Status = Ignored_Blank
        or else Status = Ignored_Comment;
   end Apply_Line;

   procedure Load_File
     (C                : in out Config;
      Path             : String;
      Missing_Is_Error : Boolean := True)
   is
      File : Ada.Text_IO.File_Type;
      Line_Number : Natural := 0;

      procedure Read_Line
        (Text     : out String;
         Length   : out Natural;
         Overflow : out Boolean)
      is
         Ch : Character;
      begin
         Length := 0;
         Overflow := False;
         while not Ada.Text_IO.End_Of_Line (File) loop
            Ada.Text_IO.Get (File, Ch);
            if Length < Text'Length then
               Length := Length + 1;
               Text (Text'First + Length - 1) := Ch;
            else
               Overflow := True;
            end if;
         end loop;
         if not Ada.Text_IO.End_Of_File (File) then
            Ada.Text_IO.Skip_Line (File);
         end if;
      end Read_Line;

      procedure Close_After_Exception is
      begin
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
      exception
         when Ada.IO_Exceptions.Status_Error
            | Ada.IO_Exceptions.Mode_Error
            | Ada.IO_Exceptions.Name_Error
            | Ada.IO_Exceptions.Use_Error
            | Ada.IO_Exceptions.Device_Error
            | Ada.IO_Exceptions.End_Error
            | Ada.IO_Exceptions.Data_Error
            | Ada.IO_Exceptions.Layout_Error =>
            null;
      end Close_After_Exception;
   begin
      C.Load_Status := Config_Not_Checked;
      C.Invalid_Line := 0;
      C.Invalid_Line_Status := Accepted;
      if Path'Length = 0 then
         if Missing_Is_Error then
            C.Load_Status := Config_Not_Found;
         end if;
         return;
      elsif not Ada.Directories.Exists (Path) then
         if Missing_Is_Error then
            C.Load_Status := Config_Not_Found;
         end if;
         return;
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      C.Load_Status := Config_Loaded;
      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : String (1 .. Max_Config_Line_Length);
            Length : Natural;
            Overflow : Boolean;
            Status : Line_Status;
         begin
            Line_Number := Line_Number + 1;
            Read_Line (Line, Length, Overflow);
            if Overflow then
               Status := Invalid_Value;
            else
               Apply_Line (C, Line (1 .. Length), Status);
            end if;
            if Status in Missing_Separator | Unknown_Key | Invalid_Value
              and then C.Load_Status = Config_Loaded
            then
               C.Load_Status := Config_Invalid;
               C.Invalid_Line := Line_Number;
               C.Invalid_Line_Status := Status;
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (File);
   exception
      when Ada.IO_Exceptions.Status_Error
         | Ada.IO_Exceptions.Mode_Error
         | Ada.IO_Exceptions.Name_Error
         | Ada.IO_Exceptions.Use_Error
         | Ada.IO_Exceptions.Device_Error
         | Ada.IO_Exceptions.End_Error
         | Ada.IO_Exceptions.Data_Error
         | Ada.IO_Exceptions.Layout_Error =>
         Close_After_Exception;
         C.Load_Status := Config_IO_Error;
      when others =>
         Close_After_Exception;
         raise;
   end Load_File;

   procedure Import_File
     (C      : in out Config;
      Path   : String;
      Status : out Config_Load_Status)
   is
      Candidate : Config := (others => <>);
   begin
      Load_File (Candidate, Path, Missing_Is_Error => True);
      Status := Candidate.Load_Status;
      if Status = Config_Loaded then
         C := Candidate;
      end if;
   end Import_File;

   procedure Export_File
     (C      : Config;
      Path   : String;
      Status : out Config_Export_Status)
   is
      File : Ada.Text_IO.File_Type;
      Temp_Path : constant String := Path & ".tmp";

      function Bool (Value : Boolean) return String is
        (if Value then "true" else "false");

      function Hex_Digit (Value : Natural) return Character is
        (if Value < 10
         then Character'Val (Character'Pos ('0') + Value)
         else Character'Val (Character'Pos ('A') + Value - 10));

      function Hex_Color
        (Value : Terminal.App.Theme.RM.Pixel_Color) return String
      is
         Result : String (1 .. 9) := "#000000FF";
         Components : constant array (Positive range 1 .. 4) of Float :=
           [Value.R, Value.G, Value.B, Value.A];
      begin
         for I in Components'Range loop
            declare
               Byte : constant Natural :=
                 Natural
                   (Float'Rounding
                      (Float'Max (0.0, Float'Min (1.0, Components (I)))
                       * 255.0));
            begin
               Result (I * 2) := Hex_Digit (Byte / 16);
               Result (I * 2 + 1) := Hex_Digit (Byte mod 16);
            end;
         end loop;
         return Result;
      end Hex_Color;

      procedure Put (Key, Value : String) is
      begin
         Ada.Text_IO.Put_Line (File, Key & " = " & Value);
      end Put;

      procedure Put_Profile_Field
        (Name, Field, Value : String) is
      begin
         if Value /= "" then
            Put ("profile." & Name & "." & Field, Value);
         end if;
      end Put_Profile_Field;
   begin
      if Path = "" then
         Status := Config_Export_Invalid_Path;
         return;
      end if;
      declare
         Parent : constant String := Ada.Directories.Containing_Directory (Path);
      begin
         if Parent /= "" and then not Ada.Directories.Exists (Parent) then
            Ada.Directories.Create_Path (Parent);
         end if;
      end;
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Temp_Path);
      Ada.Text_IO.Put_Line (File, "# bracke-terminal configuration export v1");
      Put ("theme", Terminal.App.Theme.Image (C.Color_Theme));
      Put ("follow-system-theme", Bool (C.Follow_System_Theme));
      if C.Use_Custom_Theme then
         Put ("foreground", Hex_Color (C.Custom_Theme.Default_FG));
         Put ("background", Hex_Color (C.Custom_Theme.Default_BG));
         Put ("cursor-foreground", Hex_Color (C.Custom_Theme.Cursor_FG));
         Put ("cursor-background", Hex_Color (C.Custom_Theme.Cursor_BG));
         Put ("selection-foreground", Hex_Color (C.Custom_Theme.Selection_FG));
         Put ("selection-background", Hex_Color (C.Custom_Theme.Selection_BG));
         Put ("url-highlight", Hex_Color (C.Custom_Theme.URL_Highlight));
         for I in C.Custom_Theme.Palette'Range loop
            Put ("palette-" & Trim_Image (I), Hex_Color (C.Custom_Theme.Palette (I)));
         end loop;
      end if;
      Put ("scrollback-limit", Trim_Image (C.Scrollback_Limit));
      Put ("wheel-scroll-lines", Trim_Image (C.Wheel_Scroll_Lines));
      Put ("window-width", Trim_Image (C.Window_Width));
      Put ("window-height", Trim_Image (C.Window_Height));
      Put ("window-opacity", Trim_Image (C.Window_Opacity_Percent));
      Put ("background-blur", Bool (C.Background_Blur));
      Put
        ("background-image",
         (if C.Background_Image.Length = 0
          then "none" else Background_Image_Path_String (C)));
      Put
        ("background-image-opacity",
         Trim_Image (C.Background_Image_Opacity_Percent));
      Put ("always-on-top", Bool (C.Always_On_Top));
      Put ("window-decorations", Bool (C.Window_Decorations));
      Put ("focus-mode", Bool (C.Focus_Mode));
      Put
        ("global-hotkey",
         (if C.Global_Hotkey.Length = 0 then "none"
          else Global_Hotkey_String (C)));
      Put ("content-padding", Trim_Image (C.Content_Padding));
      Put ("tab-bar", Terminal.App.Theme.Image (C.Tab_Bar));
      Put ("tab-bar-background", Hex_Color (C.Tabs.Bar_Background));
      Put ("active-tab-background", Hex_Color (C.Tabs.Active_Background));
      Put ("inactive-tab-background", Hex_Color (C.Tabs.Inactive_Background));
      Put ("startup-rows", Trim_Image (C.Startup_Rows));
      Put ("startup-cols", Trim_Image (C.Startup_Cols));
      Put ("font-path", (if C.Font_Path.Length = 0 then "auto" else Font_Path_String (C)));
      Put ("font-size", Trim_Image (C.Font_Pixel_Size));
      Put ("font-bold-path", Font_Bold_Path_String (C));
      Put ("font-italic-path", Font_Italic_Path_String (C));
      Put ("font-bold-italic-path", Font_Bold_Italic_Path_String (C));
      Put ("font-features", Font_Features_String (C));
      Put ("font-variations", Font_Variations_String (C));
      for Action in Terminal.App.Key_Bindings.Configurable_Action loop
         Put
           ("bind-" & Terminal.App.Key_Bindings.Action_Name (Action),
            Terminal.App.Key_Bindings.Image (C.Bindings (Action)));
      end loop;
      Put ("desktop-notifications", Bool (C.Desktop_Notifications));
      Put ("bell-notifications", Bool (C.Bell_Notifications));
      Put
        ("command-completion-notifications",
         Bool (C.Command_Completion_Notifications));
      Put ("protected-input", Bool (C.Protected_Input));
      for I in 1 .. Terminal.App.Output_Triggers.Count
        (C.Output_Trigger_Rules)
      loop
         Put
           ("output-trigger."
            & Terminal.App.Output_Triggers.Name (C.Output_Trigger_Rules, I),
            Terminal.App.Output_Triggers.Pattern (C.Output_Trigger_Rules, I));
      end loop;
      Put ("shell-integration", Bool (C.Shell_Integration));
      if C.Workspace_Path.Length > 0 then
         Put
           ("workspace-file",
            C.Workspace_Path.Text (1 .. C.Workspace_Path.Length));
      end if;
      Put ("restore-workspace", Bool (C.Restore_Workspace));
      Put ("save-workspace", Bool (C.Save_Workspace));
      Put ("startup-command", Startup_Command_String (C));
      Put ("discover-ssh-profiles", Bool (C.Discover_SSH_Profiles));
      for I in 1 .. Terminal.App.Session_Profiles.Count (C.Session_Profiles) loop
         declare
            Profile : constant Terminal.App.Session_Profiles.Profile :=
              Terminal.App.Session_Profiles.Item (C.Session_Profiles, I);
            Name : constant String := Terminal.App.Session_Profiles.Name (Profile);
         begin
            Put_Profile_Field
              (Name, "cwd", Terminal.App.Session_Profiles.Working_Directory (Profile));
            Put_Profile_Field
              (Name, "command", Terminal.App.Session_Profiles.Command (Profile));
            Put_Profile_Field
              (Name, "shell", Terminal.App.Session_Profiles.Shell (Profile));
            Put_Profile_Field
              (Name, "environment", Terminal.App.Session_Profiles.Environment (Profile));
            Put_Profile_Field
              (Name, "ssh", Terminal.App.Session_Profiles.SSH_Host (Profile));
            Put_Profile_Field
              (Name, "ssh-identity",
               Terminal.App.Session_Profiles.SSH_Identity (Profile));
            Put_Profile_Field
              (Name, "ssh-port",
               Terminal.App.Session_Profiles.SSH_Port (Profile));
            Put_Profile_Field
              (Name, "ssh-jump",
               Terminal.App.Session_Profiles.SSH_Jump_Host (Profile));
            Put_Profile_Field
              (Name, "ssh-setup",
               (if Terminal.App.Session_Profiles.SSH_Remote_Setup (Profile)
                then "true" else "false"));
            Put_Profile_Field
              (Name, "persistent",
               (if Terminal.App.Session_Profiles.Persistent (Profile)
                then "true" else "false"));
            Put_Profile_Field
              (Name, "serial", Terminal.App.Session_Profiles.Serial_Device (Profile));
            Put_Profile_Field
              (Name, "baud", Terminal.App.Session_Profiles.Serial_Baud (Profile));
            Put_Profile_Field
              (Name, "socket", Terminal.App.Session_Profiles.Socket_Path (Profile));
            Put_Profile_Field
              (Name, "container", Terminal.App.Session_Profiles.Container_Name (Profile));
            Put_Profile_Field
              (Name, "wsl", Terminal.App.Session_Profiles.WSL_Distribution (Profile));
            Put_Profile_Field
              (Name, "tls", Terminal.App.Session_Profiles.TLS_Host (Profile));
            Put_Profile_Field
              (Name, "theme", Terminal.App.Session_Profiles.Theme_Name (Profile));
         end;
      end loop;
      declare
         Default : constant Natural :=
           Terminal.App.Session_Profiles.Default_Index (C.Session_Profiles);
      begin
         if Default > 0 then
            Put
              ("default-profile",
               Terminal.App.Session_Profiles.Name
                 (Terminal.App.Session_Profiles.Item (C.Session_Profiles, Default)));
         end if;
      end;
      Put ("kitty-file-transfer", Bool (C.Kitty_File_Transfer));
      Put ("kitty-temporary-transfer", Bool (C.Kitty_Temporary_Transfer));
      Put ("kitty-shared-memory", Bool (C.Kitty_Shared_Memory));
      Put ("iterm2-file-downloads", Bool (C.ITerm2_File_Downloads));
      Put ("graphics-transaction-bytes", Trim_Image (C.Graphics_Transaction_Bytes));
      Put ("graphics-pending-events", Trim_Image (C.Graphics_Pending_Events));
      Put ("graphics-pending-bytes", Trim_Image (C.Graphics_Pending_Bytes));
      Put
        ("graphics-deferred-input-bytes",
         Trim_Image (C.Graphics_Deferred_Input_Bytes));
      Put ("graphics-image-objects", Trim_Image (C.Graphics_Image_Objects));
      Put ("graphics-image-bytes", Trim_Image (C.Graphics_Image_Bytes));
      Put ("graphics-per-image-bytes", Trim_Image (C.Graphics_Per_Image_Bytes));
      Put ("graphics-placements", Trim_Image (C.Graphics_Placements));
      Put ("graphics-animation-frames", Trim_Image (C.Graphics_Animation_Frames));
      Put ("graphics-pixel-dimension", Trim_Image (C.Graphics_Pixel_Dimension));
      Put ("graphics-gpu-atlas-bytes", Trim_Image (C.Graphics_GPU_Atlas_Bytes));
      Put
        ("graphics-gpu-atlas-dimension",
         Trim_Image (C.Graphics_GPU_Atlas_Dimension));
      Ada.Text_IO.Close (File);
      if Terminal.App.Platform_Files.Replace_File (Temp_Path, Path) then
         Status := Config_Exported;
      else
         Status := Config_Export_IO_Error;
      end if;
   exception
      when Ada.IO_Exceptions.Status_Error | Ada.IO_Exceptions.Mode_Error
         | Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error
         | Ada.IO_Exceptions.Device_Error | Ada.IO_Exceptions.End_Error
         | Ada.IO_Exceptions.Data_Error | Ada.IO_Exceptions.Layout_Error =>
         if Ada.Text_IO.Is_Open (File) then Ada.Text_IO.Close (File); end if;
         if Ada.Directories.Exists (Temp_Path) then
            Ada.Directories.Delete_File (Temp_Path);
         end if;
         Status := Config_Export_IO_Error;
   end Export_File;

   function Default_Path return String is
      Explicit : constant String :=
        Ada.Environment_Variables.Value ("ADA_TERMINAL_CONFIG", "");
      XDG_Config : constant String :=
        Ada.Environment_Variables.Value ("XDG_CONFIG_HOME", "");
      Home : constant String := Ada.Environment_Variables.Value ("HOME", "");
   begin
      if Explicit /= "" then
         return Explicit;
      elsif XDG_Config /= "" then
         return XDG_Config & "/ada-terminal/config";
      elsif Home /= "" then
         return Home & "/.config/ada-terminal/config";
      else
         return "";
      end if;
   end Default_Path;

   procedure Load_Default_File (C : in out Config) is
      Explicit : constant String :=
        Ada.Environment_Variables.Value ("ADA_TERMINAL_CONFIG", "");
      XDG_Config : constant String :=
        Ada.Environment_Variables.Value ("XDG_CONFIG_HOME", "");
      Home : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      if Explicit'Length > 0 then
         Load_File (C, Explicit, Missing_Is_Error => True);
      elsif XDG_Config'Length > 0 then
         Load_File
           (C,
            XDG_Config & "/ada-terminal/config",
            Missing_Is_Error => False);
      elsif Home'Length > 0 then
         Load_File
           (C,
            Home & "/.config/ada-terminal/config",
            Missing_Is_Error => False);
      end if;
   end Load_Default_File;

   procedure Load (C : out Config) is
      Name : Terminal.App.Theme.Theme_Name;
      Added : Natural;
      Home : constant String := Ada.Environment_Variables.Value ("HOME", "");
   begin
      C := (others => <>);
      Load_Default_File (C);
      if C.Discover_SSH_Profiles and then Home /= "" then
         Terminal.App.Session_Profile_Discovery.Discover_SSH
           (C.Session_Profiles, Home & "/.ssh/config", Added);
      end if;
      if Terminal.App.Theme.Parse_Name
        (Ada.Environment_Variables.Value ("ADA_TERMINAL_THEME", ""),
         Name)
      then
         C.Color_Theme := Name;
         C.Use_Custom_Theme := False;
         C.Custom_Theme := Terminal.App.Theme.Built_In (Name);
      end if;
   end Load;

   function Active_Theme (C : Config) return Terminal.App.Theme.Theme is
   begin
      return (if C.Use_Custom_Theme then C.Custom_Theme
              else Terminal.App.Theme.Built_In (C.Color_Theme));
   end Active_Theme;

   function Font_Path_String (C : Config) return String is
   begin
      if C.Font_Path.Length = 0 then
         return "";
      else
         return C.Font_Path.Text (1 .. C.Font_Path.Length);
      end if;
   end Font_Path_String;

   function Font_Bold_Path_String (C : Config) return String is
     (if C.Font_Bold_Path.Length = 0 then ""
      else C.Font_Bold_Path.Text (1 .. C.Font_Bold_Path.Length));
   function Font_Italic_Path_String (C : Config) return String is
     (if C.Font_Italic_Path.Length = 0 then ""
      else C.Font_Italic_Path.Text (1 .. C.Font_Italic_Path.Length));
   function Font_Bold_Italic_Path_String (C : Config) return String is
     (if C.Font_Bold_Italic_Path.Length = 0 then ""
      else C.Font_Bold_Italic_Path.Text
        (1 .. C.Font_Bold_Italic_Path.Length));
   function Font_Features_String (C : Config) return String is
     (if C.Font_Features.Length = 0 then ""
      else C.Font_Features.Text (1 .. C.Font_Features.Length));
   function Font_Variations_String (C : Config) return String is
     (if C.Font_Variations.Length = 0 then ""
      else C.Font_Variations.Text (1 .. C.Font_Variations.Length));

   function Background_Image_Path_String (C : Config) return String is
     (if C.Background_Image.Length = 0 then ""
      else C.Background_Image.Text (1 .. C.Background_Image.Length));

   function Global_Hotkey_String (C : Config) return String is
     (if C.Global_Hotkey.Length = 0 then ""
      else C.Global_Hotkey.Text (1 .. C.Global_Hotkey.Length));

   function Workspace_Path_String (C : Config) return String is
      XDG_State : constant String :=
        Ada.Environment_Variables.Value ("XDG_STATE_HOME", "");
      Home : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      if C.Workspace_Path.Length > 0 then
         return C.Workspace_Path.Text (1 .. C.Workspace_Path.Length);
      elsif XDG_State /= "" then
         return XDG_State & "/ada-terminal/workspace";
      elsif Home /= "" then
         return Home & "/.local/state/ada-terminal/workspace";
      else
         return "";
      end if;
   end Workspace_Path_String;

   procedure Set_Workspace_Path
     (C : in out Config; Path : String; Accepted : out Boolean) is
   begin
      Accepted := Path'Length > 0 and then Path'Length <= Max_Font_Path_Length;
      if not Accepted then return; end if;
      C.Workspace_Path := (others => <>);
      C.Workspace_Path.Length := Path'Length;
      C.Workspace_Path.Text (1 .. Path'Length) := Path;
      C.Restore_Workspace := True;
      C.Save_Workspace := True;
   end Set_Workspace_Path;

   function Startup_Command_String (C : Config) return String is
     (if C.Startup_Command.Length = 0 then ""
      else C.Startup_Command.Text (1 .. C.Startup_Command.Length));

   function Image (C : Config) return String is
   begin
      return
        "theme="
        & (if C.Use_Custom_Theme then "custom"
           else Terminal.App.Theme.Image (C.Color_Theme))
        & " scrollback-limit="
        & Trim_Image (C.Scrollback_Limit)
        & " wheel-scroll-lines="
        & Trim_Image (C.Wheel_Scroll_Lines)
        & " window="
        & Trim_Image (C.Window_Width)
        & "x"
        & Trim_Image (C.Window_Height)
        & " startup-grid="
        & Trim_Image (C.Startup_Rows)
        & "x"
        & Trim_Image (C.Startup_Cols)
        & " kitty-local-media="
        & (if not C.Kitty_File_Transfer
             and then not C.Kitty_Temporary_Transfer
             and then not C.Kitty_Shared_Memory
           then "none"
           else
             (if C.Kitty_File_Transfer
              then "file"
                & (if C.Kitty_Temporary_Transfer or else C.Kitty_Shared_Memory
                   then "," else "")
              else "")
             & (if C.Kitty_Temporary_Transfer
                then "temp"
                  & (if C.Kitty_Shared_Memory then "," else "")
                else "")
             & (if C.Kitty_Shared_Memory then "shm" else ""))
        & " iterm2-file-downloads="
        & (if C.ITerm2_File_Downloads then "allow" else "deny")
        & " graphics-core="
        & Trim_Image (C.Graphics_Transaction_Bytes)
        & "/"
        & Trim_Image (C.Graphics_Pending_Events)
        & "/"
        & Trim_Image (C.Graphics_Pending_Bytes)
        & "/"
        & Trim_Image (C.Graphics_Deferred_Input_Bytes)
        & " graphics-store="
        & Trim_Image (C.Graphics_Image_Objects)
        & "/"
        & Trim_Image (C.Graphics_Image_Bytes)
        & " graphics-per-image="
        & Trim_Image (C.Graphics_Per_Image_Bytes)
        & " graphics-placements="
        & Trim_Image (C.Graphics_Placements)
        & " graphics-frames="
        & Trim_Image (C.Graphics_Animation_Frames)
        & " graphics-pixels="
        & Trim_Image (C.Graphics_Pixel_Dimension)
        & " graphics-gpu-atlas="
        & Trim_Image (C.Graphics_GPU_Atlas_Bytes)
        & "/"
        & Trim_Image (C.Graphics_GPU_Atlas_Dimension);
   end Image;

   function Line_Status_Label (Status : Line_Status) return String is
   begin
      case Status is
         when Accepted =>
            return "Config line accepted";
         when Ignored_Blank =>
            return "Blank config line ignored";
         when Ignored_Comment =>
            return "Comment config line ignored";
         when Missing_Separator =>
            return "Config line missing separator";
         when Unknown_Key =>
            return "Unknown config key";
         when Invalid_Value =>
            return "Invalid config value";
      end case;
   end Line_Status_Label;

   function Status_Label (C : Config) return String is
      Load_Label : constant String :=
        (case C.Load_Status is
            when Config_Not_Checked | Config_Loaded => "",
            when Config_Not_Found => "; config file not found",
            when Config_IO_Error => "; config file read failed",
            when Config_Invalid =>
              "; config line " & Trim_Image (C.Invalid_Line) & " "
              & Line_Status_Label (C.Invalid_Line_Status));
      Text : constant String :=
        Terminal.App.Theme.Status_Label (C.Color_Theme)
        & "; window "
        & Trim_Image (C.Window_Width)
        & "x"
        & Trim_Image (C.Window_Height)
        & "; startup grid "
        & Trim_Image (C.Startup_Rows)
        & "x"
        & Trim_Image (C.Startup_Cols)
        & Load_Label;
   begin
      return
        (if Text'Length <= Max_Status_Label_Length
         then Text
         else Text (Text'First .. Text'First + Max_Status_Label_Length - 1));
   end Status_Label;
end Terminal.App.Config;

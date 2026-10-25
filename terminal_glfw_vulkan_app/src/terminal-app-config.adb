with Ada.Directories;
with Ada.Environment_Variables;
with Ada.IO_Exceptions;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;

with Ada.Characters.Handling;

package body Terminal.App.Config is
   function Trimmed (Text : String) return String is
     (Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both));

   function Trim_Image (Value : Natural) return String is
      Text : constant String := Natural'Image (Value);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Trim_Image;

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
      begin
         if Key = "theme" or else Key = "color-theme" then
            if Terminal.App.Theme.Parse_Name (Value, Name) then
               C.Color_Theme := Name;
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
         elsif Key = "startup-rows" then
            if Parse_Natural (Value, Cells)
              and then Cells >= 1
              and then Cells <= Max_Startup_Cells
            then
               C.Startup_Rows := Positive (Cells);
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
         elsif Key = "startup-cols" then
            if Parse_Natural (Value, Cells)
              and then Cells >= 1
              and then Cells <= Max_Startup_Cells
            then
               C.Startup_Cols := Positive (Cells);
               Status := Accepted;
            else
               Status := Invalid_Value;
            end if;
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
            Line : constant String := Ada.Text_IO.Get_Line (File);
            Status : Line_Status;
         begin
            Line_Number := Line_Number + 1;
            Apply_Line (C, Line, Status);
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
   begin
      C := (others => <>);
      Load_Default_File (C);
      if Terminal.App.Theme.Parse_Name
        (Ada.Environment_Variables.Value ("ADA_TERMINAL_THEME", ""),
         Name)
      then
         C.Color_Theme := Name;
      end if;
   end Load;

   function Active_Theme (C : Config) return Terminal.App.Theme.Theme is
   begin
      return Terminal.App.Theme.Built_In (C.Color_Theme);
   end Active_Theme;

   function Image (C : Config) return String is
   begin
      return
        "theme="
        & Terminal.App.Theme.Image (C.Color_Theme)
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

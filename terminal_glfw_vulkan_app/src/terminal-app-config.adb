with Ada.Directories;
with Ada.Environment_Variables;
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
         when others =>
            return False;
      end Parse_Natural;
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
     (C    : in out Config;
      Path : String)
   is
      File : Ada.Text_IO.File_Type;
   begin
      if Path'Length = 0 or else not Ada.Directories.Exists (Path) then
         return;
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (File);
            Accepted : Boolean;
         begin
            Apply_Line (C, Line, Accepted);
         end;
      end loop;
      Ada.Text_IO.Close (File);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
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
         Load_File (C, Explicit);
      elsif XDG_Config'Length > 0 then
         Load_File (C, XDG_Config & "/ada-terminal/config");
      elsif Home'Length > 0 then
         Load_File (C, Home & "/.config/ada-terminal/config");
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
        & Trim_Image (C.Startup_Cols);
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
   begin
      return
        Terminal.App.Theme.Status_Label (C.Color_Theme)
        & "; window "
        & Trim_Image (C.Window_Width)
        & "x"
        & Trim_Image (C.Window_Height)
        & "; startup grid "
        & Trim_Image (C.Startup_Rows)
        & "x"
        & Trim_Image (C.Startup_Cols);
   end Status_Label;
end Terminal.App.Config;

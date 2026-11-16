with Ada.Strings;
with Ada.Strings.Fixed;
with Terminal.App.Session_Profiles;
with Terminal.App.Theme;

package body Terminal.App.Settings is
   use type Terminal.App.Config.Line_Status;
   use type Terminal.App.Config.Config_Load_Status;
   use type Terminal.App.Config.Config_Export_Status;
   procedure Enter (Item : in out State) is
   begin
      Item.Is_Active := True;
      Item.Is_Editing := False;
   end Enter;

   procedure Leave (Item : in out State) is
   begin
      Item.Is_Active := False;
      Item.Is_Editing := False;
   end Leave;

   function Active (Item : State) return Boolean is (Item.Is_Active);
   function Editing (Item : State) return Boolean is (Item.Is_Editing);

   procedure Move (Item : in out State; Direction : Integer) is
      Count : constant Positive := Setting_Item'Pos (Setting_Item'Last) + 1;
      Position : Integer;
   begin
      if not Item.Is_Editing and then Direction /= 0 then
         Position := Setting_Item'Pos (Item.Current) + Direction mod Count;
         Position := Position mod Count;
         if Position < 0 then Position := Position + Count; end if;
         Item.Current := Setting_Item'Val (Position);
      end if;
   end Move;

   procedure Adjust
     (Item      : in out State;
      Config    : in out Terminal.App.Config.Config;
      Direction : Integer;
      Changed   : out Boolean)
   is
      use type Terminal.App.Theme.Theme_Name;
      Profiles : Natural;
      Current : Natural;
      Accepted : Boolean;
      Proposed : Long_Long_Integer;
   begin
      Changed := False;
      if Direction = 0 then
         return;
      end if;
      case Item.Current is
         when Theme =>
            declare
               Count : constant Positive :=
                 Terminal.App.Theme.Theme_Name'Pos
                   (Terminal.App.Theme.Theme_Name'Last) + 1;
               Position : Integer :=
                 Terminal.App.Theme.Theme_Name'Pos (Config.Color_Theme)
                   + Direction mod Count;
               Previous : constant Terminal.App.Theme.Theme_Name :=
                 Config.Color_Theme;
            begin
               Position := Position mod Count;
               if Position < 0 then Position := Position + Count; end if;
               Config.Color_Theme :=
                 Terminal.App.Theme.Theme_Name'Val (Position);
               Config.Use_Custom_Theme := False;
               Config.Custom_Theme :=
                 Terminal.App.Theme.Built_In (Config.Color_Theme);
               Changed := Config.Color_Theme /= Previous;
            end;
         when Follow_System_Theme =>
            Config.Follow_System_Theme := not Config.Follow_System_Theme;
            Changed := True;
         when Font_Size =>
            declare
               Previous : constant Positive := Config.Font_Pixel_Size;
            begin
               Proposed := Long_Long_Integer (Config.Font_Pixel_Size)
                 + Long_Long_Integer (Direction);
               Config.Font_Pixel_Size := Positive
                 (Long_Long_Integer'Max
                    (Long_Long_Integer
                       (Terminal.App.Config.Min_Font_Pixel_Size),
                     Long_Long_Integer'Min
                       (Long_Long_Integer
                          (Terminal.App.Config.Max_Font_Pixel_Size),
                        Proposed)));
               Changed := Config.Font_Pixel_Size /= Previous;
            end;
         when Wheel_Lines =>
            declare
               Previous : constant Positive := Config.Wheel_Scroll_Lines;
            begin
               Proposed := Long_Long_Integer (Config.Wheel_Scroll_Lines)
                 + Long_Long_Integer (Direction);
               Config.Wheel_Scroll_Lines := Positive
                 (Long_Long_Integer'Max
                    (1,
                     Long_Long_Integer'Min
                       (Long_Long_Integer
                          (Terminal.App.Config.Max_Wheel_Scroll_Lines),
                        Proposed)));
               Changed := Config.Wheel_Scroll_Lines /= Previous;
            end;
         when Window_Opacity =>
            declare
               Previous : constant Positive := Config.Window_Opacity_Percent;
            begin
               Proposed := Long_Long_Integer (Config.Window_Opacity_Percent)
                 + Long_Long_Integer (Direction) * 5;
               Config.Window_Opacity_Percent := Positive
                 (Long_Long_Integer'Max
                    (Long_Long_Integer
                       (Terminal.App.Config.Min_Window_Opacity_Percent),
                     Long_Long_Integer'Min (100, Proposed)));
               Changed := Config.Window_Opacity_Percent /= Previous;
            end;
         when Background_Blur =>
            Config.Background_Blur := not Config.Background_Blur;
            Changed := True;
         when Content_Padding =>
            declare
               Previous : constant Natural := Config.Content_Padding;
            begin
               Proposed := Long_Long_Integer (Config.Content_Padding)
                 + Long_Long_Integer (Direction);
               Config.Content_Padding := Natural
                 (Long_Long_Integer'Max
                    (0,
                     Long_Long_Integer'Min
                       (Long_Long_Integer
                          (Terminal.App.Config.Max_Content_Padding),
                        Proposed)));
               Changed := Config.Content_Padding /= Previous;
            end;
         when Always_On_Top =>
            Config.Always_On_Top := not Config.Always_On_Top;
            Changed := True;
         when Focus_Mode =>
            Config.Focus_Mode := not Config.Focus_Mode;
            Changed := True;
         when Window_Decorations =>
            Config.Window_Decorations := not Config.Window_Decorations;
            Changed := True;
         when Shell_Integration =>
            Config.Shell_Integration := not Config.Shell_Integration;
            Changed := True;
         when Desktop_Notifications =>
            Config.Desktop_Notifications := not Config.Desktop_Notifications;
            Changed := True;
         when Bell_Notifications =>
            Config.Bell_Notifications := not Config.Bell_Notifications;
            Changed := True;
         when Completion_Notifications =>
            Config.Command_Completion_Notifications :=
              not Config.Command_Completion_Notifications;
            Changed := True;
         when Protected_Input =>
            Config.Protected_Input := not Config.Protected_Input;
            Changed := True;
         when Default_Profile =>
            Profiles := Terminal.App.Session_Profiles.Count
              (Config.Session_Profiles);
            if Profiles = 0 then
               Changed := False;
            else
               Current := Terminal.App.Session_Profiles.Default_Index
                 (Config.Session_Profiles);
               if Current = 0 then
                  Current := (if Direction < 0 then Profiles else 1);
               else
                  Current := Natural
                    ((Integer (Current) - 1 + Direction mod Integer (Profiles)
                      + Integer (Profiles))
                     mod Integer (Profiles)) + 1;
               end if;
               declare
                  Previous : constant Natural :=
                    Terminal.App.Session_Profiles.Default_Index
                      (Config.Session_Profiles);
               begin
                  Terminal.App.Session_Profiles.Set_Default
                    (Config.Session_Profiles,
                     Terminal.App.Session_Profiles.Name
                       (Terminal.App.Session_Profiles.Item
                         (Config.Session_Profiles, Current)),
                     Accepted);
                  Changed := Accepted and then Current /= Previous;
               end;
            end if;
         when Config_Line | Import_Config | Export_Config =>
            Changed := False;
      end case;
   end Adjust;

   procedure Begin_Edit (Item : in out State) is
   begin
      if Item.Current in Config_Line | Import_Config | Export_Config then
         Item.Is_Editing := True;
         Item.Line_Length := 0;
      end if;
   end Begin_Edit;

   procedure Append
     (Item : in out State; Code : Terminal.Common.Code_Point) is
   begin
      if Item.Is_Editing and then Code in 32 .. 126
        and then Item.Line_Length < Max_Line_Length
      then
         Item.Line_Length := Item.Line_Length + 1;
         Item.Line (Item.Line_Length) := Character'Val (Code);
      end if;
   end Append;

   procedure Backspace (Item : in out State) is
   begin
      if Item.Is_Editing and then Item.Line_Length > 0 then
         Item.Line (Item.Line_Length) := ' ';
         Item.Line_Length := Item.Line_Length - 1;
      end if;
   end Backspace;

   procedure Apply_Edit
     (Item     : in out State;
      Config   : in out Terminal.App.Config.Config;
      Accepted : out Boolean)
   is
      Status : Terminal.App.Config.Line_Status;
      Load_Status : Terminal.App.Config.Config_Load_Status;
      Export_Status : Terminal.App.Config.Config_Export_Status;
   begin
      Accepted := False;
      if not Item.Is_Editing or else Item.Line_Length = 0 then return; end if;
      case Item.Current is
         when Config_Line =>
            Terminal.App.Config.Apply_Line
              (Config, Item.Line (1 .. Item.Line_Length), Status);
            Accepted := Status = Terminal.App.Config.Accepted;
            Set_Message
              (Item, Terminal.App.Config.Line_Status_Label (Status));
            if Accepted then Item.Is_Editing := False; end if;
         when Import_Config =>
            Terminal.App.Config.Import_File
              (Config, Item.Line (1 .. Item.Line_Length), Load_Status);
            Accepted := Load_Status = Terminal.App.Config.Config_Loaded;
            Set_Message
              (Item, (if Accepted then "config imported" else "config import failed"));
            if Accepted then Item.Is_Editing := False; end if;
         when Export_Config =>
            Terminal.App.Config.Export_File
              (Config, Item.Line (1 .. Item.Line_Length), Export_Status);
            Set_Message
              (Item,
               (if Export_Status = Terminal.App.Config.Config_Exported
                then "config exported" else "config export failed"));
            if Export_Status = Terminal.App.Config.Config_Exported then
               Item.Is_Editing := False;
            end if;
         when others =>
            null;
      end case;
   end Apply_Edit;

   procedure Set_Message (Item : in out State; Message : String) is
      Length : constant Natural := Natural'Min
        (Message'Length, Max_Message_Length);
   begin
      Item.Message := (others => ' ');
      Item.Message_Length := Length;
      if Length > 0 then
         Item.Message (1 .. Length) :=
           Message (Message'First .. Message'First + Length - 1);
      end if;
   end Set_Message;

   function Trim_Image (Value : Integer) return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (Value), Ada.Strings.Both));

   function On_Off (Value : Boolean) return String is
     (if Value then "on" else "off");

   function Status_Label
     (Item : State; Config : Terminal.App.Config.Config) return String
   is
      Profile_Index : constant Natural :=
        Terminal.App.Session_Profiles.Default_Index (Config.Session_Profiles);
      Value : constant String :=
        (case Item.Current is
           when Theme => Terminal.App.Theme.Image (Config.Color_Theme),
           when Follow_System_Theme => On_Off (Config.Follow_System_Theme),
           when Font_Size => Trim_Image (Config.Font_Pixel_Size) & " px",
           when Wheel_Lines => Trim_Image (Config.Wheel_Scroll_Lines),
           when Window_Opacity =>
             Trim_Image (Config.Window_Opacity_Percent) & "%",
           when Background_Blur => On_Off (Config.Background_Blur),
           when Content_Padding => Trim_Image (Config.Content_Padding) & " px",
           when Always_On_Top => On_Off (Config.Always_On_Top),
           when Focus_Mode => On_Off (Config.Focus_Mode),
           when Window_Decorations => On_Off (Config.Window_Decorations),
           when Shell_Integration => On_Off (Config.Shell_Integration),
           when Desktop_Notifications => On_Off (Config.Desktop_Notifications),
           when Bell_Notifications => On_Off (Config.Bell_Notifications),
           when Completion_Notifications =>
             On_Off (Config.Command_Completion_Notifications),
           when Protected_Input => On_Off (Config.Protected_Input),
           when Default_Profile =>
             (if Profile_Index = 0 then "none"
              else Terminal.App.Session_Profiles.Name
                (Terminal.App.Session_Profiles.Item
                   (Config.Session_Profiles, Profile_Index))),
           when Config_Line =>
             (if Item.Is_Editing
              then Item.Line (1 .. Item.Line_Length)
              else "press Enter; e.g. profile.work.command = tmux"),
           when Import_Config | Export_Config =>
             (if Item.Is_Editing
              then Item.Line (1 .. Item.Line_Length)
              else "press Enter, then type a config path"));
      Name : constant String :=
        (case Item.Current is
           when Theme => "theme",
           when Follow_System_Theme => "follow system theme",
           when Font_Size => "font size",
           when Wheel_Lines => "wheel lines",
           when Window_Opacity => "window opacity",
           when Background_Blur => "background blur",
           when Content_Padding => "content padding",
           when Always_On_Top => "always on top",
           when Focus_Mode => "focus mode",
           when Window_Decorations => "window decorations",
           when Shell_Integration => "shell integration",
           when Desktop_Notifications => "desktop notifications",
           when Bell_Notifications => "bell notifications",
           when Completion_Notifications => "completion notifications",
           when Protected_Input => "protected input",
           when Default_Profile => "default profile",
           when Config_Line => "config/profile line",
           when Import_Config => "import config",
           when Export_Config => "export config");
   begin
      if not Item.Is_Active then return ""; end if;
      return "SETTINGS " & Name & ": " & Value
        & (if Item.Message_Length = 0 then ""
           else " [" & Item.Message (1 .. Item.Message_Length) & "]")
        & "  (Up/Down item, Left/Right change)";
   end Status_Label;
end Terminal.App.Settings;
